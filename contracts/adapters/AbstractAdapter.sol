// SPDX-License-Identifier: GPL-2.0-or-later
// Gearbox Protocol. Generalized leverage for DeFi protocols
// (c) Gearbox Holdings, 2022
pragma solidity ^0.8.17;

import { Address } from "@openzeppelin/contracts/utils/Address.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { ICreditManagerV2 } from "../interfaces/ICreditManagerV2.sol";
import { IAdapter } from "../interfaces/adapters/IAdapter.sol";
import { ZeroAddressException } from "../interfaces/IErrors.sol";

/// @title Abstract adapter
/// @dev Must be inherited by other adapters
abstract contract AbstractAdapter is IAdapter {
    using Address for address;

    /// @inheritdoc IAdapter
    ICreditManagerV2 public immutable override creditManager;
    /// @inheritdoc IAdapter
    address public immutable override targetContract;

    /// @dev Constructor
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
    /// @notice Adapter functions are only allowed to be called from within the multicall
    ///         Since at this point Credit Account is owned by the Credit Facade, all functions
    ///         of inheriting adapters that perform actions on account MUST have this modifier
    modifier creditFacadeOnly() {
        if (msg.sender != _creditFacade()) {
            revert CreditFacadeOnlyException(); // F: [AA-4]
        }
        _;
    }

    /// @dev Returns the Credit Facade connected to the Credit Manager
    function _creditFacade() internal view returns (address) {
        return creditManager.creditFacade(); // F: [AA-3]
    }

    /// @dev Returns the Credit Account currently owned by the Credit Facade
    /// @notice Inheriting adapters MUST use this function to find the account address
    function _creditAccount() internal view returns (address) {
        return creditManager.getCreditAccountOrRevert(_creditFacade()); // F: [AA-5,6]
    }

    /// @dev Executes an arbitrary call from the Credit Account to the target contract
    /// @param callData Data to call the target contract with
    /// @return result Call output
    function _execute(bytes memory callData)
        internal
        returns (bytes memory result)
    {
        return creditManager.executeOrder(targetContract, callData); // F: [AA-5,6,10]
    }

    /// @dev Approves a token from the Credit Account to the target contract
    /// @param token Token to be approved
    /// @param amount Amount to be approved
    function _approveToken(address token, uint256 amount) internal {
        creditManager.approveCreditAccount(targetContract, token, amount); // F: [AA-5,6,11]
    }

    /// @dev Executes a swap operation on the target contract from the Credit Account
    ///      without explicit approval to spend `tokenIn`
    /// @param tokenIn The token that the call is expected to spend
    /// @param tokenOut The token that the call is expected to produce
    /// @param callData Data to call the target contract with
    /// @param disableTokenIn Whether the input token should be disabled afterwards
    ///        (for operations that spend the entire balance)
    /// @return result Call output
    function _executeSwapNoApprove(
        address tokenIn,
        address tokenOut,
        bytes memory callData,
        bool disableTokenIn
    ) internal returns (bytes memory result) {
        return
            _executeSwap(
                _creditAccount(),
                tokenIn,
                tokenOut,
                callData,
                false,
                disableTokenIn,
                0
            ); // F: [AA-7]
    }

    /// @dev Same as the previous one, but allows to specify pre-computed credit account to save gas
    /// @notice `creditAccount` passed by inheritors MUST be the result of `_creditAccount()` call
    function _executeSwapNoApprove(
        address creditAccount,
        address tokenIn,
        address tokenOut,
        bytes memory callData,
        bool disableTokenIn
    ) internal returns (bytes memory result) {
        return
            _executeSwap(
                creditAccount,
                tokenIn,
                tokenOut,
                callData,
                false,
                disableTokenIn,
                0
            ); // F: [AA-7]
    }

    /// @dev Executes a swap operation on the target contract from the Credit Account
    ///      with maximal `tokenIn` allowance, and then sets the allowance to max again
    /// @param tokenIn The token that the call is expected to spend
    /// @param tokenOut The token that the call is expected to produce
    /// @param callData Data to call the target contract with
    /// @param disableTokenIn Whether the input token should be disabled afterwards
    ///        (for operations that spend the entire balance)
    /// @return result Call output
    /// @notice Must only be used for highly secure and immutable protocols, such as Uniswap & Curve
    function _executeSwapMaxApprove(
        address tokenIn,
        address tokenOut,
        bytes memory callData,
        bool disableTokenIn
    ) internal returns (bytes memory result) {
        return
            _executeSwap(
                _creditAccount(),
                tokenIn,
                tokenOut,
                callData,
                true,
                disableTokenIn,
                type(uint256).max
            ); // F: [AA-8]
    }

    /// @dev Same as the previous one, but allows to specify pre-computed credit account to save gas
    /// @notice `creditAccount` passed by inheritors MUST be the result of `_creditAccount()` call
    function _executeSwapMaxApprove(
        address creditAccount,
        address tokenIn,
        address tokenOut,
        bytes memory callData,
        bool disableTokenIn
    ) internal returns (bytes memory result) {
        return
            _executeSwap(
                creditAccount,
                tokenIn,
                tokenOut,
                callData,
                true,
                disableTokenIn,
                type(uint256).max
            ); // F: [AA-8]
    }

    /// @dev Executes a swap operation on the target contract from the Credit Account
    ///      with maximal `tokenIn` allowance, and then sets the allowance to 1
    /// @param tokenIn The token that the call is expected to spend
    /// @param tokenOut The token that the call is expected to produce
    /// @param callData Data to call the target contract with
    /// @param disableTokenIn Whether the input token should be disabled afterwards
    ///        (for operations that spend the entire balance)
    /// @return result Call output
    function _executeSwapSafeApprove(
        address tokenIn,
        address tokenOut,
        bytes memory callData,
        bool disableTokenIn
    ) internal returns (bytes memory result) {
        return
            _executeSwap(
                _creditAccount(),
                tokenIn,
                tokenOut,
                callData,
                true,
                disableTokenIn,
                1
            ); // F: [AA-9]
    }

    /// @dev Same as the previous one, but allows to specify pre-computed credit account to save gas
    /// @notice `creditAccount` passed by inheritors MUST be the result of `_creditAccount()` call
    function _executeSwapSafeApprove(
        address creditAccount,
        address tokenIn,
        address tokenOut,
        bytes memory callData,
        bool disableTokenIn
    ) internal returns (bytes memory result) {
        return
            _executeSwap(
                creditAccount,
                tokenIn,
                tokenOut,
                callData,
                true,
                disableTokenIn,
                1
            ); // F: [AA-9]
    }

    /// @dev Implementation of `_executeSwap...` operations
    /// @notice Kept private as only the internal wrappers are intended to be used
    ///         by inheritors
    function _executeSwap(
        address creditAccount,
        address tokenIn,
        address tokenOut,
        bytes memory callData,
        bool allowTokenIn,
        bool disableTokenIn,
        uint256 allowanceAfter
    ) private returns (bytes memory result) {
        if (allowTokenIn) {
            _approveToken(tokenIn, type(uint256).max); // F: [AA-8,9]
        }

        result = _execute(callData); // F: [AA-7,8,9]

        if (allowTokenIn) {
            _approveToken(tokenIn, allowanceAfter); // F: [AA-8,9]
        }

        if (disableTokenIn) {
            creditManager.disableToken(creditAccount, tokenIn); // F: [AA-7,8,9]
        }
        creditManager.checkAndEnableToken(creditAccount, tokenOut); // F: [AA-7,8,9]
    }
}
