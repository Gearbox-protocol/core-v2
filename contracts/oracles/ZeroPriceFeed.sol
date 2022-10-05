// SPDX-License-Identifier: BUSL-1.1
// Gearbox Protocol. Generalized leverage for DeFi protocols
// (c) Gearbox Holdings, 2021
pragma solidity ^0.8.10;

import { AggregatorV3Interface } from "@chainlink/contracts/src/v0.8/interfaces/AggregatorV3Interface.sol";
import { IPriceFeedType, PriceFeedType } from "../interfaces/IPriceFeedType.sol";

// EXCEPTIONS
import { NotImplementedException } from "../interfaces/IErrors.sol";

/// @title Pricefeed which always returns 0
/// @notice Used for collateral tokens that do not have a valid USD price feed
contract ZeroPriceFeed is AggregatorV3Interface, IPriceFeedType {
    string public constant override description = "Zero pricefeed"; // F:[ZPF-1]

    uint8 public constant override decimals = 8; // F:[ZPF-1]

    uint256 public constant override version = 1;

    PriceFeedType public constant override priceFeedType =
        PriceFeedType.ZERO_ORACLE;

    bool public constant override skipPriceCheck = true; // F:[ZPF-1]

    /// @dev Not implemented, since Gearbox does not use historical data
    function getRoundData(
        uint80 //_roundId)
    )
        external
        pure
        override
        returns (
            uint80, // roundId,
            int256, //answer,
            uint256, // startedAt,
            uint256, // updatedAt,
            uint80 // answeredInRound
        )
    {
        revert NotImplementedException(); // F:[ZPF-2]
    }

    /// @dev Returns the latest result according to Chainlink spec
    /// @notice 'answer' is always 0
    function latestRoundData()
        external
        view
        override
        returns (
            uint80 roundId,
            int256 answer,
            uint256 startedAt,
            uint256 updatedAt,
            uint80 answeredInRound
        )
    {
        roundId = 1; // F:[ZPF-3]
        answer = 0; // F:[ZPF-3]
        startedAt = block.timestamp; // F:[ZPF-3]
        updatedAt = block.timestamp; // F:[ZPF-3]
        answeredInRound = 1; // F:[ZPF-3]
    }
}
