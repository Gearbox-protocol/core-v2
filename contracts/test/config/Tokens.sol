// SPDX-License-Identifier: UNLICENSED
// Gearbox. Generalized leverage protocol that allows to take leverage and then use it across other DeFi protocols and platforms in a composable way.
// (c) Gearbox Holdings, 2022
pragma solidity ^0.8.10;

/// @dev c-Tokens and LUNA are added for unit test purposes
enum Tokens {
    NO_TOKEN,
    DAI,
    USDC,
    WETH,
    LINK,
    USDT,
    STETH,
    CRV,
    CVX,
    LUNA,
    wstETH
}
