// SPDX-License-Identifier: UNLICENSED
// Gearbox Protocol. Generalized leverage for DeFi protocols
// (c) Gearbox Holdings, 2022
pragma solidity ^0.8.10;

import { AddressProvider } from "../../core/AddressProvider.sol";
import { ContractsRegister } from "../../core/ContractsRegister.sol";
import { ACL } from "../../core/ACL.sol";
import { DieselToken } from "../../tokens/DieselToken.sol";

import { IPool4626, Pool4626Opts } from "../../interfaces/IPool4626.sol";
import { TestPoolService } from "../mocks/pool/TestPoolService.sol";
import { Tokens } from "../config/Tokens.sol";

import { LinearInterestRateModel } from "../../pool/LinearInterestRateModel.sol";

import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { CreditManagerMockForPoolTest } from "../mocks/pool/CreditManagerMockForPoolTest.sol";
import { WETHMock } from "../mocks/token/WETHMock.sol";
import { ERC20FeeMock } from "../mocks/token/ERC20FeeMock.sol";

import "../lib/constants.sol";
import { ITokenTestSuite } from "../interfaces/ITokenTestSuite.sol";
import { Pool4626 } from "../../pool/Pool4626.sol";

import { Pool4626_USDT } from "../../pool/Pool4626_USDT.sol";

uint256 constant liquidityProviderInitBalance = 100 ether;
uint256 constant addLiquidity = 10 ether;
uint256 constant removeLiquidity = 5 ether;
uint16 constant referral = 12333;

/// @title PoolServiceTestSuite
/// @notice Deploys contract for unit testing of PoolService.sol
contract PoolServiceTestSuite {
    CheatCodes evm = CheatCodes(HEVM_ADDRESS);

    ACL public acl;
    WETHMock public weth;

    AddressProvider public addressProvider;
    TestPoolService public poolService;
    Pool4626 public pool4626;
    CreditManagerMockForPoolTest public cmMock;
    IERC20 public underlying;
    DieselToken public dieselToken;
    LinearInterestRateModel public linearIRModel;

    address public treasury;

    constructor(
        ITokenTestSuite _tokenTestSuite,
        address _underlying,
        bool is4626
    ) {
        linearIRModel = new LinearInterestRateModel(
            8000,
            9000,
            200,
            400,
            4000,
            7500,
            false
        );

        evm.startPrank(CONFIGURATOR);

        acl = new ACL();
        weth = WETHMock(payable(_tokenTestSuite.wethToken()));
        addressProvider = new AddressProvider();
        addressProvider.setACL(address(acl));
        addressProvider.setTreasuryContract(DUMB_ADDRESS2);
        ContractsRegister cr = new ContractsRegister(address(addressProvider));
        addressProvider.setContractsRegister(address(cr));
        treasury = DUMB_ADDRESS2;
        addressProvider.setWethToken(address(weth));

        underlying = IERC20(_underlying);

        _tokenTestSuite.mint(_underlying, USER, liquidityProviderInitBalance);
        _tokenTestSuite.mint(
            _underlying,
            INITIAL_LP,
            liquidityProviderInitBalance
        );

        address newPool;

        bool isFeeToken = false;

        try ERC20FeeMock(_underlying).basisPointsRate() returns (uint256) {
            isFeeToken = true;
        } catch {}

        if (is4626) {
            Pool4626Opts memory opts = Pool4626Opts({
                addressProvider: address(addressProvider),
                underlyingToken: _underlying,
                interestRateModel: address(linearIRModel),
                expectedLiquidityLimit: type(uint256).max,
                supportsQuotas: false
            });
            pool4626 = isFeeToken
                ? new Pool4626_USDT(opts)
                : new Pool4626(opts);
            newPool = address(pool4626);
        } else {
            poolService = new TestPoolService(
                address(addressProvider),
                address(underlying),
                address(linearIRModel),
                type(uint256).max
            );
            newPool = address(poolService);
            dieselToken = DieselToken(poolService.dieselToken());
            evm.label(address(dieselToken), "DieselToken");
        }

        evm.stopPrank();

        evm.prank(USER);
        underlying.approve(newPool, type(uint256).max);

        evm.prank(INITIAL_LP);
        underlying.approve(newPool, type(uint256).max);

        evm.startPrank(CONFIGURATOR);

        cmMock = new CreditManagerMockForPoolTest(newPool);

        cmMock.changePoolService(newPool);

        cr.addPool(newPool);
        cr.addCreditManager(address(cmMock));

        evm.label(newPool, "Pool");

        // evm.label(address(underlying), "UnderlyingToken");

        evm.stopPrank();
    }
}
