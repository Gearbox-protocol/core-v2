// SPDX-License-Identifier: GPL-2.0-or-later
// Gearbox Protocol. Generalized leverage for DeFi protocols
// (c) Gearbox Holdings, 2022
pragma solidity ^0.8.10;

import { Address } from "@openzeppelin/contracts/utils/Address.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { ICreditManagerV2 } from "../interfaces/ICreditManagerV2.sol";
import { IAdapter } from "../interfaces/adapters/IAdapter.sol";
import { ZeroAddressException } from "../interfaces/IErrors.sol";

abstract contract AbstractAdapter is IAdapter {
    error CreditFacadeOnlyException();

    using Address for address;

    ICreditManagerV2 public immutable override creditManager;
    address public immutable override targetContract;

    constructor(address _creditManager, address _targetContract) {
        if (_creditManager == address(0) || _targetContract == address(0)) {
            revert ZeroAddressException();
        } // F:[AA-2]

        creditManager = ICreditManagerV2(_creditManager); // F:[AA-1]
        targetContract = _targetContract; // F:[AA-1]
    }

    modifier creditFacadeOnly() {
        if (msg.sender != _creditFacade()) {
            revert CreditFacadeOnlyException();
        }

        _;
    }

    function _creditFacade() internal view returns (address) {
        return creditManager.creditFacade();
    }

    function _creditAccount() internal view returns (address) {
        return creditManager.getCreditAccountOrRevert(_creditFacade());
    }

    /// @dev Approves a token from the Credit Account to the target contract
    /// @param token Token to be approved
    /// @param amount Amount to be approved
    function _approveToken(address token, uint256 amount) internal {
        creditManager.approveCreditAccount(targetContract, token, amount);
    }

    function _execute(bytes memory callData)
        internal
        returns (bytes memory result)
    {
        return creditManager.executeOrder(targetContract, callData);
    }

    /// @dev Calls a target contract with maximal allowance and performs a fast check after
    /// @param creditAccount A credit account from which a call is made
    /// @param tokenIn The token that the interaction is expected to spend
    /// @param tokenOut The token that the interaction is expected to produce
    /// @param callData Data to call targetContract with
    /// @param allowTokenIn Whether the input token must be approved beforehand
    /// @param disableTokenIn Whether the input token should be disable afterwards (for interaction that spend the entire balance)
    /// @notice Must only be used for highly secure and immutable protocols, such as Uniswap & Curve
    function _executeMaxAllowance(
        address creditAccount,
        address tokenIn,
        address tokenOut,
        bytes memory callData,
        bool allowTokenIn,
        bool disableTokenIn
    ) internal returns (bytes memory result) {
        return
            _executeSwap(
                creditAccount,
                tokenIn,
                tokenOut,
                callData,
                allowTokenIn,
                disableTokenIn,
                type(uint256).max
            );
    }

    /// @dev Wrapper for _executeMaxAllowance that computes the Credit Account on the spot
    /// See params and other details above
    function _executeMaxAllowance(
        address tokenIn,
        address tokenOut,
        bytes memory callData,
        bool allowTokenIn,
        bool disableTokenIn
    ) internal creditFacadeOnly returns (bytes memory result) {
        return
            _executeSwap(
                _creditAccount(),
                tokenIn,
                tokenOut,
                callData,
                allowTokenIn,
                disableTokenIn,
                type(uint256).max
            );
    }

    /// @dev Calls a target contract with maximal allowance, then sets allowance to 1 and performs a fast check
    /// @param creditAccount A credit account from which a call is made
    /// @param tokenIn The token that the interaction is expected to spend
    /// @param tokenOut The token that the interaction is expected to produce
    /// @param callData Data to call targetContract with
    /// @param allowTokenIn Whether the input token must be approved beforehand
    /// @param disableTokenIn Whether the input token should be disable afterwards (for interaction that spend the entire balance)
    function _safeExecute(
        address creditAccount,
        address tokenIn,
        address tokenOut,
        bytes memory callData,
        bool allowTokenIn,
        bool disableTokenIn
    ) internal returns (bytes memory result) {
        return
            _executeSwap(
                creditAccount,
                tokenIn,
                tokenOut,
                callData,
                allowTokenIn,
                disableTokenIn,
                1
            );
    }

    /// @dev Wrapper for _safeExecute that computes the Credit Account on the spot
    /// See params and other details above
    function _safeExecute(
        address tokenIn,
        address tokenOut,
        bytes memory callData,
        bool allowTokenIn,
        bool disableTokenIn
    ) internal returns (bytes memory result) {
        return
            _executeSwap(
                _creditAccount(),
                tokenIn,
                tokenOut,
                callData,
                allowTokenIn,
                disableTokenIn,
                1
            );
    }

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
            _approveToken(tokenIn, type(uint256).max);
        }

        result = _execute(callData);

        if (allowTokenIn) {
            _approveToken(tokenIn, allowanceAfter);
        }

        if (disableTokenIn) {
            creditManager.disableToken(creditAccount, tokenIn);
        }
        creditManager.checkAndEnableToken(creditAccount, tokenOut);
    }
}
