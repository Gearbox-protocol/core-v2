// SPDX-License-Identifier: BUSL-1.1
// Gearbox. Generalized leverage protocol that allows to take leverage and then use it across other DeFi protocols and platforms in a composable way.
// (c) Gearbox.fi, 2021
pragma solidity ^0.8.10;
import "../lib/test.sol";
import { CheatCodes, HEVM_ADDRESS } from "../lib/cheatCodes.sol";

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
