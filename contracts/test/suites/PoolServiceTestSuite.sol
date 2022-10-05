// SPDX-License-Identifier: BUSL-1.1
// Gearbox Protocol. Generalized leverage for DeFi protocols
// (c) Gearbox Holdings, 2021
pragma solidity ^0.8.10;

import { AddressProvider } from "../../core/AddressProvider.sol";
import { ACL } from "../../core/ACL.sol";
import { DieselToken } from "../../tokens/DieselToken.sol";

//import {TokensTestSuite, Tokens} from "../suites/TokensTestSuite.sol";

import { TestPoolService } from "../mocks/pool/TestPoolService.sol";
import { LinearInterestRateModel } from "../../pool/LinearInterestRateModel.sol";

import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { CreditManagerMockForPoolTest } from "../mocks/pool/CreditManagerMockForPoolTest.sol";

import { TokensTestSuite, Tokens } from "../suites/TokensTestSuite.sol";
import "../lib/constants.sol";

uint256 constant liquidityProviderInitBalance = 100 ether;
uint256 constant addLiquidity = 10 ether;
uint256 constant removeLiquidity = 5 ether;
uint256 constant referral = 12333;

/// @title PoolServiceTestSuite
/// @notice Deploys contract for unit testing of PoolService.sol
contract PoolServiceTestSuite {
    CheatCodes evm = CheatCodes(HEVM_ADDRESS);

    ACL public acl;
    AddressProvider public addressProvider;
    TestPoolService public poolService;
    CreditManagerMockForPoolTest public cmMock;
    IERC20 public underlying;
    DieselToken public dieselToken;
    LinearInterestRateModel public linearIRModel;

    address public treasury;

    constructor(TokensTestSuite _tokenTestSuite) {
        linearIRModel = new LinearInterestRateModel(8000, 200, 400, 7500);

        evm.startPrank(CONFIGURATOR);

        acl = new ACL();
        addressProvider = new AddressProvider();
        addressProvider.setACL(address(acl));
        addressProvider.setTreasuryContract(DUMB_ADDRESS2);
        treasury = DUMB_ADDRESS2;

        underlying = IERC20(_tokenTestSuite.addressOf(Tokens.DAI));

        _tokenTestSuite.mint(Tokens.DAI, USER, liquidityProviderInitBalance);

        poolService = new TestPoolService(
            address(addressProvider),
            address(underlying),
            address(linearIRModel),
            type(uint256).max
        );

        dieselToken = DieselToken(poolService.dieselToken());

        evm.stopPrank();

        evm.prank(USER);
        underlying.approve(address(poolService), type(uint256).max);

        evm.startPrank(CONFIGURATOR);

        cmMock = new CreditManagerMockForPoolTest(address(poolService));

        evm.label(address(poolService), "PoolService");
        evm.label(address(dieselToken), "DieselToken");
        evm.label(address(underlying), "UnderlyingTokenDAI");

        evm.stopPrank();
    }
}
