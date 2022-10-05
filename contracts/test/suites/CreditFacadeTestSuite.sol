// SPDX-License-Identifier: BUSL-1.1
// Gearbox Protocol. Generalized leverage for DeFi protocols
// (c) Gearbox Holdings, 2021
pragma solidity ^0.8.10;

import { CreditFacade } from "../../credit/CreditFacade.sol";
import { CreditConfigurator } from "../../credit/CreditConfigurator.sol";

import { TokensTestSuite, Tokens } from "../suites/TokensTestSuite.sol";
import { CreditManager } from "../../credit/CreditManager.sol";

import { CreditManagerFactory } from "../../factories/CreditManagerFactory.sol";
import { CreditManagerOpts, CollateralToken } from "../../credit/CreditConfigurator.sol";

import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import { DegenNFT } from "../../tokens/DegenNFT.sol";

import "../lib/constants.sol";

import { BaseCreditTestSuite, CollateralTokensItem } from "./BaseCreditTestSuite.sol";

/// @title CreditManagerTestSuite
/// @notice Deploys contract for unit testing of CreditManager.sol
contract CreditFacadeTestSuite is BaseCreditTestSuite {
    CreditManager public creditManager;
    CreditFacade public creditFacade;
    CreditConfigurator public creditConfigurator;
    DegenNFT public degenNFT;

    uint128 public minBorrowedAmount;
    uint128 public maxBorrowedAmount;

    constructor(TokensTestSuite _tokenTestSuite, Tokens _underlying)
        BaseCreditTestSuite(_tokenTestSuite, _underlying)
    {
        minBorrowedAmount = uint128(WAD);
        maxBorrowedAmount = uint128(10 * _getAccountAmount());

        CreditManagerOpts memory creditOpts = CreditManagerOpts({
            minBorrowedAmount: minBorrowedAmount,
            maxBorrowedAmount: maxBorrowedAmount,
            collateralTokens: _getCollateralTokens(_underlying),
            degenNFT: address(0),
            expirable: false
        });

        CreditManagerFactory cmf = new CreditManagerFactory(
            address(poolMock),
            creditOpts,
            0
        );

        creditManager = cmf.creditManager();
        creditFacade = cmf.creditFacade();
        creditConfigurator = cmf.creditConfigurator();

        cr.addCreditManager(address(creditManager));

        evm.label(address(poolMock), "Pool");
        evm.label(address(creditFacade), "CreditFacade");
        evm.label(address(creditManager), "CreditManager");
        evm.label(address(creditConfigurator), "CreditConfigurator");

        // Charge USER
        tokenTestSuite.mint(_underlying, USER, _getAccountAmount());
        tokenTestSuite.mint(_underlying, FRIEND, _getAccountAmount());
        evm.prank(USER);
        IERC20(underlying).approve(address(creditManager), type(uint256).max);
        evm.prank(FRIEND);
        IERC20(underlying).approve(address(creditManager), type(uint256).max);

        addressProvider.transferOwnership(CONFIGURATOR);
        acl.transferOwnership(CONFIGURATOR);

        evm.startPrank(CONFIGURATOR);

        acl.claimOwnership();
        addressProvider.claimOwnership();

        evm.stopPrank();
    }

    function testFacadeWithDegenNFT() external {
        degenNFT = new DegenNFT(
            address(addressProvider),
            "DegenNFT",
            "Gear-Degen"
        );

        evm.startPrank(CONFIGURATOR);

        degenNFT.setMinter(CONFIGURATOR);

        creditFacade = new CreditFacade(
            address(creditManager),
            address(degenNFT),
            false
        );

        creditConfigurator.upgradeCreditFacade(address(creditFacade), true);

        degenNFT.addCreditFacade(address(creditFacade));

        evm.stopPrank();
    }

    function testFacadeWithExpiration() external {
        evm.startPrank(CONFIGURATOR);

        creditFacade = new CreditFacade(
            address(creditManager),
            address(0),
            true
        );

        creditConfigurator.upgradeCreditFacade(address(creditFacade), true);
        creditConfigurator.setExpirationDate(uint40(block.timestamp + 1));

        evm.stopPrank();
    }
}
