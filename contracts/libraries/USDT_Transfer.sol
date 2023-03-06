// SPDX-License-Identifier: MIT
// Gearbox Protocol. Generalized leverage for DeFi protocols
// (c) Gearbox Holdings, 2022
pragma solidity ^0.8.10;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {IUSDT} from "../interfaces/external/IUSDT.sol";
import {PERCENTAGE_FACTOR} from "../libraries/Constants.sol";

import "forge-std/console.sol";

contract USDT_Transfer {
    using SafeERC20 for IERC20;

    address private immutable usdt;

    constructor(address _usdt) {
        usdt = _usdt;
    }

    function _safeUSDTTransfer(address to, uint256 amount) internal returns (uint256) {
        uint256 balanceBefore = IERC20(usdt).balanceOf(to);
        IERC20(usdt).balanceOf(msg.sender);

        IERC20(usdt).safeTransferFrom(msg.sender, to, amount);

        return IERC20(usdt).balanceOf(to) - balanceBefore;
    }

    /// @dev Computes how much usdt you should send to get exact amount on destination account
    function _amountUSDTWithFee(uint256 amount) internal view virtual returns (uint256) {
        uint256 amountWithBP = (amount * PERCENTAGE_FACTOR) / (PERCENTAGE_FACTOR - IUSDT(usdt).basisPointsRate());
        uint256 maximumFee = IUSDT(usdt).maximumFee();
        unchecked {
            uint256 amountWithMaxFee = maximumFee > type(uint256).max - amount ? maximumFee : amount + maximumFee;
            return amountWithBP > amountWithMaxFee ? amountWithMaxFee : amountWithBP;
        }
    }

    /// @dev Computes how much usdt you should send to get exact amount on destination account
    function _amountUSDTMinusFee(uint256 amount) internal view virtual returns (uint256) {
        uint256 fee = amount * IUSDT(usdt).basisPointsRate() / 10000;
        uint256 maximumFee = IUSDT(usdt).maximumFee();
        if (fee > maximumFee) {
            fee = maximumFee;
        }
        return amount - fee;
    }
}
