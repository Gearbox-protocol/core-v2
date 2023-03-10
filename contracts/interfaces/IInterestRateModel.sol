// SPDX-License-Identifier: MIT
// Gearbox Protocol. Generalized leverage for DeFi protocols
// (c) Gearbox Holdings, 2022
pragma solidity ^0.8.10;

import {IVersion} from "@gearbox-protocol/core-v2/contracts/interfaces/IVersion.sol";

interface IInterestRateModelExceptions {
    error IncorrectParameterException();
    error BorrowingMoreOptimalForbiddenException();
}

interface IInterestRateModel is IInterestRateModelExceptions, IVersion {
    /// @dev Returns the borrow rate calculated based on expectedLiquidity and availableLiquidity
    /// @param expectedLiquidity Expected liquidity in the pool
    /// @param availableLiquidity Available liquidity in the pool
    /// @notice In RAY format
    function calcBorrowRate(uint256 expectedLiquidity, uint256 availableLiquidity) external view returns (uint256);

    /// @dev Returns the borrow rate calculated based on expectedLiquidity and availableLiquidity
    /// @param expectedLiquidity Expected liquidity in the pool
    /// @param availableLiquidity Available liquidity in the pool
    /// @notice In RAY format
    function calcBorrowRate(uint256 expectedLiquidity, uint256 availableLiquidity, bool checkOptimalBorrowing)
        external
        view
        returns (uint256);

    function availableToBorrow(uint256 expectedLiquidity, uint256 availableLiquidity) external view returns (uint256);

    function U_Optimal_WAD() external view returns (uint256);

    // Uoptimal[0 external view returns (uint256);1] in Wad
    function U_Reserve_WAD() external view returns (uint256);

    // R_base in Ray
    function R_base_RAY() external view returns (uint256);

    // R_Slope1 in Ray
    function R_slope1_RAY() external view returns (uint256);

    // R_Slope2 in Ray
    function R_slope2_RAY() external view returns (uint256);

    // R_Slope2 in Ray
    function R_slope3_RAY() external view returns (uint256);
}
