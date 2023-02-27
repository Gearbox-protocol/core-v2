// SPDX-License-Identifier: UNLICENSED
// Gearbox Protocol. Generalized leverage for DeFi protocols
// (c) Gearbox Holdings, 2022
pragma solidity ^0.8.10;

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {ERC20Mock} from "./ERC20Mock.sol";
import {PERCENTAGE_FACTOR} from "../../../libraries/PercentageMath.sol";
import {IUSDT} from "../../../interfaces/external/IUSDT.sol";
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract ERC20FeeMock is IUSDT, ERC20Mock {
    uint256 public override basisPointsRate;
    uint256 public override maximumFee;

    constructor(string memory name_, string memory symbol_, uint8 decimals_) ERC20Mock(name_, symbol_, decimals_) {}

    function transfer(address recipient, uint256 amount) public virtual override (ERC20, IERC20) returns (bool) {
        uint256 fee = _computeFee(amount);
        _transfer(_msgSender(), recipient, amount - fee);
        if (fee > 0) _transfer(_msgSender(), owner(), fee);
        return true;
    }

    function transferFrom(address sender, address recipient, uint256 amount)
        public
        virtual
        override (ERC20, IERC20)
        returns (bool)
    {
        uint256 fee = _computeFee(amount);
        if (fee > 0) _transfer(sender, owner(), fee);
        return super.transferFrom(sender, recipient, amount - fee);
    }

    function _computeFee(uint256 amount) internal view returns (uint256) {
        uint256 fee = (amount * basisPointsRate) / PERCENTAGE_FACTOR;
        if (fee > maximumFee) {
            fee = maximumFee;
        }
        return fee;
    }

    function setMaximumFee(uint256 _fee) external {
        maximumFee = _fee;
    }

    function setBasisPointsRate(uint256 _rate) external {
        require(_rate < PERCENTAGE_FACTOR, "Incorrect fee");
        basisPointsRate = _rate;
    }
}
