// SPDX-License-Identifier: UNLICENSED
// Gearbox Protocol. Generalized leverage for DeFi protocols
// (c) Gearbox Holdings, 2022
pragma solidity ^0.8.10;

import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import { TestPoolService } from "../mocks/pool/TestPoolService.sol";
import { IPoolServiceEvents } from "../../interfaces/IPoolService.sol";
import { LinearInterestRateModel } from "../../pool/LinearInterestRateModel.sol";
import { DieselToken } from "../../tokens/DieselToken.sol";

import { ACL } from "../../core/ACL.sol";
import { CreditManagerMockForPoolTest } from "../mocks/pool/CreditManagerMockForPoolTest.sol";
import { liquidityProviderInitBalance, addLiquidity, removeLiquidity, referral, PoolServiceTestSuite } from "../suites/PoolServiceTestSuite.sol";

import "../../libraries/Errors.sol";

import { TokensTestSuite } from "../suites/TokensTestSuite.sol";
import { Tokens } from "../config/Tokens.sol";
import { BalanceHelper } from "../helpers/BalanceHelper.sol";

// TEST
import "../lib/constants.sol";

// EXCEPTIONS
import { CallerNotConfiguratorException } from "../../interfaces/IErrors.sol";

/// @title PoolService
/// @notice Business logic for borrowing liquidity pools
contract PoolServiceTest is DSTest, BalanceHelper, IPoolServiceEvents {
    CheatCodes evm = CheatCodes(HEVM_ADDRESS);

    PoolServiceTestSuite psts;

    ACL acl;
    TestPoolService poolService;
    DieselToken dieselToken;
    address underlying;
    CreditManagerMockForPoolTest cmMock;

    function setUp() public {
        tokenTestSuite = new TokensTestSuite();
        psts = new PoolServiceTestSuite(
            tokenTestSuite,
            tokenTestSuite.addressOf(Tokens.DAI),
            false
        );

        poolService = psts.poolService();
        dieselToken = psts.dieselToken();
        underlying = address(psts.underlying());
        cmMock = psts.cmMock();
        acl = psts.acl();
    }

    // [PS-1]: getDieselRate_RAY=RAY, withdrawFee=0 and expectedLiquidityLimit as expected at start
    function test_PS_01_start_parameters_correct() public {
        assertEq(poolService.getDieselRate_RAY(), RAY);
        assertEq(poolService.withdrawFee(), 0);
        assertEq(poolService.expectedLiquidityLimit(), type(uint256).max);
    }

    // [PS-2]: addLiquidity correctly adds liquidity
    function test_PS_02_add_liquidity_adds_correctly() public {
        evm.expectEmit(true, true, false, true);
        emit AddLiquidity(USER, FRIEND, addLiquidity, referral);

        evm.prank(USER);
        poolService.addLiquidity(addLiquidity, FRIEND, referral);

        expectBalance(address(dieselToken), FRIEND, addLiquidity);
        expectBalance(
            underlying,
            USER,
            liquidityProviderInitBalance - addLiquidity
        );
        assertEq(poolService.expectedLiquidity(), addLiquidity);
        assertEq(poolService.availableLiquidity(), addLiquidity);
    }

    // [PS-3]: removeLiquidity correctly removes liquidity
    function test_PS_03_remove_liquidity_removes_correctly() public {
        evm.prank(USER);
        poolService.addLiquidity(addLiquidity, FRIEND, referral);

        evm.expectEmit(true, true, false, true);
        emit RemoveLiquidity(FRIEND, USER, removeLiquidity);

        evm.prank(FRIEND);
        poolService.removeLiquidity(removeLiquidity, USER);

        expectBalance(
            address(dieselToken),
            FRIEND,
            addLiquidity - removeLiquidity
        );
        expectBalance(
            underlying,
            USER,
            liquidityProviderInitBalance - addLiquidity + removeLiquidity
        );
        assertEq(
            poolService.expectedLiquidity(),
            addLiquidity - removeLiquidity
        );
        assertEq(
            poolService.availableLiquidity(),
            addLiquidity - removeLiquidity
        );
    }

    // [PS-4]: addLiquidity, removeLiquidity, lendCreditAccount, repayCreditAccount reverts if contract is paused
    function test_PS_04_cannot_be_used_while_paused() public {
        evm.startPrank(CONFIGURATOR);
        acl.addPausableAdmin(CONFIGURATOR);
        poolService.pause();
        evm.stopPrank();

        evm.startPrank(USER);

        evm.expectRevert(bytes(PAUSABLE_ERROR));
        poolService.addLiquidity(addLiquidity, FRIEND, referral);

        evm.expectRevert(bytes(PAUSABLE_ERROR));
        poolService.removeLiquidity(removeLiquidity, FRIEND);

        evm.expectRevert(bytes(PAUSABLE_ERROR));
        poolService.lendCreditAccount(1, FRIEND);

        evm.expectRevert(bytes(PAUSABLE_ERROR));
        poolService.repayCreditAccount(1, 0, 0);

        evm.stopPrank();
    }

    // [PS-5]: constructor set correct cumulative index to 1 at start
    function test_PS_05_starting_cumulative_index_correct() public {
        assertEq(poolService.getCumulativeIndex_RAY(), RAY);
    }

    // [PS-6]: getDieselRate_RAY correctly computes rate
    function test_PS_06_diesel_rate_computes_correctly() public {
        evm.prank(USER);
        poolService.addLiquidity(addLiquidity, FRIEND, referral);

        poolService.setExpectedLiquidity(addLiquidity * 2);

        assertEq(poolService.expectedLiquidity(), addLiquidity * 2);
        assertEq(poolService.getDieselRate_RAY(), RAY * 2);
    }

    // [PS-7]: addLiquidity correctly adds liquidity with DieselRate != 1
    function test_PS_07_correctly_adds_liquidity_at_new_diesel_rate() public {
        evm.prank(USER);
        poolService.addLiquidity(addLiquidity, USER, referral);

        poolService.setExpectedLiquidity(addLiquidity * 2);

        evm.prank(USER);
        poolService.addLiquidity(addLiquidity, FRIEND, referral);

        assertEq(dieselToken.balanceOf(FRIEND), addLiquidity / 2);
    }

    // [PS-8]: removeLiquidity correctly removes liquidity if diesel rate != 1
    function test_PS_08_correctly_removes_liquidity_at_new_diesel_rate()
        public
    {
        evm.prank(USER);
        poolService.addLiquidity(addLiquidity, FRIEND, referral);

        poolService.setExpectedLiquidity(addLiquidity * 2);

        evm.prank(FRIEND);
        poolService.removeLiquidity(removeLiquidity, USER);

        expectBalance(
            address(dieselToken),
            FRIEND,
            addLiquidity - removeLiquidity
        );
        expectBalance(
            underlying,
            USER,
            liquidityProviderInitBalance - addLiquidity + 2 * removeLiquidity
        );
        assertEq(
            poolService.expectedLiquidity(),
            (addLiquidity - removeLiquidity) * 2
        );
        assertEq(
            poolService.availableLiquidity(),
            addLiquidity - removeLiquidity * 2
        );
    }

    // [PS-9]: connectCreditManager, forbidCreditManagerToBorrow, newInterestRateModel, setExpecetedLiquidityLimit reverts if called with non-configurator
    function test_PS_09_admin_functions_revert_on_non_admin() public {
        evm.startPrank(USER);

        evm.expectRevert(CallerNotConfiguratorException.selector);
        poolService.connectCreditManager(DUMB_ADDRESS);

        evm.expectRevert(CallerNotConfiguratorException.selector);
        poolService.forbidCreditManagerToBorrow(DUMB_ADDRESS);

        evm.expectRevert(CallerNotConfiguratorException.selector);
        poolService.updateInterestRateModel(DUMB_ADDRESS);

        evm.expectRevert(CallerNotConfiguratorException.selector);
        poolService.setExpectedLiquidityLimit(0);

        evm.stopPrank();
    }

    // [PS-10]: connectCreditManager reverts if another pool is setup in CreditManager
    function test_PS_10_connectCreditManager_fails_on_incompatible_CM() public {
        cmMock.changePoolService(DUMB_ADDRESS);

        evm.expectRevert(
            bytes(Errors.POOL_INCOMPATIBLE_CREDIT_ACCOUNT_MANAGER)
        );

        evm.prank(CONFIGURATOR);
        poolService.connectCreditManager(address(cmMock));
    }

    // [PS-11]: connectCreditManager adds CreditManager correctly and emits event
    function test_PS_11_CM_is_connected_correctly() public {
        assertEq(poolService.creditManagersCount(), 0);

        evm.expectEmit(true, false, false, false);
        emit NewCreditManagerConnected(address(cmMock));

        evm.prank(CONFIGURATOR);
        poolService.connectCreditManager(address(cmMock));

        assertEq(poolService.creditManagersCount(), 1);
        assertTrue(poolService.creditManagersCanBorrow(address(cmMock)));
        assertTrue(poolService.creditManagersCanRepay(address(cmMock)));
    }

    // [PS-12]: lendCreditAccount, repayCreditAccount reverts if called non-CreditManager
    function test_PS_12_CA_can_be_lent_repaid_only_by_CM() public {
        evm.startPrank(USER);

        evm.expectRevert(bytes(Errors.POOL_CONNECTED_CREDIT_MANAGERS_ONLY));
        poolService.lendCreditAccount(0, DUMB_ADDRESS);

        evm.expectRevert(bytes(Errors.POOL_CONNECTED_CREDIT_MANAGERS_ONLY));
        poolService.repayCreditAccount(0, 0, 0);

        evm.stopPrank();
    }

    // [PS-13]: lendCreditAccount reverts of creditManagers was disallowed by forbidCreditManagerToBorrow
    function test_PS_13_lendCreditAccount_reverts_on_forbidden_CM() public {
        evm.prank(CONFIGURATOR);
        poolService.connectCreditManager(address(cmMock));

        evm.prank(USER);
        poolService.addLiquidity(addLiquidity, USER, referral);

        cmMock.lendCreditAccount(addLiquidity / 2, DUMB_ADDRESS);

        evm.expectEmit(false, false, false, true);
        emit BorrowForbidden(address(cmMock));

        evm.prank(CONFIGURATOR);
        poolService.forbidCreditManagerToBorrow(address(cmMock));

        evm.expectRevert(bytes(Errors.POOL_CONNECTED_CREDIT_MANAGERS_ONLY));
        cmMock.lendCreditAccount(addLiquidity / 2, DUMB_ADDRESS);
    }

    // [PS-14]: lendCreditAccount transfers tokens correctly
    function test_PS_14_lendCreditAccount_correctly_transfers_tokens() public {
        evm.prank(CONFIGURATOR);
        poolService.connectCreditManager(address(cmMock));

        evm.prank(USER);
        poolService.addLiquidity(addLiquidity, USER, referral);

        address ca = cmMock.getCreditAccountOrRevert(DUMB_ADDRESS);

        expectBalance(underlying, ca, 0);

        cmMock.lendCreditAccount(addLiquidity / 2, ca);

        expectBalance(underlying, ca, addLiquidity / 2);
    }

    // [PS-15]: lendCreditAccount emits Borrow event
    function test_PS_15_lendCreditAccount_emits_event() public {
        evm.prank(CONFIGURATOR);
        poolService.connectCreditManager(address(cmMock));

        evm.prank(USER);
        poolService.addLiquidity(addLiquidity, USER, referral);

        address ca = cmMock.getCreditAccountOrRevert(DUMB_ADDRESS);

        evm.expectEmit(false, false, false, true);
        emit Borrow(address(cmMock), ca, addLiquidity / 2);

        cmMock.lendCreditAccount(addLiquidity / 2, ca);
    }

    // [PS-16]: lendCreditAccount correctly updates parameters
    function test_PS_16_lendCreditAccount_correctly_updates_parameters()
        public
    {
        evm.prank(CONFIGURATOR);
        poolService.connectCreditManager(address(cmMock));

        evm.prank(USER);
        poolService.addLiquidity(addLiquidity, USER, referral);

        address ca = cmMock.getCreditAccountOrRevert(DUMB_ADDRESS);

        uint256 totalBorrowed = poolService.totalBorrowed();

        cmMock.lendCreditAccount(addLiquidity / 2, ca);

        assertEq(
            poolService.totalBorrowed(),
            totalBorrowed + addLiquidity / 2,
            "Incorrect new borrow amount"
        );
    }

    // [PS-17]: lendCreditAccount correctly updates borrow rate
    function test_PS_17_lendCreditAccount_correctly_updates_borrow_rate()
        public
    {
        evm.prank(CONFIGURATOR);
        poolService.connectCreditManager(address(cmMock));

        evm.prank(USER);
        poolService.addLiquidity(addLiquidity, USER, referral);

        address ca = cmMock.getCreditAccountOrRevert(DUMB_ADDRESS);

        cmMock.lendCreditAccount(addLiquidity / 2, ca);

        uint256 expectedLiquidity = addLiquidity;
        uint256 expectedAvailable = expectedLiquidity - addLiquidity / 2;

        uint256 expectedBorrowRate = psts.linearIRModel().calcBorrowRate(
            expectedLiquidity,
            expectedAvailable
        );

        assertEq(
            expectedBorrowRate,
            poolService.borrowAPY_RAY(),
            "Borrow rate is incorrect"
        );
    }

    // [PS-18]: repayCreditAccount emits Repay event
    function test_PS_18_repayCreditAccount_emits_event() public {
        evm.prank(CONFIGURATOR);
        poolService.connectCreditManager(address(cmMock));

        evm.prank(USER);
        poolService.addLiquidity(addLiquidity, USER, referral);

        address ca = cmMock.getCreditAccountOrRevert(DUMB_ADDRESS);

        cmMock.lendCreditAccount(addLiquidity / 2, ca);

        evm.expectEmit(true, false, false, true);
        emit Repay(address(cmMock), addLiquidity / 2, 1, 0);

        cmMock.repayCreditAccount(addLiquidity / 2, 1, 0);
    }

    // [PS-19]: repayCreditAccount correctly updates params on loss accrued: treasury < loss
    function test_PS_19_repayCreditAccount_correctly_updates_on_uncovered_loss()
        public
    {
        address treasury = psts.treasury();

        evm.prank(CONFIGURATOR);
        poolService.connectCreditManager(address(cmMock));

        evm.prank(USER);
        poolService.addLiquidity(addLiquidity, USER, referral);

        evm.prank(address(poolService));
        dieselToken.mint(treasury, 1e4);

        address ca = cmMock.getCreditAccountOrRevert(DUMB_ADDRESS);

        cmMock.lendCreditAccount(addLiquidity / 2, ca);

        uint256 borrowRate = poolService.borrowAPY_RAY();
        uint256 timeWarp = 365 days;

        uint256 expectedInterest = ((addLiquidity / 2) * borrowRate) / RAY;
        uint256 expectedLiquidity = addLiquidity + expectedInterest - 1e6;

        uint256 expectedBorrowRate = psts.linearIRModel().calcBorrowRate(
            expectedLiquidity,
            addLiquidity + expectedInterest - 1e6
        );

        evm.warp(block.timestamp + timeWarp);

        uint256 treasuryUnderlying = poolService.fromDiesel(
            dieselToken.balanceOf(treasury)
        );

        tokenTestSuite.mint(
            Tokens.DAI,
            address(poolService),
            addLiquidity / 2 + expectedInterest - 1e6
        );

        evm.expectEmit(true, false, false, true);
        emit UncoveredLoss(address(cmMock), 1e6 - treasuryUnderlying);

        cmMock.repayCreditAccount(addLiquidity / 2, 0, 1e6);

        assertEq(
            poolService.expectedLiquidity(),
            expectedLiquidity,
            "Expected liquidity was not updated correctly"
        );

        assertEq(
            dieselToken.balanceOf(treasury),
            0,
            "dToken remains in the treasury"
        );

        assertEq(
            poolService.borrowAPY_RAY(),
            expectedBorrowRate,
            "Borrow rate was not updated correctly"
        );
    }

    // [PS-20]: repayCreditAccount correctly updates params on loss accrued: treasury >= loss; and emits event
    function test_PS_20_repayCreditAccount_correctly_updates_on_covered_loss()
        public
    {
        address treasury = psts.treasury();

        evm.prank(CONFIGURATOR);
        poolService.connectCreditManager(address(cmMock));

        evm.prank(USER);
        poolService.addLiquidity(addLiquidity, USER, referral);

        uint256 dieselSupply = dieselToken.totalSupply();

        evm.prank(address(poolService));
        dieselToken.mint(treasury, dieselSupply);

        address ca = cmMock.getCreditAccountOrRevert(DUMB_ADDRESS);

        cmMock.lendCreditAccount(addLiquidity / 2, ca);

        uint256 borrowRate = poolService.borrowAPY_RAY();
        uint256 timeWarp = 365 days;

        evm.warp(block.timestamp + timeWarp);

        uint256 treasuryUnderlying = poolService.fromDiesel(
            dieselToken.balanceOf(treasury)
        );

        uint256 expectedInterest = ((addLiquidity / 2) * borrowRate) / RAY;
        uint256 expectedLiquidity = addLiquidity +
            expectedInterest -
            (treasuryUnderlying / 2);

        uint256 expectedBorrowRate = psts.linearIRModel().calcBorrowRate(
            expectedLiquidity,
            addLiquidity
        );

        tokenTestSuite.mint(Tokens.DAI, address(poolService), addLiquidity / 2);

        cmMock.repayCreditAccount(addLiquidity / 2, 0, treasuryUnderlying / 2);

        assertEq(
            poolService.expectedLiquidity(),
            expectedLiquidity,
            "Expected liquidity was not updated correctly"
        );

        assertEq(
            dieselToken.balanceOf(treasury),
            poolService.toDiesel(treasuryUnderlying - treasuryUnderlying / 2),
            "dToken balance incorrect"
        );

        assertEq(
            poolService.borrowAPY_RAY(),
            expectedBorrowRate,
            "Borrow rate was not updated correctly"
        );
    }

    // [PS-21]: repayCreditAccount correctly updates params on profit
    function test_PS_21_repayCreditAccount_correctly_updates_on_profit()
        public
    {
        address treasury = psts.treasury();

        evm.prank(CONFIGURATOR);
        poolService.connectCreditManager(address(cmMock));

        evm.prank(USER);
        poolService.addLiquidity(addLiquidity, USER, referral);

        address ca = cmMock.getCreditAccountOrRevert(DUMB_ADDRESS);

        cmMock.lendCreditAccount(addLiquidity / 2, ca);

        uint256 borrowRate = poolService.borrowAPY_RAY();
        uint256 timeWarp = 365 days;

        evm.warp(block.timestamp + timeWarp);

        uint256 expectedInterest = ((addLiquidity / 2) * borrowRate) / RAY;
        uint256 expectedLiquidity = addLiquidity + expectedInterest + 100;

        uint256 expectedBorrowRate = psts.linearIRModel().calcBorrowRate(
            expectedLiquidity,
            addLiquidity + expectedInterest + 100
        );

        tokenTestSuite.mint(
            Tokens.DAI,
            address(poolService),
            addLiquidity / 2 + expectedInterest + 100
        );

        cmMock.repayCreditAccount(addLiquidity / 2, 100, 0);

        assertEq(
            poolService.expectedLiquidity(),
            expectedLiquidity,
            "Expected liquidity was not updated correctly"
        );

        assertEq(
            dieselToken.balanceOf(treasury),
            poolService.toDiesel(100),
            "dToken balance incorrect"
        );

        assertEq(
            poolService.borrowAPY_RAY(),
            expectedBorrowRate,
            "Borrow rate was not updated correctly"
        );
    }

    // [PS-22]: repayCreditAccount does not change the diesel rate outside margin of error
    function test_PS_22_repayCreditAccount_does_not_change_diesel_rate()
        public
    {
        evm.prank(CONFIGURATOR);
        poolService.connectCreditManager(address(cmMock));

        evm.prank(USER);
        poolService.addLiquidity(addLiquidity, USER, referral);

        address ca = cmMock.getCreditAccountOrRevert(DUMB_ADDRESS);

        cmMock.lendCreditAccount(addLiquidity / 2, ca);

        uint256 borrowRate = poolService.borrowAPY_RAY();
        uint256 timeWarp = 365 days;

        evm.warp(block.timestamp + timeWarp);

        uint256 expectedInterest = ((addLiquidity / 2) * borrowRate) / RAY;
        uint256 expectedLiquidity = addLiquidity + expectedInterest;

        tokenTestSuite.mint(
            Tokens.DAI,
            address(poolService),
            addLiquidity / 2 + expectedInterest
        );

        cmMock.repayCreditAccount(addLiquidity / 2, 100, 0);

        assertEq(
            (RAY * expectedLiquidity) / addLiquidity / 1e8,
            poolService.getDieselRate_RAY() / 1e8,
            "Expected liquidity was not updated correctly"
        );
    }

    // [PS-23]: fromDiesel / toDiesel works correctly
    function test_PS_23_diesel_conversion_is_correct() public {
        evm.prank(CONFIGURATOR);
        poolService.connectCreditManager(address(cmMock));

        evm.prank(USER);
        poolService.addLiquidity(addLiquidity, USER, referral);

        address ca = cmMock.getCreditAccountOrRevert(DUMB_ADDRESS);

        cmMock.lendCreditAccount(addLiquidity / 2, ca);

        uint256 timeWarp = 365 days;

        evm.warp(block.timestamp + timeWarp);

        uint256 dieselRate = poolService.getDieselRate_RAY();

        assertEq(
            poolService.toDiesel(addLiquidity),
            (addLiquidity * RAY) / dieselRate,
            "ToDiesel does not compute correctly"
        );

        assertEq(
            poolService.fromDiesel(addLiquidity),
            (addLiquidity * dieselRate) / RAY,
            "ToDiesel does not compute correctly"
        );
    }

    // [PS-24]: updateInterestRateModel changes interest rate model & emit event
    function test_PS_24_updateInterestRateModel_works_correctly_and_emits_event()
        public
    {
        LinearInterestRateModel newIR = new LinearInterestRateModel(
            8000,
            9000,
            200,
            500,
            4000,
            7500,
            false
        );

        evm.expectEmit(true, false, false, false);
        emit NewInterestRateModel(address(newIR));

        evm.prank(CONFIGURATOR);
        poolService.updateInterestRateModel(address(newIR));

        assertEq(
            address(poolService.interestRateModel()),
            address(newIR),
            "Interest rate model was not set correctly"
        );
    }

    // [PS-25]: updateInterestRateModel correctly computes new borrow rate
    function test_PS_25_updateInterestRateModel_correctly_computes_new_borrow_rate()
        public
    {
        LinearInterestRateModel newIR = new LinearInterestRateModel(
            8000,
            9000,
            200,
            500,
            4000,
            7500,
            false
        );

        evm.prank(CONFIGURATOR);
        poolService.connectCreditManager(address(cmMock));

        evm.prank(USER);
        poolService.addLiquidity(addLiquidity, USER, referral);

        address ca = cmMock.getCreditAccountOrRevert(DUMB_ADDRESS);

        cmMock.lendCreditAccount(addLiquidity / 2, ca);

        uint256 expectedLiquidity = poolService.expectedLiquidity();
        uint256 availableLiquidity = poolService.availableLiquidity();

        evm.prank(CONFIGURATOR);
        poolService.updateInterestRateModel(address(newIR));

        assertEq(
            newIR.calcBorrowRate(expectedLiquidity, availableLiquidity),
            poolService.borrowAPY_RAY(),
            "Borrow rate does not match"
        );
    }

    // [PS-26]: updateBorrowRate correctly updates parameters
    function test_PS_26_updateBorrowRate_correct() public {
        evm.prank(CONFIGURATOR);
        poolService.connectCreditManager(address(cmMock));

        evm.prank(USER);
        poolService.addLiquidity(addLiquidity, USER, referral);

        address ca = cmMock.getCreditAccountOrRevert(DUMB_ADDRESS);

        cmMock.lendCreditAccount(addLiquidity / 2, ca);

        uint256 borrowRate = poolService.borrowAPY_RAY();
        uint256 timeWarp = 365 days;

        evm.warp(block.timestamp + timeWarp);

        uint256 expectedInterest = ((addLiquidity / 2) * borrowRate) / RAY;
        uint256 expectedLiquidity = addLiquidity + expectedInterest;

        uint256 expectedBorrowRate = psts.linearIRModel().calcBorrowRate(
            expectedLiquidity,
            addLiquidity / 2
        );

        poolService.updateBorrowRate();

        assertEq(
            poolService.expectedLiquidity(),
            expectedLiquidity,
            "Expected liquidity was not updated correctly"
        );

        assertEq(
            poolService._timestampLU(),
            block.timestamp,
            "Timestamp was not updated correctly"
        );

        assertEq(
            poolService.borrowAPY_RAY(),
            expectedBorrowRate,
            "Borrow rate was not updated correctly"
        );

        assertEq(
            poolService.calcLinearCumulative_RAY(),
            poolService.getCumulativeIndex_RAY(),
            "Index value was not updated correctly"
        );
    }

    // [PS-27]: calcLinearCumulative_RAY computes correctly
    function test_PS_27_calcLinearCumulative_RAY_correct() public {
        evm.prank(CONFIGURATOR);
        poolService.connectCreditManager(address(cmMock));

        evm.prank(USER);
        poolService.addLiquidity(addLiquidity, USER, referral);

        address ca = cmMock.getCreditAccountOrRevert(DUMB_ADDRESS);

        cmMock.lendCreditAccount(addLiquidity / 2, ca);

        uint256 timeWarp = 180 days;

        evm.warp(block.timestamp + timeWarp);

        uint256 borrowRate = poolService.borrowAPY_RAY();

        uint256 expectedLinearRate = RAY + (borrowRate * timeWarp) / 365 days;

        assertEq(
            poolService.calcLinearCumulative_RAY(),
            expectedLinearRate,
            "Index value was not updated correctly"
        );
    }

    // [PS-28]: expectedLiquidity() computes correctly
    function test_PS_28_expectedLiquidity_correct() public {
        evm.prank(CONFIGURATOR);
        poolService.connectCreditManager(address(cmMock));

        evm.prank(USER);
        poolService.addLiquidity(addLiquidity, USER, referral);

        address ca = cmMock.getCreditAccountOrRevert(DUMB_ADDRESS);

        cmMock.lendCreditAccount(addLiquidity / 2, ca);

        uint256 borrowRate = poolService.borrowAPY_RAY();
        uint256 timeWarp = 365 days;

        evm.warp(block.timestamp + timeWarp);

        uint256 expectedInterest = ((addLiquidity / 2) * borrowRate) / RAY;
        uint256 expectedLiquidity = poolService._expectedLiquidityLU() +
            expectedInterest;

        assertEq(
            poolService.expectedLiquidity(),
            expectedLiquidity,
            "Index value was not updated correctly"
        );
    }

    // [PS-29]: setExpectedLiquidityLimit() sets limit & emits event
    function test_PS_29_setExpectedLiquidityLimit_correct_and_emits_event()
        public
    {
        evm.expectEmit(false, false, false, true);
        emit NewExpectedLiquidityLimit(10000);

        evm.prank(CONFIGURATOR);
        poolService.setExpectedLiquidityLimit(10000);

        assertEq(
            poolService.expectedLiquidityLimit(),
            10000,
            "expectedLiquidityLimit not set correctly"
        );
    }

    // [PS-30]: addLiquidity reverts above expectedLiquidityLimit
    function test_PS_30_addLiquidity_reverts_above_liquidity_limit() public {
        evm.prank(CONFIGURATOR);
        poolService.connectCreditManager(address(cmMock));

        evm.prank(CONFIGURATOR);
        poolService.setExpectedLiquidityLimit(10000);

        evm.expectRevert(bytes(Errors.POOL_MORE_THAN_EXPECTED_LIQUIDITY_LIMIT));

        evm.prank(USER);
        poolService.addLiquidity(addLiquidity, USER, referral);
    }

    // [PS-31]: setWithdrawFee reverts on fee > 1%
    function test_PS_31_setWithdrawFee_reverts_on_fee_too_lage() public {
        evm.expectRevert(bytes(Errors.POOL_INCORRECT_WITHDRAW_FEE));

        evm.prank(CONFIGURATOR);
        poolService.setWithdrawFee(101);
    }

    // [PS-32]: setWithdrawFee changes fee and emits event
    function test_PS_32_setWithdrawFee_correct_and_emits_event() public {
        evm.expectEmit(false, false, false, true);
        emit NewWithdrawFee(50);

        evm.prank(CONFIGURATOR);
        poolService.setWithdrawFee(50);

        assertEq(
            poolService.withdrawFee(),
            50,
            "withdrawFee not set correctly"
        );
    }

    // [PS-33]: removeLiqudity correctly takes withdrawal fee
    function test_PS_33_removeLiquidity_takes_withdrawal_fee() public {
        address treasury = psts.treasury();

        evm.startPrank(CONFIGURATOR);
        poolService.connectCreditManager(address(cmMock));
        poolService.setWithdrawFee(50);
        evm.stopPrank();

        evm.startPrank(USER);
        poolService.addLiquidity(addLiquidity, USER, referral);

        uint256 balanceBefore = IERC20(underlying).balanceOf(USER);

        poolService.removeLiquidity(addLiquidity, USER);
        evm.stopPrank();

        expectBalance(
            underlying,
            treasury,
            (addLiquidity * 50) / 10000,
            "Incorrect balance in treasury"
        );

        expectBalance(
            underlying,
            USER,
            balanceBefore + (addLiquidity * 9950) / 10000,
            "Incorrect balance for user"
        );
    }

    // [PS-34]: connectCreditManager reverts on adding a manager twice
    function test_PS_34_connectCreditManager_reverts_on_duplicate() public {
        evm.prank(CONFIGURATOR);
        poolService.connectCreditManager(address(cmMock));

        evm.expectRevert(bytes(Errors.POOL_CANT_ADD_CREDIT_MANAGER_TWICE));

        evm.prank(CONFIGURATOR);
        poolService.connectCreditManager(address(cmMock));
    }

    // [PS-35]: updateInterestRateModel reverts on zero address
    function test_PS_35_updateInterestRateModel_reverts_on_zero_address()
        public
    {
        evm.expectRevert(bytes(Errors.ZERO_ADDRESS_IS_NOT_ALLOWED));
        evm.prank(CONFIGURATOR);
        poolService.updateInterestRateModel(address(0));
    }
}
