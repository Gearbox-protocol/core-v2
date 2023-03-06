// SPDX-License-Identifier: UNLICENSED
// Gearbox Protocol. Generalized leverage for DeFi protocols
// (c) Gearbox Holdings, 2022
pragma solidity ^0.8.10;

import {BotList} from "../../support/BotList.sol";
import {IBotListEvents, IBotListExceptions, BotFunding} from "../../interfaces/IBotList.sol";

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
contract BotListTest is IBotListEvents, IBotListExceptions, DSTest {
    CheatCodes evm = CheatCodes(HEVM_ADDRESS);

    AddressProviderACLMock public addressProvider;

    BotList botList;

    TokensTestSuite tokenTestSuite;

    function setUp() public {
        evm.prank(CONFIGURATOR);
        addressProvider = new AddressProviderACLMock();

        tokenTestSuite = new TokensTestSuite();

        botList = new BotList(address(addressProvider));
    }

    ///
    ///
    ///  TESTS
    ///
    ///

    /// @dev [BL-1]: constructor sets correct values
    function test_BL_01_constructor_sets_correct_values() public {
        assertEq(botList.treasury(), FRIEND2, "Treasury contract incorrect");
        assertEq(botList.daoFee(), 0, "Initial DAO fee incorrect");
    }

    /// @dev [BL-2]: setDAOFee works correctly
    function test_BL_02_setDAOFee_works_correctly() public {
        evm.expectRevert(CallerNotConfiguratorException.selector);
        botList.setDAOFee(1);

        evm.expectEmit(false, false, false, true);
        emit NewBotDAOFee(15);

        evm.prank(CONFIGURATOR);
        botList.setDAOFee(15);

        assertEq(botList.daoFee(), 15, "DAO fee incorrect");
    }

    /// @dev [BL-3]: increaseBotFunding works correctly
    function test_BL_03_increaseBotFunding_works_correctly() public {
        evm.deal(USER, 10 ether);

        evm.expectRevert(AmountCantBeZeroException.selector);
        botList.increaseBotFunding(FRIEND);

        evm.expectRevert(InvalidBotException.selector);
        evm.prank(USER);
        botList.increaseBotFunding{value: 1 ether}(FRIEND);

        evm.prank(USER);
        botList.setBotStatus(address(addressProvider), true);

        evm.prank(CONFIGURATOR);
        botList.setBotForbiddenStatus(address(addressProvider), true);

        evm.expectRevert(InvalidBotException.selector);
        evm.prank(USER);
        botList.increaseBotFunding{value: 1 ether}(address(addressProvider));

        evm.prank(CONFIGURATOR);
        botList.setBotForbiddenStatus(address(addressProvider), false);

        evm.prank(USER);
        botList.increaseBotFunding{value: 1 ether}(address(addressProvider));

        (uint72 remainingFunds,,,) = botList.botFunding(USER, address(addressProvider));

        assertEq(remainingFunds, 1 ether, "Remaining funds incorrect");

        evm.prank(USER);
        botList.increaseBotFunding{value: 1 ether}(address(addressProvider));

        (remainingFunds,,,) = botList.botFunding(USER, address(addressProvider));

        assertEq(remainingFunds, 2 ether, "Remaining funds incorrect");
    }

    /// @dev [BL-4]: decreaseBotFunding works correctly
    function test_BL_04_decreaseBotFunding_works_correctly() public {
        evm.deal(USER, 10 ether);

        evm.prank(USER);
        botList.setBotStatus(address(addressProvider), true);

        evm.prank(USER);
        botList.increaseBotFunding{value: 2 ether}(address(addressProvider));

        evm.prank(USER);
        botList.decreaseBotFunding(address(addressProvider), 1 ether);

        (uint72 remainingFunds,,,) = botList.botFunding(USER, address(addressProvider));

        assertEq(remainingFunds, 1 ether, "Remaining funds incorrect");

        assertEq(USER.balance, 9 ether, "USER was sent an incorrect amount");
    }

    /// @dev [BL-5]: setWeeklyAllowance works correctly
    function test_BL_05_setWeeklyAllowance_works_correctly() public {
        evm.deal(USER, 10 ether);

        evm.prank(USER);
        botList.setBotStatus(address(addressProvider), true);

        evm.prank(USER);
        botList.setWeeklyBotAllowance(address(addressProvider), 1 ether);

        (, uint72 maxWeeklyAllowance,,) = botList.botFunding(USER, address(addressProvider));

        assertEq(maxWeeklyAllowance, 1 ether, "Incorrect new allowance");

        evm.prank(USER);
        botList.increaseBotFunding{value: 1 ether}(address(addressProvider));

        evm.prank(address(addressProvider));
        botList.pullPayment(USER, 1 ether / 10);

        evm.prank(USER);
        botList.setWeeklyBotAllowance(address(addressProvider), 1 ether / 2);

        uint72 remainingWeeklyAllowance;

        (, maxWeeklyAllowance, remainingWeeklyAllowance,) = botList.botFunding(USER, address(addressProvider));

        assertEq(maxWeeklyAllowance, 1 ether / 2, "Incorrect new allowance");

        assertEq(remainingWeeklyAllowance, 1 ether / 2, "Incorrect new remaining allowance");
    }

    /// @dev [BL-6]: pullPayment works correctly
    function test_BL_06_pullPayment_works_correctly() public {
        evm.deal(USER, 10 ether);

        evm.prank(USER);
        botList.setBotStatus(address(addressProvider), true);

        evm.prank(USER);
        botList.setWeeklyBotAllowance(address(addressProvider), 1 ether);

        evm.prank(USER);
        botList.increaseBotFunding{value: 2 ether}(address(addressProvider));

        evm.prank(address(addressProvider));
        botList.pullPayment(USER, 1 ether / 10);

        (uint72 remainingFunds,, uint72 remainingWeeklyAllowance,) = botList.botFunding(USER, address(addressProvider));

        assertEq(remainingFunds, 2 ether - 1 ether / 10, "Incorrect new remaining funds");

        assertEq(remainingWeeklyAllowance, 1 ether - 1 ether / 10, "Incorrect new remaining allowance");

        assertEq(address(addressProvider).balance, 1 ether / 10, "Incorrect amount sent to bot");

        evm.prank(CONFIGURATOR);
        botList.setDAOFee(10000);

        evm.prank(address(addressProvider));
        botList.pullPayment(USER, 1 ether / 10);

        (remainingFunds,, remainingWeeklyAllowance,) = botList.botFunding(USER, address(addressProvider));

        assertEq(remainingFunds, 2 ether - 3 ether / 10, "Incorrect new remaining funds");

        assertEq(remainingWeeklyAllowance, 1 ether - 3 ether / 10, "Incorrect new remaining allowance");

        assertEq(address(addressProvider).balance, 2 ether / 10, "Incorrect amount sent to bot");

        assertEq(FRIEND2.balance, 1 ether / 10, "Incorrect amount sent to treasury");
    }
}
