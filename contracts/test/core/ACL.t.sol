// SPDX-License-Identifier: BUSL-1.1
// Gearbox Protocol. Generalized leverage for DeFi protocols
// (c) Gearbox Holdings, 2022
pragma solidity ^0.8.10;

import { ACL } from "../../core/ACL.sol";

import { IACLEvents, IACLExceptions } from "../../interfaces/IACL.sol";

// TEST
import "../lib/constants.sol";

/// @title AccessControlList
/// @notice Maintains the list of admin addresses
contract ACLTest is DSTest, IACLEvents, IACLExceptions {
    CheatCodes evm = CheatCodes(HEVM_ADDRESS);

    ACL acl;

    function setUp() public {
        evm.prank(CONFIGURATOR);
        acl = new ACL();
    }

    // [ACL-1]: addPausableAdmin, addUnpausableAdmin, removePausableAdmin, removeUnpausableAdmin reverts if called by non-owner
    function test_ACL_01_add_remove_reverts_on_non_owner() public {
        evm.startPrank(USER);

        evm.expectRevert(bytes(OWNABLE_ERROR));
        acl.addPausableAdmin(DUMB_ADDRESS);

        evm.expectRevert(bytes(OWNABLE_ERROR));
        acl.addUnpausableAdmin(DUMB_ADDRESS);

        evm.expectRevert(bytes(OWNABLE_ERROR));
        acl.removePausableAdmin(DUMB_ADDRESS);

        evm.expectRevert(bytes(OWNABLE_ERROR));
        acl.removeUnpausableAdmin(DUMB_ADDRESS);

        evm.stopPrank();
    }

    // [ACL-2]: addPausableAdmin correctly adds pool
    function test_ACL_02_addPausableAdmin_adds_pool() public {
        assertTrue(!acl.isPausableAdmin(DUMB_ADDRESS));

        evm.expectEmit(true, false, false, false);
        emit PausableAdminAdded(DUMB_ADDRESS);

        evm.prank(CONFIGURATOR);
        acl.addPausableAdmin(DUMB_ADDRESS);

        assertTrue(acl.isPausableAdmin(DUMB_ADDRESS));
    }

    // [ACL-3]: removePausableAdmin removes pausable admin
    function test_ACL_03_removePausableAdmin_removes_admin() public {
        evm.startPrank(CONFIGURATOR);

        acl.addPausableAdmin(DUMB_ADDRESS);
        assertTrue(acl.isPausableAdmin(DUMB_ADDRESS));

        evm.expectEmit(true, false, false, false);
        emit PausableAdminRemoved(DUMB_ADDRESS);

        acl.removePausableAdmin(DUMB_ADDRESS);

        assertTrue(!acl.isPausableAdmin(DUMB_ADDRESS));

        evm.stopPrank();
    }

    // [ACL-3A]: removePausableAdmin reverts for non-admins
    function test_ACL_03A_removePausable_admin_reverts_for_non_admins() public {
        evm.startPrank(CONFIGURATOR);

        evm.expectRevert(
            abi.encodeWithSelector(
                AddressNotPausableAdminException.selector,
                DUMB_ADDRESS
            )
        );
        acl.removePausableAdmin(DUMB_ADDRESS);

        evm.stopPrank();
    }

    // [ACL-4]: addUnpausableAdmin correctly adds pool
    function test_ACL_04_addUnpausableAdmin_adds_pool() public {
        assertTrue(!acl.isUnpausableAdmin(DUMB_ADDRESS));

        evm.expectEmit(true, false, false, false);
        emit UnpausableAdminAdded(DUMB_ADDRESS);

        evm.prank(CONFIGURATOR);
        acl.addUnpausableAdmin(DUMB_ADDRESS);

        assertTrue(acl.isUnpausableAdmin(DUMB_ADDRESS));
    }

    // [ACL-5]: removeUnpausableAdmin removes unpausable admin
    function test_ACL_05_removeUnpausableAdmin_removes_admin() public {
        evm.startPrank(CONFIGURATOR);

        acl.addUnpausableAdmin(DUMB_ADDRESS);
        assertTrue(acl.isUnpausableAdmin(DUMB_ADDRESS));

        evm.expectEmit(true, false, false, false);
        emit UnpausableAdminRemoved(DUMB_ADDRESS);

        acl.removeUnpausableAdmin(DUMB_ADDRESS);

        assertTrue(!acl.isUnpausableAdmin(DUMB_ADDRESS));

        evm.stopPrank();
    }

    // [ACL-5A]: removeUnpausableAdmin reverts for non-admins
    function test_ACL_05A_removeUnpausable_admin_reverts_for_non_admins()
        public
    {
        evm.startPrank(CONFIGURATOR);

        evm.expectRevert(
            abi.encodeWithSelector(
                AddressNotUnpausableAdminException.selector,
                DUMB_ADDRESS
            )
        );
        acl.removeUnpausableAdmin(DUMB_ADDRESS);

        evm.stopPrank();
    }

    // [ACL-6]: isConfigurator works properly
    function test_ACL_06_isConfigurator_correct() public {
        assertTrue(acl.isConfigurator(CONFIGURATOR));
        assertTrue(!acl.isConfigurator(DUMB_ADDRESS));
    }

    // [ACL-7]: transferOwnership/claimOwnership functions work correctly
    function test_ACL_07_claimable_functions_work_correctly() public {
        assertEq(acl.pendingOwner(), address(0), "Incorrect pending owner");

        evm.prank(CONFIGURATOR);
        acl.transferOwnership(DUMB_ADDRESS);

        assertEq(acl.pendingOwner(), DUMB_ADDRESS, "Incorrect pending owner");

        evm.expectRevert("Claimable: Sender is not pending owner");
        evm.prank(USER);
        acl.claimOwnership();

        evm.prank(DUMB_ADDRESS);
        acl.claimOwnership();

        assertEq(acl.pendingOwner(), address(0), "Incorrect pending owner");
        assertEq(acl.owner(), DUMB_ADDRESS, "Incorrect owner");
    }
}
