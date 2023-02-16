// SPDX-License-Identifier: MIT
// Gearbox Protocol. Generalized leverage for DeFi protocols
// (c) Gearbox Holdings, 2022
pragma solidity ^0.8.10;

import { IERC4626 } from "@openzeppelin/contracts/interfaces/IERC4626.sol";
import { IVersion } from "./IVersion.sol";

struct Pool4626Opts {
    address addressProvider;
    address underlyingToken;
    address interestRateModel;
    uint256 expectedLiquidityLimit;
    bool supportQuotaPremiums;
}

interface IPool4626Exceptions {
    error ExpectedLiquidityLimitException();

    error CreditManagerCantBorrowException();
    error CreditManagerOnlyException();
    error IncorrectWithdrawalFeeException();
    error ZeroAssetsException();
    error AssetIsNotWETHException();
    error IncompatibleCreditManagerException();
    error CreditManagerNotRegsiterException();
    error AdditionalYieldPoolException();
}

interface IPool4626Events {
    /// @dev Emits on new liquidity being added to the pool
    event DepositReferral(
        address indexed sender,
        address indexed onBehalfOf,
        uint256 amount,
        uint16 referralCode
    );

    /// @dev Emits on a Credit Manager borrowing funds for a Credit Account
    event Borrow(
        address indexed creditManager,
        address indexed creditAccount,
        uint256 amount
    );

    /// @dev Emits on repayment of a Credit Account's debt
    event Repay(
        address indexed creditManager,
        uint256 borrowedAmount,
        uint256 profit,
        uint256 loss
    );

    /// @dev Emits on updating the interest rate model
    event NewInterestRateModel(address indexed newInterestRateModel);

    /// @dev Emits on connecting a new Credit Manager
    event NewCreditManagerConnected(address indexed creditManager);

    event NewTotalBorrowedLimit(uint256 limit);

    /// @dev Emits when a Credit Manager is forbidden to borrow
    event BorrowLimitChanged(address indexed creditManager, uint256 newLimit);

    /// @dev Emitted when loss is incurred that can't be covered by treasury funds
    event UncoveredLoss(address indexed creditManager, uint256 loss);

    /// @dev Emits when the liquidity limit is changed
    event NewExpectedLiquidityLimit(uint256 newLimit);

    /// @dev Emits when the withdrawal fee is changed
    event NewWithdrawFee(uint256 fee);
}

/// @title Pool Service Interface
/// @notice Implements business logic:
///   - Adding/removing pool liquidity
///   - Managing diesel tokens & diesel rates
///   - Taking/repaying Credit Manager debt
/// More: https://dev.gearbox.fi/developers/pool/abstractpoolservice
interface IPool4626 is
    IPool4626Events,
    IPool4626Exceptions,
    IERC4626,
    IVersion
{
    function depositReferral(
        uint256 assets,
        address receiver,
        uint16 referralCode
    ) external returns (uint256 shares);

    function depositETHReferral(address receiver, uint16 referralCode)
        external
        payable
        returns (uint256 shares);

    function withdrawETH(
        uint256 assets,
        address receiver,
        address owner
    ) external returns (uint256 shares);

    function redeemETH(
        uint256 shares,
        address receiver,
        address owner
    ) external returns (uint256 assets);

    function burn(uint256 shares) external;

    /// CREDIT MANAGERS FUNCTIONS

    /// @dev Lends pool funds to a Credit Account
    /// @param borrowedAmount Credit Account's debt principal
    /// @param creditAccount Credit Account's address
    function lendCreditAccount(uint256 borrowedAmount, address creditAccount)
        external;

    /// @dev Repays the Credit Account's debt
    /// @param borrowedAmount Amount of principal ro repay
    /// @param profit The treasury profit from repayment
    /// @param loss Amount of underlying that the CA wan't able to repay
    /// @notice Assumes that the underlying (including principal + interest + fees)
    ///         was already transferred
    function repayCreditAccount(
        uint256 borrowedAmount,
        uint256 profit,
        uint256 loss
    ) external;

    /// @dev Updates quota index
    function updateQuotas(uint128 _quotaIndex) external;

    //
    // GETTERS
    //

    /// @dev The same value like in total assets in ERC4626 standrt
    function expectedLiquidity() external view returns (uint256);

    /// @dev Limit for expected liquidity, 2**256-1 if no limit there
    function expectedLiquidityLimit() external view returns (uint256);

    /// @dev Available liquidity (pool balance in underlying token)
    function availableLiquidity() external view returns (uint256);

    /// @dev Current interest index, RAY format
    function calcLinearCumulative_RAY() external view returns (uint256);

    /// @dev Calculates the current borrow rate, RAY format
    function borrowRate_RAY() external view returns (uint256);

    ///  @dev Total borrowed amount (includes principal only)
    function totalBorrowed() external view returns (uint256);

    /// @dev diesel rate in RAY format
    function getDieselRate_RAY() external view returns (uint256);

    /// @dev Address of the underlying
    function underlyingToken() external view returns (address);

    /// @dev Addresses of all connected credit managers
    function creditManagers() external view returns (address[] memory);

    /// @dev Borrow limit for particular credit manager
    function creditManagerBorrowed(address) external view returns (uint256);

    /// @dev Borrow limit for particular credit manager
    function creditManagerLimit(address) external view returns (uint256);

    /// @dev Whether the pool supports quota premiums
    function supportQuotaPremiums() external view returns (bool);

    /// @dev PoolQuotaKeeper address
    function poolQuotaKeeper() external view returns (address);

    /// @dev Withdrawal fee
    function withdrawFee() external view returns (uint16);

    /// @dev Timestamp of the pool's last update
    function timestampLU() external view returns (uint64);

    function totalBorrowedLimit() external view returns (uint256);

    /// @dev Address provider
    function addressProvider() external view returns (address);
}
