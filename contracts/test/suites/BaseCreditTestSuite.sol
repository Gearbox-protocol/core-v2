// SPDX-License-Identifier: BUSL-1.1
// Gearbox Protocol. Generalized leverage for DeFi protocols
// (c) Gearbox Holdings, 2021
pragma solidity ^0.8.10;

import { AddressProvider } from "../../core/AddressProvider.sol";
import { IPriceOracleV2Ext } from "../../interfaces/IPriceOracle.sol";
import { ACL } from "../../core/ACL.sol";
import { ContractsRegister } from "../../core/ContractsRegister.sol";
import { AccountFactory } from "../../core/AccountFactory.sol";
import { GenesisFactory } from "../../factories/GenesisFactory.sol";
import { PoolFactory, PoolOpts } from "../../factories/PoolFactory.sol";

import { TokensTestSuite, Tokens } from "../suites/TokensTestSuite.sol";

import { CreditManagerOpts, CollateralToken } from "../../credit/CreditConfigurator.sol";
import { PoolServiceMock } from "../mocks/pool/PoolServiceMock.sol";

import "../lib/constants.sol";

import { PriceFeedMock } from "../mocks/oracles/PriceFeedMock.sol";
import { AggregatorV3Interface } from "@chainlink/contracts/src/v0.8/interfaces/AggregatorV3Interface.sol";

struct PoolCreditOpts {
    PoolOpts poolOpts;
    CreditManagerOpts creditOpts;
}

struct CollateralTokensItem {
    Tokens token;
    uint16 liquidationThreshold;
}

/// @title CreditManagerTestSuite
/// @notice Deploys contract for unit testing of CreditManager.sol
contract BaseCreditTestSuite is DSTest {
    CheatCodes evm = CheatCodes(HEVM_ADDRESS);

    TokensTestSuite public tokenTestSuite;
    AddressProvider public addressProvider;
    GenesisFactory public gp;
    AccountFactory public af;
    PoolServiceMock public poolMock;
    ContractsRegister public cr;
    ACL public acl;

    IPriceOracleV2Ext public priceOracle;

    address public underlying;

    mapping(Tokens => uint16) public lt;

    constructor(TokensTestSuite _tokenTestSuite, Tokens _underlying) {
        new Roles();

        tokenTestSuite = _tokenTestSuite;

        gp = new GenesisFactory(tokenTestSuite.wethToken(), DUMB_ADDRESS);

        gp.acl().claimOwnership();
        gp.addressProvider().claimOwnership();

        gp.acl().addPausableAdmin(CONFIGURATOR);
        gp.acl().addUnpausableAdmin(CONFIGURATOR);

        gp.acl().transferOwnership(address(gp));
        gp.claimACLOwnership();

        gp.addPriceFeeds(tokenTestSuite.getPriceFeeds());
        gp.acl().claimOwnership();

        addressProvider = gp.addressProvider();
        af = AccountFactory(addressProvider.getAccountFactory());

        priceOracle = IPriceOracleV2Ext(addressProvider.getPriceOracle());

        acl = ACL(addressProvider.getACL());

        cr = ContractsRegister(addressProvider.getContractsRegister());

        underlying = tokenTestSuite.addressOf(_underlying);

        poolMock = new PoolServiceMock(
            address(gp.addressProvider()),
            underlying
        );

        tokenTestSuite.mint(
            _underlying,
            address(poolMock),
            10 * _getAccountAmount()
        );

        cr.addPool(address(poolMock));
    }

    function _getCollateralTokens(Tokens t)
        public
        returns (CollateralToken[] memory collateralTokens)
    {
        CollateralTokensItem[11] memory collateralTokenOpts = [
            CollateralTokensItem({
                token: Tokens.USDC,
                liquidationThreshold: 9000
            }),
            CollateralTokensItem({
                token: Tokens.USDT,
                liquidationThreshold: 8800
            }),
            CollateralTokensItem({
                token: Tokens.DAI,
                liquidationThreshold: 8300
            }),
            CollateralTokensItem({
                token: Tokens.WETH,
                liquidationThreshold: 8300
            }),
            CollateralTokensItem({
                token: Tokens.LINK,
                liquidationThreshold: 7300
            }),
            CollateralTokensItem({
                token: Tokens.CRV,
                liquidationThreshold: 7300
            }),
            CollateralTokensItem({
                token: Tokens.CVX,
                liquidationThreshold: 7300
            }),
            CollateralTokensItem({
                token: Tokens.STETH,
                liquidationThreshold: 7300
            }),
            CollateralTokensItem({
                token: Tokens.cDAI,
                liquidationThreshold: 8300
            }),
            CollateralTokensItem({
                token: Tokens.cUSDC,
                liquidationThreshold: 9000
            }),
            CollateralTokensItem({
                token: Tokens.cUSDT,
                liquidationThreshold: 8800
            })
        ];

        lt[t] = 9300;

        uint256 len = collateralTokenOpts.length;
        collateralTokens = new CollateralToken[](len - 1);
        uint256 j;
        for (uint256 i = 0; i < len; i++) {
            if (collateralTokenOpts[i].token == t) continue;

            lt[collateralTokenOpts[i].token] = collateralTokenOpts[i]
                .liquidationThreshold;

            collateralTokens[j] = CollateralToken({
                token: tokenTestSuite.addressOf(collateralTokenOpts[i].token),
                liquidationThreshold: collateralTokenOpts[i]
                    .liquidationThreshold
            });
            j++;
        }
    }

    function addMockPriceFeed(address token, uint256 price) external {
        AggregatorV3Interface priceFeed = new PriceFeedMock(int256(price), 8);

        evm.prank(CONFIGURATOR);
        priceOracle.addPriceFeed(token, address(priceFeed));
    }

    function _getAccountAmount() public view returns (uint256) {
        return
            (underlying == tokenTestSuite.addressOf(Tokens.DAI))
                ? DAI_ACCOUNT_AMOUNT
                : WETH_ACCOUNT_AMOUNT;
    }
}
