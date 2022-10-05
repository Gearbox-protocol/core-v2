// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface IPriceFeedAddress {
    /// @dev Returns the number of decimals in the price feed's returned result
    function decimals() external view returns (uint8);

    /// @dev Returns the price feed descriptiom
    function description() external view returns (string memory);

    /// @dev Returns the price feed version
    function version() external view returns (uint256);

    /// @dev Returns the latest price feed value
    /// @notice Return type is according to Chainlink spec
    function latestRoundData(address creditAccount)
        external
        view
        returns (
            uint80 roundId,
            int256 answer,
            uint256 startedAt,
            uint256 updatedAt,
            uint80 answeredInRound
        );
}
