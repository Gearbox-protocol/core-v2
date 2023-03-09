// SPDX-License-Identifier: MIT
// Gearbox Protocol. Generalized leverage for DeFi protocols
// (c) Gearbox Holdings, 2022
pragma solidity ^0.8.10;

import {IVersion} from "./IVersion.sol";

enum QuotaStatusChange {
    NOT_CHANGED,
    ZERO_TO_POSITIVE,
    POSITIVE_TO_ZERO
}

/// @notice Quota update params
/// @param token Address of the token to change the quota for
/// @param quotaChange Requested quota change in pool's underlying asset units
struct QuotaUpdate {
    address token;
    int96 quotaChange;
}

struct QuotaRateUpdate {
    address token;
    uint16 rate;
}

struct TokenLT {
    address token;
    uint16 lt;
}

struct TokenQuotaParams {
    uint96 totalQuoted;
    uint96 limit;
    uint16 rate; // current rate update
    uint192 cumulativeIndexLU_RAY; // max 10^57
}

struct AccountQuota {
    uint96 quota;
    uint192 cumulativeIndexLU;
}

interface IPoolQuotaKeeperExceptions {
    /// @dev Thrown when attempting to add a quoted token that is already added
    error QuotedTokenIsAlreadyAdded();

    /// @dev Thrown when a gauge-only function is called by non-gauge
    error GaugeOnlyException();

    /// @dev Thrown when a Credit Manager-only function is called by non-Credit Manager
    error CreditManagerOnlyException();

    /// @dev Thrown when attempting to set a quota for a token that is not quoted
    error TokenIsNotQuotedException();
}

interface IPoolQuotaKeeperEvents {
    /// @dev Emits when CA's quota for token is changed
    event AccountQuotaChanged(address creditAccount, address token, uint96 oldQuota, uint96 newQuota);

    /// @dev Emits when pool's total quota for token is changed
    event PoolQuotaChanged(address token, uint96 oldQuota, uint96 newQuota);

    /// @dev Emits when the quota rate is updated
    event QuotaRateUpdated(address indexed token, uint16 rate);

    /// @dev Emits when the gauge address is updated
    event GaugeUpdated(address indexed newGauge);

    /// @dev Emits when a new Credit Manager is allowed in PoolQuotaKeeper
    event CreditManagerAdded(address indexed creditManager);

    /// @dev Emits when a new limit is set for a token
    event TokenLimitSet(address indexed token, uint96 limit);
}

/// @title Pool Quotas Interface
interface IPoolQuotaKeeper is IPoolQuotaKeeperEvents, IPoolQuotaKeeperExceptions, IVersion {
    /// @dev Updates credit account's quotas for multiple tokens
    /// @param creditAccount Address of credit account
    /// @param quotaUpdates Requested quota updates, see `QuotaUpdate`
    function updateQuotas(address creditAccount, QuotaUpdate[] memory quotaUpdates)
        external
        returns (uint256, QuotaStatusChange[] memory, bool);

    /// @dev Updates all quotas to zero when closing a credit account, and computes the final quota interest change
    /// @param creditAccount Address of the Credit Account being closed
    /// @param tokensLT Array of all active quoted tokens on the account
    function closeCreditAccount(address creditAccount, TokenLT[] memory tokensLT) external returns (uint256);

    /// @dev Computes the accrued quota interest and updates interest indexes
    /// @param creditAccount Address of the Credit Account to accrue interest for
    /// @param tokensLT Array of all active quoted tokens on the account
    function accrueQuotaInterest(address creditAccount, TokenLT[] memory tokensLT)
        external
        returns (uint256 caQuotaInterestChange);

    /// @dev Batch updates the quota rates and changes the combined quota revenue
    /// @param qUpdates Array of new rates for all quoted tokens
    function updateRates(QuotaRateUpdate[] memory qUpdates) external;

    /// @dev Registers a new quoted token in the keeper
    function addQuotaToken(address token) external;

    //
    // GETTERS
    //

    /// @dev Returns quota rate in PERCENTAGE FORMAT
    function getQuotaRate(address) external view returns (uint16);

    /// @dev Returns cumulative index in RAY for a quoted token. Returns 0 for non-quoted tokens.
    function cumulativeIndex(address token) external view returns (uint192);

    /// @dev Returns an array of all quoted tokens
    function quotedTokens() external view returns (address[] memory);

    /// @dev Returns whether a token is quoted
    function isQuotedToken(address token) external view returns (bool);

    /// @dev Returns quota parameters for a single (account, token) pair
    function getQuota(address creditManager, address creditAccount, address token)
        external
        view
        returns (AccountQuota memory);

    /// @dev Computes collateral value for quoted tokens on the account, as well as accrued quota interest
    function computeQuotedCollateralUSD(
        address creditManager,
        address creditAccount,
        address _priceOracle,
        TokenLT[] memory tokens
    ) external view returns (uint256 value, uint256 totalQuotaInterest);

    /// @dev Computes outstanding quota interest
    function outstandingQuotaInterest(address creditManager, address creditAccount, TokenLT[] memory tokens)
        external
        view
        returns (uint256 caQuotaInterestChange);
}
