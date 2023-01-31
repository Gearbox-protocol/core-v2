// SPDX-License-Identifier: UNLICENSED
// Gearbox Protocol. Generalized leverage for DeFi protocols
// (c) Gearbox Holdings, 2022
pragma solidity ^0.8.10;

import { IPool4626, Pool4626Opts } from "../../../interfaces/IPool4626.sol";

import { Pool4626 } from "../../../pool/Pool4626.sol";

/// @title Pool 4626 Test implementation
/// @notice Used for testing Pool46626 Service. Implements some functions to set internal parameters
/// @author Gearbox
contract TestPool4626 is IPool4626, Pool4626 {
    /// @dev Constructor
    /// @param opts Core pool options
    constructor(Pool4626Opts memory opts) Pool4626(opts) {}

    function setExpectedLiquidityLU(uint256 newExpectedLiquidityLU) external {
        _expectedLiquidityLU = uint128(newExpectedLiquidityLU);
    }

    function getCumulativeIndex_RAY() external view returns (uint256) {
        return _cumulativeIndex_RAY;
    }

    function getExpectedLU() external view returns (uint256) {
        return _expectedLiquidityLU;
    }

    function updateBorrowRate() external {
        _updateParameters(0, 0, false);
    }
}
