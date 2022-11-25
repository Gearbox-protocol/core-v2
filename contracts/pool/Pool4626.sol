// SPDX-License-Identifier: BUSL-1.1
// Gearbox Protocol. Generalized leverage for DeFi protocols
// (c) Gearbox Holdings, 2022
pragma solidity ^0.8.10;

import { ERC20 } from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { Address } from "@openzeppelin/contracts/utils/Address.sol";
import { IERC20Metadata } from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import { SafeERC20 } from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import { ReentrancyGuard } from "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import { EnumerableSet } from "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";
import { IWETH } from "../interfaces/external/IWETH.sol";

import { AddressProvider } from "../core/AddressProvider.sol";
import { ACLTrait } from "../core/ACLTrait.sol";

import { IInterestRateModel } from "../interfaces/IInterestRateModel.sol";
import { IPool4626 } from "../interfaces/IPool4626.sol";
import { ICreditManagerV2 } from "../interfaces/ICreditManagerV2.sol";

import { RAY, PERCENTAGE_FACTOR, SECONDS_PER_YEAR, MAX_WITHDRAW_FEE } from "../libraries/Constants.sol";
import { Errors } from "../libraries/Errors.sol";
import { FixedPointMathLib } from "../libraries/SolmateMath.sol";

// EXCEPTIONS
import { ZeroAddressException } from "../interfaces/IErrors.sol";

struct CreditManagerDebt {
    uint128 totalBorrowed;
    uint128 limit;
}

/// @title Pool contract compatible with ERC4626
/// @notice Implements pool & diesel token business logic
contract Pool4626 is ERC20, IPool4626, ACLTrait, ReentrancyGuard {
    using FixedPointMathLib for uint256;
    using EnumerableSet for EnumerableSet.AddressSet;
    using SafeERC20 for IERC20;
    using Address for address payable;

    /// @dev The pool's underlying asset
    address public immutable override underlyingToken;

    /// @dev Diesel token Decimals
    uint8 internal immutable _decimals;

    /// @dev The limit on expected (total) liquidity
    uint256 public override expectedLiquidityLimit;

    /// @dev Expected liquidity at last update (LU)
    uint128 internal _expectedLiquidityLU;

    /// @dev Total borrowed amount
    uint128 internal _totalBorrowed;

    /// @dev Address provider
    address public immutable override addressProvider;

    /// @dev Interest rate model
    IInterestRateModel public interestRateModel;

    /// @dev Map from Credit Manager addresses to the status of their ability to borrow
    mapping(address => CreditManagerDebt) internal creditManagersDebt;

    /// @dev The list of all Credit Managers
    EnumerableSet.AddressSet internal creditManagerSet;

    /// @dev Address of the protocol treasury
    address public immutable treasuryAddress;

    /// @dev The cumulative interest index at last update
    uint256 public override _cumulativeIndex_RAY;

    /// @dev The current borrow rate
    uint128 internal _borrowAPY_RAY;

    /// @dev Timestamp of last update
    uint64 public override _timestampLU;

    /// @dev Withdrawal fee in PERCENTAGE FORMAT
    uint16 public override withdrawFee;

    /// @dev Contract version
    uint256 public constant override version = 2_01;

    /// @dev Asset is fee token
    bool internal immutable isFeeToken;

    /// @dev Asset is fee token
    address internal immutable wethAddress;

    //
    // CONSTRUCTOR
    //

    /// @dev Constructor
    /// @param _addressProvider Address provider
    /// @param _underlyingToken Address of the underlying token
    /// @param _interestRateModelAddress Address of the initial interest rate model
    constructor(
        address _addressProvider,
        address _underlyingToken,
        address _interestRateModelAddress,
        uint256 _expectedLiquidityLimit,
        bool _isFeeToken
    )
        ACLTrait(_addressProvider)
        ERC20(
            string(
                abi.encodePacked(
                    "diesel ",
                    _underlyingToken != address(0)
                        ? IERC20Metadata(_underlyingToken).name()
                        : ""
                )
            ),
            string(
                abi.encodePacked(
                    "d",
                    _underlyingToken != address(0)
                        ? IERC20Metadata(_underlyingToken).symbol()
                        : ""
                )
            )
        )
    {
        // Additional check that receiver is not address(0)
        if (
            _addressProvider == address(0) ||
            _underlyingToken == address(0) ||
            _interestRateModelAddress == address(0)
        ) {
            revert ZeroAddressException();
        }

        addressProvider = _addressProvider;
        underlyingToken = _underlyingToken;
        _decimals = IERC20Metadata(_underlyingToken).decimals();

        treasuryAddress = AddressProvider(_addressProvider)
            .getTreasuryContract();

        _timestampLU = uint64(block.timestamp);
        _cumulativeIndex_RAY = RAY;
        _updateInterestRateModel(_interestRateModelAddress);
        expectedLiquidityLimit = _expectedLiquidityLimit;
        isFeeToken = _isFeeToken;
        wethAddress = AddressProvider(_addressProvider).getWethToken();
    }

    //
    // ERC-4626 LOGIC
    //

    //
    // DEPOSIT/WITHDRAWAL LOGIC
    //

    /// @dev Deposit liquidity to the pool with referral code
    /// Mints shares Vault shares to receiver by depositing exactly assets of underlying tokens.
    /// MUST emit the Deposit event.
    /// MUST support EIP-20 approve / transferFrom on asset as a deposit flow. MAY support an additional flow in which the underlying tokens are owned by the Vault contract before the deposit execution, and are accounted for during deposit.
    /// MUST revert if all of assets cannot be deposited (due to deposit limit being reached, slippage, the user not approving enough underlying tokens to the Vault contract, etc).
    /// Note that most implementations will require pre-approval of the Vault with the Vault’s underlying asset token.
    /// @param assets Amount of underlying tokens to be deposited
    /// @param receiver The address that will receive the dToken
    function deposit(uint256 assets, address receiver)
        external
        override
        whenNotPaused
        nonReentrant
        returns (uint256 shares)
    {
        shares = _deposit(assets, receiver);
    }

    /// @dev Deposit liquidity to the pool with referral code
    /// @param assets Amount of underlying tokens to be deposited
    /// @param receiver The address that will receive the dToken
    /// @param referralCode Code used to register the integrator originating the operation, for potential rewards.
    ///   0 if the action is executed directly by the user, without a facilitator.
    function depositReferral(
        uint256 assets,
        address receiver,
        uint256 referralCode
    )
        external
        override
        whenNotPaused // T:[PS-4]
        nonReentrant
        returns (uint256 shares)
    {
        shares = _deposit(assets, receiver);
        emit DepositReferral(msg.sender, receiver, assets, referralCode); // T:[PS-2, 7]
    }

    /// @dev Deposit ETH liquidity to the WETH pool only with referral code
    /// @param receiver The address that will receive the dToken
    /// @param referralCode Code used to register the integrator originating the operation, for potential rewards.
    ///   0 if the action is executed directly by the user, without a facilitator.
    function depositETHReferral(address receiver, uint256 referralCode)
        external
        payable
        override
        whenNotPaused // T:[PS-4]
        nonReentrant
        returns (uint256 shares)
    {
        if (underlyingToken != wethAddress) revert AssetIsNotWETHException();
        if (receiver == address(0)) revert ZeroAddressException();

        IWETH(wethAddress).deposit{ value: msg.value }();

        uint256 assets = msg.value;
        shares = convertToShares(assets);

        _addLiquidity(receiver, assets, shares);
        emit DepositReferral(msg.sender, receiver, assets, referralCode); // T:[PS-2, 7]
    }

    /// @dev Mints exactly shares Vault shares to receiver by depositing assets of underlying tokens.
    // MUST emit the Deposit event.
    // MUST support EIP-20 approve / transferFrom on asset as a mint flow. MAY support an additional flow in which the underlying tokens are owned by the Vault contract before the mint execution, and are accounted for during mint.
    // MUST revert if all of shares cannot be minted (due to deposit limit being reached, slippage, the user not approving enough underlying tokens to the Vault contract, etc).
    // Note that most implementations will require pre-approval of the Vault with the Vault’s underlying asset token.
    function mint(uint256 shares, address receiver)
        external
        override
        whenNotPaused
        nonReentrant
        returns (uint256 assets)
    {
        // Additional check that receiver is not address(0)
        if (receiver == address(0)) revert ZeroAddressException();

        assets = previewMint(shares); // No need to check for rounding error, previewMint rounds up.
        uint256 assetsTransferred = _feeSafeTransfer(assets);

        if (assetsTransferred != assets) {
            assets = assetsTransferred;
            shares = convertToShares(assets);
        }

        _addLiquidity(receiver, assets, shares);
    }

    //
    // LIQUIDITY INTERNAL
    //
    function _deposit(uint256 assets, address receiver)
        internal
        returns (uint256 shares)
    {
        if (receiver == address(0)) revert ZeroAddressException();

        assets = _feeSafeTransfer(assets);
        shares = convertToShares(assets);

        _addLiquidity(receiver, assets, shares);
    }

    function _feeSafeTransfer(uint256 amount) internal returns (uint256) {
        uint256 balanceBefore;
        if (isFeeToken) {
            balanceBefore = IERC20(underlyingToken).balanceOf(address(this));
        }
        IERC20(underlyingToken).safeTransferFrom(
            msg.sender,
            address(this),
            amount
        ); // T:[PS-2, 7]

        return
            isFeeToken
                ? IERC20(underlyingToken).balanceOf(address(this)) -
                    balanceBefore
                : amount;
    }

    function _addLiquidity(
        address receiver,
        uint256 assets,
        uint256 shares
    ) internal {
        if (expectedLiquidity() + assets > expectedLiquidityLimit) {
            revert ExpectedLiquidityLimitException();
        }

        _expectedLiquidityLU += uint128(assets); // T:[PS-2, 7]
        _updateBorrowRate(availableLiquidity() + assets); // T:[PS-2, 7]
        _mint(receiver, shares); // T:[PS-2, 7]

        emit Deposit(msg.sender, receiver, assets, shares); // T:[PS-2, 7]
    }

    /// @dev Removes liquidity from pool
    /// Burns shares from owner and sends exactly assets of underlying tokens to receiver.
    // MUST emit the Withdraw event.
    // MUST support a withdraw flow where the shares are burned from owner directly where owner is msg.sender.
    // MUST support a withdraw flow where the shares are burned from owner directly where msg.sender has EIP-20 approval over the shares of owner.
    // MAY support an additional flow in which the shares are transferred to the Vault contract before the withdraw execution, and are accounted for during withdraw.
    // SHOULD check msg.sender can spend owner funds, assets needs to be converted to shares and shares should be checked for allowance.
    // MUST revert if all of assets cannot be withdrawn (due to withdrawal limit being reached, slippage, the owner not having enough shares, etc).
    // Note that some implementations will require pre-requesting to the Vault before a withdrawal may be performed. Those methods should be performed separately.
    function withdraw(
        uint256 assets,
        address receiver,
        address owner
    ) external override whenNotPaused nonReentrant returns (uint256 shares) {
        shares = previewWithdraw(assets);
        _removeLiquidity(assets, shares, receiver, owner, false);
    }

    function withdrawETH(
        uint256 assets,
        address receiver,
        address owner
    ) external override whenNotPaused nonReentrant returns (uint256 shares) {
        if (underlyingToken != wethAddress) revert AssetIsNotWETHException();
        shares = previewWithdraw(assets);
        _removeLiquidity(assets, shares, receiver, owner, true);
    }

    /// @dev  Burns exactly shares from owner and sends assets of underlying tokens to receiver.
    // MUST emit the Withdraw event.
    // MUST support a redeem flow where the shares are burned from owner directly where owner is msg.sender.
    // MUST support a redeem flow where the shares are burned from owner directly where msg.sender has EIP-20 approval over the shares of owner.
    // MAY support an additional flow in which the shares are transferred to the Vault contract before the redeem execution, and are accounted for during redeem.
    // SHOULD check msg.sender can spend owner funds using allowance.
    // MUST revert if all of shares cannot be redeemed (due to withdrawal limit being reached, slippage, the owner not having enough shares, etc).
    // Note that some implementations will require pre-requesting to the Vault before a withdrawal may be performed. Those methods should be performed separately.
    function redeem(
        uint256 shares,
        address receiver,
        address owner
    ) external override whenNotPaused nonReentrant returns (uint256 assets) {
        assets = convertToAssets(shares);

        // Check for rounding error since we round down in previewRedeem.
        if (assets == 0) revert ZeroAssetsException();

        _removeLiquidity(assets, shares, receiver, owner, false);
    }

    function redeemETH(
        uint256 shares,
        address receiver,
        address owner
    ) external override whenNotPaused nonReentrant returns (uint256 assets) {
        if (underlyingToken != wethAddress) revert AssetIsNotWETHException();
        assets = convertToAssets(shares);

        // Check for rounding error since we round down in previewRedeem.
        if (assets == 0) revert ZeroAssetsException();

        _removeLiquidity(assets, shares, receiver, owner, true);
    }

    function _removeLiquidity(
        uint256 assets,
        uint256 shares,
        address receiver,
        address owner,
        bool convertWETH
    ) internal {
        if (receiver == address(0)) revert ZeroAddressException();

        if (msg.sender != owner) {
            uint256 allowed = allowance(owner, msg.sender); // Saves gas for limited approvals.

            if (allowed != type(uint256).max) {
                _spendAllowance(owner, msg.sender, shares);
            }
        }

        _expectedLiquidityLU -= uint128(assets); // T:[PS-3, 8]

        _updateBorrowRate(availableLiquidity() - assets); // T:[PS-3,8 ]

        if (withdrawFee > 0) {
            uint256 fee = (assets * withdrawFee) / PERCENTAGE_FACTOR;
            assets -= fee;

            IERC20(underlyingToken).safeTransfer(treasuryAddress, fee);
        } // T:[PS-3, 34]

        _burn(msg.sender, shares); // T:[PS-3, 8]

        if (convertWETH) {
            _unwrapWETH(receiver, assets);
        } else {
            IERC20(underlyingToken).safeTransfer(receiver, assets); // T:[PS-3, 34]
        }

        emit Withdraw(msg.sender, receiver, owner, assets, shares); // T:[PS-3, 8]
    }

    /// @dev Internal implementation for unwrapETH
    function _unwrapWETH(address to, uint256 amount) internal {
        IWETH(wethAddress).withdraw(amount); // T: [WG-7]
        payable(to).sendValue(amount); // T: [WG-7]
    }

    //
    //  ACCOUNTING LOGIC
    //

    /// @dev Returns the current exchange rate of Diesel tokens to underlying
    /// More info: https://dev.gearbox.fi/developers/pools/economy#diesel-rate
    function getDieselRate_RAY() public view override returns (uint256) {
        if (totalSupply() == 0) return RAY; // T:[PS-1]
        return (expectedLiquidity() * RAY) / totalSupply(); // T:[PS-6]
    }

    /// @dev The address of the underlying token used for the Vault for accounting, depositing, and withdrawing.
    function asset() external view returns (address) {
        return underlyingToken;
    }

    /// @dev Total amount of the underlying asset that is “managed” by Vault.
    function totalAssets() external view returns (uint256 assets) {
        return expectedLiquidity();
    }

    function decimals() public view virtual override returns (uint8) {
        return _decimals;
    }

    /// @dev Converts a quantity of the underlying to Diesel tokens
    /// The amount of shares that the Vault would exchange for the amount of assets provided, in an ideal scenario where all the conditions are met.
    // MUST NOT be inclusive of any fees that are charged against assets in the Vault.
    // MUST NOT show any variations depending on the caller.
    // MUST NOT reflect slippage or other on-chain conditions, when performing the actual exchange.
    // MUST NOT revert unless due to integer overflow caused by an unreasonably large input.
    // MUST round down towards 0.
    // This calculation MAY NOT reflect the “per-user” price-per-share, and instead should reflect the “average-user’s” price-per-share, meaning what the average user should expect to see when exchanging to and from.
    /// @param assets Amount in underlyingToken tokens to be converted to diesel tokens
    function convertToShares(uint256 assets)
        public
        view
        override
        returns (uint256 shares)
    {
        return (assets * RAY) / getDieselRate_RAY(); // T:[PS-24]
    }

    /// @dev Converts a quantity of Diesel tokens to the underlying
    /// The amount of assets that the Vault would exchange for the amount of shares provided, in an ideal scenario where all the conditions are met.
    // MUST NOT be inclusive of any fees that are charged against assets in the Vault.
    // MUST NOT show any variations depending on the caller.
    // MUST NOT reflect slippage or other on-chain conditions, when performing the actual exchange.
    // MUST NOT revert unless due to integer overflow caused by an unreasonably large input.
    // MUST round down towards 0.
    // This calculation MAY NOT reflect the “per-user” price-per-share, and instead should reflect the “average-user’s” price-per-share, meaning what the average user should expect to see when exchanging to and from.
    /// @param shares Amount in diesel tokens to be converted to diesel tokens
    function convertToAssets(uint256 shares)
        public
        view
        override
        returns (uint256 assets)
    {
        return (shares * getDieselRate_RAY()) / RAY; // T:[PS-24]
    }

    /// @dev Maximum amount of the underlying asset that can be deposited into the Vault for the receiver, through a deposit call.
    // MUST return the maximum amount of assets deposit would allow to be deposited for receiver and not cause a revert, which MUST NOT be higher than the actual maximum that would be accepted (it should underestimate if necessary). This assumes that the user has infinite assets, i.e. MUST NOT rely on balanceOf of asset.
    // MUST factor in both global and user-specific limits, like if deposits are entirely disabled (even temporarily) it MUST return 0.
    // MUST return 2 ** 256 - 1 if there is no limit on the maximum amount of assets that may be deposited.
    // MUST NOT revert.

    function maxDeposit(address) external view returns (uint256) {
        return
            (expectedLiquidityLimit == type(uint256).max)
                ? type(uint256).max
                : expectedLiquidityLimit - expectedLiquidity();
    }

    /// Allows an on-chain or off-chain user to simulate the effects of their deposit at the current block, given current on-chain conditions.
    // MUST return as close to and no more than the exact amount of Vault shares that would be minted in a deposit call in the same transaction. I.e. deposit should return the same or more shares as previewDeposit if called in the same transaction.
    // MUST NOT account for deposit limits like those returned from maxDeposit and should always act as though the deposit would be accepted, regardless if the user has enough tokens approved, etc.
    // MUST be inclusive of deposit fees. Integrators should be aware of the existence of deposit fees.
    // MUST NOT revert due to vault specific user/global limits. MAY revert due to other conditions that would also cause deposit to revert.
    // Note that any unfavorable discrepancy between convertToShares and previewDeposit SHOULD be considered slippage in share price or some other type of condition, meaning the depositor will lose assets by depositing.
    function previewDeposit(uint256 assets)
        public
        view
        override
        returns (uint256)
    {
        return convertToShares(assets);
    }

    /// @dev Maximum amount of shares that can be minted from the Vault for the receiver, through a mint call.
    /// MUST return the maximum amount of shares mint would allow to be deposited to receiver and not cause a revert, which MUST NOT be higher than the actual maximum that would be accepted (it should underestimate if necessary). This assumes that the user has infinite assets, i.e. MUST NOT rely on balanceOf of asset.
    /// MUST factor in both global and user-specific limits, like if mints are entirely disabled (even temporarily) it MUST return 0.
    /// MUST return 2 ** 256 - 1 if there is no limit on the maximum amount of shares that may be minted.
    /// MUST NOT revert.

    function maxMint(address) external view returns (uint256) {
        uint256 limit = expectedLiquidityLimit;
        return
            (limit == type(uint256).max)
                ? type(uint256).max
                : convertToShares(limit - expectedLiquidity());
    }

    /// @dev Allows an on-chain or off-chain user to simulate the effects of their mint at the current block, given current on-chain conditions.
    /// MUST return as close to and no fewer than the exact amount of assets that would be deposited in a mint call in the same transaction. I.e. mint should return the same or fewer assets as previewMint if called in the same transaction.
    /// MUST NOT account for mint limits like those returned from maxMint and should always act as though the mint would be accepted, regardless if the user has enough tokens approved, etc.
    /// MUST be inclusive of deposit fees. Integrators should be aware of the existence of deposit fees.
    /// MUST NOT revert due to vault specific user/global limits. MAY revert due to other conditions that would also cause mint to revert.
    /// Note that any unfavorable discrepancy between convertToAssets and previewMint SHOULD be considered slippage in share price or some other type of condition, meaning the depositor will lose assets by minting.
    function previewMint(uint256 shares) public view virtual returns (uint256) {
        uint256 supply = totalSupply(); // Saves an extra SLOAD if totalSupply is non-zero.

        return supply == 0 ? shares : convertToAssets(shares); // We need to round up shares.mulDivUp(totalAssets(), supply);
    }

    /// @dev Maximum amount of the underlying asset that can be withdrawn from the owner balance in the Vault, through a withdraw call.
    /// MUST return the maximum amount of assets that could be transferred from owner through withdraw and not cause a revert, which MUST NOT be higher than the actual maximum that would be accepted (it should underestimate if necessary).
    /// MUST factor in both global and user-specific limits, like if withdrawals are entirely disabled (even temporarily) it MUST return 0.
    /// MUST NOT revert.
    function maxWithdraw(address owner) external view returns (uint256) {
        return availableLiquidity().min(previewWithdraw(balanceOf(owner)));
    }

    /// @dev Allows an on-chain or off-chain user to simulate the effects of their withdrawal at the current block, given current on-chain conditions.
    // MUST return as close to and no fewer than the exact amount of Vault shares that would be burned in a withdraw call in the same transaction. I.e. withdraw should return the same or fewer shares as previewWithdraw if called in the same transaction.
    // MUST NOT account for withdrawal limits like those returned from maxWithdraw and should always act as though the withdrawal would be accepted, regardless if the user has enough shares, etc.
    // MUST be inclusive of withdrawal fees. Integrators should be aware of the existence of withdrawal fees.
    // MUST NOT revert due to vault specific user/global limits. MAY revert due to other conditions that would also cause withdraw to revert.
    // Note that any unfavorable discrepancy between convertToShares and previewWithdraw SHOULD be considered slippage in share price or some other type of condition, meaning the depositor will lose assets by depositing.
    function previewWithdraw(uint256 assets)
        public
        view
        override
        returns (uint256)
    {
        uint256 supply = totalSupply(); // Saves an extra SLOAD if totalSupply is non-zero.
        return
            supply == 0 ? assets : assets.mulDivUp(supply, expectedLiquidity());
    }

    /// @dev Maximum amount of Vault shares that can be redeemed from the owner balance in the Vault, through a redeem call.
    // MUST return the maximum amount of shares that could be transferred from owner through redeem and not cause a revert, which MUST NOT be higher than the actual maximum that would be accepted (it should underestimate if necessary).
    // MUST factor in both global and user-specific limits, like if redemption is entirely disabled (even temporarily) it MUST return 0.
    // MUST NOT revert.
    function maxRedeem(address owner) external view returns (uint256 shares) {
        shares = balanceOf(owner);
        uint256 assets = convertToAssets(shares);
        uint256 assetsAvailable = availableLiquidity();
        if (assets > assetsAvailable) {
            shares = previewWithdraw(assetsAvailable);
        }
    }

    /// @dev Allows an on-chain or off-chain user to simulate the effects of their redeemption at the current block, given current on-chain conditions.
    // MUST return as close to and no more than the exact amount of assets that would be withdrawn in a redeem call in the same transaction. I.e. redeem should return the same or more assets as previewRedeem if called in the same transaction.
    // MUST NOT account for redemption limits like those returned from maxRedeem and should always act as though the redemption would be accepted, regardless if the user has enough shares, etc.
    // MUST be inclusive of withdrawal fees. Integrators should be aware of the existence of withdrawal fees.
    // MUST NOT revert due to vault specific user/global limits. MAY revert due to other conditions that would also cause redeem to revert.
    // Note that any unfavorable discrepancy between convertToAssets and previewRedeem SHOULD be considered slippage in share price or some other type of condition, meaning the depositor will lose assets by redeeming.
    function previewRedeem(uint256 shares)
        public
        view
        override
        returns (uint256)
    {
        return convertToAssets(shares);
    }

    /// @return expected liquidity - the amount of money that should be in the pool
    /// after all users close their Credit accounts and fully repay debts
    function expectedLiquidity() public view override returns (uint256) {
        // timeDifference = blockTime - previous timeStamp
        uint256 timeDifference = block.timestamp - _timestampLU;

        //                                    currentBorrowRate * timeDifference
        //  interestAccrued = totalBorrow *  ------------------------------------
        //                                             SECONDS_PER_YEAR
        //
        uint256 interestAccrued = (_totalBorrowed *
            _borrowAPY_RAY *
            timeDifference) /
            RAY /
            SECONDS_PER_YEAR; // T:[PS-29]

        return _expectedLiquidityLU + interestAccrued; // T:[PS-29]
    }

    /// @dev Returns available liquidity in the pool (pool balance)
    function availableLiquidity() public view override returns (uint256) {
        return IERC20(underlyingToken).balanceOf(address(this));
    }

    //
    // CREDIT ACCOUNT LENDING
    //

    /// @dev Lends funds to a Credit Account and updates the pool parameters
    /// @param borrowedAmount Credit Account's debt principal
    /// @param creditAccount Credit Account's address

    function lendCreditAccount(uint256 borrowedAmount, address creditAccount)
        external
        override
        whenNotPaused // T:[PS-4]
    {
        CreditManagerDebt storage cmDebt = creditManagersDebt[msg.sender];
        uint256 limit = cmDebt.limit;

        if (cmDebt.totalBorrowed + borrowedAmount > limit) {
            revert CreditManagerCantBorrowException();
        } else {
            if (limit != type(uint256).max) {
                unchecked {
                    cmDebt.totalBorrowed += uint128(borrowedAmount);
                }
            }
        }

        // Increase total borrowed amount
        _totalBorrowed += uint128(borrowedAmount); // T:[PS-16]

        // Transfer funds to credit account
        IERC20(underlyingToken).safeTransfer(creditAccount, borrowedAmount); // T:[PS-14]

        // Update borrow Rate
        _updateBorrowRate(availableLiquidity()); // T:[PS-17]

        emit Borrow(msg.sender, creditAccount, borrowedAmount); // T:[PS-15]
    }

    /// @dev Registers Credit Account's debt repayment and updates parameters.
    /// Assumes that the underlying (including principal + interest + fees) was already transferred
    /// @param borrowedAmount Amount of principal ro repay
    /// @param profit The treasury profit from repayment
    /// @param loss Amount of underlying that the CA wan't able to repay
    function repayCreditAccount(
        uint256 borrowedAmount,
        uint256 profit,
        uint256 loss
    )
        external
        override
        whenNotPaused // T:[PS-4]
    {
        if (!creditManagerSet.contains(msg.sender)) {
            revert CreditManagerOnlyException();
        }

        _expectedLiquidityLU =
            _expectedLiquidityLU +
            uint128(profit) -
            uint128(loss);

        CreditManagerDebt storage cmDebt = creditManagersDebt[msg.sender];

        if (cmDebt.limit != type(uint256).max) {
            cmDebt.totalBorrowed -= uint128(borrowedAmount);
        }

        // Update borrow rate
        _updateBorrowRate(availableLiquidity());

        // Updating total borrowed
        _totalBorrowed -= uint128(borrowedAmount);

        // For fee surplus we mint tokens for treasury
        if (profit > 0) {
            _mint(treasuryAddress, convertToShares(profit));
        } else {
            // If returned money < borrowed amount + interest accrued
            // it tries to compensate loss by burning diesel (LP) tokens
            // from treasury fund
            uint256 sharesToBurn = convertToShares(loss); // T:[PS-19,20]
            uint256 sharesInTreasury = balanceOf(treasuryAddress); // T:[PS-19,20]

            if (sharesInTreasury < sharesToBurn) {
                sharesToBurn = sharesInTreasury;
                emit UncoveredLoss(
                    msg.sender,
                    loss - convertToAssets(sharesInTreasury)
                ); // T:[PS-23]
            }

            // If treasury has enough funds, it just burns needed amount
            // to keep diesel rate on the same level
            _burn(treasuryAddress, sharesToBurn); // T:[PS-19, 20]
        }

        emit Repay(msg.sender, borrowedAmount, profit, loss); // T:[PS-18]
    }

    //
    // INTEREST RATE MANAGEMENT
    //

    /**
     * @dev Calculates the most current value of the cumulative interest index
     *
     *                              /     currentBorrowRate * timeDifference \
     *  newIndex  = currentIndex * | 1 + ------------------------------------ |
     *                              \              SECONDS_PER_YEAR          /
     *
     * @return current cumulative index in RAY
     */
    function calcLinearCumulative_RAY() public view override returns (uint256) {
        //solium-disable-next-line
        uint256 timeDifference = block.timestamp - _timestampLU; // T:[PS-28]

        return
            calcLinearIndex_RAY(
                _cumulativeIndex_RAY,
                _borrowAPY_RAY,
                timeDifference
            ); // T:[PS-28]
    }

    /// @dev Calculates a new cumulative index value from the initial value, borrow rate and time elapsed
    /// @param cumulativeIndex_RAY Cumulative index at last update, in RAY
    /// @param currentBorrowRate_RAY Current borrow rate, in RAY
    /// @param timeDifference Time elapsed since last update, in seconds
    function calcLinearIndex_RAY(
        uint256 cumulativeIndex_RAY,
        uint256 currentBorrowRate_RAY,
        uint256 timeDifference
    ) public pure returns (uint256) {
        //                               /     currentBorrowRate * timeDifference \
        //  newIndex  = currentIndex *  | 1 + ------------------------------------ |
        //                               \              SECONDS_PER_YEAR          /
        //
        uint256 linearAccumulated_RAY = RAY +
            (currentBorrowRate_RAY * timeDifference) /
            SECONDS_PER_YEAR; // T:[GM-2]

        return (cumulativeIndex_RAY * linearAccumulated_RAY) / RAY; // T:[GM-2]
    }

    /// @dev Updates the borrow rate when liquidity parameters are changed
    /// @param _availableLiquidity Available liquidity used in calculations
    function _updateBorrowRate(uint256 _availableLiquidity) internal {
        // Update cumulativeIndex
        _cumulativeIndex_RAY = calcLinearCumulative_RAY(); // T:[PS-27]

        // update borrow APY
        _borrowAPY_RAY = uint128(
            interestRateModel.calcBorrowRate(
                _expectedLiquidityLU,
                _availableLiquidity
            )
        );
        _timestampLU = uint64(block.timestamp);
    }

    // GETTERS

    /// @dev Calculates the current borrow rate, RAY format
    function borrowAPY_RAY() external view returns (uint256) {
        return uint256(_borrowAPY_RAY);
    }

    ///  @dev Total borrowed amount (includes principal only)
    function totalBorrowed() external view returns (uint256) {
        return uint256(_totalBorrowed);
    }

    //
    // CONFIGURATION
    //

    /// @dev Connects a new Credit manager to pool
    /// @param _creditManager Address of the Credit Manager
    function connectCreditManager(address _creditManager)
        external
        configuratorOnly
    {
        require(
            address(this) == ICreditManagerV2(_creditManager).pool(),
            Errors.POOL_INCOMPATIBLE_CREDIT_ACCOUNT_MANAGER
        );

        creditManagerSet.add(_creditManager);
        emit NewCreditManagerConnected(_creditManager);
    }

    /// @dev Forbids a Credit Manager to borrow
    /// @param _creditManager Address of the Credit Manager
    function chnageCreditManagerLimit(address _creditManager, uint128 _limit)
        external
        controllerOnly
    {
        CreditManagerDebt storage cmDebt = creditManagersDebt[_creditManager];
        cmDebt.limit = _limit;
        emit BorrowLimitChanged(_creditManager, _limit);
    }

    /// @dev Sets the new interest rate model for the pool
    /// @param _interestRateModel Address of the new interest rate model contract
    function updateInterestRateModel(address _interestRateModel)
        public
        configuratorOnly // T:[PS-9]
    {
        _updateInterestRateModel(_interestRateModel);
    }

    /// @dev IMPLEMENTATION: updateInterestRateModel
    function _updateInterestRateModel(address _interestRateModel) internal {
        if (_interestRateModel == address(0)) revert ZeroAddressException();

        interestRateModel = IInterestRateModel(_interestRateModel); // T:[PS-25]
        _updateBorrowRate(availableLiquidity()); // T:[PS-26]
        emit NewInterestRateModel(_interestRateModel); // T:[PS-25]
    }

    /// @dev Sets a new expected liquidity limit
    /// @param newLimit New expected liquidity limit
    function setExpectedLiquidityLimit(uint256 newLimit)
        external
        controllerOnly // T:[PS-9]
    {
        expectedLiquidityLimit = newLimit; // T:[PS-30]
        emit NewExpectedLiquidityLimit(newLimit); // T:[PS-30]
    }

    /// @dev Sets a new withdrawal fee
    /// @param _withdrawFee The new fee amount, in bp
    function setWithdrawFee(uint16 _withdrawFee)
        public
        controllerOnly // T:[PS-9]
    {
        if (_withdrawFee > MAX_WITHDRAW_FEE) {
            revert IncorrectWithdrawalFeeException();
        }
        withdrawFee = _withdrawFee; // T:[PS-33]
        emit NewWithdrawFee(_withdrawFee); // T:[PS-33]
    }

    function creditManagers() external view returns (address[] memory) {
        return creditManagerSet.values();
    }

    /// @dev Total borrowed for particular credit manager
    function creditManagerBorrowed(address _creditManager)
        external
        view
        returns (uint256)
    {
        CreditManagerDebt storage cmDebt = creditManagersDebt[_creditManager];
        return cmDebt.totalBorrowed;
    }

    /// @dev Borrow limit for particular credit manager
    function creditManagerLimit(address _creditManager)
        external
        view
        returns (uint256)
    {
        CreditManagerDebt storage cmDebt = creditManagersDebt[_creditManager];
        return cmDebt.limit;
    }
}
