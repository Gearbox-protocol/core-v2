// SPDX-License-Identifier: MIT
// Gearbox Protocol. Generalized leverage for DeFi protocols
// (c) Gearbox Holdings, 2022
pragma solidity ^0.8.10;

struct GaugeOpts {
    address addressProvider;
    address pool;
    uint256 firstEpochTimestamp;
    address gearToken;
}

interface IGaugeExceptions {
    error TokenQuotaIsAlreadyAdded();

    error NotEnoughBalance();
}

interface IGaugeEvents {
    event Deposit(address indexed caller, address indexed owner, uint256 assets);

    event Withdraw(address indexed caller, address indexed receiver, uint256 assets);

    event VoteFor(address indexed token, uint96 votes, bool lpSide);

    event UnvoteFrom(address indexed token, uint96 votes, bool lpSide);

    event QuotaTokenAdded(address indexed token);

    event QuotaRateUpdated(address indexed token, uint16 rate);
}

/// @title IGauge

interface IGauge is IGaugeEvents, IGaugeExceptions {
    /// @dev Returns quota rate in PERCENTAGE FORMAT
    function getQuotaRate(address) external view returns (uint16);

    /// @dev Returns cumulative index in RAY for particular token. If token is not
    function cumulativeIndex(address token) external view returns (uint256);
}
