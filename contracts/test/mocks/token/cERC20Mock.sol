// SPDX-License-Identifier: UNLICENSED
// Gearbox Protocol. Generalized leverage for DeFi protocols
// (c) Gearbox Holdings, 2021
pragma solidity ^0.8.10;

import { Ownable } from "@openzeppelin/contracts/access/Ownable.sol";
import { ERC20 } from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract cERC20Mock is ERC20, Ownable {
    uint8 private immutable _decimals;
    address public immutable underlying;

    constructor(
        string memory name_,
        string memory symbol_,
        uint8 decimals_,
        address underlying_
    ) ERC20(name_, symbol_) {
        _decimals = decimals_;
        underlying = underlying_;
    }

    function decimals() public view override returns (uint8) {
        return _decimals;
    }

    function mint(address to, uint256 amount) external {
        IERC20(underlying).transferFrom(msg.sender, address(this), amount);
        _mint(to, amount);
    }

    function redeem(address to, uint256 amount) external {
        _burn(msg.sender, amount);
        IERC20(underlying).transfer(to, amount);
    }
}
