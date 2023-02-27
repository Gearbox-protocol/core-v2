// SPDX-License-Identifier: UNLICENSED
// Gearbox Protocol. Generalized leverage for DeFi protocols
// (c) Gearbox Holdings, 2022
pragma solidity ^0.8.10;

import {BoundedPriceFeed} from "../../oracles/BoundedPriceFeed.sol";
import {PriceFeedMock} from "../mocks/oracles/PriceFeedMock.sol";
import {AddressProviderACLMock} from "../mocks/core/AddressProviderACLMock.sol";

import {CheatCodes, HEVM_ADDRESS} from "../lib/cheatCodes.sol";
import "../lib/test.sol";
import "../lib/constants.sol";

// SUITES
import {TokensTestSuite} from "../suites/TokensTestSuite.sol";

// EXCEPTIONS
import {NotImplementedException, CallerNotConfiguratorException} from "../../interfaces/IErrors.sol";

/// @title BoundedPriceFeedTest
/// @notice Designed for unit test purposes only
contract BoundedPriceFeedTest is DSTest {
    CheatCodes evm = CheatCodes(HEVM_ADDRESS);

    PriceFeedMock public targetPf;
    BoundedPriceFeed public pf;

    TokensTestSuite tokenTestSuite;

    function setUp() public {
        targetPf = new PriceFeedMock(8 * 10**8, 8);
        pf = new BoundedPriceFeed(address(targetPf), 10 * 10**8);
    }

    ///
    ///
    ///  TESTS
    ///
    ///

    /// @dev [BPF-1]: constructor sets correct values
    function test_BPF_01_constructor_sets_correct_values() public {
        assertEq(pf.description(), "price oracle Bounded", "Incorrect description");

        assertEq(pf.decimals(), 8, "Incorrect decimals");

        assertTrue(!pf.skipPriceCheck(), "Incorrect skipPriceCheck");
    }

    /// @dev [BPF-2]: getRoundData reverts
    function test_BPF_02_getRoundData_reverts() public {
        evm.expectRevert(NotImplementedException.selector);

        pf.getRoundData(1);
    }

    /// @dev [BPF-3]: latestRoundData works correctly
    function test_BPF_03_latestRoundData_works_correctly() public {
        (uint80 roundId, int256 answer, uint256 startedAt, uint256 updatedAt, uint80 answeredInRound) =
            pf.latestRoundData();
        (
            uint80 roundIdTarget,
            int256 answerTarget,
            uint256 startedAtTarget,
            uint256 updatedAtTarget,
            uint80 answeredInRoundTarget
        ) = targetPf.latestRoundData();

        assertEq(roundId, roundIdTarget, "Incorrect round Id #1");
        assertEq(answer, answerTarget, "Incorrect answer #1");
        assertEq(startedAt, startedAtTarget, "Incorrect startedAt #1");
        assertEq(updatedAt, updatedAtTarget, "Incorrect updatedAt #1");
        assertEq(answeredInRound, answeredInRoundTarget, "Incorrect answeredInRound #1");

        targetPf.setPrice(15 * 10 ** 8);

        (roundId, answer, startedAt, updatedAt, answeredInRound) = pf.latestRoundData();
        (roundIdTarget, answerTarget, startedAtTarget, updatedAtTarget, answeredInRoundTarget) =
            targetPf.latestRoundData();

        assertEq(roundId, roundIdTarget, "Incorrect round Id #2");
        assertEq(answer, int256(pf.upperBound()), "Incorrect answer #2");
        assertEq(startedAt, startedAtTarget, "Incorrect startedAt #2");
        assertEq(updatedAt, updatedAtTarget, "Incorrect updatedAt #2");
        assertEq(answeredInRound, answeredInRoundTarget, "Incorrect answeredInRound #2");
    }
}
