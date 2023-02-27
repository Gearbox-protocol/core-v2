// SPDX-License-Identifier: GPL-2.0-or-later
// Gearbox Protocol. Generalized leverage for DeFi protocols
// (c) Gearbox Holdings, 2022
pragma solidity ^0.8.17;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import {IAdapter} from "../interfaces/adapters/IAdapter.sol";
import {ICreditManagerV2} from "../interfaces/ICreditManagerV2.sol";
import {ZeroAddressException} from "../interfaces/IErrors.sol";

/// @title Abstract adapter
/// @dev Inheriting adapters MUST use provided internal functions to perform all operations with credit accounts
abstract contract AbstractAdapter is IAdapter {
    /// @notice Credit Manager the adapter is connected to
    ICreditManagerV2 public immutable override creditManager;
    /// @notice Address of the contract the adapter is interacting with
    address public immutable override targetContract;

    /// @notice Constructor
    /// @param _creditManager Credit Manager to connect this adapter to
    /// @param _targetContract Address of the contract this adapter should interact with
    constructor(address _creditManager, address _targetContract) {
        if (_creditManager == address(0) || _targetContract == address(0)) {
            revert ZeroAddressException();
        } // F: [AA-2]

        creditManager = ICreditManagerV2(_creditManager); // F: [AA-1]
        targetContract = _targetContract; // F: [AA-1]
    }

    /// @dev Reverts if the caller of the function is not the Credit Facade
    /// @dev Adapter functions are only allowed to be called from within the multicall
    ///      Since at this point Credit Account is owned by the Credit Facade, all functions
    ///      of inheriting adapters that perform actions on account MUST have this modifier
    modifier creditFacadeOnly() {
        if (msg.sender != _creditFacade()) {
            revert CreditFacadeOnlyException(); // F: [AA-5]
        }
        _;
    }

    /// @dev Returns the Credit Facade connected to the Credit Manager
    function _creditFacade() internal view returns (address) {
        return creditManager.creditFacade(); // F: [AA-3]
    }

    /// @dev Returns the Credit Account currently owned by the Credit Facade
    /// @dev Inheriting adapters MUST use this function to find the account address
    function _creditAccount() internal view returns (address) {
        return creditManager.getCreditAccountOrRevert(_creditFacade()); // F: [AA-4]
    }

    /// @dev Executes an arbitrary call from the Credit Account to the target contract
    /// @param callData Data to call the target contract with
    /// @return result Call output
    function _execute(bytes memory callData) internal returns (bytes memory result) {
        return creditManager.executeOrder(targetContract, callData); // F: [AA-6,9]
    }

    /// @dev Approves a token from the Credit Account to the target contract
    /// @param token Token to be approved
    /// @param amount Amount to be approved
    function _approveToken(address token, uint256 amount) internal {
        creditManager.approveCreditAccount(targetContract, token, amount); // F: [AA-6,10]
    }

    /// @dev Enable a token in the Credit Account
    /// @param token Address of the token to enable
    function _enableToken(address token) internal {
        creditManager.checkAndEnableToken(token); // F: [AA-6,11]
    }

    /// @dev Disable a token in the Credit Account
    /// @param token Address of the token to disable
    function _disableToken(address token) internal {
        creditManager.disableToken(token); // F: [AA-6,12]
    }

    /// @dev Executes a swap operation on the target contract from the Credit Account
    ///      without explicit approval to spend `tokenIn`
    /// @param tokenIn The token that the call is expected to spend
    /// @param tokenOut The token that the call is expected to produce
    /// @param callData Data to call the target contract with
    /// @param disableTokenIn Whether the input token should be disabled afterwards
    ///        (for operations that spend the entire balance)
    /// @return result Call output
    function _executeSwapNoApprove(address tokenIn, address tokenOut, bytes memory callData, bool disableTokenIn)
        internal
        returns (bytes memory result)
    {
        return _executeSwap(tokenIn, tokenOut, callData, disableTokenIn, false); // F: [AA-6,7]
    }

    /// @dev Executes a swap operation on the target contract from the Credit Account
    ///      with maximal `tokenIn` allowance, and then sets the allowance to 1
    /// @param tokenIn The token that the call is expected to spend
    /// @param tokenOut The token that the call is expected to produce
    /// @param callData Data to call the target contract with
    /// @param disableTokenIn Whether the input token should be disabled afterwards
    ///        (for operations that spend the entire balance)
    /// @return result Call output
    function _executeSwapSafeApprove(address tokenIn, address tokenOut, bytes memory callData, bool disableTokenIn)
        internal
        returns (bytes memory result)
    {
        return _executeSwap(tokenIn, tokenOut, callData, disableTokenIn, true); // F: [AA-6,8]
    }

    /// @dev Implementation of `_executeSwap...` operations
    /// @dev Kept private as only the internal wrappers are intended to be used
    ///      by inheritors
    function _executeSwap(
        address tokenIn,
        address tokenOut,
        bytes memory callData,
        bool disableTokenIn,
        bool allowTokenIn
    ) private returns (bytes memory result) {
        if (allowTokenIn) {
            _approveToken(tokenIn, type(uint256).max); // F: [AA-8]
        }

        result = _execute(callData); // F: [AA-7,8]

        if (allowTokenIn) {
            _approveToken(tokenIn, 1); // F: [AA-8]
        }

        if (disableTokenIn) {
            _disableToken(tokenIn); // F: [AA-7,8]
        }
        _enableToken(tokenOut); // F: [AA-7,8]
    }
}
