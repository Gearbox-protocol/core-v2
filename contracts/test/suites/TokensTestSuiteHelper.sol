// SPDX-License-Identifier: BUSL-1.1
// Gearbox. Generalized leverage protocol that allows to take leverage and then use it across other DeFi protocols and platforms in a composable way.
// (c) Gearbox Holdings, 2022
pragma solidity ^0.8.10;

import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import { IWETH } from "../../interfaces/external/IWETH.sol";

import { ITokenTestSuite } from "../interfaces/ITokenTestSuite.sol";

// MOCKS
import { ERC20Mock } from "../mocks/token/ERC20Mock.sol";
import "../lib/constants.sol";

contract TokensTestSuiteHelper is DSTest, ITokenTestSuite {
    CheatCodes evm = CheatCodes(HEVM_ADDRESS);
    address public wethToken;

    function topUpWETH() public payable override {
        IWETH(wethToken).deposit{ value: msg.value }();
    }

    function topUpWETH(address onBehalfOf, uint256 value) public override {
        evm.prank(onBehalfOf);
        IWETH(wethToken).deposit{ value: value }();
    }

    function mint(
        address token,
        address to,
        uint256 amount
    ) public virtual override {
        if (token == wethToken) {
            evm.deal(address(this), amount);
            IWETH(wethToken).deposit{ value: amount }();
        } else {
            ERC20Mock(token).mint(address(this), amount);
        }
        IERC20(token).transfer(to, amount);
    }

    function balanceOf(address token, address holder)
        public
        view
        override
        returns (uint256 balance)
    {
        balance = IERC20(token).balanceOf(holder);
    }

    function approve(
        address token,
        address holder,
        address targetContract
    ) public override {
        approve(token, holder, targetContract, type(uint256).max);
    }

    function approve(
        address token,
        address holder,
        address targetContract,
        uint256 amount
    ) public override {
        evm.prank(holder);
        IERC20(token).approve(targetContract, amount);
    }

    function burn(
        address token,
        address from,
        uint256 amount
    ) public override {
        ERC20Mock(token).burn(from, amount);
    }

    receive() external payable {}
}
