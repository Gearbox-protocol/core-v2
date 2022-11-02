// SPDX-License-Identifier: UNLICENSED
// Gearbox Protocol. Generalized leverage for DeFi protocols
// (c) Gearbox Holdings, 2022
pragma solidity ^0.8.10;

import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { IWETH } from "../../interfaces/external/IWETH.sol";

import { CreditFacade } from "../../credit/CreditFacade.sol";

import { CreditAccount } from "../../credit/CreditAccount.sol";
import { AccountFactory } from "../../core/AccountFactory.sol";

import { ICreditFacade, ICreditFacadeExtended } from "../../interfaces/ICreditFacade.sol";
import { ICreditManagerV2, ICreditManagerV2Events, ClosureAction } from "../../interfaces/ICreditManagerV2.sol";
import { ICreditFacadeEvents, ICreditFacadeExceptions } from "../../interfaces/ICreditFacade.sol";
import { IDegenNFT, IDegenNFTExceptions } from "../../interfaces/IDegenNFT.sol";

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

// SUITES
import { TokensTestSuite } from "../suites/TokensTestSuite.sol";
import { Tokens } from "../config/Tokens.sol";
import { CreditFacadeTestSuite } from "../suites/CreditFacadeTestSuite.sol";
import { CreditConfig } from "../config/CreditConfig.sol";

uint256 constant WETH_TEST_AMOUNT = 5 * WAD;
uint16 constant REFERRAL_CODE = 23;

/// @title CreditFacadeTest
/// @notice Designed for unit test purposes only
contract CreditFacadeTest is
    DSTest,
    BalanceHelper,
    CreditFacadeTestHelper,
    ICreditManagerV2Events,
    ICreditFacadeEvents,
    ICreditFacadeExceptions
{
    using CreditFacadeCalls for CreditFacadeMulticaller;
    AccountFactory accountFactory;

    TargetContractMock targetMock;
    AdapterMock adapterMock;

    function setUp() public {
        tokenTestSuite = new TokensTestSuite();
        tokenTestSuite.topUpWETH{ value: 100 * WAD }();

        CreditConfig creditConfig = new CreditConfig(
            tokenTestSuite,
            Tokens.DAI
        );

        cft = new CreditFacadeTestSuite(creditConfig);

        underlying = tokenTestSuite.addressOf(Tokens.DAI);
        creditManager = cft.creditManager();
        creditFacade = cft.creditFacade();
        creditConfigurator = cft.creditConfigurator();

        accountFactory = cft.af();

        targetMock = new TargetContractMock();
        adapterMock = new AdapterMock(
            address(creditManager),
            address(targetMock)
        );

        evm.label(address(adapterMock), "AdapterMock");
        evm.label(address(targetMock), "TargetContractMock");
    }

    ///
    ///
    ///  HELPERS
    ///
    ///

    function _prepareForWETHTest() internal {
        _prepareForWETHTest(USER);
    }

    function _prepareForWETHTest(address tester) internal {
        address weth = tokenTestSuite.addressOf(Tokens.WETH);

        evm.startPrank(tester);
        if (tester.balance > 0) {
            IWETH(weth).deposit{ value: tester.balance }();
        }

        IERC20(weth).transfer(
            address(this),
            tokenTestSuite.balanceOf(Tokens.WETH, tester)
        );

        evm.stopPrank();
        expectBalance(Tokens.WETH, tester, 0);

        evm.deal(tester, WETH_TEST_AMOUNT);
    }

    function _checkForWETHTest() internal {
        _checkForWETHTest(USER);
    }

    function _checkForWETHTest(address tester) internal {
        expectBalance(Tokens.WETH, tester, WETH_TEST_AMOUNT);

        expectEthBalance(tester, 0);
    }

    function _prepareMockCall() internal returns (bytes memory callData) {
        evm.prank(CONFIGURATOR);
        creditConfigurator.allowContract(
            address(targetMock),
            address(adapterMock)
        );

        callData = abi.encodeWithSignature("hello(string)", "world");
    }

    ///
    ///
    ///  TESTS
    ///
    ///

    /// @dev [FA-1]: constructor reverts for zero address
    function test_FA_01_constructor_reverts_for_zero_address() public {
        evm.expectRevert(ZeroAddressException.selector);
        new CreditFacade(address(0), address(0), false);
    }

    /// @dev [FA-1A]: constructor sets correct values
    function test_FA_01A_constructor_sets_correct_values() public {
        assertEq(
            address(creditFacade.creditManager()),
            address(creditManager),
            "Incorrect creditManager"
        );
        assertEq(
            creditFacade.underlying(),
            underlying,
            "Incorrect underlying token"
        );

        assertEq(
            creditFacade.wethAddress(),
            creditManager.wethAddress(),
            "Incorrect wethAddress token"
        );

        assertEq(creditFacade.degenNFT(), address(0), "Incorrect degenNFT");

        assertTrue(
            creditFacade.whitelisted() == false,
            "Incorrect whitelisted"
        );

        cft.testFacadeWithDegenNFT();
        creditFacade = cft.creditFacade();

        assertEq(
            creditFacade.degenNFT(),
            address(cft.degenNFT()),
            "Incorrect degenNFT"
        );

        assertTrue(creditFacade.whitelisted() == true, "Incorrect whitelisted");
    }

    //
    // ALL FUNCTIONS REVERTS IF USER HAS NO ACCOUNT
    //

    /// @dev [FA-2]: functions reverts if borrower has no account
    function test_FA_02_functions_reverts_if_borrower_has_no_account() public {
        bytes4 NO_CREDIT_ACCOUNT_EXCEPTION = ICreditManagerV2Exceptions
            .HasNoOpenedAccountException
            .selector;

        evm.expectRevert(NO_CREDIT_ACCOUNT_EXCEPTION);
        evm.prank(USER);
        creditFacade.closeCreditAccount(FRIEND, 0, false, multicallBuilder());

        evm.expectRevert(NO_CREDIT_ACCOUNT_EXCEPTION);
        evm.prank(USER);
        creditFacade.closeCreditAccount(
            FRIEND,
            0,
            false,
            multicallBuilder(
                MultiCall({
                    target: address(creditFacade),
                    callData: abi.encodeWithSelector(
                        ICreditFacade.addCollateral.selector,
                        USER,
                        underlying,
                        DAI_ACCOUNT_AMOUNT / 4
                    )
                })
            )
        );

        evm.expectRevert(NO_CREDIT_ACCOUNT_EXCEPTION);
        evm.prank(USER);
        creditFacade.liquidateCreditAccount(
            USER,
            DUMB_ADDRESS,
            0,
            false,
            multicallBuilder()
        );

        evm.expectRevert(NO_CREDIT_ACCOUNT_EXCEPTION);
        evm.prank(USER);
        creditFacade.increaseDebt(1);

        evm.expectRevert(NO_CREDIT_ACCOUNT_EXCEPTION);
        creditFacade.addCollateral(USER, underlying, 1);

        evm.expectRevert(NO_CREDIT_ACCOUNT_EXCEPTION);
        evm.prank(USER);
        creditFacade.multicall(multicallBuilder());

        evm.prank(CONFIGURATOR);
        creditConfigurator.allowContract(
            address(targetMock),
            address(adapterMock)
        );

        evm.expectRevert(NO_CREDIT_ACCOUNT_EXCEPTION);
        evm.prank(USER);
        creditFacade.approve(address(targetMock), underlying, 1);

        evm.expectRevert(NO_CREDIT_ACCOUNT_EXCEPTION);
        evm.prank(USER);
        creditFacade.transferAccountOwnership(FRIEND);

        evm.expectRevert(NO_CREDIT_ACCOUNT_EXCEPTION);
        evm.prank(USER);
        creditFacade.enableToken(underlying);
    }

    //
    // ETH => WETH TESTS
    //

    /// @dev [FA-3A]: openCreditAccount correctly wraps ETH
    function test_FA_03A_openCreditAccount_correctly_wraps_ETH() public {
        /// - openCreditAccount
        _prepareForWETHTest();

        evm.prank(USER);
        creditFacade.openCreditAccount{ value: WETH_TEST_AMOUNT }(
            DAI_ACCOUNT_AMOUNT / 2,
            USER,
            200,
            0
        );
        _checkForWETHTest();
    }

    function test_FA_03B_openCreditAccountMulticall_correctly_wraps_ETH()
        public
    {
        /// - openCreditAccountMulticall

        _prepareForWETHTest();

        evm.prank(USER);
        creditFacade.openCreditAccountMulticall{ value: WETH_TEST_AMOUNT }(
            WAD,
            USER,
            multicallBuilder(
                MultiCall({
                    target: address(creditFacade),
                    callData: abi.encodeWithSelector(
                        ICreditFacade.addCollateral.selector,
                        USER,
                        underlying,
                        DAI_ACCOUNT_AMOUNT / 4
                    )
                })
            ),
            0
        );
        _checkForWETHTest();
    }

    function test_FA_03C_closeCreditAccount_correctly_wraps_ETH() public {
        _openTestCreditAccount();

        evm.roll(block.number + 1);

        _prepareForWETHTest();
        evm.prank(USER);
        creditFacade.closeCreditAccount{ value: WETH_TEST_AMOUNT }(
            USER,
            0,
            false,
            multicallBuilder()
        );
        _checkForWETHTest();
    }

    function test_FA_03D_liquidate_correctly_wraps_ETH() public {
        (address creditAccount, ) = _openTestCreditAccount();

        evm.roll(block.number + 1);

        tokenTestSuite.burn(
            Tokens.DAI,
            creditAccount,
            tokenTestSuite.balanceOf(Tokens.DAI, creditAccount)
        );

        _prepareForWETHTest(LIQUIDATOR);

        tokenTestSuite.approve(Tokens.DAI, LIQUIDATOR, address(creditManager));

        tokenTestSuite.mint(Tokens.DAI, LIQUIDATOR, DAI_ACCOUNT_AMOUNT);

        evm.prank(LIQUIDATOR);
        creditFacade.liquidateCreditAccount{ value: WETH_TEST_AMOUNT }(
            USER,
            LIQUIDATOR,
            0,
            false,
            multicallBuilder()
        );
        _checkForWETHTest(LIQUIDATOR);
    }

    function test_FA_03E_addCollateral_correctly_wraps_ETH() public {
        _openTestCreditAccount();

        // /// - addCollateral
        _prepareForWETHTest(USER);

        tokenTestSuite.mint(Tokens.DAI, USER, WAD);

        tokenTestSuite.approve(Tokens.DAI, USER, address(creditManager));

        evm.prank(USER);
        creditFacade.addCollateral{ value: WETH_TEST_AMOUNT }(
            USER,
            underlying,
            WAD
        );

        _checkForWETHTest(USER);
    }

    function test_FA_03F_multicall_correctly_wraps_ETH() public {
        _openTestCreditAccount();

        // MULTICALL
        _prepareForWETHTest();

        evm.prank(USER);
        creditFacade.multicall{ value: WETH_TEST_AMOUNT }(multicallBuilder());
        _checkForWETHTest();
    }

    //
    // OPEN CREDIT ACCOUNT
    //

    /// @dev [FA-4A]: openCreditAccount reverts for using addresses which is not allowed by transfer allowance
    function test_FA_04A_openCreditAccount_reverts_for_using_addresses_which_is_not_allowed_by_transfer_allowance()
        public
    {
        (uint256 minBorrowedAmount, ) = creditFacade.limits();

        evm.startPrank(USER);

        evm.expectRevert(AccountTransferNotAllowedException.selector);
        creditFacade.openCreditAccount(minBorrowedAmount, FRIEND, 100, 0);

        MultiCall[] memory calls;
        evm.expectRevert(AccountTransferNotAllowedException.selector);
        creditFacade.openCreditAccountMulticall(
            minBorrowedAmount,
            FRIEND,
            calls,
            0
        );

        evm.stopPrank();
    }

    /// @dev [FA-4B]: openCreditAccount reverts if user has no NFT for degen mode
    function test_FA_04B_openCreditAccount_reverts_for_non_whitelisted_account()
        public
    {
        cft.testFacadeWithDegenNFT();
        creditFacade = cft.creditFacade();

        (uint256 minBorrowedAmount, ) = creditFacade.limits();

        evm.expectRevert(NotAllowedInWhitelistedMode.selector);
        evm.prank(USER);
        creditFacade.openCreditAccount(minBorrowedAmount, FRIEND, 100, 0);

        evm.expectRevert(
            IDegenNFTExceptions.InsufficientBalanceException.selector
        );
        evm.prank(FRIEND);
        creditFacade.openCreditAccount(minBorrowedAmount, FRIEND, 100, 0);

        evm.expectRevert(NotAllowedInWhitelistedMode.selector);

        evm.prank(USER);
        creditFacade.openCreditAccountMulticall(
            minBorrowedAmount,
            FRIEND,
            multicallBuilder(),
            0
        );

        evm.expectRevert(
            IDegenNFTExceptions.InsufficientBalanceException.selector
        );

        evm.prank(FRIEND);
        creditFacade.openCreditAccountMulticall(
            minBorrowedAmount,
            FRIEND,
            multicallBuilder(),
            0
        );
    }

    /// @dev [FA-4C]: openCreditAccount opens account and burns token
    function test_FA_04C_openCreditAccount_burns_token_in_whitelisted_mode()
        public
    {
        cft.testFacadeWithDegenNFT();
        creditFacade = cft.creditFacade();

        IDegenNFT degenNFT = IDegenNFT(creditFacade.degenNFT());

        evm.prank(CONFIGURATOR);
        degenNFT.mint(USER, 2);

        expectBalance(address(degenNFT), USER, 2);

        _openTestCreditAccount();

        expectBalance(address(degenNFT), USER, 1);

        _closeTestCreditAccount();

        tokenTestSuite.mint(Tokens.DAI, USER, DAI_ACCOUNT_AMOUNT);

        evm.prank(USER);
        creditFacade.openCreditAccountMulticall(
            DAI_ACCOUNT_AMOUNT,
            USER,
            multicallBuilder(
                MultiCall({
                    target: address(creditFacade),
                    callData: abi.encodeWithSelector(
                        ICreditFacade.addCollateral.selector,
                        USER,
                        underlying,
                        DAI_ACCOUNT_AMOUNT
                    )
                })
            ),
            0
        );

        expectBalance(address(degenNFT), USER, 0);
    }

    /// @dev [FA-5]: openCreditAccount sets correct values
    function test_FA_05_openCreditAccount_sets_correct_values() public {
        uint16 LEVERAGE = 300; // x3

        address expectedCreditAccountAddress = accountFactory.head();

        evm.prank(FRIEND);
        creditFacade.approveAccountTransfer(USER, true);

        evm.expectCall(
            address(creditManager),
            abi.encodeWithSignature(
                "openCreditAccount(uint256,address)",
                (DAI_ACCOUNT_AMOUNT * LEVERAGE) / LEVERAGE_DECIMALS,
                FRIEND
            )
        );

        evm.expectEmit(true, true, false, true);
        emit OpenCreditAccount(
            FRIEND,
            expectedCreditAccountAddress,
            (DAI_ACCOUNT_AMOUNT * LEVERAGE) / LEVERAGE_DECIMALS,
            REFERRAL_CODE
        );

        evm.expectCall(
            address(creditManager),
            abi.encodeWithSignature(
                "addCollateral(address,address,address,uint256)",
                USER,
                expectedCreditAccountAddress,
                underlying,
                DAI_ACCOUNT_AMOUNT
            )
        );

        evm.expectEmit(true, true, false, true);
        emit AddCollateral(FRIEND, underlying, DAI_ACCOUNT_AMOUNT);

        evm.prank(USER);
        creditFacade.openCreditAccount(
            DAI_ACCOUNT_AMOUNT,
            FRIEND,
            LEVERAGE,
            REFERRAL_CODE
        );
    }

    /// @dev [FA-6]: openCreditAccount reverts for hf <1 cases
    function test_FA_06_openCreditAccount_reverts_for_hf_less_one(
        uint16 leverageFactor
    ) public {
        evm.assume(leverageFactor > 0);

        // such limits're needed for fuzz testing
        evm.prank(CONFIGURATOR);
        creditConfigurator.setLimitPerBlock(type(uint128).max);

        evm.prank(CONFIGURATOR);
        creditConfigurator.setLimits(1, type(uint96).max);

        tokenTestSuite.mint(
            Tokens.DAI,
            address(creditManager.poolService()),
            type(uint96).max
        );

        bool shouldRevert = ((uint256(leverageFactor) + 100) *
            DEFAULT_UNDERLYING_LT) /
            10000 <
            uint256(leverageFactor);

        if (shouldRevert) {
            evm.expectRevert(NotEnoughCollateralException.selector);
        }

        evm.prank(USER);
        creditFacade.openCreditAccount(
            DAI_ACCOUNT_AMOUNT,
            USER,
            leverageFactor,
            REFERRAL_CODE
        );

        if (!shouldRevert) {
            address creditAccount = creditManager.getCreditAccountOrRevert(
                USER
            );

            assertTrue(
                creditFacade.calcCreditAccountHealthFactor(creditAccount) >=
                    10000,
                "HF <1"
            );
        }
    }

    /// @dev [FA-7]: openCreditAccountMulticall and openCreditAccount reverts when debt increase is forbidden
    function test_FA_07_openCreditAccountMulticall_reverts_if_increase_debt_forbidden()
        public
    {
        (uint256 minBorrowedAmount, ) = creditFacade.limits();

        evm.prank(CONFIGURATOR);
        creditConfigurator.setIncreaseDebtForbidden(true);

        evm.expectRevert(IncreaseDebtForbiddenException.selector);
        MultiCall[] memory calls;

        evm.prank(USER);
        creditFacade.openCreditAccountMulticall(
            minBorrowedAmount,
            USER,
            calls,
            0
        );

        evm.expectRevert(IncreaseDebtForbiddenException.selector);
        evm.prank(USER);
        creditFacade.openCreditAccount(minBorrowedAmount, USER, 100, 0);
    }

    /// @dev [FA-8]: openCreditAccountMulticall runs operations in correct order
    function test_FA_08_openCreditAccountMulticall_runs_operations_in_correct_order()
        public
    {
        evm.prank(FRIEND);
        creditFacade.approveAccountTransfer(USER, true);

        // tokenTestSuite.mint(Tokens.DAI, USER, WAD);
        // tokenTestSuite.approve(Tokens.DAI, USER, address(creditManager));

        address expectedCreditAccountAddress = accountFactory.head();

        MultiCall[] memory calls = multicallBuilder(
            MultiCall({
                target: address(creditFacade),
                callData: abi.encodeWithSelector(
                    ICreditFacade.addCollateral.selector,
                    FRIEND,
                    underlying,
                    DAI_ACCOUNT_AMOUNT
                )
            }),
            MultiCall({
                target: address(creditFacade),
                callData: abi.encodeWithSelector(
                    ICreditFacade.increaseDebt.selector,
                    WAD
                )
            })
        );

        // EXPECTED STACK TRACE & EVENTS

        evm.expectCall(
            address(creditManager),
            abi.encodeWithSignature(
                "openCreditAccount(uint256,address)",
                DAI_ACCOUNT_AMOUNT,
                FRIEND
            )
        );

        evm.expectEmit(true, true, false, true);
        emit OpenCreditAccount(
            FRIEND,
            expectedCreditAccountAddress,
            DAI_ACCOUNT_AMOUNT,
            REFERRAL_CODE
        );

        evm.expectCall(
            address(creditManager),
            abi.encodeWithSignature(
                "transferAccountOwnership(address,address)",
                FRIEND,
                address(creditFacade)
            )
        );

        evm.expectEmit(true, false, false, false);
        emit MultiCallStarted(FRIEND);

        evm.expectCall(
            address(creditManager),
            abi.encodeWithSignature(
                "addCollateral(address,address,address,uint256)",
                USER,
                expectedCreditAccountAddress,
                underlying,
                DAI_ACCOUNT_AMOUNT
            )
        );

        evm.expectEmit(true, true, false, true);
        emit AddCollateral(FRIEND, underlying, DAI_ACCOUNT_AMOUNT);

        evm.expectCall(
            address(creditManager),
            abi.encodeWithSignature(
                "manageDebt(address,uint256,bool)",
                expectedCreditAccountAddress,
                WAD,
                true
            )
        );

        evm.expectEmit(true, false, false, true);
        emit IncreaseBorrowedAmount(FRIEND, WAD);

        evm.expectEmit(false, false, false, true);
        emit MultiCallFinished();

        evm.expectCall(
            address(creditManager),
            abi.encodeWithSignature(
                "transferAccountOwnership(address,address)",
                address(creditFacade),
                FRIEND
            )
        );

        evm.expectCall(
            address(creditManager),
            abi.encodeWithSignature(
                "fullCollateralCheck(address)",
                expectedCreditAccountAddress
            )
        );

        evm.prank(USER);
        creditFacade.openCreditAccountMulticall(
            DAI_ACCOUNT_AMOUNT,
            FRIEND,
            calls,
            REFERRAL_CODE
        );
    }

    /// @dev [FA-9]: openCreditAccountMulticall cant open credit account with hf <1;
    function test_FA_09_openCreditAccountMulticall_cant_open_credit_account_with_hf_less_one(
        uint256 amount,
        uint8 token1
    ) public {
        evm.assume(amount > 0 && amount < DAI_ACCOUNT_AMOUNT);
        evm.assume(
            token1 > 0 && token1 < creditManager.collateralTokensCount()
        );

        tokenTestSuite.mint(
            Tokens.DAI,
            address(creditManager.poolService()),
            type(uint96).max
        );

        evm.prank(CONFIGURATOR);
        creditConfigurator.setLimitPerBlock(type(uint96).max);

        evm.prank(CONFIGURATOR);
        creditConfigurator.setLimits(1, type(uint96).max);

        (address collateral, ) = creditManager.collateralTokens(token1);

        tokenTestSuite.mint(collateral, USER, type(uint96).max);

        tokenTestSuite.approve(collateral, USER, address(creditManager));

        MultiCall[] memory calls = multicallBuilder(
            MultiCall({
                target: address(creditFacade),
                callData: abi.encodeWithSelector(
                    ICreditFacade.addCollateral.selector,
                    USER,
                    collateral,
                    amount
                )
            })
        );

        uint256 lt = creditManager.liquidationThresholds(collateral);

        uint256 twvUSD = cft.priceOracle().convertToUSD(
            amount * lt,
            collateral
        );

        uint256 borrowedAmountUSD = cft.priceOracle().convertToUSD(
            DAI_ACCOUNT_AMOUNT * PERCENTAGE_FACTOR,
            underlying
        );

        bool shouldRevert = twvUSD <
            (borrowedAmountUSD * (PERCENTAGE_FACTOR - DEFAULT_UNDERLYING_LT)) /
                PERCENTAGE_FACTOR;

        if (shouldRevert) {
            evm.expectRevert(
                ICreditManagerV2Exceptions.NotEnoughCollateralException.selector
            );
        }

        evm.prank(USER);
        creditFacade.openCreditAccountMulticall(
            DAI_ACCOUNT_AMOUNT,
            USER,
            calls,
            REFERRAL_CODE
        );
    }

    /// @dev [FA-10]: no free flashloans during openCreditAccount
    function test_FA_10_no_free_flashloans_during_openCreditAccount() public {
        evm.expectRevert(
            IncreaseAndDecreaseForbiddenInOneCallException.selector
        );

        evm.prank(USER);

        creditFacade.openCreditAccountMulticall(
            DAI_ACCOUNT_AMOUNT,
            USER,
            multicallBuilder(
                MultiCall({
                    target: address(creditFacade),
                    callData: abi.encodeWithSelector(
                        ICreditFacade.decreaseDebt.selector,
                        812
                    )
                })
            ),
            REFERRAL_CODE
        );
    }

    /// @dev [FA-11A]: openCreditAccount reverts if met borrowed limit per block
    function test_FA_11A_openCreditAccount_reverts_if_met_borrowed_limit_per_block()
        public
    {
        (uint128 blockLimit, , ) = creditFacade.params();

        evm.expectRevert(BorrowedBlockLimitException.selector);

        evm.prank(USER);
        creditFacade.openCreditAccount(blockLimit + 1, USER, 100, 0);

        MultiCall[] memory calls;

        evm.expectRevert(BorrowedBlockLimitException.selector);

        evm.prank(USER);
        creditFacade.openCreditAccountMulticall(blockLimit + 1, USER, calls, 0);
    }

    /// @dev [FA-11B]: openCreditAccount reverts if amount < minAmount or amount > maxAmount
    function test_FA_11B_openCreditAccount_reverts_if_amount_less_minBorrowedAmount_or_bigger_than_maxBorrowedAmount()
        public
    {
        (uint128 minBorrowedAmount, uint128 maxBorrowedAmount) = creditFacade
            .limits();

        evm.expectRevert(BorrowAmountOutOfLimitsException.selector);
        evm.prank(USER);
        creditFacade.openCreditAccount(minBorrowedAmount - 1, USER, 100, 0);

        evm.expectRevert(BorrowAmountOutOfLimitsException.selector);
        evm.prank(USER);
        creditFacade.openCreditAccount(maxBorrowedAmount + 1, USER, 100, 0);
    }

    //
    // CLOSE CREDIT ACCOUNT
    //

    /// @dev [FA-12]: closeCreditAccount runs multicall operations in correct order
    function test_FA_12_closeCreditAccount_runs_operations_in_correct_order()
        public
    {
        (address creditAccount, ) = _openTestCreditAccount();

        bytes memory DUMB_CALLDATA = _prepareMockCall();

        MultiCall[] memory calls = multicallBuilder(
            MultiCall({ target: address(adapterMock), callData: DUMB_CALLDATA })
        );

        // TODO: add Mutlicall events here

        evm.expectCall(
            address(creditManager),
            abi.encodeWithSignature(
                "transferAccountOwnership(address,address)",
                USER,
                address(creditFacade)
            )
        );

        evm.expectEmit(true, false, false, false);
        emit MultiCallStarted(USER);

        evm.expectCall(
            address(creditManager),
            abi.encodeWithSignature(
                "executeOrder(address,address,bytes)",
                address(creditFacade),
                address(targetMock),
                DUMB_CALLDATA
            )
        );

        evm.expectEmit(true, true, false, true);
        emit ExecuteOrder(address(creditFacade), address(targetMock));

        evm.expectCall(
            creditAccount,
            abi.encodeWithSelector(
                CreditAccount.execute.selector,
                address(targetMock),
                DUMB_CALLDATA
            )
        );

        evm.expectCall(address(targetMock), DUMB_CALLDATA);

        evm.expectEmit(false, false, false, true);
        emit MultiCallFinished();

        evm.expectCall(
            address(creditManager),
            abi.encodeWithSignature(
                "transferAccountOwnership(address,address)",
                address(creditFacade),
                USER
            )
        );

        evm.expectCall(
            address(creditManager),
            abi.encodeWithSelector(
                ICreditManagerV2.closeCreditAccount.selector,
                USER,
                ClosureAction.CLOSE_ACCOUNT,
                0,
                USER,
                FRIEND,
                10,
                true
            )
        );

        evm.expectEmit(true, true, false, false);
        emit CloseCreditAccount(USER, FRIEND);

        // increase block number, cause it's forbidden to close ca in the same block
        evm.roll(block.number + 1);

        evm.prank(USER);
        creditFacade.closeCreditAccount(FRIEND, 10, true, calls);

        assertEq0(targetMock.callData(), DUMB_CALLDATA, "Incorrect calldata");
    }

    /// @dev [FA-13]: closeCreditAccount reverts on internal calls in multicall
    function test_FA_13_closeCreditAccount_reverts_on_internal_call_in_multicall_on_closure()
        public
    {
        bytes memory DUMB_CALLDATA = abi.encodeWithSignature(
            "hello(string)",
            "world"
        );

        _openTestCreditAccount();

        evm.roll(block.number + 1);

        evm.expectRevert(ForbiddenDuringClosureException.selector);

        // It's used dumb calldata, cause all calls to creditFacade are forbidden

        evm.prank(USER);
        creditFacade.closeCreditAccount(
            FRIEND,
            0,
            true,
            multicallBuilder(
                MultiCall({
                    target: address(creditFacade),
                    callData: DUMB_CALLDATA
                })
            )
        );
    }

    //
    // LIQUIDATE CREDIT ACCOUNT
    //

    /// @dev [FA-14]: liquidateCreditAccount reverts if hf > 1
    function test_FA_14_liquidateCreditAccount_reverts_if_hf_is_greater_than_1()
        public
    {
        _openTestCreditAccount();

        evm.expectRevert(CantLiquidateWithSuchHealthFactorException.selector);

        evm.prank(LIQUIDATOR);
        creditFacade.liquidateCreditAccount(
            USER,
            LIQUIDATOR,
            0,
            true,
            multicallBuilder()
        );
    }

    /// @dev [FA-15]: liquidateCreditAccount executes needed calls and emits events
    function test_FA_15_liquidateCreditAccount_executes_needed_calls_and_emits_events()
        public
    {
        (address creditAccount, ) = _openTestCreditAccount();

        bytes memory DUMB_CALLDATA = _prepareMockCall();

        _makeAccountsLiquitable();

        // EXPECTED STACK TRACE & EVENTS

        evm.expectCall(
            address(creditManager),
            abi.encodeWithSignature(
                "transferAccountOwnership(address,address)",
                USER,
                address(creditFacade)
            )
        );

        evm.expectEmit(true, false, false, false);
        emit MultiCallStarted(USER);

        evm.expectCall(
            address(creditManager),
            abi.encodeWithSignature(
                "executeOrder(address,address,bytes)",
                address(creditFacade),
                address(targetMock),
                DUMB_CALLDATA
            )
        );

        evm.expectEmit(true, true, false, false);
        emit ExecuteOrder(address(creditFacade), address(targetMock));

        evm.expectCall(
            creditAccount,
            abi.encodeWithSelector(
                CreditAccount.execute.selector,
                address(targetMock),
                DUMB_CALLDATA
            )
        );

        evm.expectCall(address(targetMock), DUMB_CALLDATA);

        evm.expectEmit(false, false, false, false);
        emit MultiCallFinished();

        evm.expectCall(
            address(creditManager),
            abi.encodeWithSignature(
                "transferAccountOwnership(address,address)",
                address(creditFacade),
                USER
            )
        );

        // Total value = 2 * DAI_ACCOUNT_AMOUNT, cause we have x2 leverage
        uint256 totalValue = 2 * DAI_ACCOUNT_AMOUNT;

        evm.expectCall(
            address(creditManager),
            abi.encodeWithSelector(
                ICreditManagerV2.closeCreditAccount.selector,
                USER,
                ClosureAction.LIQUIDATE_ACCOUNT,
                totalValue,
                LIQUIDATOR,
                FRIEND,
                10,
                true
            )
        );

        evm.expectEmit(true, true, true, true);
        emit LiquidateCreditAccount(USER, LIQUIDATOR, FRIEND, 0);

        evm.prank(LIQUIDATOR);
        creditFacade.liquidateCreditAccount(
            USER,
            FRIEND,
            10,
            true,
            multicallBuilder(
                MultiCall({
                    target: address(adapterMock),
                    callData: DUMB_CALLDATA
                })
            )
        );
    }

    function test_FA_16_liquidateCreditAccount_reverts_on_internal_call_in_multicall_on_closure()
        public
    {
        bytes memory DUMB_CALLDATA = abi.encodeWithSignature(
            "hello(string)",
            "world"
        );

        _openTestCreditAccount();

        _makeAccountsLiquitable();
        evm.expectRevert(ForbiddenDuringClosureException.selector);

        evm.prank(LIQUIDATOR);

        // It's used dumb calldata, cause all calls to creditFacade are forbidden
        creditFacade.liquidateCreditAccount(
            USER,
            FRIEND,
            10,
            true,
            multicallBuilder(
                MultiCall({
                    target: address(creditFacade),
                    callData: DUMB_CALLDATA
                })
            )
        );
    }

    // [FA-16A]: liquidateCreditAccount reverts when zero address is passed as to
    function test_FA_16A_liquidateCreditAccount_reverts_on_zero_to_address()
        public
    {
        bytes memory DUMB_CALLDATA = abi.encodeWithSignature(
            "hello(string)",
            "world"
        );

        _openTestCreditAccount();

        _makeAccountsLiquitable();
        evm.expectRevert(ZeroAddressException.selector);

        evm.prank(LIQUIDATOR);

        // It's used dumb calldata, cause all calls to creditFacade are forbidden
        creditFacade.liquidateCreditAccount(
            USER,
            address(0),
            10,
            true,
            multicallBuilder(
                MultiCall({
                    target: address(creditFacade),
                    callData: DUMB_CALLDATA
                })
            )
        );
    }

    //
    // INCREASE & DECREASE DEBT
    //

    /// @dev [FA-17]: increaseDebt executes function as expected
    function test_FA_17_increaseDebt_executes_actions_as_expected() public {
        (address creditAccount, ) = _openTestCreditAccount();

        evm.expectCall(
            address(creditManager),
            abi.encodeWithSelector(
                ICreditManagerV2.manageDebt.selector,
                creditAccount,
                512,
                true
            )
        );

        evm.expectCall(
            address(creditManager),
            abi.encodeWithSelector(
                ICreditManagerV2.fullCollateralCheck.selector,
                creditAccount
            )
        );

        evm.expectEmit(true, false, false, true);
        emit IncreaseBorrowedAmount(USER, 512);

        evm.prank(USER);
        creditFacade.increaseDebt(512);
    }

    /// @dev [FA-18A]: increaseDebt revets if more than block limit
    function test_FA_18A_increaseDebt_revets_if_more_than_block_limit() public {
        _openTestCreditAccount();

        (uint128 limit, , ) = creditFacade.params();

        evm.expectRevert(BorrowedBlockLimitException.selector);

        evm.prank(USER);
        creditFacade.increaseDebt(limit + 1);
    }

    /// @dev [FA-18B]: increaseDebt revets if more than maxBorrowedAmount
    function test_FA_18B_increaseDebt_revets_if_more_than_block_limit() public {
        _openTestCreditAccount();

        (, uint128 maxBorrowedAmount) = creditFacade.limits();

        uint256 amount = maxBorrowedAmount - DAI_ACCOUNT_AMOUNT + 1;

        tokenTestSuite.mint(Tokens.DAI, address(cft.poolMock()), amount);

        evm.expectRevert(BorrowAmountOutOfLimitsException.selector);

        evm.prank(USER);
        creditFacade.increaseDebt(amount);
    }

    /// @dev [FA-18C]: increaseDebt revets isIncreaseDebtForbidden is enabled
    function test_FA_18C_increaseDebt_revets_isIncreaseDebtForbidden_is_enabled()
        public
    {
        _openTestCreditAccount();

        evm.prank(CONFIGURATOR);
        creditConfigurator.setIncreaseDebtForbidden(true);

        evm.expectRevert(IncreaseDebtForbiddenException.selector);

        evm.prank(USER);
        creditFacade.increaseDebt(1);
    }

    /// @dev [FA-18D]: increaseDebt reverts if there is a forbidden token on account
    function test_FA_18D_increaseDebt_reverts_with_forbidden_tokens() public {
        _openTestCreditAccount();

        address link = tokenTestSuite.addressOf(Tokens.LINK);

        evm.prank(USER);
        creditFacade.enableToken(link);

        evm.prank(CONFIGURATOR);
        creditConfigurator.forbidToken(link);

        evm.expectRevert(ActionProhibitedWithForbiddenTokensException.selector);

        evm.prank(USER);
        creditFacade.increaseDebt(1);
    }

    /// @dev [FA-19]: decreaseDebt executes function as expected
    function test_FA_19_decreaseDebt_executes_actions_as_expected() public {
        (address creditAccount, ) = _openTestCreditAccount();

        evm.expectCall(
            address(creditManager),
            abi.encodeWithSelector(
                ICreditManagerV2.manageDebt.selector,
                creditAccount,
                512,
                false
            )
        );

        evm.expectCall(
            address(creditManager),
            abi.encodeWithSelector(
                ICreditManagerV2.fullCollateralCheck.selector,
                creditAccount
            )
        );

        evm.expectEmit(true, false, false, true);
        emit DecreaseBorrowedAmount(USER, 512);

        evm.prank(USER);
        creditFacade.decreaseDebt(512);
    }

    /// @dev [FA-20]:decreaseDebt revets if less than minBorrowedAmount
    function test_FA_20_decreaseDebt_revets_if_less_than_minBorrowedAmount()
        public
    {
        _openTestCreditAccount();

        (uint128 minBorrowedAmount, ) = creditFacade.limits();

        uint256 amount = DAI_ACCOUNT_AMOUNT - minBorrowedAmount + 1;

        tokenTestSuite.mint(Tokens.DAI, address(cft.poolMock()), amount);

        evm.expectRevert(BorrowAmountOutOfLimitsException.selector);

        evm.prank(USER);
        creditFacade.decreaseDebt(amount);
    }

    //
    // ADD COLLATERAL
    //

    /// @dev [FA-21]: addCollateral executes function as expected
    function test_FA_21_addCollateral_executes_actions_as_expected() public {
        (address creditAccount, ) = _openTestCreditAccount();

        evm.prank(USER);
        creditFacade.approveAccountTransfer(FRIEND, true);

        expectTokenIsEnabled(Tokens.USDC, false);

        address usdcToken = tokenTestSuite.addressOf(Tokens.USDC);

        tokenTestSuite.mint(Tokens.USDC, FRIEND, 512);
        tokenTestSuite.approve(Tokens.USDC, FRIEND, address(creditManager));

        evm.expectCall(
            address(creditManager),
            abi.encodeWithSelector(
                ICreditManagerV2.addCollateral.selector,
                FRIEND,
                creditAccount,
                usdcToken,
                512
            )
        );

        evm.expectEmit(true, true, false, true);
        emit AddCollateral(USER, usdcToken, 512);

        evm.prank(FRIEND);
        creditFacade.addCollateral(USER, usdcToken, 512);

        expectBalance(Tokens.USDC, creditAccount, 512);
        expectTokenIsEnabled(Tokens.USDC, true);
    }

    /// @dev [FA-21A]: addCollateral reverts when account transfer is not allowed
    function test_FA_21A_addCollateral_reverts_on_account_transfer_not_allowed()
        public
    {
        _openTestCreditAccount();

        evm.expectRevert(AccountTransferNotAllowedException.selector);
        evm.prank(FRIEND);
        creditFacade.addCollateral(USER, DUMB_ADDRESS, 512);
    }

    /// @dev [FA-21B]: addCollateral reverts in a multicall when account transfer is not allowed
    function test_FA_21B_addCollateral_reverts_on_account_transfer_not_allowed_multicall()
        public
    {
        _openTestCreditAccount();
        _openExtraTestCreditAccount();

        evm.expectRevert(AccountTransferNotAllowedException.selector);
        evm.prank(FRIEND);
        creditFacade.multicall(
            multicallBuilder(
                MultiCall({
                    target: address(creditFacade),
                    callData: abi.encodeWithSelector(
                        ICreditFacade.addCollateral.selector,
                        USER,
                        DUMB_ADDRESS,
                        USDC_EXCHANGE_AMOUNT
                    )
                })
            )
        );
    }

    /// @dev [FA-21C]: addCollateral calls checkAndOptimizeEnabledTokens
    function test_FA_21C_addCollateral_optimizes_enabled_tokens() public {
        (address creditAccount, ) = _openTestCreditAccount();

        evm.prank(USER);
        creditFacade.approveAccountTransfer(FRIEND, true);

        address usdcToken = tokenTestSuite.addressOf(Tokens.USDC);

        tokenTestSuite.mint(Tokens.USDC, FRIEND, 512);
        tokenTestSuite.approve(Tokens.USDC, FRIEND, address(creditManager));

        evm.expectCall(
            address(creditManager),
            abi.encodeWithSelector(
                ICreditManagerV2.checkAndOptimizeEnabledTokens.selector,
                creditAccount
            )
        );

        evm.prank(FRIEND);
        creditFacade.addCollateral(USER, usdcToken, 512);
    }

    //
    // MULTICALL
    //

    /// @dev [FA-22]: multicall reverts if calldata length is less than 4 bytes
    function test_FA_22_multicall_reverts_if_calldata_length_is_less_than_4_bytes()
        public
    {
        _openTestCreditAccount();

        evm.expectRevert(IncorrectCallDataException.selector);

        evm.prank(USER);
        creditFacade.multicall(
            multicallBuilder(
                MultiCall({ target: DUMB_ADDRESS, callData: bytes("123") })
            )
        );
    }

    /// @dev [FA-23]: multicall reverts for unknown methods
    function test_FA_23_multicall_reverts_for_unknown_methods() public {
        _openTestCreditAccount();

        bytes memory DUMB_CALLDATA = abi.encodeWithSignature(
            "hello(string)",
            "world"
        );

        evm.expectRevert(UnknownMethodException.selector);

        evm.prank(USER);
        creditFacade.multicall(
            multicallBuilder(
                MultiCall({
                    target: address(creditFacade),
                    callData: DUMB_CALLDATA
                })
            )
        );
    }

    /// @dev [FA-24]: multicall reverts for creditManager address
    function test_FA_24_multicall_reverts_for_creditManager_address() public {
        _openTestCreditAccount();

        bytes memory DUMB_CALLDATA = abi.encodeWithSignature(
            "hello(string)",
            "world"
        );

        evm.expectRevert(TargetContractNotAllowedException.selector);

        evm.prank(USER);
        creditFacade.multicall(
            multicallBuilder(
                MultiCall({
                    target: address(creditManager),
                    callData: DUMB_CALLDATA
                })
            )
        );
    }

    /// @dev [FA-25]: multicall reverts on non-adapter targets
    function test_FA_25_multicall_reverts_for_non_adapters() public {
        _openTestCreditAccount();

        bytes memory DUMB_CALLDATA = abi.encodeWithSignature(
            "hello(string)",
            "world"
        );
        evm.expectRevert(TargetContractNotAllowedException.selector);

        evm.prank(USER);
        creditFacade.multicall(
            multicallBuilder(
                MultiCall({ target: DUMB_ADDRESS, callData: DUMB_CALLDATA })
            )
        );
    }

    /// @dev [FA-26]: multicall addCollateral and oncreaseDebt works with creditFacade calls as expected
    function test_FA_26_multicall_addCollateral_and_increase_debt_works_with_creditFacade_calls_as_expected()
        public
    {
        (address creditAccount, ) = _openTestCreditAccount();

        address usdcToken = tokenTestSuite.addressOf(Tokens.USDC);
        tokenTestSuite.mint(Tokens.USDC, USER, USDC_EXCHANGE_AMOUNT);
        tokenTestSuite.approve(Tokens.USDC, USER, address(creditManager));

        evm.expectCall(
            address(creditManager),
            abi.encodeWithSelector(
                ICreditManagerV2.transferAccountOwnership.selector,
                USER,
                address(creditFacade)
            )
        );

        evm.expectEmit(true, true, false, true);
        emit MultiCallStarted(USER);

        evm.expectCall(
            address(creditManager),
            abi.encodeWithSelector(
                ICreditManagerV2.addCollateral.selector,
                USER,
                creditAccount,
                usdcToken,
                USDC_EXCHANGE_AMOUNT
            )
        );

        evm.expectEmit(true, true, false, true);
        emit AddCollateral(USER, usdcToken, USDC_EXCHANGE_AMOUNT);

        evm.expectCall(
            address(creditManager),
            abi.encodeWithSelector(
                ICreditManagerV2.manageDebt.selector,
                creditAccount,
                256,
                true
            )
        );

        evm.expectEmit(true, false, false, true);
        emit IncreaseBorrowedAmount(USER, 256);

        evm.expectEmit(false, false, false, true);
        emit MultiCallFinished();

        evm.expectCall(
            address(creditManager),
            abi.encodeWithSelector(
                ICreditManagerV2.transferAccountOwnership.selector,
                address(creditFacade),
                USER
            )
        );

        evm.expectCall(
            address(creditManager),
            abi.encodeWithSelector(
                ICreditManagerV2.fullCollateralCheck.selector,
                creditAccount
            )
        );

        evm.prank(USER);
        creditFacade.multicall(
            multicallBuilder(
                MultiCall({
                    target: address(creditFacade),
                    callData: abi.encodeWithSelector(
                        ICreditFacade.addCollateral.selector,
                        USER,
                        usdcToken,
                        USDC_EXCHANGE_AMOUNT
                    )
                }),
                MultiCall({
                    target: address(creditFacade),
                    callData: abi.encodeWithSelector(
                        ICreditFacade.increaseDebt.selector,
                        256
                    )
                })
            )
        );
    }

    /// @dev [FA-27]: multicall addCollateral and decreaseDebt works with creditFacade calls as expected
    function test_FA_27_multicall_addCollateral_and_decreaseDebt_works_with_creditFacade_calls_as_expected()
        public
    {
        (address creditAccount, ) = _openTestCreditAccount();

        address usdcToken = tokenTestSuite.addressOf(Tokens.USDC);
        tokenTestSuite.mint(Tokens.USDC, USER, USDC_EXCHANGE_AMOUNT);
        tokenTestSuite.approve(Tokens.USDC, USER, address(creditManager));

        evm.expectCall(
            address(creditManager),
            abi.encodeWithSelector(
                ICreditManagerV2.transferAccountOwnership.selector,
                USER,
                address(creditFacade)
            )
        );

        evm.expectEmit(true, true, false, true);
        emit MultiCallStarted(USER);

        evm.expectCall(
            address(creditManager),
            abi.encodeWithSelector(
                ICreditManagerV2.addCollateral.selector,
                USER,
                creditAccount,
                usdcToken,
                USDC_EXCHANGE_AMOUNT
            )
        );

        evm.expectEmit(true, true, false, true);
        emit AddCollateral(USER, usdcToken, USDC_EXCHANGE_AMOUNT);

        evm.expectCall(
            address(creditManager),
            abi.encodeWithSelector(
                ICreditManagerV2.manageDebt.selector,
                creditAccount,
                256,
                false
            )
        );

        evm.expectEmit(true, false, false, true);
        emit DecreaseBorrowedAmount(USER, 256);

        evm.expectEmit(false, false, false, true);
        emit MultiCallFinished();

        evm.expectCall(
            address(creditManager),
            abi.encodeWithSelector(
                ICreditManagerV2.transferAccountOwnership.selector,
                address(creditFacade),
                USER
            )
        );

        evm.expectCall(
            address(creditManager),
            abi.encodeWithSelector(
                ICreditManagerV2.fullCollateralCheck.selector,
                creditAccount
            )
        );

        evm.prank(USER);
        creditFacade.multicall(
            multicallBuilder(
                MultiCall({
                    target: address(creditFacade),
                    callData: abi.encodeWithSelector(
                        ICreditFacade.addCollateral.selector,
                        USER,
                        usdcToken,
                        USDC_EXCHANGE_AMOUNT
                    )
                }),
                MultiCall({
                    target: address(creditFacade),
                    callData: abi.encodeWithSelector(
                        ICreditFacade.decreaseDebt.selector,
                        256
                    )
                })
            )
        );
    }

    /// @dev [FA-28]: multicall reverts for decrease opeartion after increase one
    function test_FA_28_multicall_reverts_for_decrease_opeartion_after_increase_one()
        public
    {
        _openTestCreditAccount();

        evm.expectRevert(
            IncreaseAndDecreaseForbiddenInOneCallException.selector
        );

        evm.prank(USER);
        creditFacade.multicall(
            multicallBuilder(
                MultiCall({
                    target: address(creditFacade),
                    callData: abi.encodeWithSelector(
                        ICreditFacade.increaseDebt.selector,
                        256
                    )
                }),
                MultiCall({
                    target: address(creditFacade),
                    callData: abi.encodeWithSelector(
                        ICreditFacade.decreaseDebt.selector,
                        256
                    )
                })
            )
        );
    }

    /// @dev [FA-29]: multicall works with adapters calls as expected
    function test_FA_29_multicall_works_with_adapters_calls_as_expected()
        public
    {
        (address creditAccount, ) = _openTestCreditAccount();

        bytes memory DUMB_CALLDATA = _prepareMockCall();

        evm.expectCall(
            address(creditManager),
            abi.encodeWithSelector(
                ICreditManagerV2.transferAccountOwnership.selector,
                USER,
                address(creditFacade)
            )
        );

        evm.expectEmit(true, true, false, true);
        emit MultiCallStarted(USER);

        evm.expectCall(
            address(creditManager),
            abi.encodeWithSelector(
                ICreditManagerV2.executeOrder.selector,
                address(creditFacade),
                address(targetMock),
                DUMB_CALLDATA
            )
        );

        evm.expectEmit(true, true, false, true);
        emit ExecuteOrder(address(creditFacade), address(targetMock));

        evm.expectCall(
            creditAccount,
            abi.encodeWithSignature(
                "execute(address,bytes)",
                address(targetMock),
                DUMB_CALLDATA
            )
        );

        evm.expectCall(address(targetMock), DUMB_CALLDATA);

        evm.expectEmit(false, false, false, true);
        emit MultiCallFinished();

        evm.expectCall(
            address(creditManager),
            abi.encodeWithSelector(
                ICreditManagerV2.transferAccountOwnership.selector,
                address(creditFacade),
                USER
            )
        );

        evm.expectCall(
            address(creditManager),
            abi.encodeWithSelector(
                ICreditManagerV2.fullCollateralCheck.selector,
                creditAccount
            )
        );

        evm.prank(USER);
        creditFacade.multicall(
            multicallBuilder(
                MultiCall({
                    target: address(adapterMock),
                    callData: DUMB_CALLDATA
                })
            )
        );
    }

    /// @dev [FA-30]: approve reverts for not allowed token and not allowed token
    function test_FA_30_approve_reverts_for_not_allowed_token_and_not_allower_contract()
        public
    {
        address daiToken = tokenTestSuite.addressOf(Tokens.DAI);
        address lunaToken = tokenTestSuite.addressOf(Tokens.LUNA);

        evm.expectRevert(TargetContractNotAllowedException.selector);
        evm.prank(USER);
        creditFacade.approve(DUMB_ADDRESS, daiToken, 1);

        evm.prank(CONFIGURATOR);
        creditConfigurator.allowContract(
            address(targetMock),
            address(adapterMock)
        );

        evm.expectRevert(
            ICreditManagerV2Exceptions.HasNoOpenedAccountException.selector
        );
        evm.prank(FRIEND);
        creditFacade.approve(address(targetMock), daiToken, 1);

        _openTestCreditAccount();

        evm.expectRevert(TokenNotAllowedException.selector);
        evm.prank(USER);
        creditFacade.approve(address(targetMock), lunaToken, 1);
    }

    /// @dev [FA-31]: approve works as expected
    function test_FA_31_approve_works_as_expected() public {
        (address creditAccount, ) = _openTestCreditAccount();

        evm.prank(CONFIGURATOR);
        creditConfigurator.allowContract(
            address(targetMock),
            address(adapterMock)
        );

        address usdcToken = tokenTestSuite.addressOf(Tokens.USDC);

        evm.expectCall(
            address(creditManager),
            abi.encodeWithSelector(
                ICreditManagerV2.approveCreditAccount.selector,
                USER,
                address(targetMock),
                usdcToken,
                USDC_EXCHANGE_AMOUNT
            )
        );

        evm.prank(USER);
        creditFacade.approve(
            address(targetMock),
            usdcToken,
            USDC_EXCHANGE_AMOUNT
        );

        expectAllowance(
            Tokens.USDC,
            creditAccount,
            address(targetMock),
            USDC_EXCHANGE_AMOUNT
        );
    }

    //
    // TRANSFER ACCOUNT OWNERSHIP
    //

    /// @dev [FA-32]: transferAccountOwnership reverts if "to" user doesn't provide allowance
    function test_FA_32_transferAccountOwnership_reverts_if_whitelisted_enabled()
        public
    {
        cft.testFacadeWithDegenNFT();
        creditFacade = cft.creditFacade();

        evm.expectRevert(NotAllowedInWhitelistedMode.selector);
        evm.prank(USER);
        creditFacade.transferAccountOwnership(DUMB_ADDRESS);
    }

    /// @dev [FA-33]: transferAccountOwnership reverts if "to" user doesn't provide allowance
    function test_FA_33_transferAccountOwnership_reverts_if_to_user_doesnt_provide_allowance()
        public
    {
        _openTestCreditAccount();
        evm.expectRevert(AccountTransferNotAllowedException.selector);

        evm.prank(USER);
        creditFacade.transferAccountOwnership(DUMB_ADDRESS);
    }

    /// @dev [FA-34]: transferAccountOwnership reverts if hf less 1
    function test_FA_34_transferAccountOwnership_reverts_if_hf_less_1() public {
        _openTestCreditAccount();

        evm.prank(FRIEND);
        creditFacade.approveAccountTransfer(USER, true);

        _makeAccountsLiquitable();

        evm.expectRevert(CantTransferLiquidatableAccountException.selector);

        evm.prank(USER);
        creditFacade.transferAccountOwnership(FRIEND);
    }

    /// @dev [FA-35]: transferAccountOwnership transfers account if it's allowed
    function test_FA_35_transferAccountOwnership_transfers_account_if_its_allowed()
        public
    {
        (address creditAccount, ) = _openTestCreditAccount();

        evm.prank(FRIEND);
        creditFacade.approveAccountTransfer(USER, true);

        evm.expectCall(
            address(creditManager),
            abi.encodeWithSelector(
                ICreditManagerV2.transferAccountOwnership.selector,
                USER,
                FRIEND
            )
        );

        evm.expectEmit(true, true, false, false);
        emit TransferAccount(USER, FRIEND);

        evm.prank(USER);
        creditFacade.transferAccountOwnership(FRIEND);

        assertEq(
            creditManager.getCreditAccountOrRevert(FRIEND),
            creditAccount,
            "Credit account was not properly transferred"
        );
    }

    /// @dev [FA-36]: checkAndUpdateBorrowedBlockLimit doesn't change block limit if maxBorrowedAmountPerBlock = type(uint128).max
    function test_FA_36_checkAndUpdateBorrowedBlockLimit_doesnt_change_block_limit_if_set_to_max()
        public
    {
        evm.prank(CONFIGURATOR);
        creditConfigurator.setLimitPerBlock(type(uint128).max);

        (uint64 blockLastUpdate, uint128 borrowedInBlock) = creditFacade
            .getTotalBorrowedInBlock();
        assertEq(blockLastUpdate, 0, "Incorrect currentBlockLimit");
        assertEq(borrowedInBlock, 0, "Incorrect currentBlockLimit");

        _openTestCreditAccount();

        (blockLastUpdate, borrowedInBlock) = creditFacade
            .getTotalBorrowedInBlock();
        assertEq(blockLastUpdate, 0, "Incorrect currentBlockLimit");
        assertEq(borrowedInBlock, 0, "Incorrect currentBlockLimit");
    }

    /// @dev [FA-37]: checkAndUpdateBorrowedBlockLimit doesn't change block limit if maxBorrowedAmountPerBlock = type(uint128).max
    function test_FA_37_checkAndUpdateBorrowedBlockLimit_updates_block_limit_properly()
        public
    {
        (uint64 blockLastUpdate, uint128 borrowedInBlock) = creditFacade
            .getTotalBorrowedInBlock();

        assertEq(blockLastUpdate, 0, "Incorrect blockLastUpdate");
        assertEq(borrowedInBlock, 0, "Incorrect borrowedInBlock");

        _openTestCreditAccount();

        (blockLastUpdate, borrowedInBlock) = creditFacade
            .getTotalBorrowedInBlock();

        assertEq(blockLastUpdate, block.number, "blockLastUpdate");
        assertEq(
            borrowedInBlock,
            DAI_ACCOUNT_AMOUNT,
            "Incorrect borrowedInBlock"
        );

        evm.prank(USER);
        creditFacade.increaseDebt(DAI_EXCHANGE_AMOUNT);

        (blockLastUpdate, borrowedInBlock) = creditFacade
            .getTotalBorrowedInBlock();

        assertEq(blockLastUpdate, block.number, "blockLastUpdate");
        assertEq(
            borrowedInBlock,
            DAI_ACCOUNT_AMOUNT + DAI_EXCHANGE_AMOUNT,
            "Incorrect borrowedInBlock"
        );

        // switch to new block
        evm.roll(block.number + 1);

        evm.prank(USER);
        creditFacade.increaseDebt(DAI_EXCHANGE_AMOUNT);

        (blockLastUpdate, borrowedInBlock) = creditFacade
            .getTotalBorrowedInBlock();

        assertEq(blockLastUpdate, block.number, "blockLastUpdate");
        assertEq(
            borrowedInBlock,
            DAI_EXCHANGE_AMOUNT,
            "Incorrect borrowedInBlock"
        );
    }

    //
    // APPROVE ACCOUNT TRANSFER
    //

    /// @dev [FA-38]: approveAccountTransfer changes transfersAllowed
    function test_FA_38_transferAccountOwnership_with_allowed_to_transfers_account()
        public
    {
        assertTrue(
            creditFacade.transfersAllowed(USER, FRIEND) == false,
            "Transfer is unexpectedly allowed "
        );

        evm.expectEmit(true, true, false, true);
        emit TransferAccountAllowed(USER, FRIEND, true);

        evm.prank(FRIEND);
        creditFacade.approveAccountTransfer(USER, true);

        assertTrue(
            creditFacade.transfersAllowed(USER, FRIEND) == true,
            "Transfer is unexpectedly not allowed "
        );

        evm.expectEmit(true, true, false, true);
        emit TransferAccountAllowed(USER, FRIEND, false);

        evm.prank(FRIEND);
        creditFacade.approveAccountTransfer(USER, false);
        assertTrue(
            creditFacade.transfersAllowed(USER, FRIEND) == false,
            "Transfer is unexpectedly allowed "
        );
    }

    //
    // ENABLE TOKEN
    //

    /// @dev [FA-39]: enable token works as expected
    function test_FA_39_enable_token_is_correct() public {
        (address creditAccount, ) = _openTestCreditAccount();

        address usdcToken = tokenTestSuite.addressOf(Tokens.USDC);
        expectTokenIsEnabled(Tokens.USDC, false);

        tokenTestSuite.mint(Tokens.USDC, creditAccount, 100);

        evm.prank(USER);
        creditFacade.enableToken(usdcToken);

        expectTokenIsEnabled(Tokens.USDC, true);
    }

    /// @dev [FA-39A]: enable token optimizes enabled tokens
    function test_FA_39A_enable_token_is_correct() public {
        (address creditAccount, ) = _openTestCreditAccount();

        address usdcToken = tokenTestSuite.addressOf(Tokens.USDC);
        expectTokenIsEnabled(Tokens.USDC, false);

        tokenTestSuite.mint(Tokens.USDC, creditAccount, 100);

        evm.expectCall(
            address(creditManager),
            abi.encodeWithSelector(
                ICreditManagerV2.checkAndOptimizeEnabledTokens.selector,
                creditAccount
            )
        );

        evm.prank(USER);
        creditFacade.enableToken(usdcToken);
    }

    //
    // GETTERS
    //

    /// @dev [FA-40]: isTokenAllowed works as expected
    function test_FA_40_isTokenAllowed_works_as_expected() public {
        address lunaToken = tokenTestSuite.addressOf(Tokens.LUNA);

        assertTrue(
            creditFacade.isTokenAllowed(lunaToken) == false,
            "stETH should be not allowed"
        );

        evm.prank(CONFIGURATOR);
        creditConfigurator.addCollateralToken(lunaToken, 9300);

        assertTrue(
            creditFacade.isTokenAllowed(lunaToken) == true,
            "stETH should be allowed"
        );

        evm.prank(CONFIGURATOR);
        creditConfigurator.forbidToken(lunaToken);

        assertTrue(
            creditFacade.isTokenAllowed(lunaToken) == false,
            "stETH should be not allowed"
        );
    }

    /// @dev [FA-41]: calcTotalValue computes correctly
    function test_FA_41_calcTotalValue_computes_correctly() public {
        (address creditAccount, ) = _openTestCreditAccount();

        // AFTER OPENING CREDIT ACCOUNT
        uint256 expectedTV = DAI_ACCOUNT_AMOUNT * 2;
        uint256 expectedTWV = (DAI_ACCOUNT_AMOUNT * 2 * DEFAULT_UNDERLYING_LT) /
            PERCENTAGE_FACTOR;

        (uint256 tv, uint256 tvw) = creditFacade.calcTotalValue(creditAccount);

        assertEq(tv, expectedTV, "Incorrect total value for 1 asset");

        assertEq(
            tvw,
            expectedTWV,
            "Incorrect Threshold weighthed value for 1 asset"
        );

        // ADDS USDC BUT NOT ENABLES IT
        address usdcToken = tokenTestSuite.addressOf(Tokens.USDC);
        tokenTestSuite.mint(Tokens.USDC, creditAccount, 10 * 10**6);

        (tv, tvw) = creditFacade.calcTotalValue(creditAccount);

        // tv and tvw shoul be the same until we deliberately enable USDC token
        assertEq(tv, expectedTV, "Incorrect total value for 1 asset");

        assertEq(
            tvw,
            expectedTWV,
            "Incorrect Threshold weighthed value for 1 asset"
        );

        // ENABLES USDC

        evm.prank(USER);
        creditFacade.enableToken(usdcToken);

        expectedTV += 10 * WAD;
        expectedTWV += (10 * WAD * 9000) / PERCENTAGE_FACTOR;

        (tv, tvw) = creditFacade.calcTotalValue(creditAccount);

        assertEq(tv, expectedTV, "Incorrect total value for 2 asset");

        assertEq(
            tvw,
            expectedTWV,
            "Incorrect Threshold weighthed value for 2 asset"
        );

        // 3 ASSET TEST: 10 DAI + 10 USDC + 0.01 WETH (3200 $/ETH)
        addCollateral(Tokens.WETH, WAD / 100);

        expectedTV += (WAD / 100) * DAI_WETH_RATE;
        expectedTWV += ((WAD / 100) * DAI_WETH_RATE * 8300) / PERCENTAGE_FACTOR;

        (tv, tvw) = creditFacade.calcTotalValue(creditAccount);

        assertEq(tv, expectedTV, "Incorrect total value for 3 asset");

        assertEq(
            tvw,
            expectedTWV,
            "Incorrect Threshold weighthed value for 3 asset"
        );
    }

    /// @dev [FA-42]: calcCreditAccountHealthFactor computes correctly
    function test_FA_42_calcCreditAccountHealthFactor_computes_correctly()
        public
    {
        (address creditAccount, ) = _openTestCreditAccount();

        // AFTER OPENING CREDIT ACCOUNT

        uint256 expectedTV = DAI_ACCOUNT_AMOUNT * 2;
        uint256 expectedTWV = (DAI_ACCOUNT_AMOUNT * 2 * DEFAULT_UNDERLYING_LT) /
            PERCENTAGE_FACTOR;

        uint256 expectedHF = (expectedTWV * PERCENTAGE_FACTOR) /
            DAI_ACCOUNT_AMOUNT;

        assertEq(
            creditFacade.calcCreditAccountHealthFactor(creditAccount),
            expectedHF,
            "Incorrect health factor"
        );

        // ADDING USDC AS COLLATERAL

        addCollateral(Tokens.USDC, 10 * 10**6);

        expectedTV += 10 * WAD;
        expectedTWV += (10 * WAD * 9000) / PERCENTAGE_FACTOR;

        expectedHF = (expectedTWV * PERCENTAGE_FACTOR) / DAI_ACCOUNT_AMOUNT;

        assertEq(
            creditFacade.calcCreditAccountHealthFactor(creditAccount),
            expectedHF,
            "Incorrect health factor"
        );

        // 3 ASSET: 10 DAI + 10 USDC + 0.01 WETH (3200 $/ETH)
        addCollateral(Tokens.WETH, WAD / 100);

        expectedTV += (WAD / 100) * DAI_WETH_RATE;
        expectedTWV += ((WAD / 100) * DAI_WETH_RATE * 8300) / PERCENTAGE_FACTOR;

        expectedHF = (expectedTWV * PERCENTAGE_FACTOR) / DAI_ACCOUNT_AMOUNT;

        assertEq(
            creditFacade.calcCreditAccountHealthFactor(creditAccount),
            expectedHF,
            "Incorrect health factor"
        );
    }

    /// @dev [FA-43]: hasOpenedCreditAccount returns true if account is open and false otherwise
    function test_FA_43_hasOpenedCreditAccount_returns_correct_values() public {
        assertTrue(
            creditFacade.hasOpenedCreditAccount(USER) == false,
            "Returned true for user who has no open account"
        );

        _openTestCreditAccount();

        assertTrue(
            creditFacade.hasOpenedCreditAccount(USER) == true,
            "Returned false for user with open account"
        );
    }

    /// CHECK IS ACCOUNT LIQUIDATABLE

    /// @dev [FA-44]: setContractToAdapter reverts if called non-configurator
    function test_FA_44_config_functions_revert_if_called_non_configurator()
        public
    {
        evm.expectRevert(CreditConfiguratorOnlyException.selector);
        evm.prank(USER);
        creditFacade.setIncreaseDebtForbidden(false);

        evm.expectRevert(CreditConfiguratorOnlyException.selector);
        evm.prank(USER);
        creditFacade.setLimitPerBlock(100);
    }

    /// CHECK SLIPPAGE PROTECTION

    /// [TODO]: add new test

    /// @dev [FA-45]: rrevertIfGetLessThan during multicalls works correctly
    function test_FA_45_revertIfGetLessThan_works_correctly() public {
        _openTestCreditAccount();

        uint256 expectedDAI = 1000;
        uint256 expectedLINK = 2000;

        address tokenLINK = tokenTestSuite.addressOf(Tokens.LINK);

        Balance[] memory expectedBalances = new Balance[](2);
        expectedBalances[0] = Balance({
            token: underlying,
            balance: expectedDAI
        });

        expectedBalances[1] = Balance({
            token: tokenLINK,
            balance: expectedLINK
        });

        // TOKEN PREPARATION
        tokenTestSuite.mint(Tokens.DAI, USER, expectedDAI * 3);
        tokenTestSuite.mint(Tokens.LINK, USER, expectedLINK * 3);

        tokenTestSuite.approve(Tokens.DAI, USER, address(creditManager));
        tokenTestSuite.approve(Tokens.LINK, USER, address(creditManager));

        evm.prank(USER);
        creditFacade.multicall(
            multicallBuilder(
                CreditFacadeMulticaller(address(creditFacade))
                    .revertIfReceivedLessThan(expectedBalances),
                CreditFacadeMulticaller(address(creditFacade)).addCollateral(
                    USER,
                    underlying,
                    expectedDAI
                ),
                CreditFacadeMulticaller(address(creditFacade)).addCollateral(
                    USER,
                    tokenLINK,
                    expectedLINK
                )
            )
        );

        for (uint256 i = 0; i < 2; i++) {
            evm.prank(USER);
            evm.expectRevert(
                abi.encodeWithSelector(
                    BalanceLessThanMinimumDesiredException.selector,
                    (i == 0) ? underlying : tokenLINK
                )
            );

            creditFacade.multicall(
                multicallBuilder(
                    MultiCall({
                        target: address(creditFacade),
                        callData: abi.encodeWithSelector(
                            ICreditFacadeExtended
                                .revertIfReceivedLessThan
                                .selector,
                            expectedBalances
                        )
                    }),
                    MultiCall({
                        target: address(creditFacade),
                        callData: abi.encodeWithSelector(
                            ICreditFacade.addCollateral.selector,
                            USER,
                            underlying,
                            (i == 0) ? expectedDAI - 1 : expectedDAI
                        )
                    }),
                    MultiCall({
                        target: address(creditFacade),
                        callData: abi.encodeWithSelector(
                            ICreditFacade.addCollateral.selector,
                            USER,
                            tokenLINK,
                            (i == 0) ? expectedLINK : expectedLINK - 1
                        )
                    })
                )
            );
        }
    }

    /// @dev [FA-45A]: rrevertIfGetLessThan everts if called twice
    function test_FA_45A_revertIfGetLessThan_reverts_if_called_twice() public {
        uint256 expectedDAI = 1000;

        Balance[] memory expectedBalances = new Balance[](1);
        expectedBalances[0] = Balance({
            token: underlying,
            balance: expectedDAI
        });

        _openTestCreditAccount();
        evm.prank(USER);
        evm.expectRevert(ExpectedBalancesAlreadySetException.selector);

        creditFacade.multicall(
            multicallBuilder(
                MultiCall({
                    target: address(creditFacade),
                    callData: abi.encodeWithSelector(
                        ICreditFacadeExtended.revertIfReceivedLessThan.selector,
                        expectedBalances
                    )
                }),
                MultiCall({
                    target: address(creditFacade),
                    callData: abi.encodeWithSelector(
                        ICreditFacadeExtended.revertIfReceivedLessThan.selector,
                        expectedBalances
                    )
                })
            )
        );
    }

    /// CREDIT FACADE WITH EXPIRATION

    /// @dev [FA-46]: openCreditAccount and openCreditAccountMulticall no longer work if the CreditFacade is expired
    function test_FA_46_openCreditAccount_reverts_on_expired_CreditFacade()
        public
    {
        cft.testFacadeWithExpiration();
        creditFacade = cft.creditFacade();

        evm.warp(block.timestamp + 1);

        evm.expectRevert(
            OpenAccountNotAllowedAfterExpirationException.selector
        );

        evm.prank(USER);
        creditFacade.openCreditAccount(DAI_ACCOUNT_AMOUNT, USER, 100, 0);

        evm.expectRevert(
            OpenAccountNotAllowedAfterExpirationException.selector
        );

        evm.prank(USER);
        creditFacade.openCreditAccountMulticall(
            DAI_ACCOUNT_AMOUNT,
            USER,
            multicallBuilder(),
            0
        );
    }

    /// @dev [FA-47]: liquidateExpiredCreditAccount should not work before the CreditFacade is expired
    function test_FA_47_liquidateExpiredCreditAccount_reverts_before_expiration()
        public
    {
        cft.testFacadeWithExpiration();
        creditFacade = cft.creditFacade();

        _openTestCreditAccount();

        evm.expectRevert(CantLiquidateNonExpiredException.selector);

        evm.prank(LIQUIDATOR);
        creditFacade.liquidateExpiredCreditAccount(
            USER,
            LIQUIDATOR,
            0,
            false,
            multicallBuilder()
        );
    }

    /// @dev [FA-48]: liquidateExpiredCreditAccount should not work when expiration is set to zero (i.e. CreditFacade is non-expiring)
    function test_FA_48_liquidateExpiredCreditAccount_reverts_on_CreditFacade_with_no_expiration()
        public
    {
        _openTestCreditAccount();

        evm.expectRevert(CantLiquidateNonExpiredException.selector);

        evm.prank(LIQUIDATOR);
        creditFacade.liquidateExpiredCreditAccount(
            USER,
            LIQUIDATOR,
            0,
            false,
            multicallBuilder()
        );
    }

    /// @dev [FA-49]: liquidateExpiredCreditAccount works correctly and emits events
    function test_FA_49_liquidateExpiredCreditAccount_works_correctly_after_expiration()
        public
    {
        cft.testFacadeWithExpiration();
        creditFacade = cft.creditFacade();

        (address creditAccount, uint256 balance) = _openTestCreditAccount();

        bytes memory DUMB_CALLDATA = _prepareMockCall();

        evm.warp(block.timestamp + 1);
        evm.roll(block.number + 1);

        (
            uint256 borrowedAmount,
            uint256 borrowedAmountWithInterest,

        ) = creditManager.calcCreditAccountAccruedInterest(creditAccount);

        (, uint256 remainingFunds, , ) = creditManager.calcClosePayments(
            balance,
            ClosureAction.LIQUIDATE_EXPIRED_ACCOUNT,
            borrowedAmount,
            borrowedAmountWithInterest
        );

        // EXPECTED STACK TRACE & EVENTS

        evm.expectCall(
            address(creditManager),
            abi.encodeWithSignature(
                "transferAccountOwnership(address,address)",
                USER,
                address(creditFacade)
            )
        );

        evm.expectEmit(true, false, false, false);
        emit MultiCallStarted(USER);

        evm.expectCall(
            address(creditManager),
            abi.encodeWithSignature(
                "executeOrder(address,address,bytes)",
                address(creditFacade),
                address(targetMock),
                DUMB_CALLDATA
            )
        );

        evm.expectEmit(true, true, false, false);
        emit ExecuteOrder(address(creditFacade), address(targetMock));

        evm.expectCall(
            creditAccount,
            abi.encodeWithSelector(
                CreditAccount.execute.selector,
                address(targetMock),
                DUMB_CALLDATA
            )
        );

        evm.expectCall(address(targetMock), DUMB_CALLDATA);

        evm.expectEmit(false, false, false, false);
        emit MultiCallFinished();

        evm.expectCall(
            address(creditManager),
            abi.encodeWithSignature(
                "transferAccountOwnership(address,address)",
                address(creditFacade),
                USER
            )
        );

        // Total value = 2 * DAI_ACCOUNT_AMOUNT, cause we have x2 leverage
        uint256 totalValue = balance;

        evm.expectCall(
            address(creditManager),
            abi.encodeWithSelector(
                ICreditManagerV2.closeCreditAccount.selector,
                USER,
                ClosureAction.LIQUIDATE_EXPIRED_ACCOUNT,
                totalValue,
                LIQUIDATOR,
                FRIEND,
                10,
                true
            )
        );

        evm.expectEmit(true, true, true, true);
        emit LiquidateExpiredCreditAccount(
            USER,
            LIQUIDATOR,
            FRIEND,
            remainingFunds
        );

        evm.prank(LIQUIDATOR);
        creditFacade.liquidateExpiredCreditAccount(
            USER,
            FRIEND,
            10,
            true,
            multicallBuilder(
                MultiCall({
                    target: address(adapterMock),
                    callData: DUMB_CALLDATA
                })
            )
        );
    }

    //
    // UPGRADEABLE LIST
    //

    /// @dev [FA-50]: upgradeableContracts setters and getters work correctly
    function test_FA_50_upgradeableContracts_setters_and_getters_work_correctly()
        public
    {
        evm.prank(CONFIGURATOR);
        creditConfigurator.addContractToUpgradeable(DUMB_ADDRESS);

        assertTrue(
            creditFacade.isUpgradeableContract(DUMB_ADDRESS),
            "isUpgradeableContract returns incorrect value"
        );

        assertEq(
            creditFacade.upgradeableContractsList()[0],
            DUMB_ADDRESS,
            "Upgradeable contracts list is incorrect"
        );

        evm.prank(CONFIGURATOR);
        creditConfigurator.removeContractFromUpgradeable(DUMB_ADDRESS);

        assertEq(
            creditFacade.upgradeableContractsList().length,
            0,
            "Contract was not removed"
        );
    }

    /// @dev [FA-51]: approve reverts for upgradeable contract
    function test_FA_51_approve_reverts_for_upgradeable_contract() public {
        evm.prank(CONFIGURATOR);
        creditConfigurator.addContractToUpgradeable(address(targetMock));

        evm.expectRevert(TargetContractNotAllowedException.selector);
        evm.prank(USER);
        creditFacade.approve(address(targetMock), underlying, 1);
    }

    ///
    /// ENABLE TOKEN
    ///
    /// @dev [FA-52]: enableToken works as expected
    function test_FA_52_enableToken_works_as_expected() public {
        (address creditAccount, ) = _openTestCreditAccount();

        address token = tokenTestSuite.addressOf(Tokens.USDC);

        evm.expectCall(
            address(creditManager),
            abi.encodeWithSelector(
                ICreditManagerV2.checkAndEnableToken.selector,
                creditAccount,
                token
            )
        );

        // [TODO]: add check
        // evm.expectCall(
        //     address(creditManager),
        //     abi.encodeWithSelector(
        //         ICreditManagerV2.checkMaxEnabledTokens.selector,
        //         creditAccount
        //     )
        // );

        evm.expectEmit(true, false, false, true);
        emit TokenEnabled(USER, token);

        evm.prank(USER);
        creditFacade.enableToken(token);

        expectTokenIsEnabled(Tokens.USDC, true);
    }

    /// @dev [FA-53]: enableToken works as expected in a multicall
    function test_FA_53_enableToken_works_as_expected_multicall() public {
        (address creditAccount, ) = _openTestCreditAccount();

        address token = tokenTestSuite.addressOf(Tokens.USDC);

        evm.expectCall(
            address(creditManager),
            abi.encodeWithSelector(
                ICreditManagerV2.checkAndEnableToken.selector,
                creditAccount,
                token
            )
        );

        evm.expectEmit(true, false, false, true);
        emit TokenEnabled(USER, token);

        evm.prank(USER);
        creditFacade.multicall(
            multicallBuilder(
                MultiCall({
                    target: address(creditFacade),
                    callData: abi.encodeWithSelector(
                        ICreditFacade.enableToken.selector,
                        token
                    )
                })
            )
        );

        expectTokenIsEnabled(Tokens.USDC, true);
    }

    /// @dev [FA-54]: disableToken works as expected in a multicall
    function test_FA_54_disableToken_works_as_expected_multicall() public {
        (address creditAccount, ) = _openTestCreditAccount();

        address token = tokenTestSuite.addressOf(Tokens.USDC);

        evm.prank(USER);
        creditFacade.enableToken(token);

        evm.expectCall(
            address(creditManager),
            abi.encodeWithSelector(
                ICreditManagerV2.disableToken.selector,
                creditAccount,
                token
            )
        );

        evm.expectEmit(true, false, false, true);
        emit TokenDisabled(USER, token);

        evm.prank(USER);
        creditFacade.multicall(
            multicallBuilder(
                MultiCall({
                    target: address(creditFacade),
                    callData: abi.encodeWithSelector(
                        ICreditFacadeExtended.disableToken.selector,
                        token
                    )
                })
            )
        );

        expectTokenIsEnabled(Tokens.USDC, false);
    }

    // /// @dev [FA-55]: liquidateCreditAccount works in pause for pausable liquidators
    // function test_FA_55_liquidateCreditAccount_works_in_pause_for_pausable_liquidators()
    //     public
    // {
    //     UniswapV2Mock uniswapMock = new UniswapV2Mock();

    //     uniswapMock.setRate(
    //         tokenTestSuite.addressOf(Tokens.DAI),
    //         tokenTestSuite.addressOf(Tokens.WETH),
    //         RAY / DAI_WETH_RATE
    //     );

    //     tokenTestSuite.mint(
    //         tokenTestSuite.addressOf(Tokens.WETH),
    //         address(uniswapMock),
    //         DAI_ACCOUNT_AMOUNT
    //     );

    //     UniswapV2Adapter adapter = new UniswapV2Adapter(
    //         address(creditManager),
    //         address(uniswapMock)
    //     );

    //     evm.prank(CONFIGURATOR);
    //     creditConfigurator.allowContract(
    //         address(uniswapMock),
    //         address(adapter)
    //     );

    //     uint256 accountAmount = DAI_ACCOUNT_AMOUNT;

    //     tokenTestSuite.mint(underlying, USER, accountAmount);

    //     MultiCall[] memory calls = multicallBuilder(
    //         MultiCall({
    //             target: address(creditFacade),
    //             callData: abi.encodeWithSelector(
    //                 ICreditFacadeExtended.addCollateral.selector,
    //                 USER,
    //                 tokenTestSuite.addressOf(Tokens.DAI),
    //                 DAI_ACCOUNT_AMOUNT
    //             )
    //         }),
    //         MultiCall({
    //             target: address(adapter),
    //             callData: abi.encodeWithSelector(
    //                 UniswapV2Adapter.swapAllTokensForTokens.selector,
    //                 0,
    //                 arrayOf(
    //                     tokenTestSuite.addressOf(Tokens.DAI),
    //                     tokenTestSuite.addressOf(Tokens.WETH)
    //                 ),
    //                 block.timestamp
    //             )
    //         })
    //     );

    //     tokenTestSuite.approve(Tokens.DAI, USER, address(creditManager));

    //     evm.prank(USER);
    //     creditFacade.openCreditAccountMulticall(accountAmount, USER, calls, 0);

    //     address creditAccount = creditManager.getCreditAccountOrRevert(USER);

    //     uint256 balance = IERC20(underlying).balanceOf(creditAccount);

    //     assertEq(balance, 1, "Incorrect underlying balance");

    //     evm.label(creditAccount, "creditAccount");
    //     {
    //         (
    //             uint16 _feeInterest,
    //             uint16 _feeLiquidation,
    //             uint16 _liquidationDiscount,
    //             uint16 _feeLiquidationExpired,
    //             uint16 _liquidationPremiumExpired
    //         ) = creditManager.fees();

    //         // set LT to 1
    //         evm.prank(CONFIGURATOR);
    //         creditConfigurator.setFees(
    //             _feeInterest,
    //             _liquidationDiscount - 1,
    //             PERCENTAGE_FACTOR - _liquidationDiscount,
    //             _feeLiquidationExpired,
    //             _liquidationPremiumExpired
    //         );

    //         evm.prank(CONFIGURATOR);
    //         creditConfigurator.setFees(
    //             _feeInterest,
    //             _feeLiquidation,
    //             PERCENTAGE_FACTOR - _liquidationDiscount,
    //             _feeLiquidationExpired,
    //             _liquidationPremiumExpired
    //         );
    //     }

    //     uint256 hf = creditFacade.calcCreditAccountHealthFactor(creditAccount);
    //     assertTrue(hf < PERCENTAGE_FACTOR, "Incorrect health factor");

    //     calls = multicallBuilder(
    //         MultiCall({
    //             target: address(adapter),
    //             callData: abi.encodeWithSelector(
    //                 UniswapV2Adapter.swapAllTokensForTokens.selector,
    //                 0,
    //                 arrayOf(
    //                     tokenTestSuite.addressOf(Tokens.WETH),
    //                     tokenTestSuite.addressOf(Tokens.DAI)
    //                 ),
    //                 block.timestamp
    //             )
    //         })
    //     );

    //     evm.prank(CONFIGURATOR);
    //     CreditManager(address(creditManager)).pause();

    //     evm.roll(block.number + 1);

    //     /// Check that it reverts when paused
    //     evm.prank(LIQUIDATOR);
    //     evm.expectRevert("Pausable: paused");
    //     creditFacade.liquidateCreditAccount(USER, LIQUIDATOR, 0, false, calls);

    //     evm.prank(CONFIGURATOR);
    //     creditConfigurator.addEmergencyLiquidator(LIQUIDATOR);

    //     // We need extra balamce for Liquidator to cover Uniswap fees
    //     // totalAmount in WETH = 2 * DAI_ACCOUNT_AMOUNT / DAI_WETH_RAY * (1 - fee)
    //     // so, after exchnage it would drop for 2 * (1 -fee)
    //     tokenTestSuite.mint(
    //         tokenTestSuite.addressOf(Tokens.DAI),
    //         LIQUIDATOR,
    //         (DAI_ACCOUNT_AMOUNT * 2 * (1000 - uniswapMock.FEE_MULTIPLIER())) /
    //             1000
    //     );

    //     tokenTestSuite.approve(underlying, LIQUIDATOR, address(creditManager));

    //     evm.prank(LIQUIDATOR);
    //     creditFacade.liquidateCreditAccount(USER, LIQUIDATOR, 0, false, calls);

    //     assertTrue(
    //         !creditFacade.hasOpenedCreditAccount(USER),
    //         "USER still has credit account"
    //     );
    // }
}
