// SPDX-License-Identifier: BUSL-1.1
// Gearbox Protocol. Generalized leverage for DeFi protocols
// (c) Gearbox Holdings, 2022
pragma solidity ^0.8.10;

import { ILPPriceFeedExceptions, ILPPriceFeedEvents } from "../../interfaces/ILPPriceFeed.sol";
import { PERCENTAGE_FACTOR } from "../../libraries/PercentageMath.sol";

// TEST
import "../lib/constants.sol";

// MOCKS
import { LPPriceFeedMock } from "../mocks/oracles/LPPriceFeedMock.sol";
import { AddressProviderACLMock } from "../mocks/core/AddressProviderACLMock.sol";

// SUITES
import { TokensTestSuite } from "../suites/TokensTestSuite.sol";

// EXCEPTIONS

import { ZeroAddressException, CallerNotConfiguratorException, NotImplementedException } from "../../interfaces/IErrors.sol";

import { IPriceOracleV2Exceptions } from "../../interfaces/IPriceOracle.sol";

uint256 constant RANGE_WIDTH = 200; // 2%

/// @title LPPriceFeedTest
/// @notice Designed for unit test purposes only
contract LPPriceFeedTest is
    DSTest,
    ILPPriceFeedEvents,
    ILPPriceFeedExceptions,
    IPriceOracleV2Exceptions
{
    CheatCodes evm = CheatCodes(HEVM_ADDRESS);

    AddressProviderACLMock public addressProvider;

    LPPriceFeedMock public pf;

    TokensTestSuite tokenTestSuite;

    function setUp() public {
        evm.prank(CONFIGURATOR);
        addressProvider = new AddressProviderACLMock();

        pf = new LPPriceFeedMock(address(addressProvider), RANGE_WIDTH, "MOCK");

        evm.label(address(pf), "LP_PRICE_FEED");
    }

    ///
    ///
    ///  TESTS
    ///
    ///

    /// @dev [LPF-1]: constructor sets correct values
    function test_LPF_01_constructor_sets_correct_values() public {
        // LP2

        assertEq(pf.description(), "MOCK");

        assertEq(pf.delta(), RANGE_WIDTH, "Incorrect delta");
    }

    /// @dev [LPF-2]: getRoundData reverts
    function test_LPF_02_getRoundData_reverts() public {
        evm.expectRevert(NotImplementedException.selector);

        pf.getRoundData(1);
    }

    /// @dev [LPF-3]: _checkAndUpperBoundValue reverts if below bounds and returns upperBound if above bounds
    function test_LPF_03_latestRoundData_works_correctly(uint256 value) public {
        evm.assume(value > 0 && value < type(uint256).max >> 16);

        evm.prank(CONFIGURATOR);
        pf.setLimiter(value);

        evm.expectRevert(ValueOutOfRangeException.selector);
        pf.checkAndUpperBoundValue(value - 1);

        uint256 val = pf.checkAndUpperBoundValue(
            (value * (PERCENTAGE_FACTOR + RANGE_WIDTH)) / PERCENTAGE_FACTOR + 1
        );

        assertEq(
            val,
            (value * (PERCENTAGE_FACTOR + RANGE_WIDTH)) / PERCENTAGE_FACTOR,
            "Upper bounded value is incorrect"
        );
    }

    /// @dev [LPF-4]: setLimiter reverts for non-configurator or value = 0
    function test_LPF_04_setLimiter_reverts_for_non_configurator_or_with_zero_value()
        public
    {
        evm.expectRevert(CallerNotConfiguratorException.selector);
        pf.setLimiter(44);

        evm.expectRevert(IncorrectLimitsException.selector);
        evm.prank(CONFIGURATOR);
        pf.setLimiter(0);
    }

    /// @dev [LPF-5]: setLimiter sets bounds correctly
    function test_LPF_05_setLimiter_sets_bounds_correctly(uint256 value)
        public
    {
        evm.assume(value > 0 && value < type(uint256).max >> 16);

        uint256 expectedUpperBound = (value *
            (PERCENTAGE_FACTOR + RANGE_WIDTH)) / PERCENTAGE_FACTOR;

        evm.expectEmit(false, false, false, true);
        emit NewLimiterParams(value, expectedUpperBound);

        evm.prank(CONFIGURATOR);
        pf.setLimiter(value);

        assertEq(pf.lowerBound(), value, "Incorrect lower bound");
        assertEq(pf.upperBound(), expectedUpperBound, "Incorrect upper bound");
    }
}
