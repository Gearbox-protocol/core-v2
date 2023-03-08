// SPDX-License-Identifier: MIT
// Gearbox Protocol. Generalized leverage for DeFi protocols
// (c) Gearbox Holdings, 2022
pragma solidity ^0.8.10;

struct GaugeOpts {
    address addressProvider;
    address pool;
    address vlGEAR;
}

interface IGaugeExceptions {
    error OnlyVoterException();
}

interface IGaugeEvents {
    event VoteFor(address indexed user, address indexed token, uint96 votes, bool lpSide);

    event UnvoteFrom(address indexed user, address indexed token, uint96 votes, bool lpSide);
}

/// @title IGauge

interface IGauge is IGaugeEvents, IGaugeExceptions {}
