// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.10;
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

interface ICRVToken is IERC20 {
    function set_minter(address minter) external;

    function mint(address to, uint256 value) external returns (bool);

    function burnFrom(address to, uint256 value) external returns (bool);
}
