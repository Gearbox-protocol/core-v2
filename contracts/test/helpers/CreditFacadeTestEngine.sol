// SPDX-License-Identifier: UNLICENSED
// Gearbox Protocol. Generalized leverage for DeFi protocols
// (c) Gearbox Holdings, 2022
pragma solidity ^0.8.10;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IERC20Metadata} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import {CreditFacade} from "../../credit/CreditFacade.sol";
import {CreditConfigurator} from "../../credit/CreditConfigurator.sol";
import {MultiCall} from "../../interfaces/ICreditFacade.sol";

import {ICreditManagerV2, ICreditManagerV2Events} from "../../interfaces/ICreditManagerV2.sol";

import {CreditFacadeTestSuite} from "../suites/CreditFacadeTestSuite.sol";
// import { TokensTestSuite, Tokens } from "../suites/TokensTestSuite.sol";

import "../lib/constants.sol";

/// @title CreditManagerTestSuite
/// @notice Deploys contract for unit testing of CreditManager.sol
contract CreditFacadeTestEngine is DSTest {
    CheatCodes evm = CheatCodes(HEVM_ADDRESS);

    // Suites
    ICreditManagerV2 public creditManager;
    CreditFacade public creditFacade;
    CreditConfigurator public creditConfigurator;

    CreditFacadeTestSuite public cft;

    address public underlying;

    ///
    /// HELPERS
    ///

    function _openTestCreditAccount() internal returns (address creditAccount, uint256 balance) {
        uint256 accountAmount = cft.creditAccountAmount();

        cft.tokenTestSuite().mint(underlying, USER, accountAmount);

        evm.prank(USER);
        creditFacade.openCreditAccount(accountAmount, USER, 100, 0);

        creditAccount = creditManager.getCreditAccountOrRevert(USER);

        balance = IERC20(underlying).balanceOf(creditAccount);

        evm.label(creditAccount, "creditAccount");
    }

    function _openExtraTestCreditAccount() internal returns (address creditAccount, uint256 balance) {
        uint256 accountAmount = cft.creditAccountAmount();

        evm.prank(FRIEND);
        creditFacade.openCreditAccount(accountAmount, FRIEND, 100, 0);

        creditAccount = creditManager.getCreditAccountOrRevert(FRIEND);

        balance = IERC20(underlying).balanceOf(creditAccount);
    }

    function _closeTestCreditAccount() internal {
        MultiCall[] memory closeCalls;

        // switch to new block to be able to close account
        evm.roll(block.number + 1);

        address creditAccount = creditManager.getCreditAccountOrRevert(USER);

        (,, uint256 underlyingToClose) = creditManager.calcCreditAccountAccruedInterest(creditAccount);
        uint256 underlyingBalance = cft.tokenTestSuite().balanceOf(underlying, creditAccount);

        if (underlyingToClose > underlyingBalance) {
            cft.tokenTestSuite().mint(underlying, USER, underlyingToClose - underlyingBalance);

            cft.tokenTestSuite().approve(underlying, USER, address(creditManager));
        }

        evm.prank(USER);
        creditFacade.closeCreditAccount(FRIEND, 0, false, closeCalls);
    }

    function expectTokenIsEnabled(address token, bool expectedState) internal {
        expectTokenIsEnabled(token, expectedState, "");
    }

    function expectTokenIsEnabled(address token, bool expectedState, string memory reason) internal {
        address creditAccount = creditManager.getCreditAccountOrRevert(USER);

        bool state = creditManager.tokenMasksMap(token) & creditManager.enabledTokensMap(creditAccount) != 0;

        if (state != expectedState && bytes(reason).length != 0) {
            emit log_string(reason);
        }

        assertTrue(
            state == expectedState,
            string(
                abi.encodePacked(
                    "Token ",
                    IERC20Metadata(token).symbol(),
                    state ? " enabled as not expetcted" : " not enabled as expected "
                )
            )
        );
    }

    function addCollateral(address token, uint256 amount) internal {
        // tokenTestSuite.mint(t, USER, amount);

        evm.startPrank(USER);
        IERC20(token).approve(address(creditManager), type(uint256).max);

        creditFacade.addCollateral(USER, token, amount);

        evm.stopPrank();
    }

    function _makeAccountsLiquitable() internal {
        evm.prank(CONFIGURATOR);
        creditConfigurator.setFees(1000, 200, 9000, 100, 9500);

        // switch to new block to be able to close account
        evm.roll(block.number + 1);
    }

    function executeOneLineMulticall(address targetContract, bytes memory callData) internal {
        evm.prank(USER);
        creditFacade.multicall(multicallBuilder(MultiCall({target: targetContract, callData: callData})));
    }

    function multicallBuilder() internal pure returns (MultiCall[] memory calls) {}

    function multicallBuilder(MultiCall memory call1) internal pure returns (MultiCall[] memory calls) {
        calls = new MultiCall[](1);
        calls[0] = call1;
    }

    function multicallBuilder(MultiCall memory call1, MultiCall memory call2)
        internal
        pure
        returns (MultiCall[] memory calls)
    {
        calls = new MultiCall[](2);
        calls[0] = call1;
        calls[1] = call2;
    }

    function multicallBuilder(MultiCall memory call1, MultiCall memory call2, MultiCall memory call3)
        internal
        pure
        returns (MultiCall[] memory calls)
    {
        calls = new MultiCall[](3);
        calls[0] = call1;
        calls[1] = call2;
        calls[2] = call3;
    }

    function expectSafeAllowance(address target) internal {
        address creditAccount = creditManager.getCreditAccountOrRevert(USER);
        uint256 len = creditManager.collateralTokensCount();
        for (uint256 i = 0; i < len; i++) {
            (address token,) = creditManager.collateralTokens(i);
            assertLe(IERC20(token).allowance(creditAccount, target), 1, "allowance is too high");
        }
    }

    function arrayOf(address addr0, address addr1) internal pure returns (address[] memory result) {
        result = new address[](2);
        result[0] = addr0;
        result[1] = addr1;
    }
}
