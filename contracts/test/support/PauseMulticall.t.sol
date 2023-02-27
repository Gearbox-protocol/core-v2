// SPDX-License-Identifier: UNLICENSED
// Gearbox Protocol. Generalized leverage for DeFi protocols
// (c) Gearbox Holdings, 2022
pragma solidity ^0.8.10;

import {IAddressProvider} from "../../interfaces/IAddressProvider.sol";
import {ContractsRegister} from "../../core/ContractsRegister.sol";
import {PauseMulticall} from "../../support/PauseMulticall.sol";
import {CreditManager, UNIVERSAL_CONTRACT} from "../../credit/CreditManager.sol";

// TESTS
import "../lib/constants.sol";

// EXCEPTIONS
import {CallerNotPausableAdminException} from "../../interfaces/IErrors.sol";

// MOCKS
import {PoolServiceMock} from "../mocks/pool/PoolServiceMock.sol";

// SUITES
import {TokensTestSuite} from "../suites/TokensTestSuite.sol";
import {Tokens} from "../config/Tokens.sol";
import {CreditManagerTestSuite} from "../suites/CreditManagerTestSuite.sol";
import {CreditConfig} from "../config/CreditConfig.sol";

/// @title Pause multicall test
/// @notice Test for pause multicall
contract PauseMulticallTest is DSTest {
    CheatCodes evm = CheatCodes(HEVM_ADDRESS);

    CreditManagerTestSuite cms;

    TokensTestSuite tokenTestSuite;
    IAddressProvider addressProvider;
    CreditManager creditManager;
    CreditManager creditManager2;
    PoolServiceMock poolMock;
    PoolServiceMock poolMock2;
    address underlying;

    ContractsRegister cr;

    PauseMulticall pm;

    function setUp() public {
        tokenTestSuite = new TokensTestSuite();
        CreditConfig creditConfig = new CreditConfig(
            tokenTestSuite,
            Tokens.DAI
        );
        cms = new CreditManagerTestSuite(creditConfig, false, false);

        addressProvider = cms.addressProvider();

        poolMock = cms.poolMock();
        creditManager = cms.creditManager();

        underlying = creditManager.underlying();

        cr = cms.cr();

        poolMock2 = new PoolServiceMock(address(addressProvider), underlying);

        evm.prank(CONFIGURATOR);
        cr.addPool(address(poolMock2));

        creditManager2 = new CreditManager(address(poolMock2));

        evm.prank(CONFIGURATOR);
        cr.addCreditManager(address(creditManager2));

        pm = new PauseMulticall(address(addressProvider));

        evm.startPrank(CONFIGURATOR);
        cms.acl().addPausableAdmin(address(pm));
        cms.acl().addPausableAdmin(USER);
        evm.stopPrank();
    }

    ///
    /// TESTS
    ///

    /// @dev [PM-01]: Constructor sets correct values
    function test_PM_01_constructor_sets_correct_values() public {
        assertEq(address(pm.acl()), address(cms.acl()), "ACL set incorrectly");

        assertEq(address(pm.cr()), address(cr), "ContractsRegister set incorrectly");
    }

    /// @dev [PM-02]: pauseAllCreditManagers correctly pauses all CMs
    function test_PM_02_pauseAllCreditManagers_works_correctly() public {
        evm.prank(USER);
        pm.pauseAllCreditManagers();

        assertTrue(creditManager.paused(), "Credit manager 1 not paused");

        assertTrue(creditManager2.paused(), "Credit manager 2 not paused");
    }

    /// @dev [PM-03]: pauseAllPools correctly pauses all pools
    function test_PM_03_pauseAllPools_works_correctly() public {
        evm.prank(USER);
        pm.pauseAllPools();

        assertTrue(poolMock.paused(), "Pool 1 not paused");

        assertTrue(poolMock2.paused(), "Pool 2 not paused");
    }

    /// @dev [PM-04]: pauseAllContracts correctly pauses all pools
    function test_PM_04_pauseAllContracts_works_correctly() public {
        evm.prank(USER);
        pm.pauseAllContracts();

        assertTrue(creditManager.paused(), "Credit manager 1 not paused");

        assertTrue(creditManager2.paused(), "Credit manager 2 not paused");

        assertTrue(poolMock.paused(), "Pool 1 not paused");

        assertTrue(poolMock2.paused(), "Pool 2 not paused");
    }

    /// @dev [PM-05]: pauseMulticall functions revert for non-admin
    function test_PM_05_functions_revert_when_caller_not_pausable_admin() public {
        evm.expectRevert(CallerNotPausableAdminException.selector);
        evm.prank(FRIEND);
        pm.pauseAllCreditManagers();

        evm.expectRevert(CallerNotPausableAdminException.selector);
        evm.prank(FRIEND);
        pm.pauseAllPools();

        evm.expectRevert(CallerNotPausableAdminException.selector);
        evm.prank(FRIEND);
        pm.pauseAllContracts();
    }
}
