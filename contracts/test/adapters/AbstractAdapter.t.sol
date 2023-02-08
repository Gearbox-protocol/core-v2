// SPDX-License-Identifier: UNLICENSED
// Gearbox Protocol. Generalized leverage for DeFi protocols
// (c) Gearbox Holdings, 2022
pragma solidity ^0.8.10;

import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import { AccountFactory } from "../../core/AccountFactory.sol";
import { CreditFacade } from "../../credit/CreditFacade.sol";

import { ICreditFacade, MultiCall } from "../../interfaces/ICreditFacade.sol";
import { ICreditManagerV2, ICreditManagerV2Events } from "../../interfaces/ICreditManagerV2.sol";
import { ICreditFacadeEvents, ICreditFacadeExceptions } from "../../interfaces/ICreditFacade.sol";

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

/// @title AbstractAdapterTest
/// @notice Designed for unit test purposes only
contract AbstractAdapterTest is
    DSTest,
    BalanceHelper,
    CreditFacadeTestHelper,
    ICreditManagerV2Events,
    ICreditFacadeEvents,
    ICreditFacadeExceptions
{
    AccountFactory accountFactory;

    TargetContractMock targetMock;
    AdapterMock adapterMock;

    address usdc;
    address dai;

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

        evm.prank(CONFIGURATOR);
        creditConfigurator.allowContract(
            address(targetMock),
            address(adapterMock)
        );

        evm.label(address(adapterMock), "AdapterMock");
        evm.label(address(targetMock), "TargetContractMock");

        usdc = tokenTestSuite.addressOf(Tokens.USDC);
        dai = tokenTestSuite.addressOf(Tokens.DAI);
    }

    ///
    ///
    ///  TESTS
    ///
    ///

    /// @dev [AA-1]: AbstractAdapter constructor sets correct values
    function test_AA_01_constructor_sets_correct_values() public {
        assertEq(
            address(adapterMock.creditManager()),
            address(creditManager),
            "Incorrect Credit Manager"
        );

        assertEq(
            adapterMock.targetContract(),
            address(targetMock),
            "Incorrect target contract"
        );
    }

    /// @dev [AA-2]: AbstractAdapter constructor reverts when passed a zero-address
    function test_AA_02_constructor_reverts_on_zero_address() public {
        evm.expectRevert(ZeroAddressException.selector);
        AdapterMock am = new AdapterMock(address(0), address(0));

        evm.expectRevert(ZeroAddressException.selector);
        am = new AdapterMock(address(creditManager), address(0));
    }

    /// @dev [AA-3]: executeFast_check_reverts_if_user_has_no_account
    function test_AA_03_executeFast_check_reverts_if_user_has_no_account()
        public
    {
        bytes memory DUMB_CALLDATA = abi.encodeWithSignature(
            "hello(string)",
            "world"
        );

        evm.expectRevert(
            ICreditManagerV2Exceptions.HasNoOpenedAccountException.selector
        );
        adapterMock.executeMaxAllowanceFastCheck(
            usdc,
            dai,
            DUMB_CALLDATA,
            true,
            false
        );

        evm.expectRevert(
            ICreditManagerV2Exceptions.HasNoOpenedAccountException.selector
        );
        adapterMock.safeExecuteFastCheck(usdc, dai, DUMB_CALLDATA, true, false);
    }

    /// @dev [AA-3A]: AbstractAdapter _executeMaxAllowanceFastCheck correctly passes parameters to CreditManager
    function test_AA_04A_executeMaxAllowanceFastCheck_correctly_passes_to_credit_manager()
        public
    {
        (address ca, ) = _openTestCreditAccount();

        bytes memory DUMB_CALLDATA = abi.encodeWithSignature(
            "hello(string)",
            "world"
        );

        evm.expectCall(
            address(creditManager),
            abi.encodeWithSelector(
                ICreditManagerV2.executeOrder.selector,
                USER,
                address(targetMock),
                DUMB_CALLDATA
            )
        );

        evm.expectCall(
            address(creditManager),
            abi.encodeWithSelector(
                ICreditManagerV2.fastCollateralCheck.selector,
                ca,
                usdc,
                dai,
                IERC20(usdc).balanceOf(ca),
                IERC20(dai).balanceOf(ca)
            )
        );

        evm.prank(USER);
        adapterMock.executeMaxAllowanceFastCheck(
            usdc,
            dai,
            DUMB_CALLDATA,
            true,
            false
        );
    }

    function test_AA_04B_executeMaxAllowanceFastCheck_correctly_passes_to_credit_manager()
        public
    {
        (address ca, ) = _openTestCreditAccount();

        bytes memory DUMB_CALLDATA = abi.encodeWithSignature(
            "hello(string)",
            "world"
        );

        MultiCall[] memory calls = new MultiCall[](1);
        calls[0] = MultiCall({
            target: address(adapterMock),
            callData: abi.encodeWithSignature(
                "executeMaxAllowanceFastCheck(address,address,address,bytes,bool,bool)",
                ca,
                usdc,
                dai,
                DUMB_CALLDATA,
                true,
                true
            )
        });

        evm.expectCall(
            address(creditManager),
            abi.encodeWithSelector(
                ICreditManagerV2.executeOrder.selector,
                address(creditFacade),
                address(targetMock),
                DUMB_CALLDATA
            )
        );

        evm.expectCall(
            address(creditManager),
            abi.encodeWithSelector(
                ICreditManagerV2.disableToken.selector,
                ca,
                usdc
            )
        );

        evm.expectCall(
            address(creditManager),
            abi.encodeWithSelector(
                ICreditManagerV2.checkAndEnableToken.selector,
                ca,
                dai
            )
        );

        evm.prank(USER);
        creditFacade.multicall(calls);
    }

    /// @dev [AA-5]: AbstractAdapter _executeMaxAllowanceFastCheck correctly sets max allowance
    function test_AA_05_executeMaxAllowanceFastCheck_correctly_sets_allowance()
        public
    {
        for (uint256 ai = 0; ai < 2; ai++) {
            bool allowTokenIn = ai != 0;

            setUp();

            (address ca, ) = _openTestCreditAccount();

            bytes memory DUMB_CALLDATA = abi.encodeWithSignature(
                "hello(string)",
                "world"
            );

            expectAllowance(Tokens.USDC, ca, address(targetMock), 0);

            if (allowTokenIn)
                evm.expectCall(
                    usdc,
                    abi.encodeWithSelector(
                        IERC20.approve.selector,
                        address(targetMock),
                        type(uint256).max
                    )
                );

            if (allowTokenIn)
                evm.expectCall(
                    usdc,
                    abi.encodeWithSelector(
                        IERC20.approve.selector,
                        address(targetMock),
                        type(uint256).max
                    )
                );

            evm.prank(USER);
            adapterMock.executeMaxAllowanceFastCheck(
                usdc,
                dai,
                DUMB_CALLDATA,
                true,
                false
            );

            if (allowTokenIn)
                expectAllowance(
                    Tokens.USDC,
                    ca,
                    address(targetMock),
                    type(uint256).max
                );
        }
    }

    /// @dev [AA-6]: AbstractAdapter _executeSafeFastCheck correctly passes parameters to CreditManager
    function test_AA_06A_executeSafeFastCheck_correctly_passes_to_credit_manager()
        public
    {
        (address ca, ) = _openTestCreditAccount();

        bytes memory DUMB_CALLDATA = abi.encodeWithSignature(
            "hello(string)",
            "world"
        );

        evm.expectCall(
            address(creditManager),
            abi.encodeWithSelector(
                ICreditManagerV2.executeOrder.selector,
                USER,
                address(targetMock),
                DUMB_CALLDATA
            )
        );

        evm.expectCall(
            address(creditManager),
            abi.encodeWithSelector(
                ICreditManagerV2.fastCollateralCheck.selector,
                ca,
                usdc,
                dai,
                IERC20(usdc).balanceOf(ca),
                IERC20(dai).balanceOf(ca)
            )
        );

        evm.prank(USER);
        adapterMock.safeExecuteFastCheck(usdc, dai, DUMB_CALLDATA, true, false);
    }

    function test_AA_06B_executeSafeFastCheck_correctly_passes_to_credit_manager()
        public
    {
        (address ca, ) = _openTestCreditAccount();

        bytes memory DUMB_CALLDATA = abi.encodeWithSignature(
            "hello(string)",
            "world"
        );

        MultiCall[] memory calls = new MultiCall[](1);
        calls[0] = MultiCall({
            target: address(adapterMock),
            callData: abi.encodeWithSignature(
                "safeExecuteFastCheck(address,address,address,bytes,bool,bool)",
                ca,
                usdc,
                dai,
                DUMB_CALLDATA,
                true,
                true
            )
        });

        evm.expectCall(
            address(creditManager),
            abi.encodeWithSelector(
                ICreditManagerV2.executeOrder.selector,
                address(creditFacade),
                address(targetMock),
                DUMB_CALLDATA
            )
        );

        evm.expectCall(
            address(creditManager),
            abi.encodeWithSelector(
                ICreditManagerV2.disableToken.selector,
                ca,
                usdc
            )
        );

        evm.expectCall(
            address(creditManager),
            abi.encodeWithSelector(
                ICreditManagerV2.checkAndEnableToken.selector,
                ca,
                dai
            )
        );

        evm.prank(USER);
        creditFacade.multicall(calls);
    }

    /// @dev [AA-7]: AbstractAdapter _executeSafeFastCheck correct sets allowances
    function test_AA_07_executeSafeFastCheck_correctly_sets_allowance() public {
        (address ca, ) = _openTestCreditAccount();

        expectAllowance(Tokens.DAI, ca, address(targetMock), 0);

        evm.expectCall(
            dai,
            abi.encodeWithSelector(
                IERC20.approve.selector,
                address(targetMock),
                type(uint256).max
            )
        );

        evm.expectCall(
            dai,
            abi.encodeWithSelector(
                IERC20.approve.selector,
                address(targetMock),
                1
            )
        );

        evm.prank(USER);
        adapterMock.safeExecuteFastCheck(dai, usdc, "calldata", true, false);

        expectAllowance(Tokens.DAI, ca, address(targetMock), 1);
    }

    /// @dev [AA-8A]: AbstractAdapter _execute correctly passes parameters to CreditManager
    function test_AA_08A_execute_correctly_passes_to_credit_manager() public {
        _openTestCreditAccount();

        bytes memory DUMB_CALLDATA = abi.encodeWithSignature(
            "hello(string)",
            "world"
        );

        evm.expectCall(
            address(creditManager),
            abi.encodeWithSelector(
                ICreditManagerV2.executeOrder.selector,
                USER,
                address(targetMock),
                DUMB_CALLDATA
            )
        );

        evm.prank(USER);
        adapterMock.execute(DUMB_CALLDATA);
    }

    /// @dev [AA-8B]: AbstractAdapter _fullCheck correctly passes parameters to CreditManager
    function test_AA_08A_fullCheck_correctly_passes_to_credit_manager() public {
        (address ca, ) = _openTestCreditAccount();

        evm.expectCall(
            address(creditManager),
            abi.encodeWithSelector(
                ICreditManagerV2.fullCollateralCheck.selector,
                ca
            )
        );

        evm.prank(USER);
        adapterMock.fullCheck(ca);
    }

    /// @dev [AA-8C]: AbstractAdapter _executeMaxAllowanceFastCheck correctly passes parameters to CreditManager
    function test_AA_08C_executeMaxAllowanceFastCheck_correctly_passes_to_credit_manager()
        public
    {
        (address ca, ) = _openTestCreditAccount();

        evm.prank(address(creditFacade));
        creditFacade.approveAccountTransfer(USER, true);

        evm.prank(USER);
        creditFacade.transferAccountOwnership(address(creditFacade));

        tokenTestSuite.burn(
            Tokens.DAI,
            ca,
            tokenTestSuite.balanceOf(Tokens.DAI, ca)
        );

        assertEq(
            creditFacade.calcCreditAccountHealthFactor(ca),
            0,
            "Incorrect health factor"
        );
    }

    /// @dev [AA-09]: AbstractAdapter works correctly after changing CreditFacade
    function test_AA_09_adapter_correctly_detects_CreditFacade_change() public {
        (address ca, ) = _openTestCreditAccount();

        _makeAccountsLiquitable();

        evm.expectRevert(NotEnoughCollateralException.selector);
        adapterMock.fullCheck(ca);

        evm.startPrank(CONFIGURATOR);

        CreditFacade newCreditFacade = new CreditFacade(
            address(creditManager),
            address(0),
            false
        );

        creditConfigurator.upgradeCreditFacade(address(newCreditFacade), true);

        evm.stopPrank();

        evm.prank(address(newCreditFacade));
        adapterMock.fullCheck(ca);
    }
}
