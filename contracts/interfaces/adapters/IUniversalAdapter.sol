// SPDX-License-Identifier: MIT
// Gearbox Protocol. Generalized leverage for DeFi protocols
// (c) Gearbox Holdings, 2023
pragma solidity ^0.8.17;

import {IAdapter} from "./IAdapter.sol";

struct RevocationPair {
    address spender;
    address token;
}

/// @title Universal adapter interface
/// @notice Implements the initial version of universal adapter, which handles allowance revocations
interface IUniversalAdapter is IAdapter {
    /// @notice Revokes adapters allowances for specified tokens of the credit account
    /// @param revocations Adapter/token pairs to revoke allowances for
    function revokeAdapterAllowances(RevocationPair[] calldata revocations) external;
}
