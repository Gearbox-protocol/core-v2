// SPDX-License-Identifier: UNLICENSED
// Gearbox Protocol. Generalized leverage for DeFi protocols
// (c) Gearbox Holdings, 2022
pragma solidity ^0.8.17;

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

    /// @dev [AA-3]: _executeSwapNoApprove correctly passes parameters to CreditManager
    function test_AA_03_executeSwapNoApprove_correctly_passes_to_credit_manager()
        public
    {
        (address ca, ) = _openTestCreditAccount();

        bytes memory DUMB_CALLDATA = abi.encodeWithSignature(
            "hello(string)",
            "world"
        );

        for (uint256 dt = 0; dt < 2; ++dt) {
            for (uint256 passCA = 0; passCA < 2; ++passCA) {
                evm.expectCall(
                    address(creditManager),
                    abi.encodeCall(
                        ICreditManagerV2.executeOrder,
                        (address(targetMock), DUMB_CALLDATA)
                    )
                );

                if (dt == 1) {
                    evm.expectCall(
                        address(creditManager),
                        abi.encodeCall(
                            ICreditManagerV2.disableToken,
                            (ca, usdc)
                        )
                    );
                }

                evm.expectCall(
                    address(creditManager),
                    abi.encodeCall(
                        ICreditManagerV2.checkAndEnableToken,
                        (ca, dai)
                    )
                );

                MultiCall memory mcall;

                if (passCA == 0) {
                    mcall = MultiCall({
                        target: address(adapterMock),
                        callData: abi.encodeWithSignature(
                            "executeSwapNoApprove(address,address,bytes,bool)",
                            usdc,
                            dai,
                            DUMB_CALLDATA,
                            dt == 1
                        )
                    });
                } else {
                    mcall = MultiCall({
                        target: address(adapterMock),
                        callData: abi.encodeWithSignature(
                            "executeSwapNoApprove(address,address,address,bytes,bool)",
                            ca,
                            usdc,
                            dai,
                            DUMB_CALLDATA,
                            dt == 1
                        )
                    });
                }

                evm.prank(USER);
                creditFacade.multicall(multicallBuilder(mcall));
            }
        }
    }

    /// @dev [AA-4]: _executeSwapMaxApprove correctly passes parameters to CreditManager and sets allowance
    function test_AA_04_executeSwapMaxApprove_correctly_passes_to_credit_manager()
        public
    {
        (address ca, ) = _openTestCreditAccount();

        bytes memory DUMB_CALLDATA = abi.encodeWithSignature(
            "hello(string)",
            "world"
        );

        for (uint256 dt = 0; dt < 2; ++dt) {
            for (uint256 passCA = 0; passCA < 2; ++passCA) {
                evm.expectCall(
                    address(creditManager),
                    abi.encodeCall(
                        ICreditManagerV2.approveCreditAccount,
                        (address(targetMock), usdc, type(uint256).max)
                    )
                );

                evm.expectCall(
                    address(creditManager),
                    abi.encodeCall(
                        ICreditManagerV2.executeOrder,
                        (address(targetMock), DUMB_CALLDATA)
                    )
                );

                evm.expectCall(
                    address(creditManager),
                    abi.encodeCall(
                        ICreditManagerV2.approveCreditAccount,
                        (address(targetMock), usdc, type(uint256).max)
                    )
                );

                if (dt == 1) {
                    evm.expectCall(
                        address(creditManager),
                        abi.encodeCall(
                            ICreditManagerV2.disableToken,
                            (ca, usdc)
                        )
                    );
                }

                evm.expectCall(
                    address(creditManager),
                    abi.encodeCall(
                        ICreditManagerV2.checkAndEnableToken,
                        (ca, dai)
                    )
                );

                MultiCall memory mcall;

                if (passCA == 0) {
                    mcall = MultiCall({
                        target: address(adapterMock),
                        callData: abi.encodeWithSignature(
                            "executeSwapMaxApprove(address,address,bytes,bool)",
                            usdc,
                            dai,
                            DUMB_CALLDATA,
                            dt == 1
                        )
                    });
                } else {
                    mcall = MultiCall({
                        target: address(adapterMock),
                        callData: abi.encodeWithSignature(
                            "executeSwapMaxApprove(address,address,address,bytes,bool)",
                            ca,
                            usdc,
                            dai,
                            DUMB_CALLDATA,
                            dt == 1
                        )
                    });
                }

                evm.prank(USER);
                creditFacade.multicall(multicallBuilder(mcall));

                assertEq(
                    IERC20(usdc).allowance(ca, address(targetMock)),
                    type(uint256).max,
                    "Incorrect allowance set"
                );
            }
        }
    }

    /// @dev [AA-5]: _executeSwapSafeApprove correctly passes parameters to CreditManager and sets allowance
    function test_AA_05_executeSwapSafeApprove_correctly_passes_to_credit_manager()
        public
    {
        (address ca, ) = _openTestCreditAccount();

        bytes memory DUMB_CALLDATA = abi.encodeWithSignature(
            "hello(string)",
            "world"
        );

        for (uint256 dt = 0; dt < 2; ++dt) {
            for (uint256 passCA = 0; passCA < 2; ++passCA) {
                evm.expectCall(
                    address(creditManager),
                    abi.encodeCall(
                        ICreditManagerV2.approveCreditAccount,
                        (address(targetMock), usdc, type(uint256).max)
                    )
                );

                evm.expectCall(
                    address(creditManager),
                    abi.encodeCall(
                        ICreditManagerV2.executeOrder,
                        (address(targetMock), DUMB_CALLDATA)
                    )
                );

                evm.expectCall(
                    address(creditManager),
                    abi.encodeCall(
                        ICreditManagerV2.approveCreditAccount,
                        (address(targetMock), usdc, 1)
                    )
                );

                if (dt == 1) {
                    evm.expectCall(
                        address(creditManager),
                        abi.encodeCall(
                            ICreditManagerV2.disableToken,
                            (ca, usdc)
                        )
                    );
                }

                evm.expectCall(
                    address(creditManager),
                    abi.encodeCall(
                        ICreditManagerV2.checkAndEnableToken,
                        (ca, dai)
                    )
                );

                MultiCall memory mcall;

                if (passCA == 0) {
                    mcall = MultiCall({
                        target: address(adapterMock),
                        callData: abi.encodeWithSignature(
                            "executeSwapSafeApprove(address,address,bytes,bool)",
                            usdc,
                            dai,
                            DUMB_CALLDATA,
                            dt == 1
                        )
                    });
                } else {
                    mcall = MultiCall({
                        target: address(adapterMock),
                        callData: abi.encodeWithSignature(
                            "executeSwapSafeApprove(address,address,address,bytes,bool)",
                            ca,
                            usdc,
                            dai,
                            DUMB_CALLDATA,
                            dt == 1
                        )
                    });
                }

                evm.prank(USER);
                creditFacade.multicall(multicallBuilder(mcall));

                assertEq(
                    IERC20(usdc).allowance(ca, address(targetMock)),
                    1,
                    "Incorrect allowance set"
                );
            }
        }
    }

    /// @dev [AA-6]: _execute correctly passes parameters to CreditManager
    function test_AA_06_execute_correctly_passes_to_credit_manager() public {
        _openTestCreditAccount();

        bytes memory DUMB_CALLDATA = abi.encodeWithSignature(
            "hello(string)",
            "world"
        );

        evm.expectCall(
            address(creditManager),
            abi.encodeCall(
                ICreditManagerV2.executeOrder,
                (address(targetMock), DUMB_CALLDATA)
            )
        );

        evm.prank(USER);
        creditFacade.multicall(
            multicallBuilder(
                MultiCall({
                    target: address(adapterMock),
                    callData: abi.encodeWithSignature(
                        "execute(bytes)",
                        DUMB_CALLDATA
                    )
                })
            )
        );
    }

    /// @dev [AA-7]: _approveToken correctly passes parameters to CreditManager
    function test_AA_07_approveToken_correctly_passes_to_credit_manager()
        public
    {
        _openTestCreditAccount();

        evm.expectCall(
            address(creditManager),
            abi.encodeCall(
                ICreditManagerV2.approveCreditAccount,
                (address(targetMock), usdc, 10)
            )
        );

        evm.prank(USER);
        creditFacade.multicall(
            multicallBuilder(
                MultiCall({
                    target: address(adapterMock),
                    callData: abi.encodeWithSignature(
                        "approveToken(address,uint256)",
                        usdc,
                        10
                    )
                })
            )
        );
    }
}
