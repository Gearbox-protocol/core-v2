// SPDX-License-Identifier: UNLICENSED
// Gearbox. Generalized leverage protocol that allows to take leverage and then use it across other DeFi protocols and platforms in a composable way.
// (c) Gearbox Holdings, 2022
pragma solidity ^0.8.10;

interface ITokenTestSuite {
    function wethToken() external view returns (address);

    function approve(address token, address holder, address targetContract) external;

    function approve(address token, address holder, address targetContract, uint256 amount) external;

    // function approve(
    //     Tokens t,
    //     address holder,
    //     address targetContract
    // ) external;

    // function approve(
    //     Tokens t,
    //     address holder,
    //     address targetContract,
    //     uint256 amount
    // ) external;

    function topUpWETH() external payable;

    function topUpWETH(address onBehalfOf, uint256 value) external;

    function balanceOf(address token, address holder) external view returns (uint256 balance);

    function mint(address token, address to, uint256 amount) external;

    function burn(address token, address from, uint256 amount) external;

    // function mint(
    //     Tokens t,
    //     address to,
    //     uint256 amount
    // ) external;
}
