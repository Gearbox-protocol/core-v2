// SPDX-License-Identifier: UNLICENSED
// Gearbox Protocol. Generalized leverage for DeFi protocols
// (c) Gearbox Holdings, 2021
pragma solidity ^0.8.10;

import { Ownable } from "@openzeppelin/contracts/access/Ownable.sol";
import { ERC20 } from "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract ERC20Mock is ERC20, Ownable {
    uint8 private immutable _decimals;
    address public minter;

    constructor(
        string memory name_,
        string memory symbol_,
        uint8 decimals_
    ) ERC20(name_, symbol_) {
        _decimals = decimals_;
        minter = msg.sender;
        // _mint(msg.sender, 1e24);
    }

    modifier minterOnly() {
        require(msg.sender == minter, "Minter calls only");
        _;
    }

    function decimals() public view override returns (uint8) {
        return _decimals;
    }

    function mint(address to, uint256 amount)
        external
        minterOnly
        returns (bool)
    {
        _mint(to, amount);
        return true;
    }

    function burnFrom(address to, uint256 amount)
        external
        minterOnly
        returns (bool)
    {
        _burn(to, amount);
        return true;
    }

    function burn(address to, uint256 amount) external returns (bool) {
        _burn(to, amount);
        return true;
    }

    function set_minter(address _minter) external {
        minter = _minter;
    }
}
