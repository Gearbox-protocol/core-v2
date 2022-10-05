// SPDX-License-Identifier: UNLICENSED
// Gearbox Protocol. Generalized leverage for DeFi protocols
// (c) Gearbox Holdings, 2021
pragma solidity ^0.8.10;

import { AggregatorV3Interface } from "@chainlink/contracts/src/v0.8/interfaces/AggregatorV3Interface.sol";
import { IPriceFeedType, PriceFeedType } from "../../../interfaces/IPriceFeedType.sol";

enum FlagState {
    FALSE,
    TRUE,
    REVERT
}

/// @title Price feed mock
/// @notice Used for test purposes only
contract PriceFeedMock is AggregatorV3Interface, IPriceFeedType {
    int256 private price;
    uint8 public immutable override decimals;

    uint80 internal roundId;
    uint256 startedAt;
    uint256 updatedAt;
    uint80 internal answerInRound;

    PriceFeedType internal _priceFeedType;

    FlagState internal _skipPriceCheck;

    bool internal revertOnLatestRound;

    constructor(int256 _price, uint8 _decimals) {
        price = _price;
        decimals = _decimals;
        roundId = 80;
        answerInRound = 80;
        startedAt = uint256(block.timestamp);
        updatedAt = uint256(block.timestamp);
    }

    function setParams(
        uint80 _roundId,
        uint256 _startedAt,
        uint256 _updatedAt,
        uint80 _answerInRound
    ) external {
        roundId = _roundId;
        startedAt = _startedAt;
        updatedAt = _updatedAt;
        answerInRound = _answerInRound;

        _skipPriceCheck = FlagState.REVERT;
    }

    function description() external pure override returns (string memory) {
        return "price oracle";
    }

    function version() external pure override returns (uint256) {
        return 1;
    }

    function setPrice(int256 newPrice) external {
        price = newPrice;
    }

    // getRoundData and latestRoundData should both raise "No data present"
    // if they do not have data to report, instead of returning unset values
    // which could be misinterpreted as actual reported values.
    function getRoundData(uint80)
        external
        view
        override
        returns (
            uint80, // roundId,
            int256, // answer,
            uint256, // startedAt,
            uint256, // updatedAt,
            uint80 // answeredInRound
        )
    {
        return (roundId, price, startedAt, updatedAt, answerInRound);
    }

    function latestRoundData()
        external
        view
        override
        returns (
            uint80, // roundId,
            int256, // answer,
            uint256, // startedAt,
            uint256, // updatedAt,
            uint80 //answeredInRound
        )
    {
        if (revertOnLatestRound) revert();

        return (roundId, price, startedAt, updatedAt, answerInRound);
    }

    function priceFeedType() external view override returns (PriceFeedType) {
        return _priceFeedType;
    }

    function skipPriceCheck() external view override returns (bool) {
        return flagState(_skipPriceCheck);
    }

    function flagState(FlagState f) internal pure returns (bool value) {
        if (f == FlagState.REVERT) revert();
        return f == FlagState.TRUE;
    }

    function setSkipPriceCheck(FlagState f) external {
        _skipPriceCheck = f;
    }

    function setRevertOnLatestRound(bool value) external {
        revertOnLatestRound = value;
    }
}
