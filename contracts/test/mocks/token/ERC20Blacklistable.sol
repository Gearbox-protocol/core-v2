// SPDX-License-Identifier: UNLICENSED
// Gearbox Protocol. Generalized leverage for DeFi protocols
// (c) Gearbox Holdings, 2022
pragma solidity ^0.8.10;

import { Ownable } from "@openzeppelin/contracts/access/Ownable.sol";
import { ERC20 } from "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract ERC20BlacklistableMock is ERC20, Ownable {
    uint8 private immutable _decimals;
    mapping(address => bool) public isBlacklisted;
    mapping(address => bool) public isBlackListed;

    constructor(
        string memory name_,
        string memory symbol_,
        uint8 decimals_
    ) ERC20(name_, symbol_) {
        _decimals = decimals_;
    }

    function decimals() public view override returns (uint8) {
        return _decimals;
    }

    function mint(address to, uint256 amount)
        external
        onlyOwner
        returns (bool)
    {
        _mint(to, amount);
        return true;
    }

    function transfer(address recipient, uint256 amount)
        public
        override
        returns (bool)
    {
        if (isBlacklisted[msg.sender] || isBlacklisted[recipient]) {
            revert("Token transaction with blacklisted address");
        }

        _transfer(_msgSender(), recipient, amount);

        return true;
    }

    function transferFrom(
        address from,
        address to,
        uint256 amount
    ) public override returns (bool) {
        if (isBlacklisted[from] || isBlacklisted[to]) {
            revert("Token transaction with blacklisted address");
        }

        address spender = _msgSender();
        _spendAllowance(from, spender, amount);
        _transfer(from, to, amount);
        return true;
    }

    function setBlacklisted(address account, bool status) external {
        isBlacklisted[account] = status;
    }

    function setBlackListed(address account, bool status) external {
        isBlackListed[account] = status;
    }
}
