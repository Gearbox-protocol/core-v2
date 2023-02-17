// SPDX-License-Identifier: MIT
// Gearbox Protocol. Generalized leverage for DeFi protocols
// (c) Gearbox Holdings, 2022
pragma solidity ^0.8.10;

import { IVersion } from "./IVersion.sol";

interface IInterestRateModelExceptions {
    error IncorrectParameterException();
    error BorrowingMoreOptimalForbiddenException();
}

interface IInterestRateModel is IInterestRateModelExceptions, IVersion {
    /// @dev Returns the borrow rate calculated based on expectedLiquidity and availableLiquidity
    /// @param expectedLiquidity Expected liquidity in the pool
    /// @param availableLiquidity Available liquidity in the pool
    /// @notice In RAY format
    function calcBorrowRate(
        uint256 expectedLiquidity,
        uint256 availableLiquidity
    ) external view returns (uint256);

    /// @dev Returns the borrow rate calculated based on expectedLiquidity and availableLiquidity
    /// @param expectedLiquidity Expected liquidity in the pool
    /// @param availableLiquidity Available liquidity in the pool
    /// @notice In RAY format
    function calcBorrowRate(
        uint256 expectedLiquidity,
        uint256 availableLiquidity,
        bool checkOptimalBorrowing
    ) external view returns (uint256);

    function availableToBorrow(
        uint256 expectedLiquidity,
        uint256 availableLiquidity
    ) external view returns (uint256);
}
