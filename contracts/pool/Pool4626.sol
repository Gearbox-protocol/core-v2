// SPDX-License-Identifier: BUSL-1.1
// Gearbox Protocol. Generalized leverage for DeFi protocols
// (c) Gearbox Holdings, 2022
pragma solidity ^0.8.10;

import { ERC20 } from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { Address } from "@openzeppelin/contracts/utils/Address.sol";
import { IERC20Metadata } from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import { SafeERC20 } from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import { EnumerableSet } from "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";

import { IWETH } from "../interfaces/external/IWETH.sol";
import { IERC4626 } from "../interfaces/IERC4626.sol";

import { AddressProvider } from "../core/AddressProvider.sol";
import { ContractsRegister } from "../core/ContractsRegister.sol";
import { ACLNonReentrantTrait } from "../core/ACLNonReentrantTrait.sol";

import { IInterestRateModel } from "../interfaces/IInterestRateModel.sol";
import { IPool4626, Pool4626Opts, QuotaUpdate } from "../interfaces/IPool4626.sol";
import { ICreditManagerV2 } from "../interfaces/ICreditManagerV2.sol";
import { IGauge } from "../interfaces/IGauge.sol";

import { RAY, PERCENTAGE_FACTOR, SECONDS_PER_YEAR, MAX_WITHDRAW_FEE } from "../libraries/Constants.sol";
import { Errors } from "../libraries/Errors.sol";
import { FixedPointMathLib } from "../libraries/SolmateMath.sol";

// EXCEPTIONS
import { ZeroAddressException } from "../interfaces/IErrors.sol";

import "forge-std/console.sol";

struct CreditManagerDebt {
    uint128 totalBorrowed;
    uint128 limit;
}

struct Quota {
    uint96 totalQuoted;
    uint96 limit;
    uint40 lastUpdate;
    uint16 rate; // current rate update
}

/// @title Core pool contract compatible with ERC4626
/// @notice Implements pool & diesel token business logic
contract Pool4626 is ERC20, IPool4626, ACLNonReentrantTrait {
    using FixedPointMathLib for uint256;
    using EnumerableSet for EnumerableSet.AddressSet;
    using SafeERC20 for IERC20;
    using Address for address payable;

    /// @dev Address provider
    address public immutable override addressProvider;

    /// @dev Address of the protocol treasury
    address public immutable treasuryAddress;

    /// @dev Asset is fee token
    address public immutable wethAddress;

    /// @dev The pool's underlying asset
    address public immutable override underlyingToken;

    /// @dev Diesel token Decimals
    uint8 internal immutable _decimals;

    /// @dev True if pool supports risk assets
    bool public immutable supportQuotaPremiums;

    /// @dev Contract version
    uint256 public constant override version = 2_1;

    // [SLOT #1]

    /// @dev Expected liquidity at last update (LU)
    uint128 internal _expectedLiquidityLU;

    /// @dev The current borrow rate
    uint128 internal _borrowRate_RAY;

    // [SLOT #2]

    /// @dev Total borrowed amount
    uint128 internal _totalBorrowed;

    /// @dev The cumulative interest index at last update
    uint128 public cumulativeIndexLU_RAY;

    // [SLOT #3]

    /// @dev Timestamp of last update
    uint64 public override timestampLU;

    /// @dev Interest rate model
    IInterestRateModel public interestRateModel;

    /// @dev Withdrawal fee in PERCENTAGE FORMAT
    uint16 public override withdrawFee;

    /// LIMITS

    // [SLOT #4]

    /// @dev Total borrowed amount
    uint128 internal _totalBorrowedLimit;

    /// @dev The limit on expected (total) liquidity
    uint128 internal _expectedLiquidityLimit;

    /// @dev Map from Credit Manager addresses to the status of their ability to borrow
    mapping(address => CreditManagerDebt) internal creditManagersDebt;

    /// @dev The list of all Credit Managers
    EnumerableSet.AddressSet internal creditManagerSet;

    /// @dev The list of all Credit Managers
    EnumerableSet.AddressSet internal quotaTokensSet;

    /// @dev
    mapping(address => Quota) public quotas;

    /// @dev IGauge
    IGauge public gauge;

    modifier wethPoolOnly() {
        if (underlyingToken != wethAddress) revert AssetIsNotWETHException(); // F:[P4-5]
        _;
    }

    modifier gaugeOnly() {
        /// TODO: udpate exception
        if (msg.sender == address(gauge)) revert AssetIsNotWETHException(); // F:[P4-5]
        _;
    }

    modifier creditManagerWithActiveDebtOnly() {
        if (creditManagersDebt[msg.sender].totalBorrowed == 0) {
            /// todo: add correct exception ??
            revert CreditManagerOnlyException();
        }
        _;
    }

    //
    // CONSTRUCTOR
    //

    /// @dev Constructor
    /// @param opts Core pool options
    constructor(Pool4626Opts memory opts)
        ACLNonReentrantTrait(opts.addressProvider)
        ERC20(
            string(
                abi.encodePacked(
                    "diesel ",
                    opts.underlyingToken != address(0)
                        ? IERC20Metadata(opts.underlyingToken).name()
                        : ""
                )
            ),
            string(
                abi.encodePacked(
                    "d",
                    opts.underlyingToken != address(0)
                        ? IERC20Metadata(opts.underlyingToken).symbol()
                        : ""
                )
            )
        ) // F:[P4-01]
    {
        // Additional check that receiver is not address(0)
        if (
            opts.addressProvider == address(0) ||
            opts.underlyingToken == address(0) ||
            opts.interestRateModel == address(0)
        ) {
            revert ZeroAddressException(); // F:[P4-02]
        }

        addressProvider = opts.addressProvider; // F:[P4-01]
        underlyingToken = opts.underlyingToken; // F:[P4-01]
        _decimals = IERC20Metadata(opts.underlyingToken).decimals(); // F:[P4-01]

        treasuryAddress = AddressProvider(opts.addressProvider)
            .getTreasuryContract(); // F:[P4-01]

        timestampLU = uint64(block.timestamp); // F:[P4-01]
        cumulativeIndexLU_RAY = uint128(RAY); // F:[P4-01]

        interestRateModel = IInterestRateModel(opts.interestRateModel);
        emit NewInterestRateModel(opts.interestRateModel); // F:[P4-03]

        _setExpectedLiquidityLimit(opts.expectedLiquidityLimit); // F:[P4-01, 03]
        _setTotalBorrowedLimit(opts.expectedLiquidityLimit); // F:[P4-03]
        supportQuotaPremiums = opts.supportQuotaPremiums; // F:[P4-01]
        wethAddress = AddressProvider(opts.addressProvider).getWethToken(); // F:[P4-01]
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
        whenNotPaused // F:[P4-4]
        nonReentrant
        returns (uint256 shares)
    {
        shares = _deposit(assets, receiver); // F:[P4-6]
    }

    /// @dev Deposit liquidity to the pool with referral code
    /// @param assets Amount of underlying tokens to be deposited
    /// @param receiver The address that will receive the dToken
    /// @param referralCode Code used to register the integrator originating the operation, for potential rewards.
    ///   0 if the action is executed directly by the user, without a facilitator.
    function depositReferral(
        uint256 assets,
        address receiver,
        uint16 referralCode
    )
        external
        override
        whenNotPaused // F:[P4-4]
        nonReentrant
        returns (uint256 shares)
    {
        shares = _deposit(assets, receiver); // F:[P4-6]
        emit DepositReferral(msg.sender, receiver, assets, referralCode); // F:[P4-6]
    }

    /// @dev Deposit ETH liquidity to the WETH pool only with referral code
    /// @param receiver The address that will receive the dToken
    /// @param referralCode Code used to register the integrator originating the operation, for potential rewards.
    ///   0 if the action is executed directly by the user, without a facilitator.
    function depositETHReferral(address receiver, uint16 referralCode)
        external
        payable
        override
        whenNotPaused // F:[P4-4]
        // nonReentrant moved to internal function to make check for receive() and this function in one place
        wethPoolOnly // F:[P4-6]
        returns (uint256 shares)
    {
        shares = _depositETHReferral(receiver, referralCode); // F:[P4-7]
    }

    /// @dev Sending ETH directly works
    /// TODO: check if someone will use pool address during CA closure or liquidation with ETH transfer
    receive()
        external
        payable
        wethPoolOnly // F:[P4-5]
        whenNotPaused // F:[P4-4]
    {
        if (msg.sender != wethAddress) {
            _depositETHReferral(msg.sender, 0); // F:[P4-7]
        }
    }

    /// @dev Mints exactly shares Vault shares to receiver by depositing assets of underlying tokens.
    // MUST emit the Deposit event.
    // MUST support EIP-20 approve / transferFrom on asset as a mint flow. MAY support an additional flow in which the underlying tokens are owned by the Vault contract before the mint execution, and are accounted for during mint.
    // MUST revert if all of shares cannot be minted (due to deposit limit being reached, slippage, the user not approving enough underlying tokens to the Vault contract, etc).
    // Note that most implementations will require pre-approval of the Vault with the Vault’s underlying asset token.
    function mint(uint256 shares, address receiver)
        external
        override
        whenNotPaused // F:[P4-4]
        nonReentrant
        returns (uint256 assets)
    {
        // Additional check that receiver is not address(0)
        if (receiver == address(0)) revert ZeroAddressException();

        // No need to check for rounding error, previewMint rounds up.
        assets = previewMint(shares); // F:[P4-4]

        uint256 assetsTransferred = _safeDepositAssets(assets); // F:[P4-8]

        /// TODO: add check for fee token
        if (assetsTransferred != assets) {
            shares = convertToShares(assetsTransferred); // F:[P4-8]
        }

        _addLiquidity(receiver, assets, assetsTransferred, shares); // F:[P4-8]
    }

    //
    // LIQUIDITY INTERNAL
    //
    function _deposit(uint256 assets, address receiver)
        internal
        returns (uint256 shares)
    {
        if (receiver == address(0)) revert ZeroAddressException();

        uint256 assetsReceived = _safeDepositAssets(assets);
        shares = convertToShares(assetsReceived);

        _addLiquidity(receiver, assets, assetsReceived, shares);
    }

    function _depositETHReferral(address receiver, uint16 referralCode)
        internal
        nonReentrant // non-reentrancy check moved here to be able to use it in receive() and depositWithdrawal functions
        returns (uint256 shares)
    {
        IWETH(wethAddress).deposit{ value: msg.value }();

        uint256 assets = msg.value;
        shares = convertToShares(assets);

        _addLiquidity(receiver, assets, assets, shares);
        emit DepositReferral(msg.sender, receiver, assets, referralCode); // T:[PS-2, 7]
    }

    function _addLiquidity(
        address receiver,
        uint256 assetsSent,
        uint256 assetsReceived,
        uint256 shares
    ) internal {
        /// Interst rate calculatiuon??
        if (
            expectedLiquidity() + assetsReceived >
            uint256(_expectedLiquidityLimit)
        ) {
            revert ExpectedLiquidityLimitException();
        }

        int256 assetsSigned = int256(assetsReceived); // F:[P4-4]

        _updateBaseParameters(assetsSigned, assetsSigned, false); // F:[P4-4]

        _mint(receiver, shares); // F:[P4-4]

        emit Deposit(msg.sender, receiver, assetsSent, shares); // F:[P4-4]
    }

    function _safeDepositAssets(uint256 amount) internal returns (uint256) {
        return _safeUnderlyingTransfer(address(this), amount);
    }

    function _safeUnderlyingTransfer(address to, uint256 amount)
        internal
        virtual
        returns (uint256)
    {
        IERC20(underlyingToken).safeTransferFrom(msg.sender, to, amount);
        return amount;
    }

    function _amountWithFee(uint256 amount)
        internal
        view
        virtual
        returns (uint256)
    {
        return amount;
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
    )
        external
        override
        whenNotPaused // F:[P4-4]
        nonReentrant
        returns (uint256 shares)
    {
        shares = previewWithdraw(assets);
        _removeLiquidity(assets, shares, receiver, owner, false);
    }

    function withdrawETH(
        uint256 assets,
        address receiver,
        address owner
    )
        external
        override
        whenNotPaused // F:[P4-4]
        nonReentrant
        wethPoolOnly // F:[P4-5]
        returns (uint256 shares)
    {
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
    )
        external
        override
        whenNotPaused // F:[P4-4]
        nonReentrant
        returns (uint256 assets)
    {
        assets = convertToAssets(shares);

        // Check for rounding error since we round down in previewRedeem.
        if (assets == 0) revert ZeroAssetsException();

        _removeLiquidity(assets, shares, receiver, owner, false);
    }

    function redeemETH(
        uint256 shares,
        address receiver,
        address owner
    )
        external
        override
        whenNotPaused // F:[P4-4]
        nonReentrant
        wethPoolOnly // F:[P4-5]
        returns (uint256 assets)
    {
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

        _updateBaseParameters(-int256(assets), -int256(assets), false);

        if (withdrawFee > 0) {
            unchecked {
                /// It's safe because we made a check that assets < uint128, and withDrawFee is < 10K
                uint256 withdrawFeeAmount = (assets * withdrawFee) /
                    PERCENTAGE_FACTOR;
                assets -= withdrawFeeAmount;

                IERC20(underlyingToken).safeTransfer(
                    treasuryAddress,
                    withdrawFeeAmount
                );
            }
        }

        _burn(msg.sender, shares);

        _withdrawAssets(receiver, assets, convertWETH);

        emit Withdraw(msg.sender, receiver, owner, assets, shares);
    }

    /// @dev Send assets back to user
    function _withdrawAssets(
        address receiver,
        uint256 assets,
        bool convertWETH
    ) internal virtual {
        if (convertWETH) {
            _unwrapWETH(receiver, assets);
        } else {
            IERC20(underlyingToken).safeTransfer(receiver, assets);
        }
    }

    /// @dev Internal implementation for unwrapETH
    function _unwrapWETH(address to, uint256 amount) internal {
        IWETH(wethAddress).withdraw(amount);
        payable(to).sendValue(amount);
    }

    function burn(uint256 shares)
        external
        override
        whenNotPaused // TODO: Add test
        nonReentrant
    {
        _burn(msg.sender, shares);
    }

    //
    //  ACCOUNTING LOGIC
    //

    /// @dev Returns the current exchange rate of Diesel tokens to underlying
    function getDieselRate_RAY() public view override returns (uint256) {
        if (totalSupply() == 0) return RAY; // F:[P4-1]

        return (uint256(expectedLiquidity()) * RAY) / totalSupply(); // F:[P4-4]
    }

    /// @dev The address of the underlying token used for the Vault for accounting, depositing, and withdrawing.
    function asset() external view returns (address) {
        return underlyingToken;
    }

    /// @dev Total amount of the underlying asset that is “managed” by Vault.
    function totalAssets() external view returns (uint256 assets) {
        return expectedLiquidity();
    }

    /// @dev Rerutn diesel token decimals
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
        return (assets * RAY) / getDieselRate_RAY();
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
            (_expectedLiquidityLimit == type(uint128).max)
                ? type(uint256).max
                : _expectedLiquidityLimit - expectedLiquidity();
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
        uint128 limit = _expectedLiquidityLimit;
        return
            (limit == type(uint128).max)
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

        return _amountWithFee(supply == 0 ? shares : convertToAssets(shares)); // We need to round up shares.mulDivUp(totalAssets(), supply);
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
        return
            _expectedLiquidityLU +
            _calcBaseInterestAccrued() +
            (supportQuotaPremiums ? _calcQuotasPremiums() : 0); //
    }

    function _calcBaseInterestAccrued() internal view returns (uint256) {
        // timeDifference = blockTime - previous timeStamp
        uint256 timeDifference = block.timestamp - timestampLU;

        //                                    currentBorrowRate * timeDifference
        //  interestAccrued = totalBorrow *  ------------------------------------
        //                                             SECONDS_PER_YEAR
        //
        return
            (uint256(_totalBorrowed) * _borrowRate_RAY * timeDifference) /
            RAY /
            SECONDS_PER_YEAR;
    }

    function _calcQuotasPremiums()
        internal
        view
        returns (uint256 quotaPremiums)
    {
        address[] memory quotaAddrs = quotaTokensSet.values();
        uint256 quotasLen = quotaAddrs.length;
        for (uint256 i; i < quotasLen; ) {
            address token = quotaAddrs[i];
            /// TODO: check gas usage with memory comparison / stact extraction
            Quota storage q = quotas[token];
            quotaPremiums += _calcQuotaPremium(q, token);

            unchecked {
                ++i;
            }
        }
    }

    function _calcQuotaPremium(Quota storage q, address token)
        internal
        view
        returns (uint256 premium)
    {
        return
            (q.totalQuoted *
                IGauge(gauge).getQuotaRate(token) *
                (block.timestamp - q.lastUpdate)) /
            (PERCENTAGE_FACTOR * SECONDS_PER_YEAR);
    }

    /// @dev Returns available liquidity in the pool (pool balance)
    function availableLiquidity()
        public
        view
        virtual
        override
        returns (uint256)
    {
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
        whenNotPaused // F:[P4-4]
    {
        // Checks credit manager specific limi is not cross and udpate it
        CreditManagerDebt storage cmDebt = creditManagersDebt[msg.sender];

        if (
            cmDebt.totalBorrowed + borrowedAmount > cmDebt.limit ||
            borrowedAmount == 0
        ) {
            revert CreditManagerCantBorrowException();
        }
        cmDebt.totalBorrowed += uint128(borrowedAmount);

        // Increase total borrowed amount
        _totalBorrowed += uint128(borrowedAmount);

        // Reverts if total borrow more than limit
        if (_totalBorrowed > _totalBorrowedLimit) {
            revert CreditManagerCantBorrowException();
        }

        // Update borrow Rate, reverts of Uoptimal limit is set up
        _updateBaseParameters(0, -int256(borrowedAmount), true);

        // Transfer funds to credit account
        IERC20(underlyingToken).safeTransfer(creditAccount, borrowedAmount);

        emit Borrow(msg.sender, creditAccount, borrowedAmount);
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
        whenNotPaused // F:[P4-4]
    {
        // Updates credit manager specific totalBorrowed
        CreditManagerDebt storage cmDebt = creditManagersDebt[msg.sender];

        uint128 totalBorrowed = cmDebt.totalBorrowed;
        if (totalBorrowed == 0) {
            /// todo: add correct exception ??
            revert CreditManagerOnlyException();
        }

        // For fee surplus we mint tokens for treasury
        if (profit > 0) {
            _mint(treasuryAddress, convertToShares(profit));
        } else {
            // If returned money < borrowed amount + interest accrued
            // it tries to compensate loss by burning diesel (LP) tokens
            // from treasury fund
            uint256 sharesToBurn = convertToShares(loss);
            uint256 sharesInTreasury = balanceOf(treasuryAddress);

            if (sharesInTreasury < sharesToBurn) {
                sharesToBurn = sharesInTreasury;
                emit UncoveredLoss(
                    msg.sender,
                    loss - convertToAssets(sharesInTreasury)
                );
            }

            // If treasury has enough funds, it just burns needed amount
            // to keep diesel rate on the same level
            _burn(treasuryAddress, sharesToBurn);
        }

        // Updates borrow rate
        _updateBaseParameters(int256(profit) - int256(loss), 0, false);

        // Updates total borrowed
        _totalBorrowed -= uint128(borrowedAmount);

        cmDebt.totalBorrowed = totalBorrowed - uint128(borrowedAmount);

        emit Repay(msg.sender, borrowedAmount, profit, loss);
    }

    //
    // INTEREST RATE MANAGEMENT
    //

    /// @dev Calculates the most current value of the cumulative interest index
    ///
    ///                              /     currentBorrowRate * timeDifference \
    ///  newIndex  = currentIndex * | 1 + ------------------------------------ |
    ///                              \              SECONDS_PER_YEAR          /
    ///
    /// @return Current cumulative index in RAY
    function calcLinearCumulative_RAY() public view override returns (uint256) {
        //solium-disable-next-line
        uint256 timeDifference = block.timestamp - timestampLU;

        return
            calcLinearIndex_RAY(
                cumulativeIndexLU_RAY,
                _borrowRate_RAY,
                timeDifference
            );
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
            SECONDS_PER_YEAR;

        return (cumulativeIndex_RAY * linearAccumulated_RAY) / RAY;
    }

    /// @dev Updates core popo when liquidity parameters are changed
    function _updateBaseParameters(
        int256 expectedLiquidityChanged,
        int256 availableLiquidityChanged,
        bool checkOptimalBorrowing
    ) internal {
        uint128 expectedLiquidityLUcached = uint128(
            int128(_expectedLiquidityLU + uint128(_calcBaseInterestAccrued())) +
                int128(expectedLiquidityChanged)
        );

        _expectedLiquidityLU = expectedLiquidityLUcached;

        // Update cumulativeIndex
        cumulativeIndexLU_RAY = uint128(calcLinearCumulative_RAY());

        // update borrow APY
        _borrowRate_RAY = uint128(
            interestRateModel.calcBorrowRate(
                expectedLiquidityLUcached +
                    (supportQuotaPremiums ? _calcQuotasPremiums() : 0),
                availableLiquidityChanged == 0
                    ? availableLiquidity()
                    : uint256(
                        int256(availableLiquidity()) + availableLiquidityChanged
                    ),
                checkOptimalBorrowing
            )
        );
        timestampLU = uint64(block.timestamp);
    }

    /// TODO: add limit check!

    /// CM only
    function updateQuota(address token, int96 quotaChange)
        external
        override
        creditManagerWithActiveDebtOnly
        returns (int96 change)
    {
        return _updateQuota(token, quotaChange);
    }

    /// CM only
    function updateQuotas(QuotaUpdate[] memory quotaUpdates)
        external
        override
        creditManagerWithActiveDebtOnly
        returns (int96[] memory changes)
    {
        uint256 len = quotaUpdates.length;
        changes = new int96[](len);
        unchecked {
            for (uint256 i; i < len; ++i) {
                changes[i] = _updateQuota(
                    quotaUpdates[i].token,
                    quotaUpdates[i].quotaChange
                );
            }
        }
    }

    function _updateQuota(address token, int96 quotaChange)
        internal
        returns (int96 change)
    {
        Quota storage q = quotas[token];
        _expectedLiquidityLU += uint128(_calcQuotaPremium(q, token));
        q.lastUpdate = uint40(block.timestamp);
        uint96 totalQuoted = q.totalQuoted;
        if (quotaChange > 0) {
            uint96 limit = q.limit;
            if (totalQuoted > limit) return 0;
            change = (totalQuoted + uint96(quotaChange) > limit)
                ? int96(limit - totalQuoted)
                : quotaChange;
            q.totalQuoted = totalQuoted + uint96(change);
        } else {
            change = quotaChange;
            q.totalQuoted = uint96(int96(totalQuoted) + change);
        }
    }

    function updateQuotas() external gaugeOnly {
        uint256 quotaPremiums;
        if (supportQuotaPremiums) {
            address[] memory quotaAddrs = quotaTokensSet.values();
            uint256 quotasLen = quotaAddrs.length;
            for (uint256 i; i < quotasLen; ) {
                address token = quotaAddrs[i];
                Quota storage q = quotas[token];
                quotaPremiums += _calcQuotaPremium(q, token);

                q.lastUpdate = uint40(block.timestamp);
                unchecked {
                    ++i;
                }
            }
        }

        /// Add check that premiums are not higher than uint128
        _expectedLiquidityLU += uint128(quotaPremiums);
    }

    // GETTERS

    /// @dev Calculates the current borrow rate, RAY format
    function borrowRate_RAY() external view returns (uint256) {
        return uint256(_borrowRate_RAY);
    }

    ///  @dev Total borrowed amount (includes principal only)
    function totalBorrowed() external view returns (uint256) {
        return uint256(_totalBorrowed);
    }

    function quotaCumulativeIndex(address token)
        external
        view
        returns (uint256)
    {
        return supportQuotaPremiums ? IGauge(gauge).cumulativeIndex(token) : 0;
    }

    //
    // CONFIGURATION
    //

    /// @dev Forbids a Credit Manager to borrow
    /// @param _creditManager Address of the Credit Manager
    function setCreditManagerLimit(address _creditManager, uint256 _limit)
        external
        controllerOnly
    {
        /// Reverts if _creditManager is not registered in ContractRE#gister
        if (
            !ContractsRegister(
                AddressProvider(addressProvider).getContractsRegister()
            ).isCreditManager(_creditManager)
        ) {
            revert CreditManagerNotRegsiterException();
        }

        /// Checks if creditManager is already in list
        if (!creditManagerSet.contains(_creditManager)) {
            /// Reverts if c redit manager has different underlying asset
            if (address(this) != ICreditManagerV2(_creditManager).pool()) {
                revert IncompatibleCreditManagerException();
            }

            creditManagerSet.add(_creditManager);
            emit NewCreditManagerConnected(_creditManager);
        }

        CreditManagerDebt storage cmDebt = creditManagersDebt[_creditManager];
        cmDebt.limit = convertToU128(_limit);
        emit BorrowLimitChanged(_creditManager, _limit);
    }

    /// @dev Sets the new interest rate model for the pool
    /// @param _interestRateModel Address of the new interest rate model contract
    function updateInterestRateModel(address _interestRateModel)
        public
        configuratorOnly // T:[PS-9]
    {
        if (_interestRateModel == address(0)) revert ZeroAddressException(); // F:[P4-2]

        interestRateModel = IInterestRateModel(_interestRateModel);

        emit NewInterestRateModel(_interestRateModel); // F:[P4-03]
    }

    /// @dev Sets a new expected liquidity limit
    /// @param limit New expected liquidity limit
    function setExpectedLiquidityLimit(uint256 limit) external controllerOnly {
        _setExpectedLiquidityLimit(limit);
    }

    function _setExpectedLiquidityLimit(uint256 limit) internal {
        _expectedLiquidityLimit = convertToU128(limit);
        emit NewExpectedLiquidityLimit(limit); // F:[P4-03]
    }

    function setTotalBorrowedLimit(uint256 limit) external controllerOnly {
        _setTotalBorrowedLimit(limit);
    }

    function _setTotalBorrowedLimit(uint256 limit) internal {
        _totalBorrowedLimit = convertToU128(limit);
        emit NewTotalBorrowedLimit(limit); // F:[P4-03]
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
        return convertToU256(cmDebt.limit);
    }

    /// @dev How much current credit manager can borrow
    function creditManagerCanBorrow(address _creditManager)
        external
        view
        returns (uint256 canBorrow)
    {
        if (_totalBorrowed > _totalBorrowedLimit) return 0;
        unchecked {
            canBorrow = _totalBorrowedLimit == type(uint128).max
                ? type(uint256).max
                : _totalBorrowedLimit - _totalBorrowed;
        }

        uint256 available = interestRateModel.availableToBorrow(
            availableLiquidity(),
            expectedLiquidity()
        );

        if (canBorrow > available) {
            canBorrow = available;
        }

        CreditManagerDebt memory cmDebt = creditManagersDebt[_creditManager];
        if (cmDebt.totalBorrowed >= cmDebt.limit) {
            return 0;
        }

        unchecked {
            uint256 cmLimit = cmDebt.limit - cmDebt.totalBorrowed;
            if (canBorrow > cmLimit) {
                canBorrow = cmLimit;
            }
        }
    }

    function expectedLiquidityLimit() external view override returns (uint256) {
        return convertToU256(_expectedLiquidityLimit);
    }

    function expectedLiquidityLU() external view returns (uint256) {
        return convertToU256(_expectedLiquidityLU);
    }

    function totalBorrowedLimit() external view override returns (uint256) {
        return convertToU256(_totalBorrowedLimit);
    }

    function convertToU256(uint128 limit) internal pure returns (uint256) {
        return (limit == type(uint128).max) ? type(uint256).max : limit;
    }

    function convertToU128(uint256 limit) internal pure returns (uint128) {
        return
            (limit == type(uint256).max) ? type(uint128).max : uint128(limit);
    }
}
