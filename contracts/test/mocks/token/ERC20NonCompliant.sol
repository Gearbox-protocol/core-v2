pragma solidity ^0.8.10;

//Non ERC20 compliant token which do not have a return value on approve/transfer (e.g. TUSD, OMG)
contract NonCompliantERC20 {
    function approve(address, uint256) external pure returns (bool) {
        return false;
    }
}
