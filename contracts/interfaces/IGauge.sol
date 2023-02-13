// SPDX-License-Identifier: MIT
// Gearbox Protocol. Generalized leverage for DeFi protocols
// (c) Gearbox Holdings, 2022
pragma solidity ^0.8.10;

struct GaugeOpts {
    address addressProvider;
    address pool;
    uint256 firstEpochTimestamp;
}

interface IGaugeExceptions {
    error TokenQuotaIsAlreadyAdded();
}

interface IGaugeEvents {}

/// @title IGauge

interface IGauge is IGaugeEvents, IGaugeExceptions {
    /// @dev Returns quota rate in PERCENTAGE FORMAT
    function getQuotaRate(address) external view returns (uint256);

    /// @dev Returns cumulative index in RAY for particular token. If token is not
    function cumulativeIndex(address token) external view returns (uint256);
}
