// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.10;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract WETHMock is IERC20 {
    string public name = "Wrapped Ether";
    string public symbol = "WETH";
    uint8 public decimals = 18;

    // event Approval(address indexed src, address indexed guy, uint256 wad);
    // event Transfer(address indexed src, address indexed dst, uint256 wad);
    event Deposit(address indexed dst, uint256 wad);
    event Withdrawal(address indexed src, uint256 wad);

    mapping(address => uint256) public balanceOf;
    mapping(address => mapping(address => uint256)) public allowance;

    function mint(address to, uint256 amount) external {
        balanceOf[to] += amount;
    }

    receive() external payable {
        deposit(); // T:[WM-1]
    }

    function deposit() public payable {
        balanceOf[msg.sender] += msg.value; // T:[WM-1]
        emit Deposit(msg.sender, msg.value); // T:[WM-1]
    }

    function withdraw(uint256 wad) public {
        require(balanceOf[msg.sender] >= wad); // T:[WM-2]
        balanceOf[msg.sender] -= wad; // T:[WM-2]
        payable(msg.sender).transfer(wad); // T:[WM-3]
        emit Withdrawal(msg.sender, wad); // T:[WM-4]
    }

    function totalSupply() public view returns (uint256) {
        return address(this).balance; // T:[WM-1, 2]
    }

    function approve(address guy, uint256 wad) public returns (bool) {
        allowance[msg.sender][guy] = wad; // T:[WM-3]
        emit Approval(msg.sender, guy, wad); // T:[WM-3]
        return true;
    }

    function transfer(address dst, uint256 wad) public returns (bool) {
        return transferFrom(msg.sender, dst, wad); // T:[WM-4,5,6]
    }

    function transferFrom(address src, address dst, uint256 wad) public returns (bool) {
        require(balanceOf[src] >= wad); // T:[WM-4]

        if (src != msg.sender && allowance[src][msg.sender] != type(uint256).max) {
            require(allowance[src][msg.sender] >= wad); // T:[WM-4]
            allowance[src][msg.sender] -= wad; // T:[WM-7]
        }

        balanceOf[src] -= wad; // T:[WM-5]
        balanceOf[dst] += wad; // T:[WM-5]

        emit Transfer(src, dst, wad); // T:[WM-6]

        return true;
    }
}
