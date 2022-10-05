// SPDX-License-Identifier: BUSL-1.1
// Gearbox Protocol. Generalized leverage for DeFi protocols
// (c) Gearbox Holdings, 2021
pragma solidity ^0.8.10;

import { PriceFeedType } from "../../../interfaces/IPriceFeedType.sol";
import { LPPriceFeed } from "../../../oracles/LPPriceFeed.sol";

// EXCEPTIONS

/// @title PPriceFeedMock pricefeed adapter
contract LPPriceFeedMock is LPPriceFeed {
    PriceFeedType public constant override priceFeedType =
        PriceFeedType.YEARN_ORACLE;
    uint256 public constant override version = 1;

    // This pricefeed doesn't need sanity check, cause we check priceFeed for underlying token and set bounds for pricePerShare value
    bool public constant override skipPriceCheck = true;

    constructor(
        address addressProvider,
        uint256 range,
        string memory descrition
    )
        LPPriceFeed(
            addressProvider,
            range, // F:[LPF-1]
            descrition
        )
    {}

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
        roundId = 1;
        answer = 0;
        startedAt = block.timestamp;
        updatedAt = block.timestamp;
        answeredInRound = 1;
    }

    function checkAndUpperBoundValue(uint256 value)
        external
        view
        returns (uint256)
    {
        return _checkAndUpperBoundValue(value);
    }

    function _checkCurrentValueInBounds(uint256, uint256)
        internal
        pure
        override
        returns (bool)
    {
        return true;
    }
}
