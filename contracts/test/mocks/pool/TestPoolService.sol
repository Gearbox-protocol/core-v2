// SPDX-License-Identifier: UNLICENSED
// Gearbox Protocol. Generalized leverage for DeFi protocols
// (c) Gearbox Holdings, 2021
pragma solidity ^0.8.10;

import { IPoolService } from "../../../interfaces/IPoolService.sol";

import { PoolService } from "../../../pool/PoolService.sol";

/**
 * @title Pool Service Test implementation
 * @notice Used for testing Pool Service. Implements some functions to set internal parameters
 * @author Gearbox
 */
contract TestPoolService is IPoolService, PoolService {
    /**
     * @dev Constructor
     * @param addressProvider Address Repository for upgradable contract model
     * @param _underlying Address of underlying token
     * @param interestRateModelAddress Address of interest rate model
     */
    constructor(
        address addressProvider,
        address _underlying,
        address interestRateModelAddress,
        uint256 _expectedLiquidityLimit
    )
        PoolService(
            addressProvider,
            _underlying,
            interestRateModelAddress,
            _expectedLiquidityLimit
        )
    {}

    /**
     * @dev Mock function to set _totalLiquidity manually
     * used for test purposes only
     */

    function setExpectedLiquidity(uint256 newExpectedLiquidity) external {
        _expectedLiquidityLU = newExpectedLiquidity;
    }

    function getCumulativeIndex_RAY() external view returns (uint256) {
        return _cumulativeIndex_RAY;
    }

    function getTimestampLU() external view returns (uint256) {
        return _timestampLU;
    }

    function getExpectedLU() external view returns (uint256) {
        return _expectedLiquidityLU;
    }

    function updateBorrowRate() external {
        _updateBorrowRate(0);
    }
}
