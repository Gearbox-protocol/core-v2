// SPDX-License-Identifier: UNLICENSED
// Gearbox Protocol. Generalized leverage for DeFi protocols
// (c) Gearbox Holdings, 2022
pragma solidity ^0.8.10;

import { AddressProvider } from "../../core/AddressProvider.sol";
import { IAddressProviderEvents } from "../../interfaces/IAddressProvider.sol";

import { Errors } from "../../libraries/Errors.sol";

// TEST
import "../lib/constants.sol";

/// @title AddressRepository
/// @notice Stores addresses of deployed contracts
contract AddressProviderTest is DSTest, IAddressProviderEvents {
    CheatCodes evm = CheatCodes(HEVM_ADDRESS);

    AddressProvider ap;

    function setUp() public {
        evm.prank(CONFIGURATOR);
        ap = new AddressProvider();
    }

    // [AP-1]: getAddress reverts if contact not found
    function test_AP_01_getAddress_reverts_if_contact_not_found() public {
        evm.expectRevert(bytes(Errors.AS_ADDRESS_NOT_FOUND));
        ap.getAccountFactory();
    }

    // [AP-2]: _setAddress emits event correctly
    function test_AP_02_setAddress_emits_event_correctly() public {
        evm.expectEmit(true, true, false, false);
        emit AddressSet("CONTRACTS_REGISTER", DUMB_ADDRESS);

        evm.prank(CONFIGURATOR);
        ap.setContractsRegister(DUMB_ADDRESS);

        // Checks that constructor emits event. Can't predict event, btw checks the fact only
        evm.expectEmit(true, false, false, false);
        emit AddressSet("ADDRESS_PROVIDER", DUMB_ADDRESS);

        new AddressProvider();
    }

    // [AP-3]: setACL correctly sets ACL
    function test_AP_03_setACL_correctly_sets_ACL() public {
        evm.prank(CONFIGURATOR);
        ap.setACL(DUMB_ADDRESS);
        assertEq(ap.getACL(), DUMB_ADDRESS);
    }

    // [AP-4]: setContractsRegister correctly sets ContractsRegister
    function test_AP_04_setContractsRegister_correctly_sets_ContractsRegister()
        public
    {
        evm.prank(CONFIGURATOR);
        ap.setContractsRegister(DUMB_ADDRESS);
        assertEq(ap.getContractsRegister(), DUMB_ADDRESS);
    }

    // [AP-5]: setPriceOracle correctly sets PriceOracle
    function test_AP_05_setPriceOracle_correctly_sets_PriceOracle() public {
        evm.prank(CONFIGURATOR);
        ap.setPriceOracle(DUMB_ADDRESS);
        assertEq(ap.getPriceOracle(), DUMB_ADDRESS);
    }

    // [AP-6]: setAccountFactory correctly sets AccountFactory
    function test_AP_06_setAccountFactory_correctly_sets_AccountFactory()
        public
    {
        evm.prank(CONFIGURATOR);
        ap.setAccountFactory(DUMB_ADDRESS);
        assertEq(ap.getAccountFactory(), DUMB_ADDRESS);
    }

    // [AP-7]: setDataCompressor correctly sets DataCompressor
    function test_AP_07_setDataCompressor_correctly_sets_DataCompressor()
        public
    {
        evm.prank(CONFIGURATOR);
        ap.setDataCompressor(DUMB_ADDRESS);
        assertEq(ap.getDataCompressor(), DUMB_ADDRESS);
    }

    // [AP-8]: setTreasuryContract correctly sets TreasuryContract
    function test_AP_08_setTreasuryContract_correctly_sets_TreasuryContract()
        public
    {
        evm.prank(CONFIGURATOR);
        ap.setTreasuryContract(DUMB_ADDRESS);
        assertEq(ap.getTreasuryContract(), DUMB_ADDRESS);
    }

    // [AP-9]: setGearToken correctly sets GearToken
    function test_AP_09_setGearToken_correctly_sets_GearToken() public {
        evm.prank(CONFIGURATOR);
        ap.setGearToken(DUMB_ADDRESS);
        assertEq(ap.getGearToken(), DUMB_ADDRESS);
    }

    // [AP-10]: setWethToken correctly sets WethToken
    function test_AP_10_setWethToken_correctly_sets_WethToken() public {
        evm.prank(CONFIGURATOR);
        ap.setWethToken(DUMB_ADDRESS);
        assertEq(ap.getWethToken(), DUMB_ADDRESS);
    }

    // [AP-11]: setWETHGateway correctly sets WethGateway
    function test_AP_11_setWETHGateway_correctly_sets_WethGateway() public {
        evm.prank(CONFIGURATOR);
        ap.setWETHGateway(DUMB_ADDRESS);
        assertEq(ap.getWETHGateway(), DUMB_ADDRESS);
    }

    // [AP-12]: set functions revert if called by non-owner
    function test_AP_12_set_functions_revert_if_called_by_non_owner() public {
        evm.startPrank(USER);

        bytes memory OWNABLE_ERROR_BYTES = bytes(OWNABLE_ERROR);

        evm.expectRevert(OWNABLE_ERROR_BYTES);
        ap.setACL(DUMB_ADDRESS);

        evm.expectRevert(OWNABLE_ERROR_BYTES);
        ap.setContractsRegister(DUMB_ADDRESS);

        evm.expectRevert(OWNABLE_ERROR_BYTES);
        ap.setPriceOracle(DUMB_ADDRESS);

        evm.expectRevert(OWNABLE_ERROR_BYTES);
        ap.setAccountFactory(DUMB_ADDRESS);

        evm.expectRevert(OWNABLE_ERROR_BYTES);
        ap.setDataCompressor(DUMB_ADDRESS);

        evm.expectRevert(OWNABLE_ERROR_BYTES);
        ap.setTreasuryContract(DUMB_ADDRESS);

        evm.expectRevert(OWNABLE_ERROR_BYTES);
        ap.setGearToken(DUMB_ADDRESS);

        evm.expectRevert(OWNABLE_ERROR_BYTES);
        ap.setWethToken(DUMB_ADDRESS);

        evm.expectRevert(OWNABLE_ERROR_BYTES);
        ap.setWETHGateway(DUMB_ADDRESS);
    }

    // [AP-13]: transferOwnership/claimOwnership functions work correctly
    function test_AP_13_claimable_functions_work_correctly() public {
        assertEq(ap.pendingOwner(), address(0), "Incorrect pending owner");

        evm.prank(CONFIGURATOR);
        ap.transferOwnership(DUMB_ADDRESS);

        assertEq(ap.pendingOwner(), DUMB_ADDRESS, "Incorrect pending owner");

        evm.expectRevert("Claimable: Sender is not pending owner");
        evm.prank(USER);
        ap.claimOwnership();

        evm.prank(DUMB_ADDRESS);
        ap.claimOwnership();

        assertEq(ap.pendingOwner(), address(0), "Incorrect pending owner");
        assertEq(ap.owner(), DUMB_ADDRESS, "Incorrect owner");
    }
}
