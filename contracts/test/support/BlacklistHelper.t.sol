// SPDX-License-Identifier: UNLICENSED
// Gearbox Protocol. Generalized leverage for DeFi protocols
// (c) Gearbox Holdings, 2022
pragma solidity ^0.8.10;

import {BlacklistHelper} from "../../support/BlacklistHelper.sol";
import {IBlacklistHelperEvents, IBlacklistHelperExceptions} from "../../interfaces/IBlacklistHelper.sol";

// TEST
import "../lib/constants.sol";

// MOCKS
import {AddressProviderACLMock} from "../mocks/core/AddressProviderACLMock.sol";
import {ERC20BlacklistableMock} from "../mocks/token/ERC20Blacklistable.sol";

// SUITES
import {TokensTestSuite} from "../suites/TokensTestSuite.sol";
import {Tokens} from "../config/Tokens.sol";

// EXCEPTIONS

import {
    ZeroAddressException, CallerNotConfiguratorException, NotImplementedException
} from "../../interfaces/IErrors.sol";

/// @title LPPriceFeedTest
/// @notice Designed for unit test purposes only
contract BlacklistHelperTest is IBlacklistHelperEvents, IBlacklistHelperExceptions, DSTest {
    CheatCodes evm = CheatCodes(HEVM_ADDRESS);

    AddressProviderACLMock public addressProvider;

    BlacklistHelper blacklistHelper;

    TokensTestSuite tokenTestSuite;

    address usdc;

    bool public isBlacklistableUnderlying = true;

    function setUp() public {
        evm.prank(CONFIGURATOR);
        addressProvider = new AddressProviderACLMock();

        tokenTestSuite = new TokensTestSuite();

        usdc = tokenTestSuite.addressOf(Tokens.USDC);

        blacklistHelper = new BlacklistHelper(
            address(addressProvider),
            usdc,
            DUMB_ADDRESS
        );
    }

    ///
    ///
    ///  TESTS
    ///
    ///

    /// @dev [BH-1]: constructor sets correct values
    function test_BH_01_constructor_sets_correct_values() public {
        assertEq(blacklistHelper.usdc(), usdc, "USDC address incorrect");

        assertEq(blacklistHelper.usdt(), DUMB_ADDRESS, "USDT address incorrect");
    }

    /// @dev [BH-2]: isBlacklisted works correctly for all tokens
    function test_BH_02_isBlacklisted_works_correctly() public {
        ERC20BlacklistableMock(usdc).setBlacklisted(USER, true);
        ERC20BlacklistableMock(usdc).setBlackListed(USER, true);

        evm.expectCall(usdc, abi.encodeWithSignature("isBlacklisted(address)", USER));

        bool status = blacklistHelper.isBlacklisted(usdc, USER);

        assertTrue(status, "Blacklisted status incorrect");

        blacklistHelper = new BlacklistHelper(
            address(addressProvider),
            DUMB_ADDRESS,
            usdc
        );

        evm.expectCall(usdc, abi.encodeWithSignature("isBlackListed(address)", USER));

        status = blacklistHelper.isBlacklisted(usdc, USER);

        assertTrue(status, "Blacklisted status incorrect");
    }

    /// @dev [BH-3]: addCreditFacade / removeCreditFacade work correctly and revert on non-configurator
    function test_BH_03_add_removeCreditFacade_work_correctly() public {
        evm.prank(CONFIGURATOR);
        blacklistHelper.addCreditFacade(address(this));

        assertTrue(blacklistHelper.isSupportedCreditFacade(address(this)), "Incorrect credit facade status");

        evm.prank(CONFIGURATOR);
        blacklistHelper.removeCreditFacade(address(this));

        assertTrue(!blacklistHelper.isSupportedCreditFacade(address(this)), "Incorrect credit facade status");

        evm.expectRevert(CallerNotConfiguratorException.selector);
        evm.prank(DUMB_ADDRESS);
        blacklistHelper.addCreditFacade(address(this));

        isBlacklistableUnderlying = false;

        evm.expectRevert(CreditFacadeNonBlacklistable.selector);
        evm.prank(CONFIGURATOR);
        blacklistHelper.addCreditFacade(address(this));
    }

    /// @dev [BH-4]: addClaimable works correctly and reverts on non-Credit Facade
    function test_BH_04_addClaimable_works_correctly() public {
        evm.prank(CONFIGURATOR);
        blacklistHelper.addCreditFacade(address(this));

        blacklistHelper.addClaimable(usdc, USER, 10000);

        assertEq(blacklistHelper.claimable(usdc, USER), 10000);

        evm.expectRevert(CreditFacadeOnlyException.selector);
        evm.prank(DUMB_ADDRESS);
        blacklistHelper.addClaimable(usdc, USER, 10000);
    }

    /// @dev [BH-5]: claim works correctly
    function test_BH_05_claim_works_correctly() public {
        evm.prank(CONFIGURATOR);
        blacklistHelper.addCreditFacade(address(this));

        blacklistHelper.addClaimable(usdc, USER, 10000);

        tokenTestSuite.mint(Tokens.USDC, address(blacklistHelper), 10000);

        evm.prank(USER);
        blacklistHelper.claim(usdc, FRIEND);

        assertEq(tokenTestSuite.balanceOf(Tokens.USDC, FRIEND), 10000);

        evm.expectRevert(NothingToClaimException.selector);
        evm.prank(USER);
        blacklistHelper.claim(usdc, FRIEND);
    }
}
