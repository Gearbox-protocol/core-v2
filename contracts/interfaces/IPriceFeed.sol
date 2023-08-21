// SPDX-License-Identifier: MIT
// Gearbox Protocol. Generalized leverage for DeFi protocols
// (c) Gearbox Foundation, 2023.
pragma solidity ^0.8.0;

import { PriceFeedType } from "@gearbox-protocol/sdk-gov/contracts/PriceFeedType.sol";

/// @title Price feed interface
interface IPriceFeed {
    function priceFeedType() external view returns (PriceFeedType);

    function version() external view returns (uint256);

    function decimals() external view returns (uint8);

    function description() external view returns (string memory);

    function skipPriceCheck() external view returns (bool);

    function latestRoundData()
        external
        view
        returns (uint80, int256 answer, uint256, uint256 updatedAt, uint80);
}

/// @title Updatable price feed interface
interface IUpdatablePriceFeed is IPriceFeed {
    function updatable() external view returns (bool);

    function updatePrice(bytes calldata data) external;
}
