// SPDX-License-Identifier: UNLICENSED
// Gearbox Protocol. Generalized leverage for DeFi protocols
// (c) Gearbox Holdings, 2022
pragma solidity ^0.8.17;

import { AbstractAdapter } from "../../../adapters/AbstractAdapter.sol";
import { AdapterType } from "../../../interfaces/adapters/IAdapter.sol";

/// @title Adapter Mock
contract AdapterMock is AbstractAdapter {
    /// @dev Constructor
    /// @param _creditManager Address Credit manager

    constructor(address _creditManager, address _targetContract)
        AbstractAdapter(_creditManager, _targetContract)
    {}

    AdapterType public constant _gearboxAdapterType = AdapterType.ABSTRACT;
    uint16 public constant _gearboxAdapterVersion = 1;

    function executeSwapNoApprove(
        address creditAccount,
        address tokenIn,
        address tokenOut,
        bytes memory callData,
        bool disableTokenIn
    ) external returns (bytes memory result) {
        return
            _executeSwapNoApprove(
                creditAccount,
                tokenIn,
                tokenOut,
                callData,
                disableTokenIn
            );
    }

    function executeSwapNoApprove(
        address tokenIn,
        address tokenOut,
        bytes memory callData,
        bool disableTokenIn
    ) external returns (bytes memory result) {
        return
            _executeSwapNoApprove(tokenIn, tokenOut, callData, disableTokenIn);
    }

    function executeSwapMaxApprove(
        address creditAccount,
        address tokenIn,
        address tokenOut,
        bytes memory callData,
        bool disableTokenIn
    ) external returns (bytes memory result) {
        return
            _executeSwapMaxApprove(
                creditAccount,
                tokenIn,
                tokenOut,
                callData,
                disableTokenIn
            );
    }

    function executeSwapMaxApprove(
        address tokenIn,
        address tokenOut,
        bytes memory callData,
        bool disableTokenIn
    ) external returns (bytes memory result) {
        return
            _executeSwapMaxApprove(tokenIn, tokenOut, callData, disableTokenIn);
    }

    function executeSwapSafeApprove(
        address creditAccount,
        address tokenIn,
        address tokenOut,
        bytes memory callData,
        bool disableTokenIn
    ) external returns (bytes memory result) {
        return
            _executeSwapSafeApprove(
                creditAccount,
                tokenIn,
                tokenOut,
                callData,
                disableTokenIn
            );
    }

    function executeSwapSafeApprove(
        address tokenIn,
        address tokenOut,
        bytes memory callData,
        bool disableTokenIn
    ) external returns (bytes memory result) {
        return
            _executeSwapSafeApprove(
                tokenIn,
                tokenOut,
                callData,
                disableTokenIn
            );
    }

    function execute(bytes memory callData)
        external
        returns (bytes memory result)
    {
        result = _execute(callData);
    }

    function approveToken(address token, uint256 amount) external {
        _approveToken(token, amount);
    }

    fallback() external {
        _execute(msg.data);
    }
}
