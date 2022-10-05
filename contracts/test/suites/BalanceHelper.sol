// SPDX-License-Identifier: BUSL-1.1
// Gearbox Protocol. Generalized leverage for DeFi protocols
// (c) Gearbox Holdings, 2021
pragma solidity ^0.8.10;

import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { IERC20Metadata } from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";

import { TokensTestSuite, Tokens } from "../suites/TokensTestSuite.sol";
import "../lib/test.sol";

/// @title CreditManagerTestSuite
/// @notice Deploys contract for unit testing of CreditManager.sol
contract BalanceHelper is DSTest {
    // Suites
    TokensTestSuite internal tokenTestSuite;

    function expectBalance(
        Tokens t,
        address holder,
        uint256 expectedBalance
    ) internal {
        expectBalance(t, holder, expectedBalance, "");
    }

    function expectBalance(
        Tokens t,
        address holder,
        uint256 expectedBalance,
        string memory reason
    ) internal {
        require(
            address(tokenTestSuite) != address(0),
            "tokenTestSuite is not set"
        );

        expectBalance(
            tokenTestSuite.addressOf(t),
            holder,
            expectedBalance,
            reason
        );
    }

    function expectBalance(
        address token,
        address holder,
        uint256 expectedBalance
    ) internal {
        expectBalance(token, holder, expectedBalance, "");
    }

    function expectBalanceGe(
        address token,
        address holder,
        uint256 minBalance,
        string memory reason
    ) internal {
        uint256 balance = IERC20(token).balanceOf(holder);

        if (balance < minBalance)
            emit log_named_address(
                string(
                    abi.encodePacked(
                        reason,
                        "Insufficient ",
                        IERC20Metadata(token).symbol(),
                        " balance on account: "
                    )
                ),
                holder
            );

        assertGe(balance, minBalance);
    }

    function expectBalanceGe(
        Tokens t,
        address holder,
        uint256 minBalance,
        string memory reason
    ) internal {
        require(
            address(tokenTestSuite) != address(0),
            "tokenTestSuite is not set"
        );

        expectBalanceGe(
            tokenTestSuite.addressOf(t),
            holder,
            minBalance,
            reason
        );
    }

    function expectBalanceLe(
        Tokens t,
        address holder,
        uint256 maxBalance,
        string memory reason
    ) internal {
        require(
            address(tokenTestSuite) != address(0),
            "tokenTestSuite is not set"
        );

        expectBalanceLe(
            tokenTestSuite.addressOf(t),
            holder,
            maxBalance,
            reason
        );
    }

    function expectBalanceLe(
        address token,
        address holder,
        uint256 maxBalance,
        string memory reason
    ) internal {
        uint256 balance = IERC20(token).balanceOf(holder);

        if (balance > maxBalance)
            emit log_named_address(
                string(
                    abi.encodePacked(
                        reason,
                        "Exceeding ",
                        IERC20Metadata(token).symbol(),
                        " balance on account: "
                    )
                ),
                holder
            );

        assertLe(balance, maxBalance);
    }

    function expectBalance(
        address token,
        address holder,
        uint256 expectedBalance,
        string memory reason
    ) internal {
        uint256 balance = IERC20(token).balanceOf(holder);

        if (balance != expectedBalance)
            emit log_named_address(
                string(
                    abi.encodePacked(
                        reason,
                        "Incorrect ",
                        IERC20Metadata(token).symbol(),
                        " balance on account: "
                    )
                ),
                holder
            );

        assertEq(balance, expectedBalance);
    }

    function expectEthBalance(address account, uint256 expectedBalance)
        internal
    {
        expectEthBalance(account, expectedBalance, "");
    }

    function expectEthBalance(
        address account,
        uint256 expectedBalance,
        string memory reason
    ) internal {
        uint256 balance = account.balance;
        if (balance != expectedBalance)
            emit log_named_address(
                string(
                    abi.encodePacked(
                        reason,
                        "Incorrect ETH balance on account: "
                    )
                ),
                account
            );

        assertEq(balance, expectedBalance);
    }

    function expectAllowance(
        Tokens t,
        address owner,
        address spender,
        uint256 expectedAllowance
    ) internal {
        expectAllowance(t, owner, spender, expectedAllowance, "");
    }

    function expectAllowance(
        Tokens t,
        address owner,
        address spender,
        uint256 expectedAllowance,
        string memory reason
    ) internal {
        require(
            address(tokenTestSuite) != address(0),
            "tokenTestSuite is not set"
        );

        expectAllowance(
            tokenTestSuite.addressOf(t),
            owner,
            spender,
            expectedAllowance,
            reason
        );
    }

    function expectAllowance(
        address token,
        address owner,
        address spender,
        uint256 expectedAllowance
    ) internal {
        expectAllowance(token, owner, spender, expectedAllowance, "");
    }

    function expectAllowance(
        address token,
        address owner,
        address spender,
        uint256 expectedAllowance,
        string memory reason
    ) internal {
        uint256 allowance = IERC20(token).allowance(owner, spender);

        if (allowance != expectedAllowance) {
            emit log_named_address(
                string(
                    abi.encodePacked(
                        reason,
                        "Incorrect ",
                        IERC20Metadata(token).symbol(),
                        " Allowance on account:  "
                    )
                ),
                owner
            );
            emit log_named_address(" spender: ", spender);
        }
        assertEq(allowance, expectedAllowance);
    }
}
