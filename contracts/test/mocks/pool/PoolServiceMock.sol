// SPDX-License-Identifier: UNLICENSED
// Gearbox Protocol. Generalized leverage for DeFi protocols
// (c) Gearbox Holdings, 2022
pragma solidity ^0.8.10;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

import {RAY} from "../../../libraries/Constants.sol";

import {IPoolService} from "../../../interfaces/IPoolService.sol";

import {AddressProvider} from "../../../core/AddressProvider.sol";

/**
 * @title Mock of pool service for CreditManager constracts testing
 * @notice Used for testing purposes only.
 * @author Gearbox
 */
contract PoolServiceMock is IPoolService {
    using SafeERC20 for IERC20;

    // Address repository
    AddressProvider public override addressProvider;

    // Total borrowed amount: https://dev.gearbox.fi/developers/pool/economy/total-borrowed
    uint256 public override totalBorrowed;
    uint256 public override expectedLiquidityLimit;

    address public override underlyingToken;
    address public asset;

    // Credit Managers
    address[] public override creditManagers;

    // Diesel(LP) token address
    address public override dieselToken;

    mapping(address => bool) public override creditManagersCanBorrow;

    // Current borrow rate in RAY: https://dev.gearbox.fi/developers/pool/economy#borrow-apy
    uint256 public override borrowAPY_RAY; // 10%

    // Timestamp of last update
    uint256 public override _timestampLU;

    uint256 public lendAmount;
    address public lendAccount;

    uint256 public repayAmount;
    uint256 public repayProfit;
    uint256 public repayLoss;
    uint256 public withdrawMultiplier;

    uint256 public override withdrawFee;
    uint256 public _expectedLiquidityLU;
    uint256 public calcLinearIndex_RAY;
    address public interestRateModel;
    address public treasuryAddress;
    mapping(address => bool) public creditManagersCanRepay;

    // Cumulative index in RAY
    uint256 public override _cumulativeIndex_RAY;

    // Contract version
    uint256 public constant override version = 1;

    // Paused flag
    bool public paused = false;

    bool public supportsQuotas = false;
    address public poolQuotaKeeper;

    constructor(address _addressProvider, address _underlyingToken) {
        addressProvider = AddressProvider(_addressProvider);
        underlyingToken = _underlyingToken;
        asset = _underlyingToken;
        borrowAPY_RAY = RAY / 10;
        _cumulativeIndex_RAY = RAY;
    }

    function setPoolQuotaKeeper(address _poolQuotaKeeper) external {
        poolQuotaKeeper = _poolQuotaKeeper;
    }

    function setSupportsQuotas(bool val) external {
        supportsQuotas = val;
    }

    function setCumulative_RAY(uint256 cumulativeIndex_RAY) external {
        _cumulativeIndex_RAY = cumulativeIndex_RAY;
    }

    function calcLinearCumulative_RAY() public view override returns (uint256) {
        return _cumulativeIndex_RAY;
    }

    function changeQuotaRevenue(int128) external {}

    function updateQuotaRevenue(uint128) external {}

    function lendCreditAccount(uint256 borrowedAmount, address creditAccount) external override {
        lendAmount = borrowedAmount;
        lendAccount = creditAccount;

        // Transfer funds to credit account
        IERC20(underlyingToken).safeTransfer(creditAccount, borrowedAmount); // T:[PS-14]
    }

    function repayCreditAccount(uint256 borrowedAmount, uint256 profit, uint256 loss) external override {
        repayAmount = borrowedAmount;
        repayProfit = profit;
        repayLoss = loss;
    }

    function addLiquidity(uint256 amount, address onBehalfOf, uint256 referralCode) external override {}

    /**
     * @dev Removes liquidity from pool
     * - Transfers to LP underlyingToken account = amount * diesel rate
     * - Burns diesel tokens
     * - Decreases underlyingToken amount from total_liquidity
     * - Updates borrow rate
     *
     * More: https://dev.gearbox.fi/developers/pool/abstractpoolservice#removeliquidity
     *
     * @param amount Amount of tokens to be transfer
     * @param to Address to transfer liquidity
     */
    function removeLiquidity(uint256 amount, address to) external override returns (uint256) {}

    function expectedLiquidity() public pure override returns (uint256) {
        return 0; // T:[MPS-1]
    }

    function availableLiquidity() public view override returns (uint256) {
        return IERC20(underlyingToken).balanceOf(address(this));
    }

    function getDieselRate_RAY() public pure override returns (uint256) {
        return RAY; // T:[MPS-1]
    }

    //
    // CONFIGURATION
    //

    /**
     * @dev Connects new Credit Manager to pool
     *
     * @param _creditManager Address of credit Manager
     */
    function connectCreditManager(address _creditManager) external {}

    /**
     * @dev Forbid to borrow for particulat credit Manager
     *
     * @param _creditManager Address of credit Manager
     */
    function forbidCreditManagerToBorrow(address _creditManager) external {}

    /**
     * @dev Set the new interest rate model for pool
     *
     * @param _interestRateModel Address of new interest rate model contract
     */
    function newInterestRateModel(address _interestRateModel) external {}

    /**
     * @dev Returns quantity of connected credit accounts managers
     *
     * @return Quantity of connected credit Manager
     */
    function creditManagersCount() external pure override returns (uint256) {
        return 1; // T:[MPS-1]
    }

    /**
     * @dev Converts amount into diesel tokens
     *
     * @param amount Amount in underlyingToken tokens to be converted to diesel tokens
     * @return Amount in diesel tokens
     */
    function toDiesel(uint256 amount) public pure override returns (uint256) {
        return (amount * RAY) / getDieselRate_RAY(); // T:[PS-24]
    }

    /**
     * @dev Converts amount from diesel tokens to undelying token
     *
     * @param amount Amount in diesel tokens to be converted to diesel tokens
     * @return Amount in underlyingToken tokens
     */
    function fromDiesel(uint256 amount) public pure override returns (uint256) {
        return (amount * getDieselRate_RAY()) / RAY; // T:[PS-24]
    }

    function pause() external {
        paused = true;
    }

    function unpause() external {
        paused = false;
    }

    function setExpectedLiquidityLimit(uint256 num) external {}

    function setWithdrawFee(uint256 num) external {}

    //    function calcCumulativeIndexAtBorrowMore(
    //        uint256 amount,
    //        uint256 dAmount,
    //        uint256 cumulativeIndexAtOpen
    //    ) external view override returns (uint256) {
    //        return
    //            (calcLinearCumulative_RAY() *
    //                (cumulativeIndexAtOpen) *
    //                (amount + dAmount)) /
    //            (calcLinearCumulative_RAY() *
    //                amount +
    //                dAmount *
    //                cumulativeIndexAtOpen);
    //    }
}
