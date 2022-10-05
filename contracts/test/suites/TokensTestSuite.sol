// SPDX-License-Identifier: BUSL-1.1
// Gearbox. Generalized leverage protocol that allows to take leverage and then use it across other DeFi protocols and platforms in a composable way.
// (c) Gearbox.fi, 2021
pragma solidity ^0.8.10;

import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import { WETHMock } from "../mocks/token/WETHMock.sol";

import { AggregatorV3Interface } from "@chainlink/contracts/src/v0.8/interfaces/AggregatorV3Interface.sol";
import { PriceFeedConfig } from "../../oracles/PriceOracle.sol";
import { IWETH } from "../../interfaces/external/IWETH.sol";
import { CheatCodes, HEVM_ADDRESS } from "../lib/cheatCodes.sol";
import { ITokenTestSuite } from "../interfaces/ITokenTestSuite.sol";

// MOCKS
import { Tokens } from "../interfaces/Tokens.sol";
import { ERC20Mock } from "../mocks/token/ERC20Mock.sol";
import { cERC20Mock } from "../mocks/token/cERC20Mock.sol";
import { PriceFeedMock } from "../mocks/oracles/PriceFeedMock.sol";
import "../lib/constants.sol";
import "../lib/test.sol";

struct TestToken {
    Tokens index;
    string symbol;
    uint8 decimals;
    int256 price;
    Tokens underlying;
}

contract TokensTestSuite is DSTest, ITokenTestSuite {
    CheatCodes evm = CheatCodes(HEVM_ADDRESS);

    address public wethToken;
    mapping(Tokens => address) public addressOf;

    mapping(Tokens => string) public symbols;
    mapping(Tokens => uint256) public prices;
    mapping(Tokens => address) public priceFeedsMap;

    uint256 public tokenCount;

    PriceFeedConfig[] public priceFeeds;
    mapping(address => Tokens) public tokenIndexes;

    constructor() {
        TestToken[10] memory tokensData = [
            TestToken({
                index: Tokens.DAI,
                symbol: "DAI",
                decimals: 18,
                price: 10**8,
                underlying: Tokens.NO_TOKEN
            }),
            TestToken({
                index: Tokens.USDC,
                symbol: "USDC",
                decimals: 6,
                price: 10**8,
                underlying: Tokens.NO_TOKEN
            }),
            TestToken({
                index: Tokens.WETH,
                symbol: "WETH",
                decimals: 18,
                price: int256(DAI_WETH_RATE) * 10**8,
                underlying: Tokens.NO_TOKEN
            }),
            TestToken({
                index: Tokens.LINK,
                symbol: "LINK",
                decimals: 18,
                price: 15 * 10**8,
                underlying: Tokens.NO_TOKEN
            }),
            TestToken({
                index: Tokens.USDT,
                symbol: "USDT",
                decimals: 18,
                price: 99 * 10**7, // .99 for test purposes
                underlying: Tokens.NO_TOKEN
            }),
            TestToken({
                index: Tokens.STETH,
                symbol: "stETH",
                decimals: 18,
                price: 3300 * 10**8,
                underlying: Tokens.NO_TOKEN
            }),
            TestToken({
                index: Tokens.CRV,
                symbol: "CRV",
                decimals: 18,
                price: 14 * 10**7,
                underlying: Tokens.NO_TOKEN
            }),
            TestToken({
                index: Tokens.CVX,
                symbol: "CVX",
                decimals: 18,
                price: 7 * 10**8,
                underlying: Tokens.NO_TOKEN
            }),
            TestToken({
                index: Tokens.LUNA,
                symbol: "LUNA",
                decimals: 18,
                price: 1,
                underlying: Tokens.NO_TOKEN
            }),
            TestToken({
                index: Tokens.wstETH,
                symbol: "wstETH",
                decimals: 18,
                price: 3300 * 10**8,
                underlying: Tokens.NO_TOKEN
            })
        ];

        TestToken[4] memory extraTokensData = [
            TestToken({
                index: Tokens.cDAI,
                symbol: "cDAI",
                decimals: 18,
                price: 10**8,
                underlying: Tokens.DAI
            }),
            TestToken({
                index: Tokens.cUSDC,
                symbol: "cUSDC",
                decimals: 6,
                price: 10**8,
                underlying: Tokens.USDC
            }),
            TestToken({
                index: Tokens.cUSDT,
                symbol: "cUSDT",
                decimals: 18,
                price: 99 * 10**7, // .99 for test purposes
                underlying: Tokens.USDT
            }),
            TestToken({
                index: Tokens.cLINK,
                symbol: "cLINK",
                decimals: 18,
                price: 15 * 10**8,
                underlying: Tokens.LINK
            })
        ];

        for (uint256 i = 0; i < tokensData.length; i++) {
            addToken(tokensData[i]);
        }

        for (uint256 i = 0; i < extraTokensData.length; i++) {
            addToken(extraTokensData[i]);
        }
    }

    function addToken(TestToken memory token) internal {
        IERC20 t;

        if (token.index == Tokens.WETH) {
            t = new WETHMock();
            wethToken = address(t);
        } else {
            t = new ERC20Mock(token.symbol, token.symbol, token.decimals);
        }

        evm.label(address(t), token.symbol);

        AggregatorV3Interface priceFeed = new PriceFeedMock(token.price, 8);

        addressOf[token.index] = address(t);
        prices[token.index] = uint256(token.price);

        tokenIndexes[address(t)] = token.index;

        priceFeeds.push(
            PriceFeedConfig({
                token: address(t),
                priceFeed: address(priceFeed)
            })
        );
        symbols[token.index] = token.symbol;
        priceFeedsMap[token.index] = address(priceFeed);
        tokenCount++;
    }

    function getPriceFeeds() external view returns (PriceFeedConfig[] memory) {
        return priceFeeds;
    }

    function topUpWETH() external payable {
        IWETH(wethToken).deposit{ value: msg.value }();
    }

    function topUpWETH(address onBehalfOf, uint256 value) external override {
        evm.prank(onBehalfOf);
        IWETH(wethToken).deposit{ value: value }();
    }

    function mint(
        address token,
        address to,
        uint256 amount
    ) external {
        Tokens index = tokenIndexes[token];
        require(index != Tokens.NO_TOKEN, "No token with such address");
        mint(index, to, amount);
    }

    function mint(
        Tokens t,
        address to,
        uint256 amount
    ) public {
        if (t == Tokens.WETH) {
            evm.deal(address(this), amount);
            IWETH(wethToken).deposit{ value: amount }();
        } else {
            ERC20Mock(addressOf[t]).mint(address(this), amount);
        }

        IERC20(addressOf[t]).transfer(to, amount);
    }

    function balanceOf(address token, address holder)
        public
        view
        returns (uint256 balance)
    {
        balance = IERC20(token).balanceOf(holder);
    }

    function balanceOf(Tokens t, address holder)
        public
        view
        returns (uint256 balance)
    {
        balance = IERC20(addressOf[t]).balanceOf(holder);
    }

    function approve(
        address token,
        address holder,
        address targetContract
    ) external {
        Tokens index = tokenIndexes[token];
        require(index != Tokens.NO_TOKEN, "No token with such address");
        approve(index, holder, targetContract);
    }

    function approve(
        Tokens t,
        address holder,
        address targetContract
    ) public {
        approve(t, holder, targetContract, type(uint256).max);
    }

    function approve(
        Tokens t,
        address holder,
        address targetContract,
        uint256 amount
    ) public {
        evm.prank(holder);
        IERC20(addressOf[t]).approve(targetContract, amount);
    }

    function allowance(
        Tokens t,
        address holder,
        address targetContract
    ) external view returns (uint256) {
        return IERC20(addressOf[t]).allowance(holder, targetContract);
    }

    function burn(
        Tokens t,
        address from,
        uint256 amount
    ) external {
        ERC20Mock(addressOf[t]).burn(from, amount);
    }

    receive() external payable {}
}
