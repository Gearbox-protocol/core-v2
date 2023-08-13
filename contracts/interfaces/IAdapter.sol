// SPDX-License-Identifier: MIT
// Gearbox Protocol. Generalized leverage for DeFi protocols
// (c) Gearbox Foundation, 2023.
pragma solidity ^0.8.0;

import { AdapterType } from "@gearbox-protocol/sdk/contracts/AdapterType.sol";

/// @title Adapter interface
interface IAdapter {
    function _gearboxAdapterType() external pure returns (AdapterType);

    function _gearboxAdapterVersion() external pure returns (uint16);

    function creditManager() external view returns (address);

    function addressProvider() external view returns (address);

    function targetContract() external view returns (address);
}
