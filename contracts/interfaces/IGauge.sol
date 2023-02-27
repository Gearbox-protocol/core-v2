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
    error NotEnoughBalance();
}

interface IGaugeEvents {
    event Deposit(address indexed caller, address indexed owner, uint256 assets);

    event Withdraw(address indexed caller, address indexed receiver, uint256 assets);

    event VoteFor(address indexed token, uint96 votes, bool lpSide);

    event UnvoteFrom(address indexed token, uint96 votes, bool lpSide);
}

/// @title IGauge

interface IGauge is IGaugeEvents, IGaugeExceptions {}
