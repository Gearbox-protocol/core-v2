// SPDX-License-Identifier: UNLICENSED
// Gearbox Protocol. Generalized leverage for DeFi protocols
// (c) Gearbox Holdings, 2021
pragma solidity ^0.8.10;

import { Ownable } from "@openzeppelin/contracts/access/Ownable.sol";
import { ERC20 } from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import { PERCENTAGE_FACTOR } from "../../../libraries/PercentageMath.sol";

contract TokenFeeMock is ERC20, Ownable {
    uint256 public fee;

    constructor(
        string memory name_,
        string memory symbol_,
        uint256 fee_
    ) ERC20(name_, symbol_) {
        _mint(msg.sender, 1e24);
        fee = fee_;
        require(fee < PERCENTAGE_FACTOR, "Incorrect fee");
    }

    function mint(address to, uint256 amount) external onlyOwner {
        _mint(to, amount);
    }

    function transfer(address recipient, uint256 amount)
        public
        virtual
        override
        returns (bool)
    {
        _transfer(
            _msgSender(),
            recipient,
            (amount * (PERCENTAGE_FACTOR - fee)) / (PERCENTAGE_FACTOR)
        );
        return true;
    }

    function transferFrom(
        address sender,
        address recipient,
        uint256 amount
    ) public virtual override returns (bool) {
        amount = (amount * (PERCENTAGE_FACTOR - fee)) / (PERCENTAGE_FACTOR);

        return ERC20.transferFrom(sender, recipient, amount);
    }
}
