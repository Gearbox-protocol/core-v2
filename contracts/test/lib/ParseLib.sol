// SPDX-License-Identifier: UNLICENSED
// Gearbox Protocol. Generalized leverage for DeFi protocols
// (c) Gearbox Holdings, 2022
pragma solidity ^0.8.10;

import {Strings} from "@openzeppelin/contracts/utils/Strings.sol";
import {StringUtils} from "./StringUtils.sol";
import {IERC20Metadata} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";

/// @notice Designed for test purposes only
library ParseLib {
    using Strings for uint256;
    using StringUtils for string;

    function add(string memory init, string memory name, address addr) internal pure returns (string memory) {
        return init.concat(name, uint256(uint160(addr)).toHexString(20));
    }

    function add(string memory init, string memory name, uint256 value) internal pure returns (string memory) {
        return init.concat(name, value.toString());
    }

    function add_amount_decimals(string memory init, string memory name, uint256 value, uint8 decimals)
        internal
        pure
        returns (string memory)
    {
        return init.concat(name, toFixString(value, decimals));
    }

    function add_amount_token(string memory init, string memory name, uint256 value, address token)
        internal
        view
        returns (string memory)
    {
        return add_amount_decimals(init, name, value, IERC20Metadata(token).decimals());
    }

    function add_token(string memory init, string memory name, address addr) internal view returns (string memory) {
        return init.concat(name, IERC20Metadata(addr).symbol());
    }

    function toFixString(uint256 value, uint8 decimals) internal pure returns (string memory) {
        uint8 divider = (decimals > 4) ? 4 : decimals;
        uint256 biggerPart = value / (10 ** (decimals));
        uint256 smallerPart = value * (10 ** divider) - biggerPart * (10 ** (decimals + divider));
        return biggerPart.toString().concat(".", smallerPart.toString());
    }
}
