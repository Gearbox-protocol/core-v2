// SPDX-License-Identifier: BUSL-1.1
// Gearbox Protocol. Generalized leverage for DeFi protocols
// (c) Gearbox Holdings, 2021
pragma solidity ^0.8.10;

import { CreditFacade } from "../../credit/CreditFacade.sol";
import { CreditConfigurator } from "../../credit/CreditConfigurator.sol";
import { CreditManager } from "../../credit/CreditManager.sol";

import { CreditManagerFactoryBase } from "../../factories/CreditManagerFactoryBase.sol";
import { CreditManagerOpts, CollateralToken } from "../../credit/CreditConfigurator.sol";

import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import { DegenNFT } from "../../tokens/DegenNFT.sol";

import "../lib/constants.sol";

import { PoolDeployer } from "./PoolDeployer.sol";
import { ICreditConfig } from "../interfaces/ICreditConfig.sol";
import { ITokenTestSuite } from "../interfaces/ITokenTestSuite.sol";

/// @title CreditManagerTestSuite
/// @notice Deploys contract for unit testing of CreditManager.sol
contract CreditFacadeTestSuite is PoolDeployer {
    ITokenTestSuite public tokenTestSuite;

    CreditManager public creditManager;
    CreditFacade public creditFacade;
    CreditConfigurator public creditConfigurator;
    DegenNFT public degenNFT;

    uint128 public minBorrowedAmount;
    uint128 public maxBorrowedAmount;

    uint256 public creditAccountAmount;

    constructor(ICreditConfig creditConfig)
        PoolDeployer(
            creditConfig.tokenTestSuite(),
            creditConfig.underlying(),
            creditConfig.wethToken(),
            10 * creditConfig.getAccountAmount(),
            creditConfig.getPriceFeeds()
        )
    {
        minBorrowedAmount = creditConfig.minBorrowedAmount();
        maxBorrowedAmount = creditConfig.maxBorrowedAmount();

        tokenTestSuite = creditConfig.tokenTestSuite();

        creditAccountAmount = creditConfig.getAccountAmount();

        CreditManagerFactoryBase cmf = new CreditManagerFactoryBase(
            address(poolMock),
            creditConfig.getCreditOpts(),
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

        tokenTestSuite.mint(underlying, USER, creditAccountAmount);
        tokenTestSuite.mint(underlying, FRIEND, creditAccountAmount);

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
