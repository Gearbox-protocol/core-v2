// SPDX-License-Identifier: UNLICENSED
// Gearbox Protocol. Generalized leverage for DeFi protocols
// (c) Gearbox Holdings, 2022
pragma solidity ^0.8.10;

import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import { AccountFactory } from "../../core/AccountFactory.sol";
import { CreditFacade } from "../../credit/CreditFacade.sol";
import { CreditManager } from "../../credit/CreditManager.sol";

import { IAddressProvider } from "../../interfaces/IAddressProvider.sol";
import { ICreditAccount } from "../../interfaces/ICreditAccount.sol";
import { ICreditFacade, MultiCall } from "../../interfaces/ICreditFacade.sol";
import { ICreditManagerV2, ICreditManagerV2Events } from "../../interfaces/ICreditManagerV2.sol";
import { ICreditFacadeEvents, ICreditFacadeExceptions } from "../../interfaces/ICreditFacade.sol";
import { IPoolService } from "../../interfaces/IPoolService.sol";

import "../lib/constants.sol";
import { BalanceHelper } from "../helpers/BalanceHelper.sol";
import { CreditFacadeTestHelper } from "../helpers/CreditFacadeTestHelper.sol";

// EXCEPTIONS
import { IAdapterExceptions } from "../../interfaces/adapters/IAdapter.sol";
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
    address weth;
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
        weth = tokenTestSuite.addressOf(Tokens.WETH);
        dai = tokenTestSuite.addressOf(Tokens.DAI);
    }

    ///
    ///
    ///  TESTS
    ///
    ///

    /// @dev [AA-1]: AbstractAdapter constructor sets correct values
    function test_AA_01_constructor_sets_correct_values() public {
        IAddressProvider addressProvider = IPoolService(creditManager.pool())
            .addressProvider();

        assertEq(
            address(adapterMock.creditManager()),
            address(creditManager),
            "Incorrect credit manager"
        );

        assertEq(
            address(adapterMock.addressProvider()),
            address(addressProvider),
            "Incorrect address provider"
        );

        assertEq(
            adapterMock.targetContract(),
            address(targetMock),
            "Incorrect target contract"
        );

        assertEq(
            address(adapterMock._acl()),
            addressProvider.getACL(),
            "Incorrect ACL"
        );
    }

    /// @dev [AA-2]: AbstractAdapter constructor reverts when passed zero-address as target contract
    function test_AA_02_constructor_reverts_on_zero_address() public {
        evm.expectRevert(ZeroAddressException.selector);
        new AdapterMock(address(0), address(0));

        evm.expectRevert(ZeroAddressException.selector);
        new AdapterMock(address(creditManager), address(0));
    }

    /// @dev [AA-3]: AbstractAdapter uses correct credit facade
    function test_AA_03_adapter_uses_correct_credit_facade() public {
        address facade = adapterMock.creditFacade();
        assertEq(facade, address(creditFacade));
    }

    /// @dev [AA-4]: AbstractAdapter uses correct credit account
    function test_AA_04_adapter_uses_correct_credit_account() public {
        (address creditAccount, ) = _openTestCreditAccount();

        evm.prank(address(creditFacade));
        creditManager.transferAccountOwnership(USER, address(creditFacade));
        assertEq(adapterMock.creditAccount(), creditAccount);
    }

    /// @dev [AA-5]: AbstractAdapter creditFacadeOnly functions revert if called not from credit facade
    function test_AA_05_creditFacadeOnly_function_reverts_if_called_not_from_credit_facade()
        public
    {
        bytes memory DUMB_CALLDATA = abi.encodeWithSignature(
            "hello(string)",
            "world"
        );

        evm.prank(USER);
        evm.expectRevert(CreditFacadeOnlyException.selector);
        adapterMock.execute(DUMB_CALLDATA);
    }

    /// @dev [AA-6]: AbstractAdapter _getMaskOrRevert works correctly
    function test_AA_06_getMaskOrRevert_works_correctly() public {
        assertEq(
            adapterMock.getMaskOrRevert(tokenTestSuite.addressOf(Tokens.DAI)),
            creditManager.tokenMasksMap(tokenTestSuite.addressOf(Tokens.DAI))
        );

        evm.expectRevert(IAdapterExceptions.TokenNotAllowedException.selector);
        adapterMock.getMaskOrRevert(address(0xdead));
    }

    /// @dev [AA-7]: AbstractAdapter functions revert if user has no credit account
    function test_AA_07_adapter_reverts_if_user_has_no_credit_account() public {
        evm.expectRevert(HasNoOpenedAccountException.selector);
        adapterMock.creditAccount();

        bytes memory DUMB_CALLDATA = abi.encodeWithSignature(
            "hello(string)",
            "world"
        );
        evm.prank(USER);
        evm.expectRevert(HasNoOpenedAccountException.selector);
        creditFacade.multicall(
            multicallBuilder(
                MultiCall({
                    target: address(adapterMock),
                    callData: abi.encodeWithSelector(
                        AdapterMock.execute.selector,
                        DUMB_CALLDATA
                    )
                })
            )
        );

        evm.prank(USER);
        evm.expectRevert(HasNoOpenedAccountException.selector);
        creditFacade.multicall(
            multicallBuilder(
                MultiCall({
                    target: address(adapterMock),
                    callData: abi.encodeWithSelector(
                        AdapterMock.approveToken.selector,
                        usdc,
                        1
                    )
                })
            )
        );

        evm.prank(USER);
        evm.expectRevert(HasNoOpenedAccountException.selector);
        creditFacade.multicall(
            multicallBuilder(
                MultiCall({
                    target: address(adapterMock),
                    callData: abi.encodeWithSelector(
                        AdapterMock.enableToken.selector,
                        usdc
                    )
                })
            )
        );

        evm.prank(USER);
        evm.expectRevert(HasNoOpenedAccountException.selector);
        creditFacade.multicall(
            multicallBuilder(
                MultiCall({
                    target: address(adapterMock),
                    callData: abi.encodeWithSelector(
                        AdapterMock.disableToken.selector,
                        usdc
                    )
                })
            )
        );

        evm.prank(USER);
        evm.expectRevert(HasNoOpenedAccountException.selector);
        creditFacade.multicall(
            multicallBuilder(
                MultiCall({
                    target: address(adapterMock),
                    callData: abi.encodeWithSelector(
                        AdapterMock.changeEnabledTokens.selector,
                        0,
                        0
                    )
                })
            )
        );

        for (uint256 dt; dt < 2; ++dt) {
            evm.prank(USER);
            evm.expectRevert(HasNoOpenedAccountException.selector);
            creditFacade.multicall(
                multicallBuilder(
                    MultiCall({
                        target: address(adapterMock),
                        callData: abi.encodeWithSelector(
                            AdapterMock.executeSwapNoApprove.selector,
                            usdc,
                            dai,
                            DUMB_CALLDATA,
                            dt == 1
                        )
                    })
                )
            );

            evm.prank(USER);
            evm.expectRevert(HasNoOpenedAccountException.selector);
            creditFacade.multicall(
                multicallBuilder(
                    MultiCall({
                        target: address(adapterMock),
                        callData: abi.encodeWithSelector(
                            AdapterMock.executeSwapSafeApprove.selector,
                            usdc,
                            dai,
                            DUMB_CALLDATA,
                            dt == 1
                        )
                    })
                )
            );
        }
    }

    /// @dev [AA-8]: _approveToken correctly passes parameters to CreditManager
    function test_AA_08_approveToken_correctly_passes_to_credit_manager()
        public
    {
        _openTestCreditAccount();

        evm.expectCall(
            address(creditManager),
            abi.encodeWithSelector(
                ICreditManagerV2.approveCreditAccount.selector,
                address(creditFacade),
                address(targetMock),
                usdc,
                10
            )
        );

        evm.prank(USER);
        creditFacade.multicall(
            multicallBuilder(
                MultiCall({
                    target: address(adapterMock),
                    callData: abi.encodeWithSelector(
                        adapterMock.approveToken.selector,
                        usdc,
                        10
                    )
                })
            )
        );
    }

    /// @dev [AA-9]: _enableToken correctly passes parameters to CreditManager
    function test_AA_09_enableToken_correctly_passes_to_credit_manager()
        public
    {
        (address creditAccount, ) = _openTestCreditAccount();

        evm.expectCall(
            address(creditManager),
            abi.encodeWithSelector(
                ICreditManagerV2.checkAndEnableToken.selector,
                creditAccount,
                usdc
            )
        );

        evm.prank(USER);
        creditFacade.multicall(
            multicallBuilder(
                MultiCall({
                    target: address(adapterMock),
                    callData: abi.encodeWithSelector(
                        adapterMock.enableToken.selector,
                        usdc
                    )
                })
            )
        );
    }

    /// @dev [AA-10]: _disableToken correctly passes parameters to CreditManager
    function test_AA_10_disableToken_correctly_passes_to_credit_manager()
        public
    {
        (address creditAccount, ) = _openTestCreditAccount();

        evm.expectCall(
            address(creditManager),
            abi.encodeWithSelector(
                ICreditManagerV2.disableToken.selector,
                creditAccount,
                usdc
            )
        );

        evm.prank(USER);
        creditFacade.multicall(
            multicallBuilder(
                MultiCall({
                    target: address(adapterMock),
                    callData: abi.encodeWithSelector(
                        adapterMock.disableToken.selector,
                        usdc
                    )
                })
            )
        );
    }

    /// @dev [AA-11]: _changeEnabledTokens correctly passes parameters to CreditManager
    function test_AA_11_changeEnabledTokens_correctly_passes_to_credit_manager()
        public
    {
        (address creditAccount, ) = _openTestCreditAccount();

        uint256 usdcMask = creditManager.tokenMasksMap(usdc);
        uint256 wethMask = creditManager.tokenMasksMap(weth);

        evm.expectCall(
            address(creditManager),
            abi.encodeWithSelector(
                ICreditManagerV2.checkAndEnableToken.selector,
                creditAccount,
                usdc
            )
        );

        evm.expectCall(
            address(creditManager),
            abi.encodeWithSelector(
                ICreditManagerV2.disableToken.selector,
                creditAccount,
                weth
            )
        );

        evm.prank(USER);
        creditFacade.multicall(
            multicallBuilder(
                MultiCall({
                    target: address(adapterMock),
                    callData: abi.encodeWithSelector(
                        adapterMock.changeEnabledTokens.selector,
                        usdcMask,
                        wethMask
                    )
                })
            )
        );
    }

    /// @dev [AA-11A] _changeEnabledTokens terminates correctly
    function test_AA_11A_changeEnabledTokens_terminates_correctly() public {
        evm.startPrank(address(creditConfigurator));
        for (uint256 i = creditManager.collateralTokensCount(); i < 256; i++) {
            CreditManager(address(creditManager)).addToken(
                address(uint160(uint256(keccak256(abi.encodePacked(i)))))
            );
        }
        evm.stopPrank();

        _openTestCreditAccount();

        evm.prank(USER);
        creditFacade.multicall(
            multicallBuilder(
                MultiCall({
                    target: address(adapterMock),
                    callData: abi.encodeWithSelector(
                        adapterMock.changeEnabledTokens.selector,
                        1 << 255,
                        0
                    )
                })
            )
        );
    }

    /// @dev [AA-12]: _execute correctly passes parameters to CreditManager
    function test_AA_12_execute_correctly_passes_to_credit_manager() public {
        _openTestCreditAccount();

        bytes memory DUMB_CALLDATA = abi.encodeWithSignature(
            "hello(string)",
            "world"
        );

        evm.expectCall(
            address(creditManager),
            abi.encodeWithSelector(
                ICreditManagerV2.executeOrder.selector,
                address(creditFacade),
                address(targetMock),
                DUMB_CALLDATA
            )
        );

        evm.prank(USER);
        creditFacade.multicall(
            multicallBuilder(
                MultiCall({
                    target: address(adapterMock),
                    callData: abi.encodeWithSelector(
                        adapterMock.execute.selector,
                        DUMB_CALLDATA
                    )
                })
            )
        );
    }

    /// @dev [AA-13]: _executeSwapNoApprove correctly passes parameters to CreditManager
    function test_AA_13_executeSwapNoApprove_correctly_passes_to_credit_manager()
        public
    {
        (address creditAccount, ) = _openTestCreditAccount();

        bytes memory DUMB_CALLDATA = abi.encodeWithSignature(
            "hello(string)",
            "world"
        );

        for (uint256 dt = 0; dt < 2; ++dt) {
            evm.expectCall(
                address(creditManager),
                abi.encodeWithSelector(
                    ICreditManagerV2.executeOrder.selector,
                    address(creditFacade),
                    address(targetMock),
                    DUMB_CALLDATA
                )
            );

            if (dt == 1) {
                evm.expectCall(
                    address(creditManager),
                    abi.encodeWithSelector(
                        ICreditManagerV2.disableToken.selector,
                        creditAccount,
                        usdc
                    )
                );
            }

            evm.expectCall(
                address(creditManager),
                abi.encodeWithSelector(
                    ICreditManagerV2.checkAndEnableToken.selector,
                    creditAccount,
                    dai
                )
            );

            evm.prank(USER);
            creditFacade.multicall(
                multicallBuilder(
                    MultiCall({
                        target: address(adapterMock),
                        callData: abi.encodeWithSelector(
                            adapterMock.executeSwapNoApprove.selector,
                            usdc,
                            dai,
                            DUMB_CALLDATA,
                            dt == 1
                        )
                    })
                )
            );
        }
    }

    /// @dev [AA-14]: _executeSwapSafeApprove correctly passes parameters to CreditManager and sets allowance
    function test_AA_14_executeSwapSafeApprove_correctly_passes_to_credit_manager()
        public
    {
        (address creditAccount, ) = _openTestCreditAccount();

        bytes memory DUMB_CALLDATA = abi.encodeWithSignature(
            "hello(string)",
            "world"
        );

        for (uint256 dt = 0; dt < 2; ++dt) {
            evm.expectCall(
                address(creditManager),
                abi.encodeWithSelector(
                    ICreditManagerV2.approveCreditAccount.selector,
                    address(creditFacade),
                    address(targetMock),
                    usdc,
                    type(uint256).max
                )
            );

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
                    ICreditManagerV2.approveCreditAccount.selector,
                    address(creditFacade),
                    address(targetMock),
                    usdc,
                    1
                )
            );

            if (dt == 1) {
                evm.expectCall(
                    address(creditManager),
                    abi.encodeWithSelector(
                        ICreditManagerV2.disableToken.selector,
                        creditAccount,
                        usdc
                    )
                );
            }

            evm.expectCall(
                address(creditManager),
                abi.encodeWithSelector(
                    ICreditManagerV2.checkAndEnableToken.selector,
                    creditAccount,
                    dai
                )
            );

            evm.prank(USER);
            creditFacade.multicall(
                multicallBuilder(
                    MultiCall({
                        target: address(adapterMock),
                        callData: abi.encodeWithSelector(
                            adapterMock.executeSwapSafeApprove.selector,
                            usdc,
                            dai,
                            DUMB_CALLDATA,
                            dt == 1
                        )
                    })
                )
            );

            assertEq(
                IERC20(usdc).allowance(creditAccount, address(targetMock)),
                1,
                "Incorrect allowance set"
            );
        }
    }

    /// @dev [AA-15]: _executeSwapNoApprove reverts if tokenIn or tokenOut are not allowed
    function test_AA_15_executeSwap_reverts_if_tokenIn_or_tokenOut_are_not_allowed()
        public
    {
        _openTestCreditAccount();

        address TOKEN = address(0xdead);
        bytes memory DUMB_CALLDATA = abi.encodeWithSignature(
            "hello(string)",
            "world"
        );

        // ti == 0 => bad tokenOut, ti == 1 => bad tokenIn
        // sa == 0 => no approve, sa == 1 => safe approve
        for (uint256 ti; ti < 2; ++ti) {
            for (uint256 sa; sa < 2; ++sa) {
                bytes memory callData;
                if (sa == 1) {
                    callData = abi.encodeWithSelector(
                        adapterMock.executeSwapSafeApprove.selector,
                        ti == 1 ? TOKEN : dai,
                        ti == 1 ? dai : TOKEN,
                        DUMB_CALLDATA,
                        false
                    );
                } else {
                    callData = abi.encodeWithSelector(
                        adapterMock.executeSwapNoApprove.selector,
                        ti == 1 ? TOKEN : dai,
                        ti == 1 ? dai : TOKEN,
                        DUMB_CALLDATA,
                        false
                    );
                }

                evm.prank(USER);
                evm.expectRevert(
                    IAdapterExceptions.TokenNotAllowedException.selector
                );
                creditFacade.multicall(
                    multicallBuilder(
                        MultiCall({
                            target: address(adapterMock),
                            callData: callData
                        })
                    )
                );
            }
        }
    }

    /// @dev [AA-16]: `configuratorOnly` function reverts if called not by configurator
    function test_AA_16_configuratorOnly_function_reverts_if_called_not_by_configurator()
        public
    {
        evm.expectRevert(
            IAdapterExceptions.CallerNotConfiguratorException.selector
        );
        evm.prank(USER);
        adapterMock.configure();
    }
}
