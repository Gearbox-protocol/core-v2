// SPDX-License-Identifier: UNLICENSED
// Gearbox Protocol. Generalized leverage for DeFi protocols
// (c) Gearbox Holdings, 2022
pragma solidity ^0.8.10;

import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { IERC20Metadata } from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";

import "../lib/test.sol";

/// @title CreditManagerTestSuite
/// @notice Deploys contract for unit testing of CreditManager.sol
contract BalanceEngine is DSTest {
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
