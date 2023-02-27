// SPDX-License-Identifier: UNLICENSED
// Gearbox Protocol. Generalized leverage for DeFi protocols
// (c) Gearbox Holdings, 2022
pragma solidity ^0.8.10;

import {CreditManager} from "../../credit/CreditManager.sol";
import {CreditFacade} from "../../credit/CreditFacade.sol";

import {AccountFactory} from "../../core/AccountFactory.sol";

import {ICreditManagerV2, ICreditManagerV2Events} from "../../interfaces/ICreditManagerV2.sol";

import {AddressProvider} from "../../core/AddressProvider.sol";
import {IDegenNFT, IDegenNFTExceptions} from "../../interfaces/IDegenNFT.sol";
import {DegenNFT} from "../../tokens/DegenNFT.sol";

import "../lib/constants.sol";
import {CreditFacadeTestHelper} from "../helpers/CreditFacadeTestHelper.sol";

// EXCEPTIONS
import {NotImplementedException, CallerNotConfiguratorException} from "../../interfaces/IErrors.sol";

// SUITES
import {TokensTestSuite} from "../suites/TokensTestSuite.sol";
import {CreditFacadeTestSuite} from "../suites/CreditFacadeTestSuite.sol";
import {CreditConfig} from "../config/CreditConfig.sol";
import {Tokens} from "../config/Tokens.sol";

uint256 constant WETH_TEST_AMOUNT = 5 * WAD;
uint16 constant REFERRAL_CODE = 23;

/// @title CreditFacadeTest
/// @notice Designed for unit test purposes only
contract DegenNFTTest is DSTest, CreditFacadeTestHelper, IDegenNFTExceptions {
    DegenNFT degenNFT;
    AddressProvider addressProvider;
    AccountFactory accountFactory;

    function setUp() public {
        new Roles();

        TokensTestSuite tokenTestSuite = new TokensTestSuite();
        tokenTestSuite.topUpWETH{value: 100 * WAD}();

        CreditConfig creditConfig = new CreditConfig(
            tokenTestSuite,
            Tokens.DAI
        );

        cft = new CreditFacadeTestSuite(creditConfig);
        cft.testFacadeWithDegenNFT();

        creditManager = cft.creditManager();
        creditFacade = cft.creditFacade();
        creditConfigurator = cft.creditConfigurator();
        degenNFT = DegenNFT(creditFacade.degenNFT());
        addressProvider = cft.addressProvider();

        accountFactory = cft.af();
    }

    ///
    ///
    ///  TESTS
    ///
    ///

    ///
    ///  Degen NFT specific functions
    ///

    // @dev [DNFT-1]: constructor sets correct values
    function test_DNFT_01_constructor_sets_correct_values() public {
        assertEq(degenNFT.name(), "DegenNFT", "Incorrect name");

        assertEq(degenNFT.symbol(), "Gear-Degen", "Incorrect symbol");
    }

    // @dev [DNFT-2A]: setBaseUri reverts on non-Configurator
    function test_DNFT_02A_setBaseUri_reverts_on_non_Configurator() public {
        evm.expectRevert(CallerNotConfiguratorException.selector);
        degenNFT.setBaseUri("Degeneracy");
    }

    // @dev [DNFT-2B]: setMinter reverts on non-Configurator
    function test_DNFT_02B_setMinter_reverts_on_non_Configurator() public {
        evm.expectRevert(CallerNotConfiguratorException.selector);
        degenNFT.setMinter(DUMB_ADDRESS);
    }

    // @dev [DNFT-2C]: addCreditFacade reverts on non-Configurator
    function test_DNFT_02C_addCreditFacade_reverts_on_non_Configurator() public {
        evm.expectRevert(CallerNotConfiguratorException.selector);
        degenNFT.addCreditFacade(DUMB_ADDRESS);
    }

    // @dev [DNFT-2D]: removeCreditFacade reverts on non-Configurator
    function test_DNFT_02D_addCreditFacade_reverts_on_non_Configurator() public {
        evm.expectRevert(CallerNotConfiguratorException.selector);
        degenNFT.removeCreditFacade(DUMB_ADDRESS);
    }

    // @dev [DNFT-3]: mint reverts on non-Minter
    function test_DNFT_03_mint_reverts_on_non_minter() public {
        evm.expectRevert(abi.encodeWithSelector(MinterOnlyException.selector));
        evm.prank(FRIEND);
        degenNFT.mint(USER, 1);
    }

    // @dev [DNFT-4]: burn reverts on non-CreditFacade or configurator
    function test_DNFT_04_burn_reverts_on_non_CreditFacade() public {
        evm.expectRevert(abi.encodeWithSelector(CreditFacadeOrConfiguratorOnlyException.selector));
        evm.prank(FRIEND);
        degenNFT.burn(USER, 1);
    }

    // @dev [DNFT-5]: setBaseUri correctly sets URI
    function test_DNFT_05_setBasUri_correctly_sets_uri() public {
        evm.prank(CONFIGURATOR);
        degenNFT.setBaseUri("Degeneracy");

        assertEq(degenNFT.baseURI(), "Degeneracy", "Base URI was set incorrectly");
    }

    // @dev [DNFT-5A]: setMinter correctly sets minter
    function test_DNFT_05A_setBasUri_correctly_sets_uri() public {
        evm.prank(CONFIGURATOR);
        degenNFT.setMinter(DUMB_ADDRESS);

        assertEq(degenNFT.minter(), DUMB_ADDRESS, "Minter was set incorrectly");
    }

    // @dev [DNFT-6]: addCreditFacade reverts on invalid address
    function test_DNFT_06_addCreditFacade_reverts_on_invalid_address() public {
        evm.expectRevert(InvalidCreditFacadeException.selector);
        evm.prank(CONFIGURATOR);
        degenNFT.addCreditFacade(DUMB_ADDRESS);

        evm.expectRevert(InvalidCreditFacadeException.selector);
        evm.prank(CONFIGURATOR);
        degenNFT.addCreditFacade(address(accountFactory));

        ICreditManagerV2 fakeCM = new CreditManager(creditManager.pool());
        CreditFacade fakeCF = new CreditFacade(
            address(fakeCM),
            DUMB_ADDRESS,
            address(0),
            false
        );

        evm.expectRevert(InvalidCreditFacadeException.selector);
        evm.prank(CONFIGURATOR);
        degenNFT.addCreditFacade(address(fakeCF));

        fakeCF = new CreditFacade(
            address(creditManager),
            DUMB_ADDRESS,
            address(0),
            false
        );

        evm.expectRevert(InvalidCreditFacadeException.selector);
        evm.prank(CONFIGURATOR);
        degenNFT.addCreditFacade(address(fakeCF));

        fakeCF = new CreditFacade(
            address(creditManager),
            address(degenNFT),
            address(0),
            false
        );

        evm.expectRevert(InvalidCreditFacadeException.selector);
        evm.prank(CONFIGURATOR);
        degenNFT.addCreditFacade(address(fakeCF));
    }

    // @dev [DNFT-7]: mint works correctly and updates all values
    function test_DNFT_07_mint_is_correct() public {
        evm.prank(CONFIGURATOR);
        degenNFT.mint(USER, 3);

        assertEq(degenNFT.balanceOf(USER), 3, "User balance is incorrect");

        for (uint256 i = 0; i < 3; i++) {
            uint256 tokenId = (uint256(uint160(USER)) << 40) + i;
            assertEq(degenNFT.ownerOf(tokenId), USER, "Owner of newly minted token is incorrect");
        }

        assertEq(degenNFT.totalSupply(), 3, "Total supply is incorrect");
    }

    // @dev [DNFT-8]: burn works correctly and updates all values
    function test_DNFT_08_burn_is_correct() public {
        evm.prank(CONFIGURATOR);
        degenNFT.mint(USER, 3);

        evm.prank(address(creditFacade));
        degenNFT.burn(USER, 2);

        assertEq(degenNFT.balanceOf(USER), 1, "User balance is incorrect");

        uint256 tokenId = uint256(uint160(USER)) + 2;

        evm.expectRevert("ERC721: invalid token ID");
        degenNFT.ownerOf(tokenId);

        tokenId = uint256(uint160(USER)) + 1;

        evm.expectRevert("ERC721: invalid token ID");
        degenNFT.ownerOf(tokenId);

        assertEq(degenNFT.totalSupply(), 1, "Total supply is incorrect");
    }

    // @dev [DNFT-8A]: burn reverts on insufficient balance
    function test_DNFT_08A_burn_reverts_on_insufficient_balance() public {
        evm.prank(CONFIGURATOR);
        degenNFT.mint(USER, 3);

        evm.expectRevert(InsufficientBalanceException.selector);
        evm.prank(CONFIGURATOR);
        degenNFT.burn(USER, 4);
    }

    // @dev [DNFT-9]: removeCreditFacade correctly sets value
    function test_DNFT_09_removeCreditFacade_sets_value() public {
        assertTrue(degenNFT.isSupportedCreditFacade(address(creditFacade)), "Expected Credit Facade is not added");

        evm.prank(CONFIGURATOR);
        degenNFT.removeCreditFacade(address(creditFacade));

        assertTrue(!degenNFT.isSupportedCreditFacade(address(creditFacade)), "Credit Facade was not removed");
    }

    // @dev [DNFT-10]: addCreditFacade correctly sets value
    function test_DNFT_10_addCreditFacade_sets_value() public {
        assertTrue(degenNFT.isSupportedCreditFacade(address(creditFacade)), "Expected Credit Facade is not added");

        evm.prank(CONFIGURATOR);
        degenNFT.removeCreditFacade(address(creditFacade));

        assertTrue(!degenNFT.isSupportedCreditFacade(address(creditFacade)), "Credit Facade was not removed");

        evm.prank(CONFIGURATOR);
        degenNFT.addCreditFacade(address(creditFacade));

        assertTrue(degenNFT.isSupportedCreditFacade(address(creditFacade)), "Credit Facade was not added");
    }

    ///
    ///  ERC721 standard functions
    ///

    // @dev [DNFT-11]: ERC721 transferability functions revert
    function test_DNFT_11_transfer_and_approval_functions_revert() public {
        evm.expectRevert(NotImplementedException.selector);
        degenNFT.transferFrom(USER, USER, 0);

        evm.expectRevert(NotImplementedException.selector);
        degenNFT.safeTransferFrom(USER, USER, 0);

        evm.expectRevert(NotImplementedException.selector);
        degenNFT.safeTransferFrom(USER, USER, 0, "");

        evm.expectRevert(NotImplementedException.selector);
        degenNFT.setApprovalForAll(FRIEND, true);

        evm.expectRevert(NotImplementedException.selector);
        degenNFT.approve(FRIEND, 0);
    }
}
