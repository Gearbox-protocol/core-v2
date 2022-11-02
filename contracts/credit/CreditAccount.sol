// SPDX-License-Identifier: BUSL-1.1
// Gearbox Protocol. Generalized leverage for DeFi protocols
// (c) Gearbox Holdings, 2022
pragma solidity ^0.8.10;

import { Initializable } from "@openzeppelin/contracts/proxy/utils/Initializable.sol";

import { Address } from "@openzeppelin/contracts/utils/Address.sol";

import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { SafeERC20 } from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import { ICreditAccount } from "../interfaces/ICreditAccount.sol";

/// @title Credit Account
/// @notice Implements generic credit account logic:
///   - Holds collateral assets
///   - Stores general parameters: borrowed amount, cumulative index at open and block when it was initialized
///   - Transfers assets
///   - Executes financial orders by calling connected protocols on its behalf
///
///  More: https://dev.gearbox.fi/developers/credit/credit_account
contract CreditAccount is ICreditAccount, Initializable {
    using SafeERC20 for IERC20;
    using Address for address;

    /// @dev Address of the Credit Account factory
    address public override factory;

    /// @dev Address of the currently connected Credit Manager
    address public override creditManager;

    /// @dev The principal amount borrowed from the pool
    uint256 public override borrowedAmount;

    /// @dev Cumulative interest index since the last Credit Account's debt update
    uint256 public override cumulativeIndexAtOpen;

    /// @dev Block at which the contract was last taken from the factory
    uint256 public override since;

    // Contract version
    uint256 public constant version = 1;

    /// @dev Restricts operations to the connected Credit Manager only
    modifier creditManagerOnly() {
        if (msg.sender != creditManager)
            revert CallerNotCreditManagerException();
        _;
    }

    /// @dev Restricts operation to the Credit Account factory
    modifier factoryOnly() {
        if (msg.sender != factory) revert CallerNotFactoryException();
        _;
    }

    /// @dev Called on new Credit Account creation.
    /// @notice Initialize is used instead of constructor, since the contract is cloned.
    function initialize() external override initializer {
        factory = msg.sender;
    }

    /// @dev Connects this credit account to a Credit Manager. Restricted to the account factory (owner) only.
    /// @param _creditManager Credit manager address
    /// @param _borrowedAmount The amount borrowed at Credit Account opening
    /// @param _cumulativeIndexAtOpen The interest index at Credit Account opening
    function connectTo(
        address _creditManager,
        uint256 _borrowedAmount,
        uint256 _cumulativeIndexAtOpen
    ) external override factoryOnly {
        creditManager = _creditManager; // T:[CA-7]
        borrowedAmount = _borrowedAmount; // T:[CA-3,7]
        cumulativeIndexAtOpen = _cumulativeIndexAtOpen; //  T:[CA-3,7]
        since = block.number; // T:[CA-7]
    }

    /// @dev Updates borrowed amount and cumulative index. Restricted to the currently connected Credit Manager.
    /// @param _borrowedAmount The amount currently lent to the Credit Account
    /// @param _cumulativeIndexAtOpen New cumulative index to calculate interest from
    function updateParameters(
        uint256 _borrowedAmount,
        uint256 _cumulativeIndexAtOpen
    )
        external
        override
        creditManagerOnly // T:[CA-2]
    {
        borrowedAmount = _borrowedAmount; // T:[CA-4]
        cumulativeIndexAtOpen = _cumulativeIndexAtOpen;
    }

    /// @dev Removes allowance for a token to a 3rd-party contract. Restricted to factory only.
    /// @param token ERC20 token to remove allowance for.
    /// @param targetContract Target contract to revoke allowance to.
    function cancelAllowance(address token, address targetContract)
        external
        override
        factoryOnly
    {
        IERC20(token).safeApprove(targetContract, 0);
    }

    /// @dev Transfers tokens from the credit account to a provided address. Restricted to the current Credit Manager only.
    /// @param token Token to be transferred from the Credit Account.
    /// @param to Address of the recipient.
    /// @param amount Amount to be transferred.
    function safeTransfer(
        address token,
        address to,
        uint256 amount
    )
        external
        override
        creditManagerOnly // T:[CA-2]
    {
        IERC20(token).safeTransfer(to, amount); // T:[CA-6]
    }

    /// @dev Executes a call to a 3rd party contract with provided data. Restricted to the current Credit Manager only.
    /// @param destination Contract address to be called.
    /// @param data Data to call the contract with.
    function execute(address destination, bytes memory data)
        external
        override
        creditManagerOnly
        returns (bytes memory)
    {
        return destination.functionCall(data); // T: [CM-48]
    }
}
