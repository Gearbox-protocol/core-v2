// SPDX-License-Identifier: UNLICENSED
// Gearbox Protocol. Generalized leverage for DeFi protocols
// (c) Gearbox Holdings, 2022
pragma solidity ^0.8.10;

import { ERC20 } from "@solmate/tokens/ERC20.sol";

import { PoolService } from "../../pool/PoolService.sol";
import { PoolServiceERC4626 } from "../../pool/ERC4626/PoolServiceERC4626.sol";
import { PoolERC4626Factory } from "../../factories/PoolERC4626Factory.sol";
import { ACL } from "../../core/ACL.sol";
import { AddressProvider } from "../../core/AddressProvider.sol";

// TEST
import "../lib/constants.sol";

contract PoolServiceERC4626ForkTest is DSTest {
    CheatCodes vm = CheatCodes(HEVM_ADDRESS);

    uint256 FORK_START_BLOCK = 16911200;

    address constant WETH_POOL_SERVICE =
        0xB03670c20F87f2169A7c4eBE35746007e9575901;
    address constant WETH_WHALE_1 = 0xF04a5cC80B1E94C69B48f5ee68a08CD2F09A7c3E;
    address constant WETH_WHALE_2 = 0x2F0b23f53734252Bda2277357e97e1517d6B042A;

    PoolERC4626Factory public poolERC4626Factory;
    PoolServiceERC4626 public poolServiceErc4626;
    PoolService public poolService;
    ERC20 public underlying;
    ERC20 public dieselToken;

    ACL acl;
    address constant ACL_OWNER = 0xA7D5DDc1b8557914F158076b228AA91eF613f1D5;

    function setUp() public {
        // create and select mainnet fork
        vm.createSelectFork(vm.envString("MAINNET_RPC_URL"), FORK_START_BLOCK);

        // create poolERC4626Factory
        poolERC4626Factory = new PoolERC4626Factory();

        poolService = PoolService(WETH_POOL_SERVICE);

        underlying = ERC20(poolService.underlyingToken());
        dieselToken = ERC20(poolService.dieselToken());

        // Get poolServiceErc4626 instance from the factory
        poolServiceErc4626 = poolERC4626Factory.createPoolERC4626(
            address(poolService)
        );

        vm.label(WETH_WHALE_1, "WHALE_1");
        vm.label(WETH_WHALE_2, "WHALE_2");
        vm.label(CONFIGURATOR, "CONFIGURATOR");
        vm.label(ACL_OWNER, "ACL_OWNER");
        vm.label(WETH_POOL_SERVICE, "WETH_POOL_SERVICE");
        vm.label(address(poolServiceErc4626), "PoolServiceERC4626");
        vm.label(address(dieselToken), "DieselToken");
        vm.label(address(underlying), "Underlying");

        acl = ACL(AddressProvider(poolService.addressProvider()).getACL());
        vm.label(address(acl), "ACL");
    }

    // [WPS-1]: mintedSharesToBurnAddress, correct pool service
    function test_WPS_01_start_parameters_correct() public {
        assertEq(poolServiceErc4626.balanceOf(address(0)), 100000);
        assertEq(address(poolServiceErc4626.poolService()), WETH_POOL_SERVICE);
    }

    // [WPS-2]: deposit with same/different sender and receiver address
    function test_WPS_02_deposit_works_correctly() public {
        // set a deposit Amount
        uint256 depositAmount = 100e18;

        vm.startPrank(WETH_WHALE_1);

        // max approval
        underlying.approve(address(poolServiceErc4626), type(uint256).max);

        /////////////////////
        // sender = receiver
        /////////////////////

        // expected amount of diesel amounts to be received by wrapper
        uint256 expectedDieselAmount1 = poolService.toDiesel(depositAmount);

        // deposit with receiver = sender
        uint256 whale1ShareAmount = poolServiceErc4626.deposit(
            depositAmount,
            WETH_WHALE_1
        );

        // check diesel amounts and shares
        assertEq(
            dieselToken.balanceOf(address(poolServiceErc4626)),
            expectedDieselAmount1
        );
        assertEq(whale1ShareAmount, depositAmount);

        /////////////////////
        // sender != receiver
        /////////////////////

        // expected amount of diesel amounts to be received by wrapper
        uint256 expectedDieselAmount2 = poolService.toDiesel(depositAmount);

        // deposit with receiver != sender
        uint256 whale2ShareAmount = poolServiceErc4626.deposit(
            depositAmount,
            WETH_WHALE_2
        );
        // check diesel amounts and shares
        assertEq(
            dieselToken.balanceOf(address(poolServiceErc4626)),
            expectedDieselAmount1 + expectedDieselAmount2
        );
        assertEq(whale2ShareAmount, poolServiceErc4626.balanceOf(WETH_WHALE_2));

        vm.stopPrank();
    }

    // [WPS-3]: maxDeposit works correctly
    function test_WPS_03_max_deposit_works_correctly() public {
        vm.prank(ACL_OWNER);
        acl.addPausableAdmin(CONFIGURATOR);
        vm.prank(ACL_OWNER);
        acl.addUnpausableAdmin(CONFIGURATOR);

        vm.prank(CONFIGURATOR);
        // pause pool service
        poolService.pause();

        vm.prank(WETH_WHALE_1);
        // maxDeposit = 0 in paused state
        assertEq(poolServiceErc4626.maxDeposit(WETH_WHALE_1), 0);

        vm.prank(CONFIGURATOR);
        // unpause pool service
        poolService.unpause();

        vm.prank(WETH_WHALE_1);
        uint256 expectedMaxDeposit = poolService.expectedLiquidityLimit() -
            poolService.expectedLiquidity();
        assertEq(
            poolServiceErc4626.maxDeposit(WETH_WHALE_1),
            expectedMaxDeposit
        );
    }

    // [WPS-4]: mint with same/different sender and receiver address
    function test_WPS_04_mint_works_correctly() public {
        // set a mint Amount
        uint256 mintAmount = 100e18;

        vm.startPrank(WETH_WHALE_1);

        // max approval
        underlying.approve(address(poolServiceErc4626), type(uint256).max);

        /////////////////////
        // sender = receiver
        /////////////////////

        // expected amount of diesel amounts to be received by wrapper
        uint256 expectedDieselAmount1 = poolService.toDiesel(mintAmount);

        // mint with receiver = sender
        poolServiceErc4626.mint(mintAmount, WETH_WHALE_1);

        // check diesel amounts and shares
        assertEq(
            dieselToken.balanceOf(address(poolServiceErc4626)),
            expectedDieselAmount1
        );
        assertEq(poolServiceErc4626.balanceOf(WETH_WHALE_1), mintAmount);

        /////////////////////
        // sender != receiver
        /////////////////////

        // expected amount of diesel amounts to be received by wrapper
        uint256 expectedDieselAmount2 = poolService.toDiesel(
            poolServiceErc4626.previewMint(mintAmount)
        );

        // mint with receiver != sender
        poolServiceErc4626.mint(mintAmount, WETH_WHALE_2);

        // check diesel amounts and shares
        assertEq(
            dieselToken.balanceOf(address(poolServiceErc4626)),
            expectedDieselAmount1 + expectedDieselAmount2
        );
        assertEq(mintAmount, poolServiceErc4626.balanceOf(WETH_WHALE_2));

        vm.stopPrank();
    }

    // [WPS-5]: maxMint works correctly
    function test_WPS_05_max_mint_works_correctly() public {
        vm.prank(ACL_OWNER);
        acl.addPausableAdmin(CONFIGURATOR);
        vm.prank(ACL_OWNER);
        acl.addUnpausableAdmin(CONFIGURATOR);

        vm.prank(CONFIGURATOR);
        // pause pool service
        poolService.pause();

        vm.prank(WETH_WHALE_1);
        // maxMint = 0 in paused state
        assertEq(poolServiceErc4626.maxMint(WETH_WHALE_1), 0);

        vm.prank(CONFIGURATOR);
        // unpause pool service
        poolService.unpause();

        vm.prank(WETH_WHALE_1);
        uint256 expectedMaxMint = poolServiceErc4626.convertToShares(
            poolService.expectedLiquidityLimit() -
                poolService.expectedLiquidity()
        );
        assertEq(poolServiceErc4626.maxMint(WETH_WHALE_1), expectedMaxMint);
    }

    // [WPS-6]: withdraw with same/different sender and owner address
    function test_WPS_06_withdraw_works_correctly() public {
        // set a withdraw Amount
        uint256 withdrawAmount = 100e18;

        vm.startPrank(WETH_WHALE_1);

        // max approval
        underlying.approve(address(poolServiceErc4626), type(uint256).max);

        // deposit assets for future withdraw
        poolServiceErc4626.deposit(withdrawAmount * 3, WETH_WHALE_1);

        /////////////////////
        // sender = owner
        /////////////////////

        // expected amount of diesel amounts to be burned by wrapper
        uint256 expectedDieselAmount1 = poolService.toDiesel(withdrawAmount);

        // diesel amount of wrapper before withdraw
        uint256 wrapperDieselAmount1 = dieselToken.balanceOf(
            address(poolServiceErc4626)
        );
        // shares amount of WETH_WHALE_1 before withdraw
        uint256 beforeWithdrawShareAmount1 = poolServiceErc4626.balanceOf(
            WETH_WHALE_1
        );

        // withdraw with sender = owner
        uint256 sharesBurned1 = poolServiceErc4626.withdraw(
            withdrawAmount,
            WETH_WHALE_1,
            WETH_WHALE_1
        );

        // check diesel amounts and shares
        assertEq(
            dieselToken.balanceOf(address(poolServiceErc4626)),
            wrapperDieselAmount1 - expectedDieselAmount1 - 1
        );
        assertEq(
            poolServiceErc4626.balanceOf(WETH_WHALE_1),
            beforeWithdrawShareAmount1 - sharesBurned1
        );

        /////////////////////
        // sender != owner
        /////////////////////

        // set allowance for WETH_WHALE_2
        poolServiceErc4626.approve(WETH_WHALE_2, type(uint256).max);

        vm.stopPrank();

        vm.startPrank(WETH_WHALE_2);

        // expected amount of diesel amounts to be burned by wrapper
        uint256 expectedDieselAmount2 = poolService.toDiesel(withdrawAmount);

        // diesel amount of wrapper before withdraw
        uint256 wrapperDieselAmount2 = dieselToken.balanceOf(
            address(poolServiceErc4626)
        );
        // shares amount of WETH_WHALE_1 before withdraw
        uint256 beforeWithdrawShareAmount2 = poolServiceErc4626.balanceOf(
            WETH_WHALE_1
        );
        // assets amount of WETH_WHALE_2 before withdraw
        uint256 beforeWithdrawAssetsAmount = underlying.balanceOf(WETH_WHALE_2);

        // withdraw with sender != owner
        uint256 sharesBurned2 = poolServiceErc4626.withdraw(
            withdrawAmount,
            WETH_WHALE_2,
            WETH_WHALE_1
        );

        // check diesel amounts and shares
        assertEq(
            dieselToken.balanceOf(address(poolServiceErc4626)),
            wrapperDieselAmount2 - expectedDieselAmount2 - 1
        );
        assertEq(
            poolServiceErc4626.balanceOf(WETH_WHALE_1),
            beforeWithdrawShareAmount2 - sharesBurned2
        );
        assertEq(
            underlying.balanceOf(WETH_WHALE_2),
            beforeWithdrawAssetsAmount + withdrawAmount
        );

        vm.stopPrank();
    }

    // [WPS-7]: maxWithdraw works correctly
    function test_WPS_07_max_withdraw_works_correctly() public {
        vm.prank(ACL_OWNER);
        acl.addPausableAdmin(CONFIGURATOR);
        vm.prank(ACL_OWNER);
        acl.addUnpausableAdmin(CONFIGURATOR);

        vm.prank(CONFIGURATOR);
        // pause pool service
        poolService.pause();

        vm.prank(WETH_WHALE_1);
        // maxWithdraw = 0 in paused state
        assertEq(poolServiceErc4626.maxWithdraw(WETH_WHALE_1), 0);

        vm.prank(CONFIGURATOR);
        // unpause pool service
        poolService.unpause();

        vm.prank(WETH_WHALE_1);
        uint256 expectedMaxWithdraw = poolServiceErc4626.convertToAssets(
            poolServiceErc4626.balanceOf(WETH_WHALE_1)
        );
        assertEq(
            poolServiceErc4626.maxWithdraw(WETH_WHALE_1),
            expectedMaxWithdraw
        );
    }

    // [WPS-8]: redeem with same/different sender and owner address
    function test_WPS_08_redeem_works_correctly() public {
        // set a redeem Amount
        uint256 redeemAmount = 100e18;

        vm.startPrank(WETH_WHALE_1);

        // max approval
        underlying.approve(address(poolServiceErc4626), type(uint256).max);

        // deposit assets for future redeem
        poolServiceErc4626.deposit(redeemAmount * 3, WETH_WHALE_1);

        /////////////////////
        // sender = owner
        /////////////////////

        // expected amount of diesel amounts to be burned by wrapper
        uint256 expectedDieselAmount1 = poolService.toDiesel(
            poolServiceErc4626.previewRedeem(redeemAmount)
        );

        // diesel amount of wrapper before redeem
        uint256 wrapperDieselAmount1 = dieselToken.balanceOf(
            address(poolServiceErc4626)
        );
        // shares amount of WETH_WHALE_1 before redeem
        uint256 beforeRedeemShareAmount1 = poolServiceErc4626.balanceOf(
            WETH_WHALE_1
        );

        // redeem with sender = owner
        poolServiceErc4626.redeem(redeemAmount, WETH_WHALE_1, WETH_WHALE_1);

        // check diesel amounts and shares
        assertEq(
            dieselToken.balanceOf(address(poolServiceErc4626)),
            wrapperDieselAmount1 - expectedDieselAmount1 - 1
        );
        assertEq(
            poolServiceErc4626.balanceOf(WETH_WHALE_1),
            beforeRedeemShareAmount1 - redeemAmount
        );

        /////////////////////
        // sender != owner
        /////////////////////

        // set allowance for WETH_WHALE_2
        poolServiceErc4626.approve(WETH_WHALE_2, type(uint256).max);

        vm.stopPrank();

        vm.startPrank(WETH_WHALE_2);

        // expected amount of diesel amounts to be burned by wrapper
        uint256 expectedDieselAmount2 = poolService.toDiesel(
            poolServiceErc4626.previewRedeem(redeemAmount)
        );

        // diesel amount of wrapper before withdraw
        uint256 wrapperDieselAmount2 = dieselToken.balanceOf(
            address(poolServiceErc4626)
        );
        // shares amount of WETH_WHALE_1 before withdraw
        uint256 beforeRedeemShareAmount2 = poolServiceErc4626.balanceOf(
            WETH_WHALE_1
        );
        // assets amount of WETH_WHALE_2 before redeem
        uint256 beforeRedeemAssetsAmount = underlying.balanceOf(WETH_WHALE_2);

        // redeem with sender != owner
        uint256 assetsReceived = poolServiceErc4626.redeem(
            redeemAmount,
            WETH_WHALE_2,
            WETH_WHALE_1
        );

        // check diesel amounts and shares
        assertEq(
            dieselToken.balanceOf(address(poolServiceErc4626)),
            wrapperDieselAmount2 - expectedDieselAmount2 - 1
        );
        assertEq(
            poolServiceErc4626.balanceOf(WETH_WHALE_1),
            beforeRedeemShareAmount2 - redeemAmount
        );
        assertEq(
            underlying.balanceOf(WETH_WHALE_2),
            beforeRedeemAssetsAmount + assetsReceived
        );

        vm.stopPrank();
    }

    // [WPS-9]: maxRedeem works correctly
    function test_WPS_09_max_redeem_works_correctly() public {
        vm.prank(ACL_OWNER);
        acl.addPausableAdmin(CONFIGURATOR);
        vm.prank(ACL_OWNER);
        acl.addUnpausableAdmin(CONFIGURATOR);

        vm.prank(CONFIGURATOR);
        // pause pool service
        poolService.pause();

        vm.prank(WETH_WHALE_1);
        // maxRedeem = 0 in paused state
        assertEq(poolServiceErc4626.maxRedeem(WETH_WHALE_1), 0);

        vm.prank(CONFIGURATOR);
        // unpause pool service
        poolService.unpause();

        vm.prank(WETH_WHALE_1);
        uint256 expectedMaxRedeem = poolServiceErc4626.balanceOf(WETH_WHALE_1);
        vm.prank(WETH_WHALE_1);
        assertEq(poolServiceErc4626.maxRedeem(WETH_WHALE_1), expectedMaxRedeem);
    }
}
