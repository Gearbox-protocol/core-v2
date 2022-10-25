// SPDX-License-Identifier: GPL-2.0-or-later
// Gearbox Protocol. Generalized leverage for DeFi protocols
// (c) Gearbox Holdings, 2022
pragma solidity ^0.8.10;

/// @title Target Contract Mock
contract TargetContractMock {
    bytes public callData;

    constructor() {}

    fallback() external {
        callData = msg.data;
    }
}
