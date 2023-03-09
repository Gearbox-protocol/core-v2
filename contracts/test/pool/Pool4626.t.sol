// SPDX-License-Identifier: UNLICENSED
// Gearbox Protocol. Generalized leverage for DeFi protocols
// (c) Gearbox Holdings, 2022
pragma solidity ^0.8.10;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IERC20Metadata} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import {IERC4626} from "@openzeppelin/contracts/interfaces/IERC4626.sol";
import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";

import {Pool4626} from "../../pool/Pool4626.sol";
import {IERC4626Events} from "../../interfaces/IERC4626.sol";
import {IPool4626Events, Pool4626Opts, IPool4626Exceptions} from "../../interfaces/IPool4626.sol";
import {IERC4626Events} from "../../interfaces/IERC4626.sol";

import {IInterestRateModel} from "../../interfaces/IInterestRateModel.sol";

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
import "../lib/StringUtils.sol";
import {PERCENTAGE_FACTOR} from "../../libraries/Constants.sol";

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
    using Math for uint256;
    using StringUtils for string;

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
    IInterestRateModel irm;

    function setUp() public {
        _setUp(Tokens.DAI, false);
    }

    function _setUp(Tokens t, bool supportQuotas) public {
        tokenTestSuite = new TokensTestSuite();
        psts = new PoolServiceTestSuite(
            tokenTestSuite,
            tokenTestSuite.addressOf(t),
            true,
            supportQuotas
        );

        pool = psts.pool4626();
        irm = psts.linearIRModel();
        underlying = address(psts.underlying());
        cmMock = psts.cmMock();
        acl = psts.acl();
    }

    //
    // HELPERS
    //
    function _setUpTestCase(
        Tokens t,
        uint256 feeToken,
        uint16 utilisation,
        uint256 availableLiquidity,
        uint256 dieselRate,
        uint16 withdrawFee,
        bool supportQuotas
    ) internal {
        _setUp(t, supportQuotas);
        if (t == Tokens.USDT) {
            // set 50% fee if fee token
            ERC20FeeMock(pool.asset()).setMaximumFee(type(uint256).max);
            ERC20FeeMock(pool.asset()).setBasisPointsRate(feeToken);
        }

        _initPoolLiquidity(availableLiquidity, dieselRate);
        _connectAndSetLimit();

        if (utilisation > 0) _borrowToUtilisation(utilisation);

        evm.prank(CONFIGURATOR);
        pool.setWithdrawFee(withdrawFee);
    }

    function _connectAndSetLimit() internal {
        evm.prank(CONFIGURATOR);
        pool.setCreditManagerLimit(address(cmMock), type(uint128).max);
    }

    function _borrowToUtilisation(uint16 utilisation) internal {
        cmMock.lendCreditAccount(pool.expectedLiquidity() / 2, DUMB_ADDRESS);

        assertEq(pool.borrowRate(), irm.calcBorrowRate(PERCENTAGE_FACTOR, utilisation, false));
    }

    function _mulFee(uint256 amount, uint256 _fee) internal returns (uint256) {
        return (amount * (PERCENTAGE_FACTOR - _fee)) / PERCENTAGE_FACTOR;
    }

    function _divFee(uint256 amount, uint256 _fee) internal returns (uint256) {
        return (amount * PERCENTAGE_FACTOR) / (PERCENTAGE_FACTOR - _fee);
    }

    function _updateBorrowrate() internal {
        evm.prank(CONFIGURATOR);
        pool.updateInterestRateModel(address(irm));
    }

    function _initPoolLiquidity() internal {
        _initPoolLiquidity(addLiquidity, 2 * RAY);
    }

    function _initPoolLiquidity(uint256 availableLiquidity, uint256 dieselRate) internal {
        assertEq(pool.convertToAssets(RAY), RAY, "Incorrect diesel rate!");

        evm.prank(INITIAL_LP);
        pool.mint(availableLiquidity, INITIAL_LP);

        evm.prank(INITIAL_LP);
        pool.burn(availableLiquidity * (dieselRate - RAY) / dieselRate);

        // assertEq(pool.expectedLiquidityLU(), availableLiquidity * dieselRate / RAY, "ExpectedLU is not correct!");
        assertEq(pool.convertToAssets(RAY), dieselRate, "Incorrect diesel rate!");
    }

    function _testCaseErr(string memory caseName, string memory err) internal pure returns (string memory) {
        return string("\nCase: ").concat(caseName).concat("\n").concat("Error: ").concat(err);
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

        assertEq(pool.treasury(), psts.addressProvider().getTreasuryContract(), "Incorrect treasury");

        assertEq(pool.convertToAssets(RAY), RAY, "Incorrect diesel rate!");

        assertEq(address(pool.interestRateModel()), address(psts.linearIRModel()), "Incorrect interest rate model");

        assertEq(pool.expectedLiquidityLimit(), type(uint256).max);

        assertEq(pool.totalBorrowedLimit(), type(uint256).max);
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
        pool.mint(addLiquidity, FRIEND);

        evm.expectRevert(bytes(PAUSABLE_ERROR));
        pool.withdraw(removeLiquidity, FRIEND, FRIEND);

        evm.expectRevert(bytes(PAUSABLE_ERROR));
        pool.redeem(removeLiquidity, FRIEND, FRIEND);

        evm.expectRevert(bytes(PAUSABLE_ERROR));
        pool.lendCreditAccount(1, FRIEND);

        evm.expectRevert(bytes(PAUSABLE_ERROR));
        pool.repayCreditAccount(1, 0, 0);

        evm.stopPrank();
    }

    struct DepositTestCase {
        string name;
        /// SETUP
        Tokens asset;
        uint256 tokenFee;
        uint256 initialLiquidity;
        uint256 dieselRate;
        uint16 utilisation;
        uint16 withdrawFee;
        /// PARAMS
        uint256 amountToDeposit;
        /// EXPECTED VALUES
        uint256 expectedShares;
        uint256 expectedAvailableLiquidity;
        uint256 expectedLiquidityAfter;
    }

    // [P4-5]: deposit adds liquidity correctly
    function test_P4_05_deposit_adds_liquidity_correctly() public {
        // adds liqudity to mint initial diesel tokens to change 1:1 rate

        DepositTestCase[2] memory cases = [
            DepositTestCase({
                name: "Normal token",
                // POOL SETUP
                asset: Tokens.DAI,
                tokenFee: 0,
                initialLiquidity: addLiquidity,
                // 1 dDAI = 2 DAI
                dieselRate: 2 * RAY,
                // 50% of available liquidity is borrowed
                utilisation: 50_00,
                withdrawFee: 0,
                // PARAMS
                amountToDeposit: addLiquidity,
                // EXPECTED VALUES:
                //
                // Depends on dieselRate
                expectedShares: addLiquidity / 2,
                // availableLiquidityBefore: addLiqudity /2 (cause 50% utilisation)
                expectedAvailableLiquidity: addLiquidity / 2 + addLiquidity,
                expectedLiquidityAfter: addLiquidity * 2
            }),
            DepositTestCase({
                name: "Fee token",
                /// SETUP
                asset: Tokens.USDT,
                // transfer fee: 60%, so 40% will be transfer to account
                tokenFee: 60_00,
                initialLiquidity: addLiquidity,
                // 1 dUSDT = 2 USDT
                dieselRate: 2 * RAY,
                // 50% of available liquidity is borrowed
                utilisation: 50_00,
                withdrawFee: 0,
                /// PARAMS
                amountToDeposit: addLiquidity,
                /// EXPECTED VALUES
                expectedShares: (addLiquidity * 40 / 100) / 2,
                expectedAvailableLiquidity: addLiquidity / 2 + addLiquidity * 40 / 100,
                expectedLiquidityAfter: addLiquidity + addLiquidity * 40 / 100
            })
        ];

        for (uint256 i; i < cases.length; ++i) {
            DepositTestCase memory testCase = cases[i];
            for (uint256 rc; rc < 2; ++rc) {
                bool withReferralCode = rc == 0;

                _setUpTestCase(
                    testCase.asset,
                    testCase.tokenFee,
                    testCase.utilisation,
                    testCase.initialLiquidity,
                    testCase.dieselRate,
                    testCase.withdrawFee,
                    false
                );

                evm.expectEmit(true, true, false, true);
                emit Transfer(address(0), FRIEND, testCase.expectedShares);

                evm.expectEmit(true, true, false, true);
                emit Deposit(USER, FRIEND, testCase.amountToDeposit, testCase.expectedShares);

                if (withReferralCode) {
                    evm.expectEmit(true, true, false, true);
                    emit DepositReferral(USER, FRIEND, testCase.amountToDeposit, referral);
                }

                evm.prank(USER);
                uint256 shares = withReferralCode
                    ? pool.depositReferral(testCase.amountToDeposit, FRIEND, referral)
                    : pool.deposit(testCase.amountToDeposit, FRIEND);

                expectBalance(
                    address(pool),
                    FRIEND,
                    testCase.expectedShares,
                    _testCaseErr(testCase.name, "Incorrect diesel tokens on FRIEND account")
                );
                expectBalance(underlying, USER, liquidityProviderInitBalance - addLiquidity);
                assertEq(
                    pool.expectedLiquidity(),
                    testCase.expectedLiquidityAfter,
                    _testCaseErr(testCase.name, "Incorrect expected liquidity")
                );
                assertEq(
                    pool.availableLiquidity(),
                    testCase.expectedAvailableLiquidity,
                    _testCaseErr(testCase.name, "Incorrect available liquidity")
                );
                assertEq(shares, testCase.expectedShares);

                assertEq(
                    pool.borrowRate(),
                    irm.calcBorrowRate(pool.expectedLiquidity(), pool.availableLiquidity(), false),
                    _testCaseErr(testCase.name, "Borrow rate wasn't update correcty")
                );
            }
        }
    }

    struct MintTestCase {
        string name;
        /// SETUP
        Tokens asset;
        uint256 tokenFee;
        uint256 initialLiquidity;
        uint256 dieselRate;
        uint16 utilisation;
        uint16 withdrawFee;
        /// PARAMS
        uint256 desiredShares;
        /// EXPECTED VALUES
        uint256 expectedAssetsWithdrawal;
        uint256 expectedAvailableLiquidity;
        uint256 expectedLiquidityAfter;
    }

    // [P4-6]: deposit adds liquidity correctly
    function test_P4_06_mint_adds_liquidity_correctly() public {
        MintTestCase[2] memory cases = [
            MintTestCase({
                name: "Normal token",
                // POOL SETUP
                asset: Tokens.DAI,
                tokenFee: 0,
                initialLiquidity: addLiquidity,
                // 1 dDAI = 2 DAI
                dieselRate: 2 * RAY,
                // 50% of available liquidity is borrowed
                utilisation: 50_00,
                withdrawFee: 0,
                // PARAMS
                desiredShares: addLiquidity / 2,
                // EXPECTED VALUES:
                //
                // Depends on dieselRate
                expectedAssetsWithdrawal: addLiquidity,
                // availableLiquidityBefore: addLiqudity /2 (cause 50% utilisation)
                expectedAvailableLiquidity: addLiquidity / 2 + addLiquidity,
                expectedLiquidityAfter: addLiquidity * 2
            }),
            MintTestCase({
                name: "Fee token",
                /// SETUP
                asset: Tokens.USDT,
                // transfer fee: 60%, so 40% will be transfer to account
                tokenFee: 60_00,
                initialLiquidity: addLiquidity,
                // 1 dUSDT = 2 USDT
                dieselRate: 2 * RAY,
                // 50% of available liquidity is borrowed
                utilisation: 50_00,
                withdrawFee: 0,
                /// PARAMS
                desiredShares: addLiquidity / 2,
                /// EXPECTED VALUES
                /// fee token makes impact on how much tokens will be wiotdrawn from user
                expectedAssetsWithdrawal: addLiquidity * 100 / 40,
                expectedAvailableLiquidity: addLiquidity / 2 + addLiquidity,
                expectedLiquidityAfter: addLiquidity * 2
            })
        ];

        for (uint256 i; i < cases.length; ++i) {
            MintTestCase memory testCase = cases[i];

            _setUpTestCase(
                testCase.asset,
                testCase.tokenFee,
                testCase.utilisation,
                testCase.initialLiquidity,
                testCase.dieselRate,
                testCase.withdrawFee,
                false
            );

            evm.expectEmit(true, true, false, true);
            emit Transfer(address(0), FRIEND, testCase.desiredShares);

            evm.expectEmit(true, true, false, true);
            emit Deposit(USER, FRIEND, testCase.expectedAssetsWithdrawal, testCase.desiredShares);

            evm.prank(USER);
            uint256 assets = pool.mint(testCase.desiredShares, FRIEND);

            expectBalance(
                address(pool), FRIEND, testCase.desiredShares, _testCaseErr(testCase.name, "Incorrect shares ")
            );
            expectBalance(
                underlying,
                USER,
                liquidityProviderInitBalance - testCase.expectedAssetsWithdrawal,
                _testCaseErr(testCase.name, "Incorrect USER balance")
            );
            assertEq(
                pool.expectedLiquidity(),
                testCase.expectedLiquidityAfter,
                _testCaseErr(testCase.name, "Incorrect expected liquidity")
            );
            assertEq(
                pool.availableLiquidity(),
                testCase.expectedAvailableLiquidity,
                _testCaseErr(testCase.name, "Incorrect available liquidity")
            );
            assertEq(
                assets, testCase.expectedAssetsWithdrawal, _testCaseErr(testCase.name, "Incorrect assets return value")
            );

            assertEq(
                pool.borrowRate(),
                irm.calcBorrowRate(pool.expectedLiquidity(), pool.availableLiquidity(), false),
                _testCaseErr(testCase.name, "Borrow rate wasn't update correcty")
            );
        }
    }

    // [P4-7]: deposit and mint if assets more than limit
    function test_P4_07_deposit_and_mint_if_assets_more_than_limit() public {
        for (uint256 j; j < 2; ++j) {
            for (uint256 i; i < 2; ++i) {
                bool feeToken = i == 1;

                Tokens asset = feeToken ? Tokens.USDT : Tokens.DAI;

                _setUpTestCase(asset, feeToken ? 60_00 : 0, 50_00, addLiquidity, 2 * RAY, 0, false);

                evm.prank(CONFIGURATOR);
                pool.setExpectedLiquidityLimit(1237882323 * WAD);

                uint256 assetsToReachLimit = pool.expectedLiquidityLimit() - pool.expectedLiquidity();

                uint256 sharesToReachLimit = assetsToReachLimit / 2;

                if (feeToken) {
                    assetsToReachLimit = _divFee(assetsToReachLimit, fee);
                }

                tokenTestSuite.mint(asset, USER, assetsToReachLimit + 1);

                if (j == 0) {
                    // DEPOSIT CASE
                    evm.prank(USER);
                    pool.deposit(assetsToReachLimit, FRIEND);
                } else {
                    // MINT CASE
                    evm.prank(USER);
                    pool.mint(sharesToReachLimit, FRIEND);
                }
            }
        }
    }

    //
    // WITHDRAW
    //
    struct WithdrawTestCase {
        string name;
        /// SETUP
        Tokens asset;
        uint256 tokenFee;
        uint256 initialLiquidity;
        uint256 dieselRate;
        uint16 utilisation;
        uint16 withdrawFee;
        /// PARAMS
        uint256 sharesToMint;
        uint256 assetsToWithdraw;
        /// EXPECTED VALUES
        uint256 expectedSharesBurnt;
        uint256 expectedAvailableLiquidity;
        uint256 expectedLiquidityAfter;
        uint256 expectedTreasury;
    }

    // [P4-8]: deposit and mint if assets more than limit
    function test_P4_08_withdraw_works_as_expected() public {
        WithdrawTestCase[4] memory cases = [
            WithdrawTestCase({
                name: "Normal token with 0 withdraw fee",
                // POOL SETUP
                asset: Tokens.DAI,
                tokenFee: 0,
                initialLiquidity: addLiquidity,
                // 1 dDAI = 2 DAI
                dieselRate: 2 * RAY,
                // 50% of available liquidity is borrowed
                utilisation: 50_00,
                withdrawFee: 0,
                // PARAMS
                sharesToMint: addLiquidity / 2,
                assetsToWithdraw: addLiquidity / 4,
                // EXPECTED VALUES:
                //
                // Depends on dieselRate
                expectedSharesBurnt: addLiquidity / 8,
                // availableLiquidityBefore: addLiqudity /2 (cause 50% utilisation)
                expectedAvailableLiquidity: addLiquidity / 2 + addLiquidity - addLiquidity / 4,
                expectedLiquidityAfter: addLiquidity * 2 - addLiquidity / 4,
                expectedTreasury: 0
            }),
            WithdrawTestCase({
                name: "Normal token with 1% withdraw fee",
                // POOL SETUP
                asset: Tokens.DAI,
                tokenFee: 0,
                initialLiquidity: addLiquidity,
                // 1 dDAI = 2 DAI
                dieselRate: 2 * RAY,
                // 50% of available liquidity is borrowed
                utilisation: 50_00,
                withdrawFee: 1_00,
                // PARAMS
                sharesToMint: addLiquidity / 2,
                assetsToWithdraw: addLiquidity / 4,
                // EXPECTED VALUES:
                //
                // Depends on dieselRate
                expectedSharesBurnt: addLiquidity / 8 * 100 / 99,
                expectedAvailableLiquidity: addLiquidity / 2 + addLiquidity - addLiquidity / 4 * 100 / 99,
                expectedLiquidityAfter: addLiquidity * 2 - addLiquidity / 4 * 100 / 99,
                expectedTreasury: addLiquidity / 4 * 1 / 99
            }),
            WithdrawTestCase({
                name: "Fee token with 0 withdraw fee",
                /// SETUP
                asset: Tokens.USDT,
                // transfer fee: 60%, so 40% will be transfer to account
                tokenFee: 60_00,
                initialLiquidity: addLiquidity,
                // 1 dUSDT = 2 USDT
                dieselRate: 2 * RAY,
                // 50% of available liquidity is borrowed
                utilisation: 50_00,
                withdrawFee: 0,
                // PARAMS
                sharesToMint: addLiquidity / 2,
                assetsToWithdraw: addLiquidity / 4,
                // EXPECTED VALUES:
                //
                // Depends on dieselRate
                expectedSharesBurnt: addLiquidity / 8 * 100 / 40,
                expectedAvailableLiquidity: addLiquidity / 2 + addLiquidity - addLiquidity / 4 * 100 / 40,
                expectedLiquidityAfter: addLiquidity * 2 - addLiquidity / 4 * 100 / 40,
                expectedTreasury: 0
            }),
            WithdrawTestCase({
                name: "Fee token with 1% withdraw fee",
                /// SETUP
                asset: Tokens.USDT,
                // transfer fee: 60%, so 40% will be transfer to account
                tokenFee: 60_00,
                initialLiquidity: addLiquidity,
                // 1 dUSDT = 2 USDT
                dieselRate: 2 * RAY,
                // 50% of available liquidity is borrowed
                utilisation: 50_00,
                withdrawFee: 1_00,
                // PARAMS
                sharesToMint: addLiquidity / 2,
                assetsToWithdraw: addLiquidity / 4,
                // EXPECTED VALUES:
                //
                // addLiquidity /2 * 1/2 (rate) * 1 / (100%-1%) / feeToken
                expectedSharesBurnt: addLiquidity / 8 * 100 / 99 * 100 / 40 + 1,
                // availableLiquidityBefore: addLiqudity /2 (cause 50% utilisation)
                expectedAvailableLiquidity: addLiquidity / 2 + addLiquidity - addLiquidity / 4 * 100 / 40 * 100 / 99 - 1,
                expectedLiquidityAfter: addLiquidity * 2 - addLiquidity / 4 * 100 / 40 * 100 / 99 - 1,
                expectedTreasury: addLiquidity / 4 * 1 / 99 + 1
            })
        ];

        for (uint256 i; i < cases.length; ++i) {
            WithdrawTestCase memory testCase = cases[i];
            /// @dev a represents allowance, 0 means required amount +1, 1 means inlimited allowance
            for (uint256 approveCase; approveCase < 2; ++approveCase) {
                _setUpTestCase(
                    testCase.asset,
                    testCase.tokenFee,
                    testCase.utilisation,
                    testCase.initialLiquidity,
                    testCase.dieselRate,
                    testCase.withdrawFee,
                    false
                );

                evm.prank(USER);
                pool.mint(testCase.sharesToMint, FRIEND);

                evm.prank(FRIEND);
                pool.approve(USER, approveCase == 0 ? testCase.expectedSharesBurnt + 1 : type(uint256).max);

                evm.expectEmit(true, true, false, true);
                emit Transfer(FRIEND, address(0), testCase.expectedSharesBurnt);

                evm.expectEmit(true, true, false, true);
                emit Withdraw(USER, FRIEND2, FRIEND, testCase.assetsToWithdraw, testCase.expectedSharesBurnt);

                evm.prank(USER);
                uint256 shares = pool.withdraw(testCase.assetsToWithdraw, FRIEND2, FRIEND);

                expectBalance(
                    underlying,
                    FRIEND2,
                    testCase.assetsToWithdraw,
                    _testCaseErr(testCase.name, "Incorrect assets on FRIEND2 account")
                );

                expectBalance(
                    underlying,
                    pool.treasury(),
                    testCase.expectedTreasury,
                    _testCaseErr(testCase.name, "Incorrect DAO fee")
                );
                assertEq(
                    shares, testCase.expectedSharesBurnt, _testCaseErr(testCase.name, "Incorrect shares return value")
                );

                expectBalance(
                    address(pool),
                    FRIEND,
                    testCase.sharesToMint - testCase.expectedSharesBurnt,
                    _testCaseErr(testCase.name, "Incorrect FRIEND balance")
                );

                assertEq(
                    pool.expectedLiquidity(),
                    testCase.expectedLiquidityAfter,
                    _testCaseErr(testCase.name, "Incorrect expected liquidity")
                );
                assertEq(
                    pool.availableLiquidity(),
                    testCase.expectedAvailableLiquidity,
                    _testCaseErr(testCase.name, "Incorrect available liquidity")
                );

                assertEq(
                    pool.allowance(FRIEND, USER),
                    approveCase == 0 ? 1 : type(uint256).max,
                    _testCaseErr(testCase.name, "Incorrect allowance after operation")
                );

                assertEq(
                    pool.borrowRate(),
                    irm.calcBorrowRate(pool.expectedLiquidity(), pool.availableLiquidity(), false),
                    _testCaseErr(testCase.name, "Borrow rate wasn't update correcty")
                );
            }
        }
    }

    //
    // REDEEM
    //
    struct RedeemTestCase {
        string name;
        /// SETUP
        Tokens asset;
        uint256 tokenFee;
        uint256 initialLiquidity;
        uint256 dieselRate;
        uint16 utilisation;
        uint16 withdrawFee;
        /// PARAMS
        uint256 sharesToMint;
        uint256 sharesToRedeem;
        /// EXPECTED VALUES
        uint256 expectedAssetsDelivered;
        uint256 expectedAvailableLiquidity;
        uint256 expectedLiquidityAfter;
        uint256 expectedTreasury;
    }

    // [P4-9]: deposit and mint if assets more than limit
    function test_P4_09_redeem_works_as_expected() public {
        RedeemTestCase[4] memory cases = [
            RedeemTestCase({
                name: "Normal token with 0 withdraw fee",
                // POOL SETUP
                asset: Tokens.DAI,
                tokenFee: 0,
                initialLiquidity: addLiquidity,
                // 1 dDAI = 2 DAI
                dieselRate: 2 * RAY,
                // 50% of available liquidity is borrowed
                utilisation: 50_00,
                withdrawFee: 0,
                // PARAMS
                sharesToMint: addLiquidity / 2,
                sharesToRedeem: addLiquidity / 4,
                // EXPECTED VALUES:
                //
                // Depends on dieselRate
                expectedAssetsDelivered: addLiquidity / 2,
                // availableLiquidityBefore: addLiqudity /2 (cause 50% utilisation)
                expectedAvailableLiquidity: addLiquidity / 2 + addLiquidity - addLiquidity / 2,
                expectedLiquidityAfter: addLiquidity * 2 - addLiquidity / 2,
                expectedTreasury: 0
            }),
            RedeemTestCase({
                name: "Normal token with 1% withdraw fee",
                // POOL SETUP
                asset: Tokens.DAI,
                tokenFee: 0,
                initialLiquidity: addLiquidity,
                // 1 dDAI = 2 DAI
                dieselRate: 2 * RAY,
                // 50% of available liquidity is borrowed
                utilisation: 50_00,
                withdrawFee: 1_00,
                // PARAMS
                sharesToMint: addLiquidity / 2,
                sharesToRedeem: addLiquidity / 4,
                // EXPECTED VALUES:
                //
                // Depends on dieselRate
                expectedAssetsDelivered: addLiquidity / 2 * 99 / 100,
                expectedAvailableLiquidity: addLiquidity / 2 + addLiquidity - addLiquidity / 2,
                expectedLiquidityAfter: addLiquidity * 2 - addLiquidity / 2,
                expectedTreasury: addLiquidity / 2 * 1 / 100
            }),
            RedeemTestCase({
                name: "Fee token with 0 withdraw fee",
                /// SETUP
                asset: Tokens.USDT,
                // transfer fee: 60%, so 40% will be transfer to account
                tokenFee: 60_00,
                initialLiquidity: addLiquidity,
                // 1 dUSDT = 2 USDT
                dieselRate: 2 * RAY,
                // 50% of available liquidity is borrowed
                utilisation: 50_00,
                withdrawFee: 0,
                // PARAMS
                sharesToMint: addLiquidity / 2,
                sharesToRedeem: addLiquidity / 4,
                // EXPECTED VALUES:
                //
                // Depends on dieselRate
                expectedAssetsDelivered: addLiquidity / 2 * 40 / 100,
                expectedAvailableLiquidity: addLiquidity / 2 + addLiquidity - addLiquidity / 2,
                expectedLiquidityAfter: addLiquidity * 2 - addLiquidity / 2,
                expectedTreasury: 0
            }),
            RedeemTestCase({
                name: "Fee token with 1% withdraw fee",
                /// SETUP
                asset: Tokens.USDT,
                // transfer fee: 60%, so 40% will be transfer to account
                tokenFee: 60_00,
                initialLiquidity: addLiquidity,
                // 1 dUSDT = 2 USDT
                dieselRate: 2 * RAY,
                // 50% of available liquidity is borrowed
                utilisation: 50_00,
                withdrawFee: 1_00,
                // PARAMS
                sharesToMint: addLiquidity / 2,
                sharesToRedeem: addLiquidity / 4,
                // EXPECTED VALUES:
                //
                // addLiquidity /2 * 1/2 (rate) * 1 / (100%-1%) / feeToken
                expectedAssetsDelivered: addLiquidity / 2 * 99 / 100 * 40 / 100,
                // availableLiquidityBefore: addLiqudity /2 (cause 50% utilisation)
                expectedAvailableLiquidity: addLiquidity / 2 + addLiquidity - addLiquidity / 2,
                expectedLiquidityAfter: addLiquidity * 2 - addLiquidity / 2,
                expectedTreasury: addLiquidity / 2 * 40 / 100 * 1 / 100
            })
        ];
        /// @dev a represents allowance, 0 means required amount +1, 1 means inlimited allowance

        for (uint256 i; i < cases.length; ++i) {
            RedeemTestCase memory testCase = cases[i];
            for (uint256 approveCase; approveCase < 2; ++approveCase) {
                bool feeToken = i == 1;

                _setUpTestCase(
                    testCase.asset,
                    testCase.tokenFee,
                    testCase.utilisation,
                    testCase.initialLiquidity,
                    testCase.dieselRate,
                    testCase.withdrawFee,
                    false
                );

                evm.prank(USER);
                pool.mint(testCase.sharesToMint, FRIEND);

                evm.prank(FRIEND);
                pool.approve(USER, approveCase == 0 ? testCase.sharesToRedeem + 1 : type(uint256).max);

                evm.expectEmit(true, true, false, true);
                emit Transfer(FRIEND, address(0), testCase.sharesToRedeem);

                evm.expectEmit(true, true, false, true);
                emit Withdraw(USER, FRIEND2, FRIEND, testCase.expectedAssetsDelivered, testCase.sharesToRedeem);

                evm.prank(USER);
                uint256 assets = pool.redeem(testCase.sharesToRedeem, FRIEND2, FRIEND);

                expectBalance(
                    underlying,
                    FRIEND2,
                    testCase.expectedAssetsDelivered,
                    _testCaseErr(testCase.name, "Incorrect assets on FRIEND2 account ")
                );

                expectBalance(
                    underlying,
                    pool.treasury(),
                    testCase.expectedTreasury,
                    _testCaseErr(testCase.name, "Incorrect treasury fee")
                );
                assertEq(
                    assets,
                    testCase.expectedAssetsDelivered,
                    _testCaseErr(testCase.name, "Incorrect assets return value")
                );
                expectBalance(
                    address(pool),
                    FRIEND,
                    testCase.sharesToMint - testCase.sharesToRedeem,
                    _testCaseErr(testCase.name, "Incorrect FRIEND balance")
                );

                assertEq(
                    pool.expectedLiquidity(),
                    testCase.expectedLiquidityAfter,
                    _testCaseErr(testCase.name, "Incorrect expected liquidity")
                );
                assertEq(
                    pool.availableLiquidity(),
                    testCase.expectedAvailableLiquidity,
                    _testCaseErr(testCase.name, "Incorrect available liquidity")
                );

                assertEq(
                    pool.allowance(FRIEND, USER),
                    approveCase == 0 ? 1 : type(uint256).max,
                    _testCaseErr(testCase.name, "Incorrect allowance after operation")
                );

                assertEq(
                    pool.borrowRate(),
                    irm.calcBorrowRate(pool.expectedLiquidity(), pool.availableLiquidity(), false),
                    _testCaseErr(testCase.name, "Borrow rate wasn't update correcty")
                );
            }
        }
    }

    // [P4-10]: burn works as expected
    function test_P4_10_burn_works_as_expected() public {
        _setUpTestCase(Tokens.DAI, 0, 50_00, addLiquidity, 2 * RAY, 0, false);

        evm.prank(USER);
        pool.mint(addLiquidity, USER);

        expectBalance(address(pool), USER, addLiquidity, "SETUP: Incorrect USER balance");

        /// Initial lp provided 1/2 AL + 1AL from USER
        assertEq(pool.totalSupply(), addLiquidity * 3 / 2, "SETUP: Incorrect total supply");

        uint256 borrowRate = pool.borrowRate();
        uint256 dieselRate = pool.convertToAssets(RAY);
        uint256 availableLiquidity = pool.availableLiquidity();
        uint256 expectedLiquidity = pool.expectedLiquidity();

        evm.prank(USER);
        pool.burn(addLiquidity / 4);

        expectBalance(address(pool), USER, addLiquidity * 3 / 4, "Incorrect USER balance");

        assertEq(pool.borrowRate(), borrowRate, "Incorrect borrow rate");
        /// Before burn totalSupply was 150% * AL, after 125% * LP
        assertEq(pool.convertToAssets(RAY), dieselRate * 150 / 125, "Incorrect diesel rate");
        assertEq(pool.availableLiquidity(), availableLiquidity, "Incorrect available liquidity");
        assertEq(pool.expectedLiquidity(), expectedLiquidity, "Incorrect expected liquidity");
    }

    ///
    /// LEND CREDIT ACCOUNT
    // [P4-11]: lendCreditAccount works as expected
    function test_P4_11_lendCreditAccount_works_as_expected() public {
        _setUpTestCase(Tokens.DAI, 0, 0, addLiquidity, 2 * RAY, 0, false);

        address creditAccount = DUMB_ADDRESS;
        uint256 borrowAmount = addLiquidity / 5;

        expectBalance(pool.asset(), creditAccount, 0, "SETUP: incorrect CA balance");
        assertEq(pool.borrowRate(), irm.R_base_RAY(), "SETUP: incorrect borrowRate");
        assertEq(pool.totalBorrowed(), 0, "SETUP: incorrect totalBorrowed");
        assertEq(pool.creditManagerBorrowed(address(cmMock)), 0, "SETUP: incorrect CM limit");

        uint256 availableLiquidityBefore = pool.availableLiquidity();
        uint256 expectedLiquidityBefore = pool.expectedLiquidity();

        evm.expectEmit(true, true, false, true);
        emit Transfer(address(pool), creditAccount, borrowAmount);

        evm.expectEmit(true, true, false, true);
        emit Borrow(address(cmMock), creditAccount, borrowAmount);

        cmMock.lendCreditAccount(borrowAmount, creditAccount);

        assertEq(pool.availableLiquidity(), availableLiquidityBefore - borrowAmount, "Incorrect available liquidity");
        assertEq(pool.expectedLiquidity(), expectedLiquidityBefore, "Incorrect expected liquidity");
        assertEq(pool.totalBorrowed(), borrowAmount, "Incorrect borrowAmount");

        assertEq(
            pool.borrowRate(),
            irm.calcBorrowRate(pool.expectedLiquidity(), pool.availableLiquidity(), false),
            "Borrow rate wasn't update correcty"
        );

        assertEq(pool.creditManagerBorrowed(address(cmMock)), borrowAmount, "Incorrect CM limit");
    }

    // [P4-12]: lendCreditAccount reverts if it breaches limits
    function test_P4_12_lendCreditAccount_reverts_if_breach_limits() public {
        address creditAccount = DUMB_ADDRESS;

        _setUpTestCase(Tokens.DAI, 0, 0, addLiquidity, 2 * RAY, 0, false);

        evm.expectRevert(IPool4626Exceptions.CreditManagerCantBorrowException.selector);
        cmMock.lendCreditAccount(0, creditAccount);

        evm.startPrank(CONFIGURATOR);
        pool.setCreditManagerLimit(address(cmMock), type(uint128).max);
        pool.setTotalBorrowedLimit(addLiquidity);
        evm.stopPrank();

        evm.expectRevert(IPool4626Exceptions.CreditManagerCantBorrowException.selector);
        cmMock.lendCreditAccount(addLiquidity + 1, creditAccount);

        evm.startPrank(CONFIGURATOR);
        pool.setCreditManagerLimit(address(cmMock), addLiquidity);
        pool.setTotalBorrowedLimit(type(uint128).max);
        evm.stopPrank();

        evm.expectRevert(IPool4626Exceptions.CreditManagerCantBorrowException.selector);
        cmMock.lendCreditAccount(addLiquidity + 1, creditAccount);
    }

    //
    // REPAY
    //

    // [P4-13]: repayCreditAccount reverts for incorrect credit managers
    function test_P4_13_repayCreditAccount_reverts_for_incorrect_credit_managers() public {
        _setUpTestCase(Tokens.DAI, 0, 0, addLiquidity, 2 * RAY, 0, false);

        /// Case for unknown CM
        evm.expectRevert(IPool4626Exceptions.CreditManagerOnlyException.selector);
        evm.prank(USER);
        pool.repayCreditAccount(1, 0, 0);

        /// Case for CM with zero debt
        assertEq(pool.creditManagerBorrowed(address(cmMock)), 0, "SETUP: Incorrect CM limit");

        evm.expectRevert(IPool4626Exceptions.CreditManagerOnlyException.selector);
        cmMock.repayCreditAccount(1, 0, 0);
    }

    struct RepayTestCase {
        string name;
        /// SETUP
        Tokens asset;
        uint256 tokenFee;
        uint256 initialLiquidity;
        uint256 dieselRate;
        uint256 sharesInTreasury;
        uint256 borrowBefore;
        /// PARAMS
        uint256 borrowAmount;
        uint256 profit;
        uint256 loss;
        /// EXPECTED VALUES
        uint256 expectedTotalSupply;
        uint256 expectedAvailableLiquidity;
        uint256 expectedLiquidityAfter;
        uint256 expectedTreasury;
        uint256 uncoveredLoss;
    }

    // [P4-14]: repayCreditAccount works as expected
    function test_P4_14_repayCreditAccount_works_as_expected() public {
        address creditAccount = DUMB_ADDRESS;
        RepayTestCase[5] memory cases = [
            RepayTestCase({
                name: "profit: 0, loss: 0",
                // POOL SETUP
                asset: Tokens.DAI,
                tokenFee: 0,
                initialLiquidity: 2 * addLiquidity,
                // 1 dDAI = 2 DAI
                dieselRate: 2 * RAY,
                // No borrowing on start
                borrowBefore: addLiquidity,
                sharesInTreasury: addLiquidity / 4,
                // PARAMS
                borrowAmount: addLiquidity / 2,
                profit: 0,
                loss: 0,
                // EXPECTED VALUES:
                //
                // Depends on dieselRate
                expectedTotalSupply: addLiquidity,
                expectedAvailableLiquidity: 2 * addLiquidity - addLiquidity + addLiquidity / 2,
                expectedLiquidityAfter: 2 * addLiquidity,
                expectedTreasury: 0,
                uncoveredLoss: 0
            }),
            RepayTestCase({
                name: "profit: 10%, loss: 0",
                // POOL SETUP
                asset: Tokens.DAI,
                tokenFee: 0,
                initialLiquidity: 2 * addLiquidity,
                // 1 dDAI = 2 DAI
                dieselRate: 2 * RAY,
                // No borrowing on start
                borrowBefore: addLiquidity,
                sharesInTreasury: addLiquidity / 4,
                // PARAMS
                borrowAmount: addLiquidity / 2,
                profit: addLiquidity * 1 / 10,
                loss: 0,
                // EXPECTED VALUES:
                //
                // addLiqudity + new minted diesel tokens for 10% with rate 2:1
                expectedTotalSupply: addLiquidity + addLiquidity * 1 / 10 / 2,
                expectedAvailableLiquidity: 2 * addLiquidity - addLiquidity + addLiquidity / 2 + addLiquidity * 1 / 10,
                // added profit here
                expectedLiquidityAfter: 2 * addLiquidity + addLiquidity * 1 / 10,
                expectedTreasury: 0,
                uncoveredLoss: 0
            }),
            RepayTestCase({
                name: "profit: 0, loss: 10% (covered)",
                // POOL SETUP
                asset: Tokens.DAI,
                tokenFee: 0,
                initialLiquidity: 2 * addLiquidity,
                // 1 dDAI = 2 DAI
                dieselRate: 2 * RAY,
                // No borrowing on start
                borrowBefore: addLiquidity,
                sharesInTreasury: addLiquidity / 4,
                // PARAMS
                borrowAmount: addLiquidity / 2,
                profit: 0,
                loss: addLiquidity * 1 / 10,
                // EXPECTED VALUES:
                //
                // with covered loss, the system should burn DAO shares based on current rate
                expectedTotalSupply: addLiquidity - addLiquidity * 1 / 10 / 2,
                expectedAvailableLiquidity: 2 * addLiquidity - addLiquidity + addLiquidity / 2 - addLiquidity * 1 / 10,
                expectedLiquidityAfter: 2 * addLiquidity - addLiquidity * 1 / 10,
                expectedTreasury: 0,
                uncoveredLoss: 0
            }),
            RepayTestCase({
                name: "profit: 0, loss: 10% (uncovered)",
                // POOL SETUP
                asset: Tokens.DAI,
                tokenFee: 0,
                initialLiquidity: 2 * addLiquidity,
                // 1 dDAI = 2 DAI
                dieselRate: 2 * RAY,
                // No borrowing on start
                borrowBefore: addLiquidity,
                sharesInTreasury: 0,
                // PARAMS
                borrowAmount: addLiquidity / 2,
                profit: 0,
                loss: addLiquidity * 1 / 10,
                // EXPECTED VALUES:
                //
                // Depends on dieselRate
                expectedTotalSupply: addLiquidity,
                expectedAvailableLiquidity: 2 * addLiquidity - addLiquidity + addLiquidity / 2 - addLiquidity * 1 / 10,
                expectedLiquidityAfter: 2 * addLiquidity - addLiquidity * 1 / 10,
                expectedTreasury: 0,
                uncoveredLoss: addLiquidity * 1 / 10
            }),
            RepayTestCase({
                name: "profit: 0, loss: 20% (partially covered)",
                // POOL SETUP
                asset: Tokens.DAI,
                tokenFee: 0,
                initialLiquidity: 2 * addLiquidity,
                // 1 dDAI = 2 DAI
                dieselRate: 2 * RAY,
                // No borrowing on start
                borrowBefore: addLiquidity,
                sharesInTreasury: addLiquidity * 1 / 10 / 2,
                // PARAMS
                borrowAmount: addLiquidity / 2,
                profit: 0,
                loss: addLiquidity * 2 / 10,
                // EXPECTED VALUES:
                //
                // Depends on dieselRate
                expectedTotalSupply: addLiquidity - addLiquidity * 1 / 10 / 2,
                expectedAvailableLiquidity: 2 * addLiquidity - addLiquidity + addLiquidity / 2 - addLiquidity * 2 / 10,
                expectedLiquidityAfter: 2 * addLiquidity - addLiquidity * 2 / 10,
                expectedTreasury: 0,
                uncoveredLoss: addLiquidity * 1 / 10
            })
        ];
        for (uint256 i; i < cases.length; ++i) {
            RepayTestCase memory testCase = cases[i];

            _setUpTestCase(
                testCase.asset,
                testCase.tokenFee,
                // sets utilisation to 0
                0,
                testCase.initialLiquidity,
                testCase.dieselRate,
                // sets withdrawFee to 0
                0,
                false
            );

            address treasury = pool.treasury();

            evm.prank(INITIAL_LP);
            pool.transfer(treasury, testCase.sharesInTreasury);

            cmMock.lendCreditAccount(testCase.borrowBefore, creditAccount);

            assertEq(pool.totalBorrowed(), testCase.borrowBefore, "SETUP: incorrect totalBorrowed");
            assertEq(pool.creditManagerBorrowed(address(cmMock)), testCase.borrowBefore, "SETUP: Incorrect CM limit");

            evm.startPrank(creditAccount);
            IERC20(pool.asset()).transfer(address(pool), testCase.borrowAmount + testCase.profit - testCase.loss);
            evm.stopPrank();

            if (testCase.uncoveredLoss > 0) {
                evm.expectEmit(true, false, false, true);
                emit UncoveredLoss(address(cmMock), testCase.uncoveredLoss);
            }

            evm.expectEmit(true, true, false, true);
            emit Repay(address(cmMock), testCase.borrowAmount, testCase.profit, testCase.loss);

            uint256 dieselRate = pool.convertToAssets(RAY);

            cmMock.repayCreditAccount(testCase.borrowAmount, testCase.profit, testCase.loss);

            if (testCase.uncoveredLoss == 0) {
                assertEq(dieselRate, pool.convertToAssets(RAY), "Unexpceted change in borrow rate");
            }

            assertEq(
                pool.totalSupply(), testCase.expectedTotalSupply, _testCaseErr(testCase.name, "Incorrect total supply")
            );

            assertEq(
                pool.totalBorrowed(),
                testCase.borrowBefore - testCase.borrowAmount,
                _testCaseErr(testCase.name, "incorrect totalBorrowed")
            );

            assertEq(
                pool.creditManagerBorrowed(address(cmMock)),
                testCase.borrowBefore - testCase.borrowAmount,
                "SETUP: Incorrect CM limit"
            );

            expectBalance(
                underlying,
                pool.treasury(),
                testCase.expectedTreasury,
                _testCaseErr(testCase.name, "Incorrect treasury fee")
            );

            assertEq(
                pool.expectedLiquidity(),
                testCase.expectedLiquidityAfter,
                _testCaseErr(testCase.name, "Incorrect expected liquidity")
            );
            assertEq(
                pool.availableLiquidity(),
                testCase.expectedAvailableLiquidity,
                _testCaseErr(testCase.name, "Incorrect available liquidity")
            );
        }
    }

    ///
    ///  CALC LINEAR CUMULATIVE
    ///

    // [P4-15]: calcLinearCumulative_RAY computes correctly
    function test_P4_15_calcLinearCumulative_RAY_correct() public {
        _setUpTestCase(Tokens.DAI, 0, 50_00, addLiquidity, 2 * RAY, 0, false);

        uint256 timeWarp = 180 days;

        evm.warp(block.timestamp + timeWarp);

        uint256 borrowRate = pool.borrowRate();

        uint256 expectedLinearRate = RAY + (borrowRate * timeWarp) / 365 days;

        assertEq(pool.calcLinearCumulative_RAY(), expectedLinearRate, "Index value was not updated correctly");
    }

    // [P4-16]: updateBorrowRate correctly updates parameters
    function test_P4_16_updateBorrowRate_correct() public {
        _setUpTestCase(Tokens.DAI, 0, 50_00, addLiquidity, 2 * RAY, 0, false);

        uint256 borrowRate = pool.borrowRate();
        uint256 timeWarp = 365 days;

        evm.warp(block.timestamp + timeWarp);

        uint256 expectedInterest = ((addLiquidity / 2) * borrowRate) / RAY;
        uint256 expectedLiquidity = addLiquidity + expectedInterest;

        uint256 expectedBorrowRate = psts.linearIRModel().calcBorrowRate(expectedLiquidity, addLiquidity / 2);

        _updateBorrowrate();

        assertEq(pool.expectedLiquidity(), expectedLiquidity, "Expected liquidity was not updated correctly");

        assertEq(uint256(pool.timestampLU()), block.timestamp, "Timestamp was not updated correctly");

        assertEq(pool.borrowRate(), expectedBorrowRate, "Borrow rate was not updated correctly");

        assertEq(pool.calcLinearCumulative_RAY(), pool.cumulativeIndexLU_RAY(), "Index value was not updated correctly");
    }

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
    //         pool.borrowRate(),
    //         "Borrow rate does not match"
    //     );
    // }

    // // [P4-28]: expectedLiquidity() computes correctly
    // function test_PX_28_expectedLiquidity_correct() public {
    //     _connectAndSetLimit();

    //     evm.prank(USER);
    //     pool.deposit(addLiquidity, USER);

    //     address ca = cmMock.getCreditAccountOrRevert(DUMB_ADDRESS);

    //     cmMock.lendCreditAccount(addLiquidity / 2, ca);

    //     uint256 borrowRate = pool.borrowRate();
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
