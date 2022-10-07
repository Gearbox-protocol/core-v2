// SPDX-License-Identifier: BUSL-1.1
// Gearbox Protocol. Generalized leverage for DeFi protocols
// (c) Gearbox Holdings, 2021
pragma solidity ^0.8.10;

import { TokensTestSuite } from "../suites/TokensTestSuite.sol";
import { CreditFacadeTestEngine } from "../helpers/CreditFacadeTestEngine.sol";
import "../lib/constants.sol";
import { Tokens } from "../config/Tokens.sol";

/// @title CreditManagerTestSuite
/// @notice Deploys contract for unit testing of CreditManager.sol
contract CreditFacadeTestHelper is CreditFacadeTestEngine {
    function expectTokenIsEnabled(Tokens t, bool expectedState) internal {
        expectTokenIsEnabled(t, expectedState, "");
    }

    function expectTokenIsEnabled(
        Tokens t,
        bool expectedState,
        string memory reason
    ) internal {
        expectTokenIsEnabled(
            tokenTestSuite().addressOf(t),
            expectedState,
            reason
        );
    }

    function _addCollateral(Tokens t, uint256 amount) internal {
        tokenTestSuite().mint(t, USER, amount);
        tokenTestSuite().approve(t, USER, address(creditManager));

        evm.startPrank(USER);
        creditFacade.addCollateral(USER, tokenTestSuite().addressOf(t), amount);
        evm.stopPrank();
    }

    function tokenTestSuite() private returns (TokensTestSuite) {
        return TokensTestSuite(payable(address(cft.tokenTestSuite())));
    }
}
