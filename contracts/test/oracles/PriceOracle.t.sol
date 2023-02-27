// SPDX-License-Identifier: UNLICENSED
// Gearbox Protocol. Generalized leverage for DeFi protocols
// (c) Gearbox Holdings, 2022
pragma solidity ^0.8.10;

import {IPriceOracleV2Events} from "../../interfaces/IPriceOracle.sol";
import {PriceOracle, PriceFeedConfig} from "../../oracles/PriceOracle.sol";

import {AddressProvider} from "../../core/AddressProvider.sol";
import {ACL} from "../../core/ACL.sol";

// LIBRARIES

// TEST
import "../lib/constants.sol";

// MOCKS
import {ERC20Mock} from "../mocks/token/ERC20Mock.sol";
import {PriceFeedMock, FlagState} from "../mocks/oracles/PriceFeedMock.sol";

// SUITES
import {TokensTestSuite} from "../suites/TokensTestSuite.sol";
import {Tokens} from "../config/Tokens.sol";

// EXCEPTIONS
import {
    ZeroAddressException,
    AddressIsNotContractException,
    IncorrectPriceFeedException,
    IncorrectTokenContractException
} from "../../interfaces/IErrors.sol";
import {IPriceOracleV2Exceptions} from "../../interfaces/IPriceOracle.sol";

/// @title PriceOracleTest
/// @notice Designed for unit test purposes only
contract PriceOracleTest is DSTest, IPriceOracleV2Events, IPriceOracleV2Exceptions {
    CheatCodes evm = CheatCodes(HEVM_ADDRESS);

    TokensTestSuite tokenTestSuite;

    AddressProvider public addressProvider;
    ACL public acl;

    PriceOracle public priceOracle;

    function setUp() public {
        tokenTestSuite = new TokensTestSuite();
        tokenTestSuite.topUpWETH{value: 100 * WAD}();

        evm.startPrank(CONFIGURATOR);
        addressProvider = new AddressProvider();
        addressProvider.setWethToken(tokenTestSuite.wethToken());

        acl = new ACL();

        addressProvider.setACL(address(acl));

        priceOracle = new PriceOracle(
            address(addressProvider),
            tokenTestSuite.getPriceFeeds()
        );

        evm.stopPrank();
    }

    ///
    ///
    ///  TESTS
    ///
    ///

    /// @dev [PO-1]: constructor sets correct values
    function test_PO_01_constructor_sets_correct_values() public {
        Tokens[4] memory tokensAdded = [Tokens.DAI, Tokens.USDC, Tokens.WETH, Tokens.LINK];

        uint256 len = tokensAdded.length;

        for (uint256 i = 0; i < len; i++) {
            address token = tokenTestSuite.addressOf(tokensAdded[i]);
            address priceFeed = tokenTestSuite.priceFeedsMap(tokensAdded[i]);

            assertEq(
                priceOracle.priceFeeds(token),
                priceFeed,
                string(abi.encodePacked("Incorrect pricefeed ", tokenTestSuite.symbols(tokensAdded[i])))
            );
        }
    }

    /// @dev [PO-2]: addPriceFeed reverts for zero address and incorrect digitals
    function test_PO_02_addPriceFeed_reverts_for_zero_address_and_incorrect_contracts() public {
        evm.startPrank(CONFIGURATOR);

        evm.expectRevert(ZeroAddressException.selector);
        priceOracle.addPriceFeed(address(0), DUMB_ADDRESS);

        evm.expectRevert(ZeroAddressException.selector);
        priceOracle.addPriceFeed(DUMB_ADDRESS, address(0));

        // Checks that it reverts for non-contract addresses
        evm.expectRevert(abi.encodeWithSelector(AddressIsNotContractException.selector, DUMB_ADDRESS));

        priceOracle.addPriceFeed(DUMB_ADDRESS, address(this));

        evm.expectRevert(abi.encodeWithSelector(AddressIsNotContractException.selector, DUMB_ADDRESS2));
        priceOracle.addPriceFeed(address(this), DUMB_ADDRESS2);

        // Checks that it reverts if token has no .decimals() method
        PriceFeedMock priceFeed = new PriceFeedMock(8 * 10**8, 8);
        evm.expectRevert(IncorrectTokenContractException.selector);
        priceOracle.addPriceFeed(address(this), address(priceFeed));

        // 19 digits case
        ERC20Mock token19decimals = new ERC20Mock("19-19", "19-19", 19);

        evm.expectRevert(IncorrectTokenContractException.selector);
        priceOracle.addPriceFeed(address(token19decimals), address(priceFeed));

        address daiToken = tokenTestSuite.addressOf(Tokens.DAI);

        evm.expectRevert(IncorrectPriceFeedException.selector);
        // Checks that it reverts if priceFeed has no .decimals() method
        priceOracle.addPriceFeed(daiToken, address(this));

        PriceFeedMock pfMock9decimals = new PriceFeedMock(10, 9);

        evm.expectRevert(IncorrectPriceFeedException.selector);
        priceOracle.addPriceFeed(daiToken, address(pfMock9decimals));

        priceFeed.setRevertOnLatestRound(true);

        evm.expectRevert(IncorrectPriceFeedException.selector);
        priceOracle.addPriceFeed(daiToken, address(priceFeed));

        priceFeed.setPrice(0);
        priceFeed.setParams(80, block.timestamp, block.timestamp, 80);

        evm.expectRevert(IncorrectPriceFeedException.selector);
        priceOracle.addPriceFeed(daiToken, address(priceFeed));

        priceFeed.setRevertOnLatestRound(false);
        priceFeed.setPrice(0);
        priceFeed.setParams(80, block.timestamp, block.timestamp, 80);

        evm.expectRevert(ZeroPriceException.selector);
        priceOracle.addPriceFeed(daiToken, address(priceFeed));

        priceFeed.setPrice(10);
        priceFeed.setParams(80, block.timestamp, block.timestamp, 78);

        evm.expectRevert(ChainPriceStaleException.selector);
        priceOracle.addPriceFeed(daiToken, address(priceFeed));

        priceFeed.setRevertOnLatestRound(false);
        priceFeed.setPrice(10);
        priceFeed.setParams(80, block.timestamp, block.timestamp, 78);

        evm.expectRevert(ChainPriceStaleException.selector);
        priceOracle.addPriceFeed(daiToken, address(priceFeed));

        priceFeed.setParams(80, block.timestamp, 0, 80);

        evm.expectRevert(ChainPriceStaleException.selector);
        priceOracle.addPriceFeed(daiToken, address(priceFeed));
    }

    /// @dev [PO-3]: addPriceFeed adds pricefeed and emits event
    function test_PO_03_addPriceFeed_adds_pricefeed_and_emits_event() public {
        for (uint256 sc = 0; sc < 2; sc++) {
            bool skipCheck = sc != 0;

            setUp();

            ERC20Mock token = new ERC20Mock("Token", "Token", 17);

            PriceFeedMock priceFeed = new PriceFeedMock(8 * 10**8, 8);

            priceFeed.setSkipPriceCheck(skipCheck ? FlagState.TRUE : FlagState.FALSE);

            evm.expectEmit(true, true, false, false);
            emit NewPriceFeed(address(token), address(priceFeed));

            evm.prank(CONFIGURATOR);

            priceOracle.addPriceFeed(address(token), address(priceFeed));

            (address newPriceFeed, bool sc_flag, uint256 decimals) = priceOracle.priceFeedsWithFlags(address(token));

            assertEq(newPriceFeed, address(priceFeed), "Incorrect pricefeed");

            assertEq(priceOracle.priceFeeds(address(token)), address(priceFeed), "Incorrect pricefeed");

            assertEq(decimals, 17, "Incorrect decimals");

            assertTrue(sc_flag == skipCheck, "Incorrect skipCheck");
        }
    }

    /// @dev [PO-4]: getPrice reverts if depends on address but address(0) was provided
    function test_PO_04_getPrice_reverts_if_depends_on_address_but_zero_address_was_provided() public {
        ERC20Mock token = new ERC20Mock("Token", "Token", 17);

        PriceFeedMock priceFeed = new PriceFeedMock(8 * 10**8, 8);

        evm.prank(CONFIGURATOR);
        priceOracle.addPriceFeed(address(token), address(priceFeed));

        priceOracle.getPrice(address(token));
    }

    /// @dev [PO-5]: getPrice reverts if not passed skipCheck when it's enabled
    function test_PO_05_getPrice_reverts_if_not_passed_skipCheck_when_its_enabled() public {
        for (uint256 sc = 0; sc < 2; sc++) {
            bool skipForCheck = sc != 0;

            setUp();

            ERC20Mock token = new ERC20Mock("Token", "Token", 17);

            PriceFeedMock priceFeed = new PriceFeedMock(8 * 10**8, 8);

            priceFeed.setSkipPriceCheck(skipForCheck ? FlagState.TRUE : FlagState.FALSE);

            evm.prank(CONFIGURATOR);
            priceOracle.addPriceFeed(address(token), address(priceFeed));

            priceFeed.setPrice(0);
            priceFeed.setParams(80, block.timestamp, block.timestamp, 80);

            if (!skipForCheck) {
                evm.expectRevert(ZeroPriceException.selector);
            }
            priceOracle.getPrice(address(token));

            priceFeed.setPrice(10);
            priceFeed.setParams(80, block.timestamp, block.timestamp, 78);

            if (!skipForCheck) {
                evm.expectRevert(ChainPriceStaleException.selector);
            }
            priceOracle.getPrice(address(token));

            priceFeed.setParams(80, block.timestamp, 0, 80);

            if (!skipForCheck) {
                evm.expectRevert(ChainPriceStaleException.selector);
            }

            priceOracle.getPrice(address(token));
        }
    }

    /// @dev [PO-6]: getPrice returs correct price getting through correct method
    function test_PO_06_getPrice_returns_correct_price(int256 price) public {
        setUp();

        evm.assume(price > 0);
        ERC20Mock token = new ERC20Mock("Token", "Token", 17);

        PriceFeedMock priceFeed = new PriceFeedMock(8 * 10**8, 8);

        evm.prank(CONFIGURATOR);
        priceOracle.addPriceFeed(address(token), address(priceFeed));

        priceFeed.setPrice(price);

        evm.expectCall(address(priceFeed), abi.encodeWithSignature("latestRoundData()"));

        uint256 actualPrice = priceOracle.getPrice(address(token));

        assertEq(actualPrice, uint256(price), "Incorrect price");
    }

    /// @dev [PO-7]: convertToUSD and convertFromUSD computes correctly
    /// All prices are taken from tokenTestSuite
    function test_PO_07_convertFromUSD_and_convertToUSD_computes_correctly(uint128 amount) public {
        address wethToken = tokenTestSuite.wethToken();
        address linkToken = tokenTestSuite.addressOf(Tokens.LINK);

        uint256 decimalsDifference = WAD / 10 ** 8;

        assertEq(
            priceOracle.convertToUSD(amount, wethToken),
            (uint256(amount) * DAI_WETH_RATE) / decimalsDifference,
            "Incorrect ETH/USD conversation"
        );

        assertEq(
            priceOracle.convertToUSD(amount, linkToken),
            (uint256(amount) * 15) / decimalsDifference,
            "Incorrect LINK/USD conversation"
        );

        assertEq(
            priceOracle.convertFromUSD(amount, wethToken),
            (uint256(amount) * decimalsDifference) / DAI_WETH_RATE,
            "Incorrect USDC/ETH conversation"
        );

        assertEq(
            priceOracle.convertFromUSD(amount, linkToken),
            (uint256(amount) * decimalsDifference) / 15,
            "Incorrect USD/LINK conversation"
        );
    }

    /// @dev [PO-8]: convert computes correctly
    /// All prices are taken from tokenTestSuite
    function test_PO_08_convert_computes_correctly() public {
        assertEq(
            priceOracle.convert(WAD, tokenTestSuite.addressOf(Tokens.WETH), tokenTestSuite.addressOf(Tokens.USDC)),
            DAI_WETH_RATE * 10 ** 6,
            "Incorrect WETH/USDC conversation"
        );

        assertEq(
            priceOracle.convert(WAD, tokenTestSuite.addressOf(Tokens.WETH), tokenTestSuite.addressOf(Tokens.LINK)),
            (DAI_WETH_RATE * WAD) / 15,
            "Incorrect WETH/LINK conversation"
        );

        assertEq(
            priceOracle.convert(WAD, tokenTestSuite.addressOf(Tokens.LINK), tokenTestSuite.addressOf(Tokens.DAI)),
            15 * WAD,
            "Incorrect LINK/DAI conversation"
        );

        assertEq(
            priceOracle.convert(10 ** 8, tokenTestSuite.addressOf(Tokens.USDC), tokenTestSuite.addressOf(Tokens.DAI)),
            100 * WAD,
            "Incorrect USDC/DAI conversation"
        );
    }

    /// @dev [PO-9]: fastCheck computes correctly
    /// All prices are taken from tokenTestSuite
    function test_PO_09_fastCheck_computes_correctly() public {
        (uint256 collateralWETH, uint256 collateralUSDC) = priceOracle.fastCheck(
            5 * WAD, tokenTestSuite.addressOf(Tokens.WETH), 10 * 10 ** 6, tokenTestSuite.addressOf(Tokens.USDC)
        );

        assertEq(collateralWETH, 5 * DAI_WETH_RATE * 10 ** 8, "Incorrect collateral WETH");
        assertEq(collateralUSDC, 10 * 10 ** 8, "Incorrect collateral USDC");
    }
}
