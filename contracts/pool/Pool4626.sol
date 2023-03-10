// SPDX-License-Identifier: BUSL-1.1
// Gearbox Protocol. Generalized leverage for DeFi protocols
// (c) Gearbox Holdings, 2022
pragma solidity ^0.8.10;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {ERC4626} from "@openzeppelin/contracts/token/ERC20/extensions/ERC4626.sol";
import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {Address} from "@openzeppelin/contracts/utils/Address.sol";
import {IERC20Metadata} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {EnumerableSet} from "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";

import {IWETH} from "@gearbox-protocol/core-v2/contracts/interfaces/external/IWETH.sol";
import {IERC4626} from "@openzeppelin/contracts/interfaces/IERC4626.sol";

import {AddressProvider} from "@gearbox-protocol/core-v2/contracts/core/AddressProvider.sol";
import {ContractsRegister} from "@gearbox-protocol/core-v2/contracts/core/ContractsRegister.sol";
import {ACLNonReentrantTrait} from "../core/ACLNonReentrantTrait.sol";

import {IInterestRateModel} from "../interfaces/IInterestRateModel.sol";
import {IPool4626, Pool4626Opts} from "../interfaces/IPool4626.sol";
import {ICreditManagerV2} from "../interfaces/ICreditManagerV2.sol";

import {RAY, SECONDS_PER_YEAR, MAX_WITHDRAW_FEE} from "@gearbox-protocol/core-v2/contracts/libraries/Constants.sol";
import {PERCENTAGE_FACTOR} from "@gearbox-protocol/core-v2/contracts/libraries/PercentageMath.sol";
import {Errors} from "@gearbox-protocol/core-v2/contracts/libraries/Errors.sol";

// EXCEPTIONS
import {ZeroAddressException} from "../interfaces/IErrors.sol";

struct CreditManagerDebt {
    uint128 totalBorrowed;
    uint128 limit;
}

/// @title Core pool contract compatible with ERC4626
/// @notice Implements pool & diesel token business logic
contract Pool4626 is ERC4626, IPool4626, ACLNonReentrantTrait {
    using Math for uint256;
    using EnumerableSet for EnumerableSet.AddressSet;
    using SafeERC20 for IERC20;
    using Address for address payable;

    /// @dev Address provider
    address public immutable override addressProvider;

    /// @dev Address of the protocol treasury
    address public immutable treasury;

    /// @dev The pool's underlying asset
    address public immutable override underlyingToken;

    /// @dev True if pool supports assets with quotas and associated interest computations
    bool public immutable supportsQuotas;

    /// @dev Contract version
    uint256 public constant override version = 2_10;

    // [SLOT #1]

    /// @dev Expected liquidity at last update (LU)
    uint128 internal _expectedLiquidityLU;

    /// @dev The current borrow rate
    uint128 internal _borrowRate;

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

    // [SLOT #4]: LIMITS

    /// @dev Total borrowed amount
    uint128 internal _totalBorrowedLimit;

    /// @dev The limit on expected (total) liquidity
    uint128 internal _expectedLiquidityLimit;

    // [SLOT #5]: POOL QUOTA KEEPER

    /// @dev Pool Quota Keeper updates quotaRevenue
    address public override poolQuotaKeeper;

    uint40 public lastQuotaRevenueUpdate;

    // [SLOT #6]: POOL QUOTA KEEPER (CNTD.)

    uint128 public quotaRevenue;

    /// @dev Map from Credit Manager addresses to the status of their ability to borrow
    mapping(address => CreditManagerDebt) internal creditManagersDebt;

    /// @dev The list of all Credit Managers
    EnumerableSet.AddressSet internal creditManagerSet;

    modifier poolQuotaKeeperOnly() {
        /// TODO: udpate exception
        if (msg.sender == poolQuotaKeeper) revert PoolQuotaKeeperOnly(); // F:[P4-5]
        _;
    }

    modifier creditManagerWithActiveDebtOnly() {
        if (creditManagersDebt[msg.sender].totalBorrowed == 0) {
            /// todo: add correct exception ??
            revert CreditManagerOnlyException();
        }
        _;
    }

    modifier nonZeroAddress(address addr) {
        if (addr == address(0)) revert ZeroAddressException(); // F:[P4-2]
        _;
    }

    //
    // CONSTRUCTOR
    //

    /// @dev Constructor
    /// @param opts Core pool options
    constructor(Pool4626Opts memory opts)
        ACLNonReentrantTrait(opts.addressProvider)
        ERC4626(IERC20(opts.underlyingToken))
        ERC20(
            string(
                abi.encodePacked(
                    "diesel ", opts.underlyingToken != address(0) ? IERC20Metadata(opts.underlyingToken).name() : ""
                )
            ),
            string(
                abi.encodePacked(
                    "d", opts.underlyingToken != address(0) ? IERC20Metadata(opts.underlyingToken).symbol() : ""
                )
            )
        ) // F:[P4-01]
        nonZeroAddress(opts.addressProvider) // F:[P4-02]
        nonZeroAddress(opts.underlyingToken) // F:[P4-02]
        nonZeroAddress(opts.interestRateModel) // F:[P4-02]
    {
        addressProvider = opts.addressProvider; // F:[P4-01]
        underlyingToken = opts.underlyingToken; // F:[P4-01]

        treasury = AddressProvider(opts.addressProvider).getTreasuryContract(); // F:[P4-01]

        timestampLU = uint64(block.timestamp); // F:[P4-01]
        cumulativeIndexLU_RAY = uint128(RAY); // F:[P4-01]

        interestRateModel = IInterestRateModel(opts.interestRateModel);
        emit NewInterestRateModel(opts.interestRateModel); // F:[P4-03]

        _setExpectedLiquidityLimit(opts.expectedLiquidityLimit); // F:[P4-01, 03]
        _setTotalBorrowedLimit(opts.expectedLiquidityLimit); // F:[P4-03]
        supportsQuotas = opts.supportsQuotas; // F:[P4-01]
    }

    //
    // ERC-4626 LOGIC
    //

    //
    // DEPOSIT/WITHDRAWAL LOGIC
    //

    /// @dev See {IERC4626-deposit}.
    function deposit(uint256 assets, address receiver)
        public
        override (ERC4626, IERC4626)
        whenNotPaused // F:[P4-4]
        nonReentrant
        nonZeroAddress(receiver)
        returns (uint256 shares)
    {
        uint256 assetsDelivered = _amountMinusFee(assets); // F:[P4-5,7]
        shares = _convertToShares(assetsDelivered, Math.Rounding.Down); // F:[P4-5,7]
        _deposit(receiver, assets, assetsDelivered, shares); // F:[P4-5]
    }

    /// @dev Deposit with emitting referral code
    function depositReferral(uint256 assets, address receiver, uint16 referralCode)
        external
        override
        returns (
            // nonReentrancy is set for deposit function
            uint256 shares
        )
    {
        shares = deposit(assets, receiver); // F:[P4-5]
        emit DepositReferral(msg.sender, receiver, assets, referralCode); // F:[P4-5]
    }

    /// @dev See {IERC4626-mint}.
    ///
    /// As opposed to {deposit}, minting is allowed even if the vault is in a state where the price of a share is zero.
    /// In this case, the shares will be minted without requiring any assets to be deposited.
    function mint(uint256 shares, address receiver)
        public
        override (ERC4626, IERC4626)
        whenNotPaused // F:[P4-4]
        nonReentrant
        nonZeroAddress(receiver)
        returns (uint256 assets)
    {
        // No need to check for rounding error, previewMint rounds up.
        assets = previewMint(shares); // F:[P4-6,7]

        _deposit(receiver, assets, _amountMinusFee(assets), shares); // F:[P4-6,7]
    }

    function _deposit(address receiver, uint256 assetsSent, uint256 assetsDelivered, uint256 shares) internal {
        /// Interst rate calculatiuon??
        if (expectedLiquidity() + assetsDelivered > uint256(_expectedLiquidityLimit)) {
            revert ExpectedLiquidityLimitException(); // F:[P4-7]
        }

        int256 assetsDeliveredSgn = int256(assetsDelivered); // F:[P4-5,6]

        /// @dev available liquidity is 0, because assets are already transffered
        /// It's updated after transfer to account real asset delivered to account
        _updateBaseParameters(assetsDeliveredSgn, assetsDeliveredSgn, false); // F:[P4-5,6]

        IERC20(underlyingToken).safeTransferFrom(msg.sender, address(this), assetsSent);

        _mint(receiver, shares); // F:[P4-5,6]

        emit Deposit(msg.sender, receiver, assetsSent, shares); // F:[P4-5,6]
    }

    /// @dev  See {IERC4626-withdraw}.
    function withdraw(uint256 assets, address receiver, address owner)
        public
        override (ERC4626, IERC4626)
        whenNotPaused // F:[P4-4]
        nonReentrant
        nonZeroAddress(receiver)
        returns (uint256 shares)
    {
        // @dev it returns share taking fee into account
        shares = previewWithdraw(assets); // F:[P4-8]
        _withdraw(assets, _convertToAssets(shares, Math.Rounding.Down), shares, receiver, owner); // F:[P4-8]
    }

    /// @dev See {IERC4626-redeem}.
    function redeem(uint256 shares, address receiver, address owner)
        public
        override (ERC4626, IERC4626)
        whenNotPaused // F:[P4-4]
        nonReentrant
        nonZeroAddress(receiver)
        returns (uint256 assetsDelivered)
    {
        /// Note: Computes assets without fees
        uint256 assetsSpent = _convertToAssets(shares, Math.Rounding.Down); // F:[P4-9]
        assetsDelivered = _calcDeliveredAsstes(assetsSpent); // F:[P4-9]

        _withdraw(assetsDelivered, assetsSpent, shares, receiver, owner); // F:[P4-9]
    }

    /// @dev Withdraw/redeem common workflow.
    function _withdraw(uint256 assetsDelivered, uint256 assetsSpent, uint256 shares, address receiver, address owner)
        internal
    {
        if (msg.sender != owner) {
            _spendAllowance(owner, msg.sender, shares); // F:[P4-8,9]
        }

        _updateBaseParameters(-int256(assetsSpent), -int256(assetsSpent), false); // F:[P4-8,9]

        _burn(owner, shares); // F:[P4-8,9]

        uint256 amountToUser = _amountWithFee(assetsDelivered); // F:[P4-8,9]

        IERC20(underlyingToken).safeTransfer(receiver, amountToUser); // F:[P4-8,9]

        if (assetsSpent > amountToUser) {
            unchecked {
                IERC20(underlyingToken).safeTransfer(treasury, assetsSpent - amountToUser); // F:[P4-8,9]
            }
        }

        emit Withdraw(msg.sender, receiver, owner, assetsDelivered, shares); // F:[P4-8, 9]
    }

    function burn(uint256 shares)
        external
        override
        whenNotPaused // TODO: Add test
        nonReentrant
    {
        _burn(msg.sender, shares); // F:[P4-10]
    }

    //
    // FEE TOKEN SUPPORT

    function _amountWithFee(uint256 amount) internal view virtual returns (uint256) {
        return amount;
    }

    function _amountMinusFee(uint256 amount) internal view virtual returns (uint256) {
        return amount;
    }

    //
    //  ACCOUNTING LOGIC
    //

    /**
     * @dev Internal conversion function (from assets to shares) with support for rounding direction.
     *
     * Will revert if assets > 0, totalSupply > 0 and totalAssets = 0. That corresponds to a case where any asset
     * would represent an infinite amount of shares.
     */
    function _convertToShares(uint256 assets, Math.Rounding rounding) internal view override returns (uint256 shares) {
        uint256 supply = totalSupply();
        return (assets == 0 || supply == 0) ? assets : assets.mulDiv(supply, expectedLiquidity(), rounding);
    }

    /**
     * @dev Internal conversion function (from shares to assets) with support for rounding direction.
     */
    function _convertToAssets(uint256 shares, Math.Rounding rounding) internal view override returns (uint256 assets) {
        uint256 supply = totalSupply();
        return (supply == 0) ? shares : shares.mulDiv(expectedLiquidity(), supply, rounding);
    }

    /// @dev See {IERC4626-totalAssets}.
    function totalAssets() public view override (ERC4626, IERC4626) returns (uint256 assets) {
        return expectedLiquidity();
    }

    /// @dev See {IERC4626-maxDeposit}.
    function maxDeposit(address) public view override (ERC4626, IERC4626) returns (uint256) {
        return (_expectedLiquidityLimit == type(uint128).max)
            ? type(uint256).max
            : _amountWithFee(_expectedLiquidityLimit - expectedLiquidity());
    }

    /// @dev See {IERC4626-previewDeposit}.
    function previewDeposit(uint256 assets) public view override (ERC4626, IERC4626) returns (uint256) {
        return _convertToShares(_amountMinusFee(assets), Math.Rounding.Down); // TODO: add fee parameter
    }

    /// @dev See {IERC4626-maxMint}.
    function maxMint(address) public view override (ERC4626, IERC4626) returns (uint256) {
        uint128 limit = _expectedLiquidityLimit;
        return (limit == type(uint128).max) ? type(uint256).max : previewMint(limit - expectedLiquidity());
    }

    ///  @dev See {IERC4626-previewMint}.
    function previewMint(uint256 shares) public view override (ERC4626, IERC4626) returns (uint256) {
        return _amountWithFee(_convertToAssets(shares, Math.Rounding.Up)); // We need to round up shares.mulDivUp(totalAssets(), supply);
    }

    /// @dev See {IERC4626-maxWithdraw}.
    function maxWithdraw(address owner) public view override (ERC4626, IERC4626) returns (uint256) {
        return availableLiquidity().min(previewWithdraw(balanceOf(owner)));
    }

    /// @dev See {IERC4626-previewWithdraw}.
    function previewWithdraw(uint256 assets) public view override (ERC4626, IERC4626) returns (uint256) {
        return _convertToShares(
            _amountWithFee(assets) * PERCENTAGE_FACTOR / (PERCENTAGE_FACTOR - withdrawFee), Math.Rounding.Up
        );
    }

    /// @dev See {IERC4626-maxRedeem}.
    function maxRedeem(address owner) public view override (ERC4626, IERC4626) returns (uint256 shares) {
        shares = balanceOf(owner);
        uint256 assets = _convertToAssets(shares, Math.Rounding.Down);
        uint256 assetsAvailable = availableLiquidity();
        if (assets > assetsAvailable) {
            shares = _convertToShares(assetsAvailable, Math.Rounding.Down);
        }
    }

    /// @dev See {IERC4626-previewRedeem}.
    function previewRedeem(uint256 shares) public view override (ERC4626, IERC4626) returns (uint256 assets) {
        assets = _calcDeliveredAsstes(_convertToAssets(shares, Math.Rounding.Down));
    }

    /// @dev Computes how much assets will de delivered takling intio account token fees & withdraw fee
    function _calcDeliveredAsstes(uint256 assetsSpent) internal view returns (uint256) {
        uint256 assetsDelivered = assetsSpent;

        if (withdrawFee > 0) {
            unchecked {
                /// It's safe because we made a check that assetsDelivered < uint128, and withDrawFee is < 10K
                uint256 withdrawFeeAmount = (assetsDelivered * withdrawFee) / PERCENTAGE_FACTOR;
                assetsDelivered -= withdrawFeeAmount;
            }
        }

        return _amountMinusFee(assetsDelivered);
    }

    /// @return Amount of money that should be in the pool
    /// after all users close their Credit accounts and fully repay debts
    function expectedLiquidity() public view override returns (uint256) {
        return _expectedLiquidityLU + _calcBaseInterestAccrued() + (supportsQuotas ? _calcOutstandingQuotaRevenue() : 0); //
    }

    /// @dev Computes interest rate accrued from last update (LU)
    function _calcBaseInterestAccrued() internal view returns (uint256) {
        // timeDifference = blockTime - previous timeStamp
        uint256 timeDifference = block.timestamp - timestampLU;

        //                                    currentBorrowRate * timeDifference
        //  interestAccrued = totalBorrow *  ------------------------------------
        //                                             SECONDS_PER_YEAR
        //
        return (uint256(_totalBorrowed) * _borrowRate * timeDifference) / RAY / SECONDS_PER_YEAR;
    }

    function _calcOutstandingQuotaRevenue() internal view returns (uint128) {
        return uint128(
            (quotaRevenue * (block.timestamp - lastQuotaRevenueUpdate)) / (SECONDS_PER_YEAR * PERCENTAGE_FACTOR)
        );
    }

    /// @dev Returns available liquidity in the pool (pool balance)
    function availableLiquidity() public view virtual override returns (uint256) {
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

        if (cmDebt.totalBorrowed + borrowedAmount > cmDebt.limit || borrowedAmount == 0) {
            revert CreditManagerCantBorrowException(); // F:[P4-12]
        }
        cmDebt.totalBorrowed += uint128(borrowedAmount); // F:[P4-11]

        // Increase total borrowed amount
        _totalBorrowed += uint128(borrowedAmount); // F:[P4-11]

        // Reverts if total borrow more than limit
        if (_totalBorrowed > _totalBorrowedLimit) {
            revert CreditManagerCantBorrowException(); // F:[P4-12]
        }

        // Update borrow Rate, reverts of Uoptimal limit is set up
        _updateBaseParameters(0, -int256(borrowedAmount), true); // F:[P4-11]

        // Transfer funds to credit account
        IERC20(underlyingToken).safeTransfer(creditAccount, borrowedAmount); // F:[P4-11]

        emit Borrow(msg.sender, creditAccount, borrowedAmount); // F:[P4-11]
    }

    /// @dev Registers Credit Account's debt repayment and updates parameters.
    /// Assumes that the underlying (including principal + interest + fees) was already transferred
    /// @param borrowedAmount Amount of principal ro repay
    /// @param profit The treasury profit from repayment
    /// @param loss Amount of underlying that the CA wan't able to repay
    function repayCreditAccount(uint256 borrowedAmount, uint256 profit, uint256 loss)
        external
        override
        whenNotPaused // F:[P4-4]
    {
        // Updates credit manager specific totalBorrowed
        CreditManagerDebt storage cmDebt = creditManagersDebt[msg.sender];

        uint128 cmTotalBorrowed = cmDebt.totalBorrowed;
        if (cmTotalBorrowed == 0) {
            revert CreditManagerOnlyException(); // F:[P4-13]
        }

        // For fee surplus we mint tokens for treasury
        if (profit > 0) {
            _mint(treasury, convertToShares(profit)); // F:[P4-14]
        } else {
            // If returned money < borrowed amount + interest accrued
            // it tries to compensate loss by burning diesel (LP) tokens
            // from treasury fund
            uint256 sharesToBurn = convertToShares(loss); // F:[P4-14]
            uint256 sharesInTreasury = balanceOf(treasury); // F:[P4-14]

            if (sharesInTreasury < sharesToBurn) {
                sharesToBurn = sharesInTreasury; // F:[P4-14]
                emit UncoveredLoss(msg.sender, loss - convertToAssets(sharesInTreasury)); // F:[P4-14]
            }

            // If treasury has enough funds, it just burns needed amount
            // to keep diesel rate on the same level
            _burn(treasury, sharesToBurn); // F:[P4-14]
        }

        // Updates borrow rate
        _updateBaseParameters(int256(profit) - int256(loss), 0, false); // F:[P4-14]

        // Updates total borrowed
        _totalBorrowed -= uint128(borrowedAmount); // F:[P4-14]

        cmDebt.totalBorrowed = cmTotalBorrowed - uint128(borrowedAmount); // F:[P4-14]

        emit Repay(msg.sender, borrowedAmount, profit, loss); // F:[P4-14]
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
        uint256 timeDifference = block.timestamp - timestampLU; // F:[P4-15]
        uint256 linearAccumulated_RAY = RAY + (_borrowRate * timeDifference) / SECONDS_PER_YEAR; // F:[P4-15]

        return (cumulativeIndexLU_RAY * linearAccumulated_RAY) / RAY; // F:[P4-15]
    }

    /// @dev Updates core popo when liquidity parameters are changed
    function _updateBaseParameters(
        int256 expectedLiquidityChanged,
        int256 availableLiquidityChanged,
        bool checkOptimalBorrowing
    ) internal {
        uint128 updatedExpectedLiquidityLU = uint128(
            int128(_expectedLiquidityLU + uint128(_calcBaseInterestAccrued())) + int128(expectedLiquidityChanged)
        );

        _expectedLiquidityLU = updatedExpectedLiquidityLU;

        // Update cumulativeIndex
        cumulativeIndexLU_RAY = uint128(calcLinearCumulative_RAY());

        // update borrow APY
        // TODO: add case to check with quotas
        _borrowRate = uint128(
            interestRateModel.calcBorrowRate(
                updatedExpectedLiquidityLU + (supportsQuotas ? _calcOutstandingQuotaRevenue() : 0),
                availableLiquidityChanged == 0
                    ? availableLiquidity()
                    : uint256(int256(availableLiquidity()) + availableLiquidityChanged),
                checkOptimalBorrowing
            )
        );
        timestampLU = uint64(block.timestamp);
    }

    /// POOL QUOTA KEEPER ONLY
    function changeQuotaRevenue(int128 _quotaRevenueChange) external override poolQuotaKeeperOnly {
        _updateQuotaRevenue(uint128(int128(quotaRevenue) + _quotaRevenueChange));
    }

    function updateQuotaRevenue(uint128 newQuotaRevenue) external override poolQuotaKeeperOnly {
        _updateQuotaRevenue(newQuotaRevenue);
    }

    function _updateQuotaRevenue(uint128 _newQuotaRevenue) internal {
        _expectedLiquidityLU += _calcOutstandingQuotaRevenue();

        lastQuotaRevenueUpdate = uint40(block.timestamp);
        quotaRevenue = _newQuotaRevenue;
    }

    // GETTERS

    /// @dev Calculates the current borrow rate, RAY format
    function borrowRate() external view returns (uint256) {
        return uint256(_borrowRate);
    }

    ///  @dev Total borrowed amount (includes principal only)
    function totalBorrowed() external view returns (uint256) {
        return uint256(_totalBorrowed);
    }

    //
    // CONFIGURATION
    //

    // TODO: Add function to set pool quota keeper

    /// @dev Forbids a Credit Manager to borrow
    /// @param _creditManager Address of the Credit Manager
    function setCreditManagerLimit(address _creditManager, uint256 _limit)
        external
        controllerOnly
        nonZeroAddress(_creditManager)
    {
        /// Reverts if _creditManager is not registered in ContractRE#gister
        if (!ContractsRegister(AddressProvider(addressProvider).getContractsRegister()).isCreditManager(_creditManager))
        {
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
        cmDebt.limit = _convertToU128(_limit);
        emit BorrowLimitChanged(_creditManager, _limit);
    }

    /// @dev Sets the new interest rate model for the pool
    /// @param _interestRateModel Address of the new interest rate model contract
    function updateInterestRateModel(address _interestRateModel)
        public
        configuratorOnly // T:[PS-9]
        nonZeroAddress(_interestRateModel)
    {
        interestRateModel = IInterestRateModel(_interestRateModel);

        _updateBaseParameters(0, 0, false);

        emit NewInterestRateModel(_interestRateModel); // F:[P4-03]
    }

    /// @dev Sets the new pool quota keeper
    /// @param _poolQuotaKeeper Address of the new poolQuotaKeeper copntract
    function connectPoolQuotaManager(address _poolQuotaKeeper)
        public
        configuratorOnly // T:[PS-9]
        nonZeroAddress(_poolQuotaKeeper)
    {
        if (poolQuotaKeeper != address(0)) {
            _updateQuotaRevenue(quotaRevenue);
        }

        poolQuotaKeeper = _poolQuotaKeeper;

        emit NewPoolQuotaKeeper(_poolQuotaKeeper); // F:[P4-03]
    }

    /// @dev Sets a new expected liquidity limit
    /// @param limit New expected liquidity limit
    function setExpectedLiquidityLimit(uint256 limit) external controllerOnly {
        _setExpectedLiquidityLimit(limit); // F:[P4-7]
    }

    function _setExpectedLiquidityLimit(uint256 limit) internal {
        _expectedLiquidityLimit = _convertToU128(limit);
        emit NewExpectedLiquidityLimit(limit); // F:[P4-03]
    }

    function setTotalBorrowedLimit(uint256 limit) external controllerOnly {
        _setTotalBorrowedLimit(limit);
    }

    function _setTotalBorrowedLimit(uint256 limit) internal {
        _totalBorrowedLimit = _convertToU128(limit);
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

    //
    // GETTERS
    //
    function creditManagers() external view returns (address[] memory) {
        return creditManagerSet.values();
    }

    /// @dev Total borrowed for particular credit manager
    function creditManagerBorrowed(address _creditManager) external view returns (uint256) {
        CreditManagerDebt storage cmDebt = creditManagersDebt[_creditManager];
        return cmDebt.totalBorrowed;
    }

    /// @dev Borrow limit for particular credit manager
    function creditManagerLimit(address _creditManager) external view returns (uint256) {
        CreditManagerDebt storage cmDebt = creditManagersDebt[_creditManager];
        return _convertToU256(cmDebt.limit);
    }

    /// @dev How much current credit manager can borrow
    function creditManagerCanBorrow(address _creditManager) external view returns (uint256 canBorrow) {
        if (_totalBorrowed > _totalBorrowedLimit) return 0;
        unchecked {
            canBorrow =
                _totalBorrowedLimit == type(uint128).max ? type(uint256).max : _totalBorrowedLimit - _totalBorrowed;
        }

        uint256 available = interestRateModel.availableToBorrow(availableLiquidity(), expectedLiquidity());

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
        return _convertToU256(_expectedLiquidityLimit);
    }

    function expectedLiquidityLU() external view returns (uint256) {
        return _convertToU256(_expectedLiquidityLU);
    }

    function totalBorrowedLimit() external view override returns (uint256) {
        return _convertToU256(_totalBorrowedLimit);
    }

    //
    //  INTERNAL HELPERS
    //
    function _convertToU256(uint128 limit) internal pure returns (uint256) {
        return (limit == type(uint128).max) ? type(uint256).max : limit;
    }

    function _convertToU128(uint256 limit) internal pure returns (uint128) {
        return (limit == type(uint256).max) ? type(uint128).max : uint128(limit);
    }
}
