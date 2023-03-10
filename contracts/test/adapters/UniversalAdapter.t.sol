// SPDX-License-Identifier: UNLICENSED
// Gearbox Protocol. Generalized leverage for DeFi protocols
// (c) Gearbox Holdings, 2023
pragma solidity ^0.8.17;

import {UniversalAdapter, RevocationPair} from "../../adapters/UniversalAdapter.sol";
import {CreditFacade} from "../../credit/CreditFacade.sol";
import {ICreditManagerV2} from "../../interfaces/ICreditManagerV2.sol";
import {ZeroAddressException} from "../../interfaces/IErrors.sol";
import {IAdapterExceptions} from "../../interfaces/adapters/IAdapter.sol";
import {UNIVERSAL_CONTRACT} from "../../libraries/Constants.sol";
import {MultiCall} from "../../libraries/MultiCall.sol";

// CONSTANTS
import {CONFIGURATOR, USER} from "../lib/constants.sol";

// HELPERS
import {BalanceHelper} from "../helpers/BalanceHelper.sol";
import {CreditFacadeTestHelper} from "../helpers/CreditFacadeTestHelper.sol";

// MOCKS
import {AdapterMock} from "../mocks/adapters/AdapterMock.sol";
import {TargetContractMock} from "../mocks/adapters/TargetContractMock.sol";

// SUITES
import {TokensTestSuite} from "../suites/TokensTestSuite.sol";
import {Tokens} from "../config/Tokens.sol";
import {CreditFacadeTestSuite} from "../suites/CreditFacadeTestSuite.sol";
import {CreditConfig} from "../config/CreditConfig.sol";

/// @title Universal adapter test
/// @notice Designed for unit test purposes only
contract UniversalAdapterTest is BalanceHelper, CreditFacadeTestHelper {
    UniversalAdapter universalAdapter;

    TargetContractMock targetMock1;
    TargetContractMock targetMock2;
    AdapterMock adapterMock1;
    AdapterMock adapterMock2;

    address dai;
    address usdc;

    /// ----- ///
    /// SETUP ///
    /// ----- ///

    function setUp() public {
        // balance helper setup
        tokenTestSuite = new TokensTestSuite();

        // credit facade helper setup
        CreditConfig creditConfig = new CreditConfig(
            tokenTestSuite,
            Tokens.DAI
        );
        cft = new CreditFacadeTestSuite(creditConfig);
        underlying = tokenTestSuite.addressOf(Tokens.DAI);
        creditManager = cft.creditManager();
        creditFacade = cft.creditFacade();
        creditConfigurator = cft.creditConfigurator();

        // universal adapter setup
        universalAdapter = new UniversalAdapter(address(creditManager));

        targetMock1 = new TargetContractMock();
        targetMock2 = new TargetContractMock();
        adapterMock1 = new AdapterMock(address(creditManager), address(targetMock1));
        adapterMock2 = new AdapterMock(address(creditManager), address(targetMock2));

        evm.startPrank(CONFIGURATOR);
        creditConfigurator.allowContract(address(targetMock1), address(adapterMock1));
        creditConfigurator.allowContract(address(targetMock2), address(adapterMock2));
        creditConfigurator.allowContract(UNIVERSAL_CONTRACT, address(universalAdapter));
        evm.stopPrank();

        evm.label(address(adapterMock1), "AdapterMock1");
        evm.label(address(targetMock1), "TargetContractMock1");
        evm.label(address(adapterMock2), "AdapterMock1");
        evm.label(address(targetMock2), "TargetContractMock1");

        usdc = tokenTestSuite.addressOf(Tokens.USDC);
        dai = tokenTestSuite.addressOf(Tokens.DAI);
    }

    /// ----- ///
    /// TESTS ///
    /// ----- ///

    /// @notice [UA-1]: UniversalAdapter constructor sets correct values
    function test_UA_01_constructor_sets_correct_values() public {
        assertEq(address(universalAdapter.creditManager()), address(creditManager), "Incorrect credit manager address");
        assertEq(universalAdapter.targetContract(), UNIVERSAL_CONTRACT, "Incorrect target contract address");
    }

    /// @notice [UA-2]: UniversalAdapter `revokeAllowances` reverts if called not from multicall
    function test_UA_02_revokeAllowances_reverts_if_called_not_from_multicall() public {
        evm.prank(USER);
        evm.expectRevert(IAdapterExceptions.CreditFacadeOnlyException.selector);
        universalAdapter.revokeAdapterAllowances(new RevocationPair[](0));
    }

    /// @notice [UA-3]: UniversalAdapter `revokeAllowances` reverts if passed zero address
    function test_UA_03_revokeAllowances_reverts_if_passed_zero_address() public {
        _openTestCreditAccount();

        RevocationPair[] memory revocations = new RevocationPair[](1);

        evm.prank(USER);
        revocations[0] = RevocationPair({spender: address(0), token: usdc});
        evm.expectRevert(ZeroAddressException.selector);
        creditFacade.multicall(
            multicallBuilder(
                MultiCall({
                    target: address(universalAdapter),
                    callData: abi.encodeCall(universalAdapter.revokeAdapterAllowances, (revocations))
                })
            )
        );

        evm.prank(USER);
        revocations[0] = RevocationPair({spender: address(targetMock1), token: address(0)});
        evm.expectRevert(ZeroAddressException.selector);
        creditFacade.multicall(
            multicallBuilder(
                MultiCall({
                    target: address(universalAdapter),
                    callData: abi.encodeCall(universalAdapter.revokeAdapterAllowances, (revocations))
                })
            )
        );
    }

    /// @notice [UA-4]: UniversalAdapter `revokeAllowances` works as expected
    function test_UA_04_revokeAllowances_works_as_expected() public {
        (address creditAccount,) = _openTestCreditAccount();

        evm.prank(USER);
        creditFacade.multicall(
            multicallBuilder(
                MultiCall({
                    target: address(adapterMock1),
                    callData: abi.encodeCall(adapterMock1.approveToken, (usdc, 10))
                }),
                MultiCall({
                    target: address(adapterMock1),
                    callData: abi.encodeCall(adapterMock1.approveToken, (dai, 20))
                }),
                MultiCall({
                    target: address(adapterMock2),
                    callData: abi.encodeCall(adapterMock2.approveToken, (dai, 30))
                })
            )
        );

        RevocationPair[] memory revocations = new RevocationPair[](3);
        revocations[0] = RevocationPair({spender: address(targetMock1), token: usdc});
        revocations[1] = RevocationPair({spender: address(targetMock2), token: usdc});
        revocations[2] = RevocationPair({spender: address(targetMock2), token: dai});

        evm.expectCall(
            address(creditManager),
            abi.encodeCall(ICreditManagerV2.approveCreditAccount, (address(targetMock1), usdc, 1))
        );
        evm.expectCall(
            address(creditManager),
            abi.encodeCall(ICreditManagerV2.approveCreditAccount, (address(targetMock2), dai, 1))
        );

        evm.prank(USER);
        creditFacade.multicall(
            multicallBuilder(
                MultiCall({
                    target: address(universalAdapter),
                    callData: abi.encodeCall(universalAdapter.revokeAdapterAllowances, (revocations))
                })
            )
        );

        expectAllowance(usdc, creditAccount, address(targetMock1), 1);
        expectAllowance(dai, creditAccount, address(targetMock1), 20);
        expectAllowance(usdc, creditAccount, address(targetMock2), 0);
        expectAllowance(dai, creditAccount, address(targetMock2), 1);
    }
}
