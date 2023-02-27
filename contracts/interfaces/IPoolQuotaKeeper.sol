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
    error TokenQuotaIsAlreadyAdded();

    error GaugeOnlyException();
    error CreditManagerOnlyException();

    error IncompatibleCreditManagerException();

    error UnknownQuotaException();
}

interface IPoolQuotaKeeperEvents {
    /// @dev Emits when CA's quota for token is changed
    event AccountQuotaChanged(address creditAccount, address token, uint96 oldQuota, uint96 newQuota);

    /// @dev Emits when pool's total quota for token is changed
    event PoolQuotaChanged(address token, uint96 oldQuota, uint96 newQuota);

    event QuotaTokenAdded(address indexed token);

    event QuotaRateUpdated(address indexed token, uint16 rate);
}

/// @title Pool Quotas Interface
interface IPoolQuotaKeeper is IPoolQuotaKeeperEvents, IPoolQuotaKeeperExceptions, IVersion {
    /// @dev Returns quota rate in PERCENTAGE FORMAT
    function getQuotaRate(address) external view returns (uint16);

    /// @dev Returns cumulative index in RAY for particular token. If token is not
    function cumulativeIndex(address token) external view returns (uint192);

    /// @notice Updates credit account's quotas for multiple tokens
    /// @param creditAccount Address of credit account
    /// @param quotaUpdates Requested quota updates, see `QuotaUpdate`
    function updateQuotas(address creditAccount, QuotaUpdate[] memory quotaUpdates)
        external
        returns (uint256, QuotaStatusChange[] memory, bool);

    function quotedTokens() external view returns (address[] memory);

    function isQuotedToken(address token) external view returns (bool);

    function updateRates(QuotaRateUpdate[] memory qUpdates) external;

    function computeQuotedCollateralUSD(
        address creditManager,
        address creditAccount,
        address _priceOracle,
        TokenLT[] memory tokens
    ) external view returns (uint256 value, uint256 totalQuotaInterest);

    function closeCreditAccount(address creditAccount, TokenLT[] memory tokens) external returns (uint256);

    function outstandingQuotaInterest(address creditManager, address creditAccount, TokenLT[] memory tokens)
        external
        view
        returns (uint256 caQuotaInterestChange);

    function accrueQuotaInterest(address creditAccount, TokenLT[] memory tokens)
        external
        returns (uint256 caQuotaInterestChange);
}
