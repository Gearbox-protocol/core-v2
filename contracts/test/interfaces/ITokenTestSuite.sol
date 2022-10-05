// SPDX-License-Identifier: BUSL-1.1
// Gearbox. Generalized leverage protocol that allows to take leverage and then use it across other DeFi protocols and platforms in a composable way.
// (c) Gearbox.fi, 2021
pragma solidity ^0.8.10;
import { AggregatorV3Interface } from "@chainlink/contracts/src/v0.8/interfaces/AggregatorV3Interface.sol";
import { Tokens } from "./Tokens.sol";

interface ITokenTestSuite {
    function approve(
        address token,
        address holder,
        address targetContract
    ) external;

    function approve(
        Tokens t,
        address holder,
        address targetContract
    ) external;

    function approve(
        Tokens t,
        address holder,
        address targetContract,
        uint256 amount
    ) external;

    function topUpWETH(address onBehalfOf, uint256 value) external;

    function balanceOf(Tokens t, address holder)
        external
        view
        returns (uint256 balance);

    function mint(
        address token,
        address to,
        uint256 amount
    ) external;

    function mint(
        Tokens t,
        address to,
        uint256 amount
    ) external;
}
