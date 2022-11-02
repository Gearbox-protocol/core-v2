// SPDX-License-Identifier: UNLICENSED
// Gearbox Protocol. Generalized leverage for DeFi protocols
// (c) Gearbox Holdings, 2022
pragma solidity ^0.8.10;

import { Ownable } from "@openzeppelin/contracts/access/Ownable.sol";
import { ERC20 } from "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract ERC20ApproveRestrictedRevert is ERC20, Ownable {
    constructor() ERC20("", "") {}

    function approve(address user, uint256 amount)
        public
        override
        returns (bool)
    {
        if ((allowance(msg.sender, user) > 0) && (amount != 0)) {
            revert("Try to change allowance from non-zero to non-zero");
        }
        _approve(msg.sender, user, amount);
        return true;
    }
}

contract ERC20ApproveRestrictedFalse is ERC20, Ownable {
    constructor() ERC20("", "") {}

    function approve(address user, uint256 amount)
        public
        override
        returns (bool)
    {
        if ((allowance(msg.sender, user) > 0) && (amount != 0)) {
            return false;
        }
        _approve(msg.sender, user, amount);
        return true;
    }
}
