// SPDX-License-Identifier: MIT
// Gearbox Protocol. Generalized leverage for DeFi protocols
// (c) Gearbox Holdings, 2022
pragma solidity ^0.8.10;

import { IVersion } from "./IVersion.sol";

struct QuotaUpdate {
    address token;
    int96 quotaChange;
}

struct QuotaRateUpdate {
    address token;
    uint16 rate;
}

struct LimitTokenCalc {
    address token;
    uint16 lt;
}

interface IPoolQuotaKeeperExceptions {
    error TokenQuotaIsAlreadyAdded();

    error GaugeOnlyException();
    error CreditManagerOnlyException();

    error IncompatibleCreditManagerException();
}

interface IPoolQuotaKeeperEvents {
    event QuotaTokenAdded(address indexed token);

    event QuotaRateUpdated(address indexed token, uint16 rate);
}

/// @title Pool Quotas Interface
interface IPoolQuotaKeeper is
    IPoolQuotaKeeperEvents,
    IPoolQuotaKeeperExceptions,
    IVersion
{
    /// @dev Returns quota rate in PERCENTAGE FORMAT
    function getQuotaRate(address) external view returns (uint16);

    /// @dev Returns cumulative index in RAY for particular token. If token is not
    function cumulativeIndex(address token) external view returns (uint256);

    /// @dev Updates quota for particular token, returns how much quota was given
    /// @param creditAccount Address of credit account
    /// @param token Token address of quoted token
    /// @param quotaChange Change in quota amount
    /// QUOTAS MGMT
    function updateQuota(
        address creditAccount,
        address token,
        int96 quotaChange
    ) external;

    /// TODO: add description
    function updateQuotas(
        address creditAccount,
        QuotaUpdate[] memory quotaUpdates
    ) external;

    function quotedTokens() external view returns (address[] memory);

    function updateRates(QuotaRateUpdate[] memory qUpdates) external;

    function computeQuotedCollateralUSD(
        address creditManager,
        address creditAccount,
        address _priceOracle,
        LimitTokenCalc[] memory tokens
    ) external view returns (uint256 value, uint256 premium);

    function closeCreditAccount(address creditAccount, address[] memory tokens)
        external
        returns (uint256);
}
