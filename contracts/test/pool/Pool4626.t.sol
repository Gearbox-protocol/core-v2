// SPDX-License-Identifier: UNLICENSED
// Gearbox Protocol. Generalized leverage for DeFi protocols
// (c) Gearbox Holdings, 2022
pragma solidity ^0.8.10;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IERC20Metadata} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import {IERC4626} from "@openzeppelin/contracts/interfaces/IERC4626.sol";

import {Pool4626} from "../../pool/Pool4626.sol";
import {IERC4626Events} from "../../interfaces/IERC4626.sol";
import {IPool4626Events, Pool4626Opts, IPool4626Exceptions} from "../../interfaces/IPool4626.sol";
import {LinearInterestRateModel} from "../../pool/LinearInterestRateModel.sol";

import {ACL} from "../../core/ACL.sol";
import {CreditManagerMockForPoolTest} from "../mocks/pool/CreditManagerMockForPoolTest.sol";
import {
    liquidityProviderInitBalance,
    addLiquidity,
    removeLiquidity,
    referral,
    PoolServiceTestSuite
} from "../suites/PoolServiceTestSuite.sol";

import "../../libraries/Errors.sol";

import {TokensTestSuite} from "../suites/TokensTestSuite.sol";
import {Tokens} from "../config/Tokens.sol";
import {BalanceHelper} from "../helpers/BalanceHelper.sol";
import {ERC20FeeMock} from "../mocks/token/ERC20FeeMock.sol";

// TEST
import "../lib/constants.sol";
import {PERCENTAGE_FACTOR} from "../../libraries/PercentageMath.sol";

import "forge-std/console.sol";

// EXCEPTIONS
import {
    CallerNotConfiguratorException,
    CallerNotControllerException,
    ZeroAddressException
} from "../../interfaces/IErrors.sol";

uint256 constant fee = 6000;

/// @title pool
/// @notice Business logic for borrowing liquidity pools
contract Pool4626Test is DSTest, BalanceHelper, IPool4626Events, IERC4626Events {
    CheatCodes evm = CheatCodes(HEVM_ADDRESS);

    PoolServiceTestSuite psts;

    /*
     * @dev Emitted when `value` tokens are moved from one account (`from`) to
     * another (`to`).
     *
     * Note that `value` may be zero.
     */
    event Transfer(address indexed from, address indexed to, uint256 value);

    ACL acl;
    Pool4626 pool;
    address underlying;
    CreditManagerMockForPoolTest cmMock;

    function setUp() public {
        _setUp(Tokens.DAI);
    }

    function _setUp(Tokens t) public {
        tokenTestSuite = new TokensTestSuite();
        psts = new PoolServiceTestSuite(
            tokenTestSuite,
            tokenTestSuite.addressOf(t),
            true
        );

        pool = psts.pool4626();
        underlying = address(psts.underlying());
        cmMock = psts.cmMock();
        acl = psts.acl();
    }

    //
    // HELPERS
    //
    function _connectAndSetLimit() internal {
        evm.prank(CONFIGURATOR);
        pool.setCreditManagerLimit(address(cmMock), type(uint128).max);
    }

    function _mulFee(uint256 amount, uint256 fee) internal returns (uint256) {
        return (amount * (PERCENTAGE_FACTOR - fee)) / PERCENTAGE_FACTOR;
    }

    function _divFee(uint256 amount, uint256 fee) internal returns (uint256) {
        return (amount * PERCENTAGE_FACTOR) / (PERCENTAGE_FACTOR - fee);
    }

    function _updateBorrowrate() internal {
        evm.prank(CONFIGURATOR);
        pool.updateInterestRateModel(address(pool.interestRateModel()));
    }

    function _initPoolLiquidity() internal {
        evm.prank(INITIAL_LP);
        pool.mint(2 * addLiquidity, INITIAL_LP);

        evm.prank(INITIAL_LP);
        pool.burn(addLiquidity);

        assertEq(pool.expectedLiquidityLU(), addLiquidity * 2, "ExpectedLU is not correct!");
        assertEq(pool.getDieselRate_RAY(), 2 * RAY, "Incorrect diesel rate!");
    }

    //
    // TESTS
    //

    // [P4-1]: getDieselRate_RAY=RAY, withdrawFee=0 and expectedLiquidityLimit as expected at start
    function test_P4_01_start_parameters_correct() public {
        assertEq(pool.name(), "diesel DAI", "Symbol incorrectly set up");
        assertEq(pool.symbol(), "dDAI", "Symbol incorrectly set up");
        assertEq(pool.addressProvider(), address(psts.addressProvider()), "Incorrect address provider");

        assertEq(pool.asset(), underlying, "Incorrect underlying provider");
        assertEq(pool.underlyingToken(), underlying, "Incorrect underlying provider");

        assertEq(pool.decimals(), IERC20Metadata(address(psts.underlying())).decimals(), "Incorrect decimals");

        assertEq(pool.treasuryAddress(), psts.addressProvider().getTreasuryContract(), "Incorrect treasury");

        assertEq(pool.getDieselRate_RAY(), RAY);

        assertEq(address(pool.interestRateModel()), address(psts.linearIRModel()), "Incorrect interest rate model");

        assertEq(pool.expectedLiquidityLimit(), type(uint256).max);

        assertEq(pool.totalBorrowedLimit(), type(uint256).max);

        // assertTrue(!pool.isFeeToken(), "Incorrect isFeeToken");

        assertEq(pool.wethAddress(), psts.addressProvider().getWethToken(), "Incorrect weth token");
    }

    // [P4-2]: constructor reverts for zero addresses
    function test_P4_02_constructor_reverts_for_zero_addresses() public {
        Pool4626Opts memory opts = Pool4626Opts({
            addressProvider: address(0),
            underlyingToken: underlying,
            interestRateModel: address(psts.linearIRModel()),
            expectedLiquidityLimit: type(uint128).max,
            supportsQuotas: false
        });

        evm.expectRevert(ZeroAddressException.selector);
        new Pool4626(opts);

        opts.addressProvider = address(psts.addressProvider());
        opts.interestRateModel = address(0);

        evm.expectRevert(ZeroAddressException.selector);
        new Pool4626(opts);

        opts.interestRateModel = address(psts.linearIRModel());
        opts.underlyingToken = address(0);

        evm.expectRevert(ZeroAddressException.selector);
        new Pool4626(opts);
    }

    // [P4-3]: constructor emits events
    function test_P4_03_constructor_emits_events() public {
        uint256 limit = 15890;
        Pool4626Opts memory opts = Pool4626Opts({
            addressProvider: address(psts.addressProvider()),
            underlyingToken: underlying,
            interestRateModel: address(psts.linearIRModel()),
            expectedLiquidityLimit: limit,
            supportsQuotas: false
        });

        evm.expectEmit(true, false, false, false);
        emit NewInterestRateModel(address(psts.linearIRModel()));

        evm.expectEmit(true, false, false, true);
        emit NewExpectedLiquidityLimit(limit);

        evm.expectEmit(false, false, false, true);
        emit NewTotalBorrowedLimit(limit);

        new Pool4626(opts);
    }

    // [P4-4]: addLiquidity, removeLiquidity, lendCreditAccount, repayCreditAccount reverts if contract is paused
    function test_P4_04_cannot_be_used_while_paused() public {
        evm.startPrank(CONFIGURATOR);
        acl.addPausableAdmin(CONFIGURATOR);
        pool.pause();
        evm.stopPrank();

        evm.startPrank(USER);

        evm.expectRevert(bytes(PAUSABLE_ERROR));
        pool.deposit(addLiquidity, FRIEND);

        evm.expectRevert(bytes(PAUSABLE_ERROR));
        pool.depositReferral(addLiquidity, FRIEND, referral);

        evm.expectRevert(bytes(PAUSABLE_ERROR));
        pool.depositETHReferral(FRIEND, referral);

        evm.expectRevert(bytes(PAUSABLE_ERROR));
        payable(address(pool)).call{value: addLiquidity}("");

        evm.expectRevert(bytes(PAUSABLE_ERROR));
        pool.mint(addLiquidity, FRIEND);

        evm.expectRevert(bytes(PAUSABLE_ERROR));
        pool.withdraw(removeLiquidity, FRIEND, FRIEND);

        evm.expectRevert(bytes(PAUSABLE_ERROR));
        pool.withdrawETH(removeLiquidity, FRIEND, FRIEND);

        evm.expectRevert(bytes(PAUSABLE_ERROR));
        pool.redeem(removeLiquidity, FRIEND, FRIEND);

        evm.expectRevert(bytes(PAUSABLE_ERROR));
        pool.redeemETH(removeLiquidity, FRIEND, FRIEND);

        evm.expectRevert(bytes(PAUSABLE_ERROR));
        pool.lendCreditAccount(1, FRIEND);

        evm.expectRevert(bytes(PAUSABLE_ERROR));
        pool.repayCreditAccount(1, 0, 0);

        evm.stopPrank();
    }

    // [P4-5]: depositing eth work for WETH pools only
    function test_P4_05_eth_functions_work_for_WETH_pools_only() public {
        // adds liqudity to mint initial diesel tokens to change 1:1 rate

        evm.deal(USER, addLiquidity);

        evm.startPrank(USER);

        evm.expectRevert(IPool4626Exceptions.AssetIsNotWETHException.selector);
        pool.depositETHReferral{value: addLiquidity}(FRIEND, referral);

        evm.expectRevert(IPool4626Exceptions.AssetIsNotWETHException.selector);
        payable(address(pool)).call{value: addLiquidity}("");

        evm.expectRevert(IPool4626Exceptions.AssetIsNotWETHException.selector);
        pool.withdrawETH(1, FRIEND, USER);

        evm.expectRevert(IPool4626Exceptions.AssetIsNotWETHException.selector);
        pool.redeemETH(1, FRIEND, USER);

        evm.stopPrank();
    }

    // TODO: fix test

    // // [P4-6]: deposit adds liquidity correctly
    // function test_P4_06_deposit_adds_liquidity_correctly() public {
    //     // adds liqudity to mint initial diesel tokens to change 1:1 rate

    //     for (uint256 j; j < 2; ++j) {
    //         for (uint256 i; i < 2; ++i) {
    //             bool withReferralCode = j == 0;

    //             bool feeToken = false; //i == 1;

    //             _setUp(feeToken ? Tokens.USDT : Tokens.DAI);

    //             if (feeToken) {
    //                 // set 50% fee if fee token
    //                 ERC20FeeMock(pool.asset()).setMaximumFee(type(uint256).max);
    //                 ERC20FeeMock(pool.asset()).setBasisPointsRate(fee);
    //             }

    //             uint256 expectedShares = feeToken ? _mulFee(addLiquidity / 2, fee) : addLiquidity / 2;

    //             evm.expectEmit(true, true, false, true);
    //             emit Transfer(address(0), FRIEND, expectedShares);

    //             evm.expectEmit(true, true, false, true);
    //             emit Deposit(USER, FRIEND, addLiquidity, expectedShares);

    //             if (withReferralCode) {
    //                 evm.expectEmit(true, true, false, true);
    //                 emit DepositReferral(USER, FRIEND, addLiquidity, referral);
    //             }

    //             evm.prank(USER);
    //             uint256 shares = withReferralCode
    //                 ? pool.depositReferral(addLiquidity, FRIEND, referral)
    //                 : pool.deposit(addLiquidity, FRIEND);

    //             expectBalance(address(pool), FRIEND, expectedShares, "Incorrect diesel tokens on FRIEND account");
    //             // expectBalance(underlying, USER, liquidityProviderInitBalance - addLiquidity);
    //             // assertEq(pool.expectedLiquidity(), addLiquidity * 3);
    //             // assertEq(pool.availableLiquidity(), addLiquidity * 3);
    //             // assertEq(shares, expectedShares);
    //         }
    //     }
    // }

    // [P4-7]: depositETH adds liquidity correctly
    function test_P4_07_depositETH_adds_liquidity_correctly() public {
        // adds liqudity to mint initial diesel tokens to change 1:1 rate

        for (uint256 i; i < 2; ++i) {
            bool depositReferral = i == 0;

            _setUp(Tokens.WETH);

            _initPoolLiquidity();

            uint256 expectedShares = addLiquidity / 2;

            address receiver = depositReferral ? FRIEND : USER;

            evm.expectEmit(true, true, false, true);
            emit Transfer(address(0), receiver, expectedShares);

            evm.expectEmit(true, true, false, true);
            emit Deposit(USER, receiver, addLiquidity, expectedShares);

            if (depositReferral) {
                evm.expectEmit(true, true, false, true);
                emit DepositReferral(USER, FRIEND, addLiquidity, referral);
            }

            evm.deal(USER, addLiquidity);

            uint256 shares;
            if (depositReferral) {
                evm.prank(USER);
                shares = pool.depositETHReferral{value: addLiquidity}(FRIEND, referral);
            } else {
                evm.prank(USER);
                payable(address(pool)).call{value: addLiquidity}("");
            }

            expectBalance(address(pool), receiver, expectedShares);
            assertEq(pool.expectedLiquidity(), addLiquidity * 3);
            assertEq(pool.availableLiquidity(), addLiquidity * 3);

            if (depositReferral) {
                assertEq(shares, expectedShares);
            }
        }
    }

    // [P4-8]: deposit adds liquidity correctly
    function test_P4_08_mint_adds_liquidity_correctly() public {
        // adds liqudity to mint initial diesel tokens to change 1:1 rate

        for (uint256 i; i < 2; ++i) {
            bool feeToken = i == 1;

            _setUp(feeToken ? Tokens.USDT : Tokens.DAI);

            if (feeToken) {
                // set 50% fee if fee token
                ERC20FeeMock(pool.asset()).setMaximumFee(type(uint256).max);
                ERC20FeeMock(pool.asset()).setBasisPointsRate(fee);
            }

            _initPoolLiquidity();

            uint256 desiredShares = addLiquidity / 2;
            uint256 expectedAssetsPaid = feeToken ? _divFee(addLiquidity, fee) : addLiquidity;
            uint256 expectedAvailableLiquidity = pool.availableLiquidity() + addLiquidity;

            evm.expectEmit(true, true, false, true);
            emit Transfer(address(0), FRIEND, desiredShares);

            evm.expectEmit(true, true, false, true);
            emit Deposit(USER, FRIEND, expectedAssetsPaid, desiredShares);

            uint256 gl = gasleft();

            evm.prank(USER);
            uint256 assets = pool.mint(desiredShares, FRIEND);

            console.log(gl - gasleft());

            expectBalance(address(pool), FRIEND, desiredShares, "Incorrect shares ");
            expectBalance(underlying, USER, liquidityProviderInitBalance - expectedAssetsPaid, "Incorrect USER balance");
            assertEq(pool.expectedLiquidity(), addLiquidity * 3, "Incorrect expected liquidity");
            assertEq(pool.availableLiquidity(), expectedAvailableLiquidity, "Incorrect available liquidity");
            assertEq(assets, expectedAssetsPaid, "Incorrect assets return value");
        }
    }

    //
    // REMOVE LIQUIDITY
    //

    // // [P4-5]: removeLiquidity correctly removes liquidity
    // function test_PX_05_remove_liquidity_removes_correctly() public {
    //     evm.prank(USER);
    //     pool.depositReferral(addLiquidity, FRIEND, referral);

    //     // evm.expectEmit(true, true, false, true);
    //     // emit RemoveLiquidity(FRIEND, USER, removeLiquidity);

    //     evm.prank(FRIEND);
    //     pool.redeem(removeLiquidity, USER, FRIEND);

    //     expectBalance(address(pool), FRIEND, addLiquidity - removeLiquidity);
    //     expectBalance(underlying, USER, liquidityProviderInitBalance - addLiquidity + removeLiquidity);
    //     assertEq(pool.expectedLiquidity(), addLiquidity - removeLiquidity);
    //     assertEq(pool.availableLiquidity(), addLiquidity - removeLiquidity);
    // }

    // // [P4-7]: constructor set correct cumulative index to 1 at start
    // function test_PX_07_starting_cumulative_index_correct() public {
    //     assertEq(pool.cumulativeIndexLU_RAY(), RAY);
    // }

    // // [P4-8]: getDieselRate_RAY correctly computes rate
    // function test_PX_08_diesel_rate_computes_correctly() public {
    //     evm.prank(USER);
    //     pool.deposit(addLiquidity, FRIEND);

    //     // pool.setExpectedLiquidityLU(addLiquidity * 2);

    //     assertEq(pool.expectedLiquidity(), addLiquidity * 2);
    //     assertEq(pool.getDieselRate_RAY(), RAY * 2);
    // }

    // // [P4-9]: addLiquidity correctly adds liquidity with DieselRate != 1
    // function test_PX_09_correctly_adds_liquidity_at_new_diesel_rate() public {
    //     evm.prank(USER);
    //     pool.deposit(addLiquidity, USER);

    //     // pool.setExpectedLiquidityLU(addLiquidity * 2);

    //     evm.prank(USER);
    //     pool.deposit(addLiquidity, FRIEND);

    //     assertEq(pool.balanceOf(FRIEND), addLiquidity / 2);
    // }

    // // [P4-10]: removeLiquidity correctly removes liquidity if diesel rate != 1
    // function test_PX_10_correctly_removes_liquidity_at_new_diesel_rate() public {
    //     evm.prank(USER);
    //     pool.deposit(addLiquidity, FRIEND);

    //     // pool.setExpectedLiquidityLU(uint128(addLiquidity * 2));

    //     evm.prank(FRIEND);
    //     pool.redeem(removeLiquidity, USER, FRIEND);

    //     expectBalance(address(pool), FRIEND, addLiquidity - removeLiquidity);
    //     expectBalance(underlying, USER, liquidityProviderInitBalance - addLiquidity + 2 * removeLiquidity);
    //     assertEq(pool.expectedLiquidity(), (addLiquidity - removeLiquidity) * 2);
    //     assertEq(pool.availableLiquidity(), addLiquidity - removeLiquidity * 2);
    // }

    // // [P4-11]: connectCreditManager, forbidCreditManagerToBorrow, newInterestRateModel, setExpecetedLiquidityLimit reverts if called with non-configurator
    // function test_PX_11_admin_functions_revert_on_non_admin() public {
    //     evm.startPrank(USER);

    //     evm.expectRevert(CallerNotControllerException.selector);
    //     pool.setCreditManagerLimit(DUMB_ADDRESS, 1);

    //     evm.expectRevert(CallerNotConfiguratorException.selector);
    //     pool.updateInterestRateModel(DUMB_ADDRESS);

    //     evm.expectRevert(CallerNotControllerException.selector);
    //     pool.setExpectedLiquidityLimit(0);

    //     evm.stopPrank();
    // }

    // // [P4-12]: connectCreditManager reverts if another pool is setup in CreditManager
    // function test_PX_12_connectCreditManager_fails_on_incompatible_CM() public {
    //     cmMock.changePoolService(DUMB_ADDRESS);

    //     evm.expectRevert(IPool4626Exceptions.IncompatibleCreditManagerException.selector);

    //     evm.prank(CONFIGURATOR);
    //     pool.setCreditManagerLimit(address(cmMock), 1);
    // }

    // // [P4-11]: connectCreditManager adds CreditManager correctly and emits event
    // function test_PX_13_CM_is_connected_correctly() public {
    //     // assertEq(pool.creditManagersCount(), 0);
    //     // evm.expectEmit(true, false, false, false);
    //     // emit NewCreditManagerConnected(address(cmMock));
    //     // evm.prank(CONFIGURATOR);
    //     // pool.connectCreditManager(address(cmMock));
    //     // assertEq(pool.creditManagersCount(), 1);
    //     // assertTrue(pool.creditManagersCanBorrow(address(cmMock)));
    //     // assertTrue(pool.creditManagersCanRepay(address(cmMock)));
    // }

    // // [P4-12]: lendCreditAccount, repayCreditAccount reverts if called non-CreditManager
    // function test_PX_14_CA_can_be_lent_repaid_only_by_CM() public {
    //     evm.startPrank(USER);

    //     evm.expectRevert(IPool4626Exceptions.CreditManagerCantBorrowException.selector);
    //     pool.lendCreditAccount(0, DUMB_ADDRESS);

    //     evm.expectRevert(IPool4626Exceptions.CreditManagerCantBorrowException.selector);
    //     pool.lendCreditAccount(10, DUMB_ADDRESS);

    //     evm.expectRevert(IPool4626Exceptions.CreditManagerOnlyException.selector);
    //     pool.repayCreditAccount(0, 0, 0);

    //     evm.stopPrank();
    // }

    // // [P4-13]: lendCreditAccount reverts of creditManagers was disallowed by forbidCreditManagerToBorrow
    // function test_PX_13_lendCreditAccount_reverts_on_forbidden_CM() public {
    //     _connectAndSetLimit();

    //     evm.prank(USER);
    //     pool.deposit(addLiquidity, USER);

    //     cmMock.lendCreditAccount(addLiquidity / 2, DUMB_ADDRESS);

    //     // evm.expectEmit(false, false, false, true);
    //     // emit BorrowForbidden(address(cmMock));

    //     evm.prank(CONFIGURATOR);
    //     pool.setCreditManagerLimit(address(cmMock), 0);

    //     evm.expectRevert(IPool4626Exceptions.CreditManagerCantBorrowException.selector);
    //     cmMock.lendCreditAccount(addLiquidity / 2, DUMB_ADDRESS);
    // }

    // // [P4-14]: lendCreditAccount transfers tokens correctly
    // function test_PX_14_lendCreditAccount_correctly_transfers_tokens() public {
    //     _connectAndSetLimit();

    //     evm.prank(USER);
    //     pool.deposit(addLiquidity, USER);

    //     address ca = cmMock.getCreditAccountOrRevert(DUMB_ADDRESS);

    //     expectBalance(underlying, ca, 0);

    //     cmMock.lendCreditAccount(addLiquidity / 2, ca);

    //     expectBalance(underlying, ca, addLiquidity / 2);
    // }

    // // [P4-15]: lendCreditAccount emits Borrow event
    // function test_PX_15_lendCreditAccount_emits_event() public {
    //     _connectAndSetLimit();

    //     evm.prank(USER);
    //     pool.deposit(addLiquidity, USER);

    //     address ca = cmMock.getCreditAccountOrRevert(DUMB_ADDRESS);

    //     evm.expectEmit(false, false, false, true);
    //     emit Borrow(address(cmMock), ca, addLiquidity / 2);

    //     cmMock.lendCreditAccount(addLiquidity / 2, ca);
    // }

    // // [P4-16]: lendCreditAccount correctly updates parameters
    // function test_PX_16_lendCreditAccount_correctly_updates_parameters() public {
    //     _connectAndSetLimit();

    //     evm.prank(USER);
    //     pool.deposit(addLiquidity, USER);

    //     address ca = cmMock.getCreditAccountOrRevert(DUMB_ADDRESS);

    //     uint256 totalBorrowed = pool.totalBorrowed();

    //     cmMock.lendCreditAccount(addLiquidity / 2, ca);

    //     assertEq(pool.totalBorrowed(), totalBorrowed + addLiquidity / 2, "Incorrect new borrow amount");
    // }

    // // [P4-17]: lendCreditAccount correctly updates borrow rate
    // function test_PX_17_lendCreditAccount_correctly_updates_borrow_rate() public {
    //     _connectAndSetLimit();

    //     evm.prank(USER);
    //     pool.deposit(addLiquidity, USER);

    //     address ca = cmMock.getCreditAccountOrRevert(DUMB_ADDRESS);

    //     cmMock.lendCreditAccount(addLiquidity / 2, ca);

    //     uint256 expectedLiquidity = addLiquidity;
    //     uint256 expectedAvailable = expectedLiquidity - addLiquidity / 2;

    //     uint256 expectedBorrowRate = psts.linearIRModel().calcBorrowRate(expectedLiquidity, expectedAvailable);

    //     assertEq(expectedBorrowRate, pool.borrowRate_RAY(), "Borrow rate is incorrect");
    // }

    // // [P4-18]: repayCreditAccount emits Repay event
    // function test_PX_18_repayCreditAccount_emits_event() public {
    //     _connectAndSetLimit();

    //     evm.prank(USER);
    //     pool.deposit(addLiquidity, USER);

    //     address ca = cmMock.getCreditAccountOrRevert(DUMB_ADDRESS);

    //     cmMock.lendCreditAccount(addLiquidity / 2, ca);

    //     evm.expectEmit(true, false, false, true);
    //     emit Repay(address(cmMock), addLiquidity / 2, 1, 0);

    //     cmMock.repayCreditAccount(addLiquidity / 2, 1, 0);
    // }

    // // [P4-19]: repayCreditAccount correctly updates params on loss accrued: treasury < loss
    // function test_PX_19_repayCreditAccount_correctly_updates_on_uncovered_loss() public {
    //     address treasury = psts.treasury();

    //     _connectAndSetLimit();

    //     evm.prank(USER);
    //     pool.deposit(addLiquidity, USER);

    //     evm.prank(USER);
    //     pool.mint(1e4, treasury);

    //     address ca = cmMock.getCreditAccountOrRevert(DUMB_ADDRESS);

    //     cmMock.lendCreditAccount(addLiquidity / 2, ca);

    //     uint256 borrowRate = pool.borrowRate_RAY();
    //     uint256 timeWarp = 365 days;

    //     uint256 expectedInterest = ((addLiquidity / 2) * borrowRate) / RAY;
    //     uint256 expectedLiquidity = 1e4 + addLiquidity + expectedInterest - 1e6;

    //     uint256 expectedBorrowRate = psts.linearIRModel().calcBorrowRate(expectedLiquidity, expectedLiquidity);

    //     evm.warp(block.timestamp + timeWarp);

    //     uint256 treasuryUnderlying = pool.convertToAssets(pool.balanceOf(treasury));

    //     tokenTestSuite.mint(Tokens.DAI, address(pool), addLiquidity / 2 + expectedInterest - 1e6);

    //     evm.expectEmit(true, false, false, true);
    //     emit UncoveredLoss(address(cmMock), 1e6 - treasuryUnderlying);

    //     cmMock.repayCreditAccount(addLiquidity / 2, 0, 1e6);

    //     // assertEq(pool.expectedLiquidity(), expectedLiquidity, "Expected liquidity was not updated correctly");

    //     assertEq(pool.balanceOf(treasury), 0, "dToken remains in the treasury");

    //     assertEq(pool.borrowRate_RAY(), expectedBorrowRate, "Borrow rate was not updated correctly");
    // }

    // // [P4-20]: repayCreditAccount correctly updates params on loss accrued: treasury >= loss; and emits event
    // function test_PX_20_repayCreditAccount_correctly_updates_on_covered_loss() public {
    //     address treasury = psts.treasury();

    //     _connectAndSetLimit();

    //     evm.prank(USER);
    //     pool.deposit(addLiquidity, USER);

    //     uint256 dieselSupply = pool.totalSupply();

    //     evm.prank(USER);
    //     pool.mint(dieselSupply, treasury);

    //     address ca = cmMock.getCreditAccountOrRevert(DUMB_ADDRESS);

    //     cmMock.lendCreditAccount(addLiquidity / 2, ca);

    //     uint256 treasuryUnderlying = pool.convertToAssets(pool.balanceOf(treasury));

    //     uint256 borrowRate = pool.borrowRate_RAY();
    //     uint256 timeWarp = 365 days;

    //     evm.warp(block.timestamp + timeWarp);

    //     uint256 expectedInterest = ((addLiquidity / 2) * borrowRate) / RAY;
    //     uint256 expectedLiquidity = treasuryUnderlying + addLiquidity - (addLiquidity / 2);

    //     uint256 expectedBorrowRate = psts.linearIRModel().calcBorrowRate(expectedLiquidity, expectedLiquidity);
    //     uint256 expectedTreasury = dieselSupply - pool.convertToShares(addLiquidity / 2 + expectedInterest);

    //     // It simulates zero return (full loss)
    //     cmMock.repayCreditAccount(addLiquidity / 2, 0, addLiquidity / 2 + expectedInterest);

    //     assertEq(pool.expectedLiquidity(), expectedLiquidity, "Expected liquidity was not updated correctly");

    //     assertEq(pool.balanceOf(treasury), expectedTreasury, "dToken balance incorrect");

    //     assertEq(pool.borrowRate_RAY(), expectedBorrowRate, "Borrow rate was not updated correctly");
    // }

    // // [P4-21]: repayCreditAccount correctly updates params on profit
    // function test_PX_21_repayCreditAccount_correctly_updates_on_profit() public {
    //     address treasury = psts.treasury();
    //     _connectAndSetLimit();

    //     evm.prank(USER);
    //     pool.deposit(addLiquidity, USER);

    //     address ca = cmMock.getCreditAccountOrRevert(DUMB_ADDRESS);

    //     cmMock.lendCreditAccount(addLiquidity / 2, ca);

    //     uint256 borrowRate = pool.borrowRate_RAY();
    //     uint256 timeWarp = 365 days;

    //     evm.warp(block.timestamp + timeWarp);

    //     uint256 expectedInterest = ((addLiquidity / 2) * borrowRate) / RAY;
    //     uint256 expectedLiquidity = addLiquidity + expectedInterest + 100;

    //     uint256 expectedBorrowRate =
    //         psts.linearIRModel().calcBorrowRate(expectedLiquidity, addLiquidity + expectedInterest + 100);

    //     tokenTestSuite.mint(Tokens.DAI, address(pool), addLiquidity / 2 + expectedInterest + 100);

    //     cmMock.repayCreditAccount(addLiquidity / 2, 100, 0);

    //     console.log("eq:", expectedLiquidity);

    //     assertEq(pool.expectedLiquidity(), expectedLiquidity, "Expected liquidity was not updated correctly");

    //     assertEq(pool.balanceOf(treasury), pool.convertToShares(100), "dToken balance incorrect");

    //     assertEq(pool.borrowRate_RAY(), expectedBorrowRate, "Borrow rate was not updated correctly");
    // }

    // // [P4-22]: repayCreditAccount does not change the diesel rate outside margin of error
    // function test_PX_22_repayCreditAccount_does_not_change_diesel_rate() public {
    //     _connectAndSetLimit();

    //     evm.prank(USER);
    //     pool.deposit(addLiquidity, USER);

    //     address ca = cmMock.getCreditAccountOrRevert(DUMB_ADDRESS);

    //     cmMock.lendCreditAccount(addLiquidity / 2, ca);

    //     uint256 borrowRate = pool.borrowRate_RAY();
    //     uint256 timeWarp = 365 days;

    //     evm.warp(block.timestamp + timeWarp);

    //     uint256 expectedInterest = ((addLiquidity / 2) * borrowRate) / RAY;
    //     uint256 expectedLiquidity = addLiquidity + expectedInterest;

    //     tokenTestSuite.mint(Tokens.DAI, address(pool), addLiquidity / 2 + expectedInterest);

    //     cmMock.repayCreditAccount(addLiquidity / 2, 100, 0);

    //     assertEq(
    //         (RAY * expectedLiquidity) / addLiquidity / 1e8,
    //         pool.getDieselRate_RAY() / 1e8,
    //         "Expected liquidity was not updated correctly"
    //     );
    // }

    // // [P4-23]: fromDiesel / toDiesel works correctly
    // function test_PX_23_diesel_conversion_is_correct() public {
    //     _connectAndSetLimit();

    //     evm.prank(USER);
    //     pool.deposit(addLiquidity, USER);

    //     address ca = cmMock.getCreditAccountOrRevert(DUMB_ADDRESS);

    //     cmMock.lendCreditAccount(addLiquidity / 2, ca);

    //     uint256 timeWarp = 365 days;

    //     evm.warp(block.timestamp + timeWarp);

    //     uint256 dieselRate = pool.getDieselRate_RAY();

    //     assertEq(
    //         pool.convertToShares(addLiquidity), (addLiquidity * RAY) / dieselRate, "ToDiesel does not compute correctly"
    //     );

    //     assertEq(
    //         pool.convertToAssets(addLiquidity), (addLiquidity * dieselRate) / RAY, "ToDiesel does not compute correctly"
    //     );
    // }

    // // [P4-24]: updateInterestRateModel changes interest rate model & emit event
    // function test_PX_24_updateInterestRateModel_works_correctly_and_emits_event() public {
    //     LinearInterestRateModel newIR = new LinearInterestRateModel(
    //         8000,
    //         9000,
    //         200,
    //         500,
    //         4000,
    //         7500,
    //         false
    //     );

    //     evm.expectEmit(true, false, false, false);
    //     emit NewInterestRateModel(address(newIR));

    //     evm.prank(CONFIGURATOR);
    //     pool.updateInterestRateModel(address(newIR));

    //     assertEq(address(pool.interestRateModel()), address(newIR), "Interest rate model was not set correctly");
    // }

    // // [P4-25]: updateInterestRateModel correctly computes new borrow rate
    // function test_PX_25_updateInterestRateModel_correctly_computes_new_borrow_rate() public {
    //     LinearInterestRateModel newIR = new LinearInterestRateModel(
    //         8000,
    //         9000,
    //         200,
    //         500,
    //         4000,
    //         7500,
    //         false
    //     );

    //     _connectAndSetLimit();

    //     evm.prank(USER);
    //     pool.deposit(addLiquidity, USER);

    //     address ca = cmMock.getCreditAccountOrRevert(DUMB_ADDRESS);

    //     cmMock.lendCreditAccount(addLiquidity / 2, ca);

    //     uint256 expectedLiquidity = pool.expectedLiquidity();
    //     uint256 availableLiquidity = pool.availableLiquidity();

    //     evm.prank(CONFIGURATOR);
    //     pool.updateInterestRateModel(address(newIR));

    //     assertEq(
    //         newIR.calcBorrowRate(expectedLiquidity, availableLiquidity),
    //         pool.borrowRate_RAY(),
    //         "Borrow rate does not match"
    //     );
    // }

    // // [P4-26]: updateBorrowRate correctly updates parameters
    // function test_PX_26_updateBorrowRate_correct() public {
    //     _connectAndSetLimit();

    //     evm.prank(USER);
    //     pool.deposit(addLiquidity, USER);

    //     address ca = cmMock.getCreditAccountOrRevert(DUMB_ADDRESS);

    //     cmMock.lendCreditAccount(addLiquidity / 2, ca);

    //     uint256 borrowRate = pool.borrowRate_RAY();
    //     uint256 timeWarp = 365 days;

    //     evm.warp(block.timestamp + timeWarp);

    //     uint256 expectedInterest = ((addLiquidity / 2) * borrowRate) / RAY;
    //     uint256 expectedLiquidity = addLiquidity + expectedInterest;

    //     uint256 expectedBorrowRate = psts.linearIRModel().calcBorrowRate(expectedLiquidity, addLiquidity / 2);

    //     _updateBorrowrate();

    //     assertEq(pool.expectedLiquidity(), expectedLiquidity, "Expected liquidity was not updated correctly");

    //     assertEq(uint256(pool.timestampLU()), block.timestamp, "Timestamp was not updated correctly");

    //     assertEq(pool.borrowRate_RAY(), expectedBorrowRate, "Borrow rate was not updated correctly");

    //     assertEq(pool.calcLinearCumulative_RAY(), pool.cumulativeIndexLU_RAY(), "Index value was not updated correctly");
    // }

    // // [P4-27]: calcLinearCumulative_RAY computes correctly
    // function test_PX_27_calcLinearCumulative_RAY_correct() public {
    //     _connectAndSetLimit();

    //     evm.prank(USER);
    //     pool.deposit(addLiquidity, USER);

    //     address ca = cmMock.getCreditAccountOrRevert(DUMB_ADDRESS);

    //     cmMock.lendCreditAccount(addLiquidity / 2, ca);

    //     uint256 timeWarp = 180 days;

    //     evm.warp(block.timestamp + timeWarp);

    //     uint256 borrowRate = pool.borrowRate_RAY();

    //     uint256 expectedLinearRate = RAY + (borrowRate * timeWarp) / 365 days;

    //     assertEq(pool.calcLinearCumulative_RAY(), expectedLinearRate, "Index value was not updated correctly");
    // }

    // // [P4-28]: expectedLiquidity() computes correctly
    // function test_PX_28_expectedLiquidity_correct() public {
    //     _connectAndSetLimit();

    //     evm.prank(USER);
    //     pool.deposit(addLiquidity, USER);

    //     address ca = cmMock.getCreditAccountOrRevert(DUMB_ADDRESS);

    //     cmMock.lendCreditAccount(addLiquidity / 2, ca);

    //     uint256 borrowRate = pool.borrowRate_RAY();
    //     uint256 timeWarp = 365 days;

    //     evm.warp(block.timestamp + timeWarp);

    //     uint256 expectedInterest = ((addLiquidity / 2) * borrowRate) / RAY;
    //     uint256 expectedLiquidity = pool.expectedLiquidityLU() + expectedInterest;

    //     assertEq(pool.expectedLiquidity(), expectedLiquidity, "Index value was not updated correctly");
    // }

    // // [P4-29]: setExpectedLiquidityLimit() sets limit & emits event
    // function test_PX_29_setExpectedLiquidityLimit_correct_and_emits_event() public {
    //     evm.expectEmit(false, false, false, true);
    //     emit NewExpectedLiquidityLimit(10000);

    //     evm.prank(CONFIGURATOR);
    //     pool.setExpectedLiquidityLimit(10000);

    //     assertEq(pool.expectedLiquidityLimit(), 10000, "expectedLiquidityLimit not set correctly");
    // }

    // // [P4-30]: addLiquidity reverts above expectedLiquidityLimit
    // function test_PX_30_addLiquidity_reverts_above_liquidity_limit() public {
    //     _connectAndSetLimit();

    //     evm.prank(CONFIGURATOR);
    //     pool.setExpectedLiquidityLimit(10000);

    //     evm.expectRevert(IPool4626Exceptions.ExpectedLiquidityLimitException.selector);

    //     evm.prank(USER);
    //     pool.deposit(addLiquidity, USER);
    // }

    // // [P4-31]: setWithdrawFee reverts on fee > 1%
    // function test_PX_31_setWithdrawFee_reverts_on_fee_too_lage() public {
    //     evm.expectRevert(IPool4626Exceptions.IncorrectWithdrawalFeeException.selector);

    //     evm.prank(CONFIGURATOR);
    //     pool.setWithdrawFee(101);
    // }

    // // [P4-32]: setWithdrawFee changes fee and emits event
    // function test_PX_32_setWithdrawFee_correct_and_emits_event() public {
    //     evm.expectEmit(false, false, false, true);
    //     emit NewWithdrawFee(50);

    //     evm.prank(CONFIGURATOR);
    //     pool.setWithdrawFee(50);

    //     assertEq(pool.withdrawFee(), 50, "withdrawFee not set correctly");
    // }

    // // [P4-33]: removeLiqudity correctly takes withdrawal fee
    // function test_PX_33_removeLiquidity_takes_withdrawal_fee() public {
    //     address treasury = psts.treasury();

    //     _connectAndSetLimit();

    //     evm.startPrank(CONFIGURATOR);
    //     pool.setWithdrawFee(50);
    //     evm.stopPrank();

    //     evm.startPrank(USER);
    //     pool.deposit(addLiquidity, USER);

    //     uint256 balanceBefore = tokenTestSuite.balanceOf(underlying, USER);

    //     pool.redeem(addLiquidity, USER, USER);
    //     evm.stopPrank();

    //     expectBalance(underlying, treasury, (addLiquidity * 50) / 10000, "Incorrect balance in treasury");

    //     expectBalance(underlying, USER, balanceBefore + (addLiquidity * 9950) / 10000, "Incorrect balance for user");
    // }

    // // [P4-35]: updateInterestRateModel reverts on zero address
    // function test_PX_35_updateInterestRateModel_reverts_on_zero_address() public {
    //     evm.expectRevert(ZeroAddressException.selector);
    //     evm.prank(CONFIGURATOR);
    //     pool.updateInterestRateModel(address(0));
    // }
}
