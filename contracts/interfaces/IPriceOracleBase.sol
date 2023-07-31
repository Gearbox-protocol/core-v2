// SPDX-License-Identifier: MIT
// Gearbox Protocol. Generalized leverage for DeFi protocols
// (c) Gearbox Holdings, 2022
pragma solidity ^0.8.10;

import { IVersion } from "./IVersion.sol";

/// @title Price oracle base interface
/// @notice Functions shared accross newer and older versions
interface IPriceOracleBase is IVersion {
    function getPrice(address token) external view returns (uint256);

    function convertToUSD(
        uint256 amount,
        address token
    ) external view returns (uint256);

    function convertFromUSD(
        uint256 amount,
        address token
    ) external view returns (uint256);

    function convert(
        uint256 amount,
        address tokenFrom,
        address tokenTo
    ) external view returns (uint256);

    function priceFeeds(
        address token
    ) external view returns (address priceFeed);
}
