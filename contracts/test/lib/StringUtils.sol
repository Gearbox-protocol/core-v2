// SPDX-License-Identifier: UNLICENSED
// Gearbox Protocol. Generalized leverage for DeFi protocols
// (c) Gearbox Holdings, 2022
pragma solidity ^0.8.10;

/// @notice Designed for test purposes only
library StringUtils {
    function memcmp(bytes memory a, bytes memory b) internal pure returns (bool) {
        return (a.length == b.length) && (keccak256(a) == keccak256(b));
    }

    function eq(string memory a, string memory b) internal pure returns (bool) {
        return memcmp(bytes(a), bytes(b));
    }

    function concat(string memory s1, string memory s2) internal pure returns (string memory res) {
        res = string(abi.encodePacked(bytes(s1), bytes(s2)));
    }

    function concat(string memory s1, string memory s2, string memory s3) internal pure returns (string memory res) {
        res = string(abi.encodePacked(bytes(s1), bytes(s2), bytes(s3)));
    }
}
