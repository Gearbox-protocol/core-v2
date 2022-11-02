// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.10;

import { WAD, RAY, DEFAULT_FEE_LIQUIDATION, DEFAULT_LIQUIDATION_PREMIUM } from "../../libraries/Constants.sol";
import "../lib/test.sol";
import { CheatCodes, HEVM_ADDRESS } from "../lib/cheatCodes.sol";

uint16 constant DEFAULT_UNDERLYING_LT = 10000 -
    DEFAULT_FEE_LIQUIDATION -
    DEFAULT_LIQUIDATION_PREMIUM;

address constant DUMB_ADDRESS = 0xC4375B7De8af5a38a93548eb8453a498222C4fF2;
address constant DUMB_ADDRESS2 = 0x93548eB8453a498222C4FF2C4375b7De8af5A38a;
address constant DUMB_ADDRESS3 = 0x822293548EB8453A49c4fF2c4375B7DE8AF5a38A;
address constant DUMB_ADDRESS4 = 0x498222C4Ff2C4393548eb8453a75B7dE8AF5A38a;

address constant USER = 0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266;
address constant CONFIGURATOR = 0x70997970C51812dc3A010C7d01b50e0d17dc79C8;
address constant LIQUIDATOR = 0x3C44CdDdB6a900fa2b585dd299e03d12FA4293BC;

address constant FRIEND = 0x90F79bf6EB2c4f870365E785982E1f101E93b906;
address constant FRIEND2 = 0x15d34AAf54267DB7D7c367839AAf71A00a2C6A65;

address constant ADAPTER = 0x9965507D1a55bcC2695C58ba16FB37d819B0A4dc;

address constant UNIVERSAL_CONTRACT_ADDRESS = 0xCcCCccccCCCCcCCCCCCcCcCccCcCCCcCcccccccC;

string constant PAUSABLE_ERROR = "Pausable: paused";
string constant OWNABLE_ERROR = "Ownable: caller is not the owner";

uint128 constant DAI_MIN_BORROWED_AMOUNT = uint128(1000 * WAD);
uint128 constant DAI_MAX_BORROWED_AMOUNT = uint128(10000 * WAD);

uint256 constant DAI_ACCOUNT_AMOUNT = 20000 * WAD;
uint256 constant DAI_EXCHANGE_AMOUNT = DAI_ACCOUNT_AMOUNT / 2;

uint256 constant USDC_ACCOUNT_AMOUNT = 20000 * (10**6);
uint256 constant USDC_EXCHANGE_AMOUNT = 1000 * (10**6);
uint256 constant USDT_ACCOUNT_AMOUNT = 42000 * WAD;
uint256 constant LINK_ACCOUNT_AMOUNT = 12000 * WAD;
uint256 constant LINK_EXCHANGE_AMOUNT = 300 * WAD;

uint256 constant CURVE_LP_ACCOUNT_AMOUNT = 100 * WAD;
uint256 constant CURVE_LP_OPERATION_AMOUNT = 55 * WAD;

uint256 constant DAI_POOL_AMOUNT = 500000 * WAD;
uint256 constant DAI_WETH_RATE = 1000;

uint256 constant WETH_ACCOUNT_AMOUNT = 200 * WAD;
uint256 constant WETH_EXCHANGE_AMOUNT = 3 * WAD;
uint256 constant STETH_ACCOUNT_AMOUNT = 150 * WAD;
uint256 constant wstETH_ACCOUNT_AMOUNT = 50 * WAD;

contract Roles is DSTest {
    CheatCodes evm = CheatCodes(HEVM_ADDRESS);

    constructor() {
        evm.label(USER, "USER");
        evm.label(FRIEND, "FRIEND");
        evm.label(LIQUIDATOR, "LIQUIDATOR");

        evm.label(DUMB_ADDRESS, "DUMB_ADDRESS");
        evm.label(ADAPTER, "ADAPTER");
    }
}
