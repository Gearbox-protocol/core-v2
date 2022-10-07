// SPDX-License-Identifier: BUSL-1.1
// Gearbox Protocol. Generalized leverage for DeFi protocols
// (c) Gearbox Holdings, 2021
pragma solidity ^0.8.10;

import { ILPPriceFeedExceptions } from "../../interfaces/ILPPriceFeed.sol";
import { ZeroPriceFeed } from "../../oracles/ZeroPriceFeed.sol";

// LIBRARIES

// TEST

import { CheatCodes, HEVM_ADDRESS } from "../lib/cheatCodes.sol";
import "../lib/test.sol";

// MOCKS

// SUITES
import { TokensTestSuite } from "../suites/TokensTestSuite.sol";
import { Tokens } from "../config/Tokens.sol";

// EXCEPTIONS
import { ZeroAddressException, NotImplementedException } from "../../interfaces/IErrors.sol";
import { IPriceOracleV2Exceptions } from "../../interfaces/IPriceOracle.sol";

/// @title ZeroFeedTest
/// @notice Designed for unit test purposes only
contract ZeroFeedTest is
    DSTest,
    ILPPriceFeedExceptions,
    IPriceOracleV2Exceptions
{
    CheatCodes evm = CheatCodes(HEVM_ADDRESS);

    ZeroPriceFeed public pf;

    TokensTestSuite tokenTestSuite;

    function setUp() public {
        pf = new ZeroPriceFeed();

        evm.label(address(pf), "ZERO_PRICE_FEED");
    }

    ///
    ///
    ///  TESTS
    ///
    ///

    /// @dev [ZPF-1]: constructor sets correct values
    function test_ZPF_01_constructor_sets_correct_values() public {
        assertEq(pf.description(), "Zero pricefeed", "Incorrect description");

        assertEq(
            pf.decimals(),
            8, // Decimals divider for DAI
            "Incorrect decimals"
        );

        assertTrue(
            pf.skipPriceCheck() == true,
            "Incorrect deepencds for address"
        );
    }

    /// @dev [ZPF-2]: getRoundData reverts
    function test_ZPF_02_getRoundData_reverts() public {
        evm.expectRevert(NotImplementedException.selector);

        pf.getRoundData(1);
    }

    /// @dev [ZPF-3]: latestRoundData works correctly
    function test_ZPF_03_latestRoundData_works_correctly() public {
        (
            uint80 roundId,
            int256 answer,
            uint256 startedAt,
            uint256 updatedAt,
            uint80 answeredInRound
        ) = pf.latestRoundData();

        assertEq(roundId, 1, "Incorrect round Id #1");
        assertEq(answer, 0, "Incorrect answer #1");
        assertEq(startedAt, block.timestamp, "Incorrect startedAt #1");
        assertEq(updatedAt, block.timestamp, "Incorrect updatedAt #1");
        assertEq(answeredInRound, 1, "Incorrect answeredInRound #1");
    }
}
