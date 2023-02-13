// SPDX-License-Identifier: MIT

pragma solidity >=0.8.4;

import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

interface IUSDT is IERC20 {
    function basisPointsRate() external view returns (uint256);

    function maximumFee() external view returns (uint256);
}
