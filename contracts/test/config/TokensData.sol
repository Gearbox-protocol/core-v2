// SPDX-License-Identifier: BUSL-1.1
// Gearbox. Generalized leverage protocol that allows to take leverage and then use it across other DeFi protocols and platforms in a composable way.
// (c) Gearbox.fi, 2021
pragma solidity ^0.8.10;

import { Tokens } from "./Tokens.sol";
import "../lib/constants.sol";
// import "../lib/test.sol";

struct TestToken {
    Tokens index;
    string symbol;
    uint8 decimals;
    int256 price;
    Tokens underlying;
}

contract TokensData {
    function tokensData() internal view returns (TestToken[] memory result) {
        TestToken[10] memory tokensData = [
            TestToken({
                index: Tokens.DAI,
                symbol: "DAI",
                decimals: 18,
                price: 10**8,
                underlying: Tokens.NO_TOKEN
            }),
            TestToken({
                index: Tokens.USDC,
                symbol: "USDC",
                decimals: 6,
                price: 10**8,
                underlying: Tokens.NO_TOKEN
            }),
            TestToken({
                index: Tokens.WETH,
                symbol: "WETH",
                decimals: 18,
                price: int256(DAI_WETH_RATE) * 10**8,
                underlying: Tokens.NO_TOKEN
            }),
            TestToken({
                index: Tokens.LINK,
                symbol: "LINK",
                decimals: 18,
                price: 15 * 10**8,
                underlying: Tokens.NO_TOKEN
            }),
            TestToken({
                index: Tokens.USDT,
                symbol: "USDT",
                decimals: 18,
                price: 99 * 10**7, // .99 for test purposes
                underlying: Tokens.NO_TOKEN
            }),
            TestToken({
                index: Tokens.STETH,
                symbol: "stETH",
                decimals: 18,
                price: 3300 * 10**8,
                underlying: Tokens.NO_TOKEN
            }),
            TestToken({
                index: Tokens.CRV,
                symbol: "CRV",
                decimals: 18,
                price: 14 * 10**7,
                underlying: Tokens.NO_TOKEN
            }),
            TestToken({
                index: Tokens.CVX,
                symbol: "CVX",
                decimals: 18,
                price: 7 * 10**8,
                underlying: Tokens.NO_TOKEN
            }),
            TestToken({
                index: Tokens.LUNA,
                symbol: "LUNA",
                decimals: 18,
                price: 1,
                underlying: Tokens.NO_TOKEN
            }),
            TestToken({
                index: Tokens.wstETH,
                symbol: "wstETH",
                decimals: 18,
                price: 3300 * 10**8,
                underlying: Tokens.NO_TOKEN
            })
        ];

        uint256 len = tokensData.length;
        result = new TestToken[](len);

        unchecked {
            for (uint256 i = 0; i < len; ++i) {
                result[i] = tokensData[i];
            }
        }
    }
}
