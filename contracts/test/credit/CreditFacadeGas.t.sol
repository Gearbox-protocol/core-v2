// SPDX-License-Identifier: UNLICENSED
// Gearbox Protocol. Generalized leverage for DeFi protocols
// (c) Gearbox Holdings, 2022
pragma solidity ^0.8.10;

import { IAddressProvider } from "../../interfaces/IAddressProvider.sol";
import { IACL } from "../../interfaces/IACL.sol";
import { IContractsRegister } from "../../interfaces/IContractsRegister.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { IERC20Metadata } from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import { IPoolService } from "../../interfaces/IPoolService.sol";

import { ICreditFacade, ICreditFacadeExtended } from "../../interfaces/ICreditFacade.sol";
import { ICreditManagerV2 } from "../../interfaces/ICreditManagerV2.sol";
import { ICreditConfigurator } from "../../interfaces/ICreditConfigurator.sol";
import { IDegenNFT } from "../../interfaces/IDegenNFT.sol";

// DATA
import { MultiCall } from "../../libraries/MultiCall.sol";

// TESTS
import "../lib/constants.sol";

import { Test } from "forge-std/Test.sol";
import { console } from "forge-std/console.sol";

contract CreditFacadeGasTest is Test {
    address ap = 0xcF64698AFF7E5f27A11dff868AF228653ba53be0;
    IContractsRegister cr;
    IACL acl;

    ICreditFacade cf;
    ICreditManagerV2 cm;
    ICreditConfigurator cc;

    address configurator;
    address treasury;

    constructor() Test() {
        cr = IContractsRegister(IAddressProvider(ap).getContractsRegister());
        acl = IACL(IAddressProvider(ap).getACL());
        configurator = acl.owner();
        treasury = IAddressProvider(ap).getTreasuryContract();
    }

    modifier allCMs() {
        address[] memory cms = cr.getCreditManagers();
        uint256 len = cms.length;
        for (uint256 i; i < len; i++) {
            cm = ICreditManagerV2(cms[i]);

            if (cm.version() < 2) continue;

            cf = ICreditFacade(cm.creditFacade());
            cc = ICreditConfigurator(cm.creditConfigurator());

            IDegenNFT degenNft = IDegenNFT(cf.degenNFT());
            vm.prank(degenNft.minter());
            degenNft.mint(USER, 2);

            vm.prank(configurator);
            cc.setMaxEnabledTokens(255);
            _;
        }
    }

    function setUp() public {}

    function test_gas_all_tokens() public allCMs {
        address undelrying = cm.underlying();
        console.log(
            "CreditManager [%s]: %s ",
            IERC20Metadata(undelrying).symbol(),
            address(cm)
        );

        deal(undelrying, USER, RAY);

        address pool = cm.pool();

        (uint256 minDebt, ) = cf.limits();

        vm.startPrank(USER);
        IERC20(undelrying).approve(pool, type(uint256).max);
        IPoolService(pool).addLiquidity(minDebt * 2, USER, 0);

        IERC20(undelrying).approve(address(cm), type(uint256).max);
        cf.openCreditAccount(minDebt, USER, 200, 0);

        vm.stopPrank();

        deal(undelrying, LIQUIDATOR, RAY);

        uint256 len = cm.collateralTokensCount();

        address[] memory tokens = new address[](len);

        uint256 j;

        for (uint256 i; i < len; i++) {
            (address token, ) = cm.collateralTokens(i);

            vm.startPrank(USER);

            try
                cf.multicall(
                    multicallBuilder(
                        MultiCall({
                            target: address(cf),
                            callData: abi.encodeWithSelector(
                                ICreditFacadeExtended.enableToken.selector,
                                token
                            )
                        })
                    )
                )
            {
                tokens[j] = token;
                ++j;
            } catch {
                console.log("cant enable enableToken", token);
            }

            vm.stopPrank();
        }

        // increase block number to make liquidation possible
        vm.roll(block.number + 1);

        vm.prank(LIQUIDATOR);
        IERC20(undelrying).approve(address(cm), type(uint256).max);

        address ca = cm.getCreditAccountOrRevert(USER);

        // simulate dust on all tokens
        // it's automatically make liquidation possible
        for (uint256 i; i < len; ++i) {
            address token = tokens[i];
            if (token == address(0)) break;
            vm.mockCall(
                token,
                abi.encodeWithSelector(IERC20.balanceOf.selector, ca),
                abi.encode(200)
            );
        }

        uint256 gasBefore = gasleft();
        vm.prank(LIQUIDATOR);
        cf.liquidateCreditAccount(
            USER,
            LIQUIDATOR,
            type(uint256).max,
            new MultiCall[](0)
        );
        console.log("dust worst case gas used", gasBefore - gasleft());
        console.log("");
    }

    function multicallBuilder(MultiCall memory call1)
        internal
        pure
        returns (MultiCall[] memory calls)
    {
        calls = new MultiCall[](1);
        calls[0] = call1;
    }
}
