// SPDX-License-Identifier: MIT
// Gearbox Protocol. Generalized leverage for DeFi protocols
// (c) Gearbox Holdings, 2022
pragma solidity ^0.8.10;

import { IVersion } from "./IVersion.sol";

struct QuotaUpdate {
    address token;
    int96 quotaChange;
}

interface IPoolQuotaKeeperExceptions {
    error GaugeOnlyException();
    error CreditManagerOnlyException();

    error IncompatibleCreditManagerException();
}

interface IPoolQuotaKeeperEvents {
    /// @dev Emits when the withdrawal fee is changed
    event NewWithdrawFee(uint256 fee);
}

/// @title Pool Quotas Interface
interface IPoolQuotaKeeper is
    IPoolQuotaKeeperEvents,
    IPoolQuotaKeeperExceptions,
    IVersion
{
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
}
