// SPDX-License-Identifier: UNLICENSED
// Gearbox Protocol. Generalized leverage for DeFi protocols
// (c) Gearbox Holdings, 2022
pragma solidity ^0.8.10;

import { IDataCompressor } from "../../interfaces/IDataCompressor.sol";

import { ICreditFacade, ICreditFacadeExtended } from "../../interfaces/ICreditFacade.sol";
import { ICreditManagerV2, ICreditManagerV2Events, ClosureAction } from "../../interfaces/ICreditManagerV2.sol";
import { ICreditFacadeEvents, ICreditFacadeExceptions } from "../../interfaces/ICreditFacade.sol";
import { IDegenNFT, IDegenNFTExceptions } from "../../interfaces/IDegenNFT.sol";
import { IBlacklistHelper } from "../../interfaces/IBlacklistHelper.sol";

// DATA
import { MultiCall, MultiCallOps } from "../../libraries/MultiCall.sol";
import { Balance } from "../../libraries/Balances.sol";

import { CreditFacadeMulticaller, CreditFacadeCalls } from "../../multicall/CreditFacadeCalls.sol";

// CONSTANTS

import { LEVERAGE_DECIMALS } from "../../libraries/Constants.sol";
import { PERCENTAGE_FACTOR } from "../../libraries/PercentageMath.sol";

// TESTS

import "../lib/constants.sol";
import { BalanceHelper } from "../helpers/BalanceHelper.sol";
import { CreditFacadeTestHelper } from "../helpers/CreditFacadeTestHelper.sol";

// EXCEPTIONS
import { ZeroAddressException } from "../../interfaces/IErrors.sol";
import { ICreditManagerV2Exceptions } from "../../interfaces/ICreditManagerV2.sol";

// MOCKS
import { AdapterMock } from "../mocks/adapters/AdapterMock.sol";
import { TargetContractMock } from "../mocks/adapters/TargetContractMock.sol";
import { ERC20BlacklistableMock } from "../mocks/token/ERC20Blacklistable.sol";

// SUITES
import { TokensTestSuite } from "../suites/TokensTestSuite.sol";
import { Tokens } from "../config/Tokens.sol";
import { CreditFacadeTestSuite } from "../suites/CreditFacadeTestSuite.sol";
import { CreditConfig } from "../config/CreditConfig.sol";
import { Test } from "forge-std/Test.sol";

uint256 constant WETH_TEST_AMOUNT = 5 * WAD;
uint16 constant REFERRAL_CODE = 23;

/// @title CreditFacadeTest
/// @notice Designed for unit test purposes only
contract CreditFacadeGasTest is Test {
    address ap = 0xcF64698AFF7E5f27A11dff868AF228653ba53be0;
    IContractRegister cr;

    ICreditFacade cf;
    ICreditManagerV2 cm;
    ICreditConfigurator cc;

    constructor() Test() {
        cr = IContractRegister(IAddressProvider(ap).getContractsRegister());
    }

    modifier allCMs() {
        address[] memory cms = cr.getCreditManagers();
    }

    function setUp() public {}

    function test_gas_all_tokens() public allCMs {}
}
