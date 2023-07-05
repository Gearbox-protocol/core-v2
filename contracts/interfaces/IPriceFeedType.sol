// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface IPriceFeedType {
    /// @dev Returns whether sanity checks on price feed result should be skipped
    function skipPriceCheck() external view returns (bool);
}
