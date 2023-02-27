// SPDX-License-Identifier: UNLICENSED
// Gearbox Protocol. Generalized leverage for DeFi protocols
// (c) Gearbox Holdings, 2022
pragma solidity ^0.8.10;

import {TokensTestSuite} from "../suites/TokensTestSuite.sol";
import {Tokens} from "./Tokens.sol";

import {CreditManagerOpts, CollateralToken} from "../../credit/CreditConfigurator.sol";

import {PriceFeedConfig} from "../../oracles/PriceOracle.sol";
import {ICreditConfig} from "../interfaces/ICreditConfig.sol";
import {ITokenTestSuite} from "../interfaces/ITokenTestSuite.sol";

import "../lib/constants.sol";

struct CollateralTokensItem {
    Tokens token;
    uint16 liquidationThreshold;
}

/// @title CreditManagerTestSuite
/// @notice Deploys contract for unit testing of CreditManager.sol
contract CreditConfig is DSTest, ICreditConfig {
    uint128 public minBorrowedAmount;
    uint128 public maxBorrowedAmount;

    TokensTestSuite public _tokenTestSuite;

    mapping(Tokens => uint16) public lt;

    address public override underlying;

    address public override wethToken;

    Tokens public underlyingSymbol;

    constructor(TokensTestSuite tokenTestSuite_, Tokens _underlying) {
        underlyingSymbol = _underlying;
        underlying = tokenTestSuite_.addressOf(_underlying);

        uint256 accountAmount = getAccountAmount();

        minBorrowedAmount = getMinBorrowAmount();
        maxBorrowedAmount = uint128(10 * accountAmount);

        _tokenTestSuite = tokenTestSuite_;

        wethToken = tokenTestSuite_.addressOf(Tokens.WETH);
        underlyingSymbol = _underlying;
    }

    function getCreditOpts() external override returns (CreditManagerOpts memory) {
        return CreditManagerOpts({
            minBorrowedAmount: minBorrowedAmount,
            maxBorrowedAmount: maxBorrowedAmount,
            collateralTokens: getCollateralTokens(),
            degenNFT: address(0),
            blacklistHelper: address(0),
            expirable: false
        });
    }

    function getCollateralTokens() public override returns (CollateralToken[] memory collateralTokens) {
        CollateralTokensItem[8] memory collateralTokenOpts = [
            CollateralTokensItem({token: Tokens.USDC, liquidationThreshold: 9000}),
            CollateralTokensItem({token: Tokens.USDT, liquidationThreshold: 8800}),
            CollateralTokensItem({token: Tokens.DAI, liquidationThreshold: 8300}),
            CollateralTokensItem({token: Tokens.WETH, liquidationThreshold: 8300}),
            CollateralTokensItem({token: Tokens.LINK, liquidationThreshold: 7300}),
            CollateralTokensItem({token: Tokens.CRV, liquidationThreshold: 7300}),
            CollateralTokensItem({token: Tokens.CVX, liquidationThreshold: 7300}),
            CollateralTokensItem({token: Tokens.STETH, liquidationThreshold: 7300})
        ];

        lt[underlyingSymbol] = DEFAULT_UNDERLYING_LT;

        uint256 len = collateralTokenOpts.length;
        collateralTokens = new CollateralToken[](len - 1);
        uint256 j;
        for (uint256 i = 0; i < len; i++) {
            if (collateralTokenOpts[i].token == underlyingSymbol) continue;

            lt[collateralTokenOpts[i].token] = collateralTokenOpts[i].liquidationThreshold;

            collateralTokens[j] = CollateralToken({
                token: _tokenTestSuite.addressOf(collateralTokenOpts[i].token),
                liquidationThreshold: collateralTokenOpts[i].liquidationThreshold
            });
            j++;
        }
    }

    function getMinBorrowAmount() internal view returns (uint128) {
        return (underlyingSymbol == Tokens.USDC) ? uint128(10 ** 6) : uint128(WAD);
    }

    function getAccountAmount() public view override returns (uint256) {
        return (underlyingSymbol == Tokens.DAI)
            ? DAI_ACCOUNT_AMOUNT
            : (underlyingSymbol == Tokens.USDC) ? USDC_ACCOUNT_AMOUNT : WETH_ACCOUNT_AMOUNT;
    }

    function getPriceFeeds() external view override returns (PriceFeedConfig[] memory) {
        return _tokenTestSuite.getPriceFeeds();
    }

    function tokenTestSuite() external view override returns (ITokenTestSuite) {
        return _tokenTestSuite;
    }
}
