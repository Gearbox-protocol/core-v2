// SPDX-License-Identifier: UNLICENSED
// Gearbox Protocol. Generalized leverage for DeFi protocols
// (c) Gearbox Holdings, 2022
pragma solidity ^0.8.10;

import { CompositePriceFeed } from "../../oracles/CompositePriceFeed.sol";
import { PriceFeedMock } from "../mocks/oracles/PriceFeedMock.sol";
import { IPriceOracleV2Exceptions } from "../../interfaces/IPriceOracle.sol";

import { CheatCodes, HEVM_ADDRESS } from "../lib/cheatCodes.sol";
import "../lib/test.sol";
import "../lib/constants.sol";

// SUITES
import { TokensTestSuite } from "../suites/TokensTestSuite.sol";

// EXCEPTIONS
import { NotImplementedException, CallerNotConfiguratorException } from "../../interfaces/IErrors.sol";

/// @title CompositePriceFeedTest
/// @notice Designed for unit test purposes only
contract CompositePriceFeedTest is DSTest, IPriceOracleV2Exceptions {
    CheatCodes evm = CheatCodes(HEVM_ADDRESS);

    PriceFeedMock public targetPf;
    PriceFeedMock public baseUsdPf;
    CompositePriceFeed public pf;

    TokensTestSuite tokenTestSuite;

    function setUp() public {
        targetPf = new PriceFeedMock(99 * 10**16, 18);
        baseUsdPf = new PriceFeedMock(1000 * 10**8, 8);
        pf = new CompositePriceFeed(address(targetPf), address(baseUsdPf));
    }

    ///
    ///
    ///  TESTS
    ///
    ///

    /// @dev [CPF-1]: constructor sets correct values
    function test_CPF_01_constructor_sets_correct_values() public {
        assertEq(
            pf.description(),
            "price oracle to USD Composite",
            "Incorrect description"
        );

        assertEq(pf.decimals(), 8, "Incorrect decimals");

        assertEq(
            pf.answerDenominator(),
            int256(10**18),
            "Incorrect ETH price feed decimals"
        );

        assertTrue(pf.skipPriceCheck(), "Incorrect skipPriceCheck");
    }

    /// @dev [CPF-2]: getRoundData reverts
    function test_CPF_02_getRoundData_reverts() public {
        evm.expectRevert(NotImplementedException.selector);

        pf.getRoundData(1);
    }

    /// @dev [CPF-3]: latestRoundData works correctly
    function test_CPF_03_latestRoundData_works_correctly(
        int256 answer1,
        int256 answer2
    ) public {
        evm.assume(answer1 > 0);
        evm.assume(answer2 > 0);
        evm.assume(answer1 < int256(RAY));
        evm.assume(answer2 < int256(RAY));

        targetPf.setPrice(answer1);
        baseUsdPf.setPrice(answer2);

        (
            uint80 roundId,
            int256 answer,
            uint256 startedAt,
            uint256 updatedAt,
            uint80 answeredInRound
        ) = pf.latestRoundData();
        (, int256 answerTarget, , , ) = targetPf.latestRoundData();
        (
            uint80 roundIdBase,
            int256 answerBase,
            uint256 startedAtBase,
            uint256 updatedAtBase,
            uint80 answeredInRoundBase
        ) = baseUsdPf.latestRoundData();

        assertEq(roundId, roundIdBase, "Incorrect round Id #1");
        assertEq(
            answer,
            (answerTarget * answerBase) / int256(10**targetPf.decimals()),
            "Incorrect answer #1"
        );
        assertEq(startedAt, startedAtBase, "Incorrect startedAt #1");
        assertEq(updatedAt, updatedAtBase, "Incorrect updatedAt #1");
        assertEq(
            answeredInRound,
            answeredInRoundBase,
            "Incorrect answeredInRound #1"
        );
    }

    /// @dev [CEPF-4]: latestRoundData reverts on failing sanity checks
    function test_CEPF_04_latestRoundData_reverts_on_incorrect_answers()
        public
    {
        (
            uint80 roundId,
            int256 answer,
            uint256 startedAt,
            uint256 updatedAt,
            uint80 answeredInRound
        ) = targetPf.latestRoundData();

        targetPf.setParams(roundId, startedAt, 0, answeredInRound);

        evm.expectRevert(ChainPriceStaleException.selector);
        pf.latestRoundData();

        targetPf.setParams(roundId, startedAt, updatedAt, roundId - 1);

        evm.expectRevert(ChainPriceStaleException.selector);
        pf.latestRoundData();

        targetPf.setParams(roundId, startedAt, updatedAt, answeredInRound);

        targetPf.setPrice(0);

        evm.expectRevert(ZeroPriceException.selector);
        pf.latestRoundData();

        targetPf.setPrice(99 * 10**16);

        (roundId, answer, startedAt, updatedAt, answeredInRound) = baseUsdPf
            .latestRoundData();

        baseUsdPf.setParams(roundId, startedAt, 0, answeredInRound);

        evm.expectRevert(ChainPriceStaleException.selector);
        pf.latestRoundData();

        baseUsdPf.setParams(roundId, startedAt, updatedAt, roundId - 1);

        evm.expectRevert(ChainPriceStaleException.selector);
        pf.latestRoundData();

        baseUsdPf.setParams(roundId, startedAt, updatedAt, answeredInRound);

        baseUsdPf.setPrice(0);

        evm.expectRevert(ZeroPriceException.selector);
        pf.latestRoundData();
    }
}
