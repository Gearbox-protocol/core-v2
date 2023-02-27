// SPDX-License-Identifier: UNLICENSED
// Gearbox Protocol. Generalized leverage for DeFi protocols
// (c) Gearbox Holdings, 2022
pragma solidity ^0.8.17;

import {AbstractAdapter} from "../../../adapters/AbstractAdapter.sol";
import {AdapterType} from "../../../interfaces/adapters/IAdapter.sol";

/// @title Adapter Mock
contract AdapterMock is AbstractAdapter {
    AdapterType public constant override _gearboxAdapterType = AdapterType.ABSTRACT;
    uint16 public constant override _gearboxAdapterVersion = 1;

    /// @notice Constructor
    /// @param _creditManager Credit manager address
    /// @param _targetContract Target contract address
    constructor(address _creditManager, address _targetContract) AbstractAdapter(_creditManager, _targetContract) {}

    function creditFacade() external view returns (address) {
        return _creditFacade();
    }

    function creditAccount() external view returns (address) {
        return _creditAccount();
    }

    function executeSwapNoApprove(
        address account,
        address tokenIn,
        address tokenOut,
        bytes memory callData,
        bool disableTokenIn
    ) external creditFacadeOnly returns (bytes memory result) {
        return _executeSwapNoApprove(account, tokenIn, tokenOut, callData, disableTokenIn);
    }

    function executeSwapNoApprove(address tokenIn, address tokenOut, bytes memory callData, bool disableTokenIn)
        external
        creditFacadeOnly
        returns (bytes memory result)
    {
        return _executeSwapNoApprove(tokenIn, tokenOut, callData, disableTokenIn);
    }

    function executeSwapMaxApprove(
        address account,
        address tokenIn,
        address tokenOut,
        bytes memory callData,
        bool disableTokenIn
    ) external creditFacadeOnly returns (bytes memory result) {
        return _executeSwapMaxApprove(account, tokenIn, tokenOut, callData, disableTokenIn);
    }

    function executeSwapMaxApprove(address tokenIn, address tokenOut, bytes memory callData, bool disableTokenIn)
        external
        creditFacadeOnly
        returns (bytes memory result)
    {
        return _executeSwapMaxApprove(tokenIn, tokenOut, callData, disableTokenIn);
    }

    function executeSwapSafeApprove(
        address account,
        address tokenIn,
        address tokenOut,
        bytes memory callData,
        bool disableTokenIn
    ) external creditFacadeOnly returns (bytes memory result) {
        return _executeSwapSafeApprove(account, tokenIn, tokenOut, callData, disableTokenIn);
    }

    function executeSwapSafeApprove(address tokenIn, address tokenOut, bytes memory callData, bool disableTokenIn)
        external
        creditFacadeOnly
        returns (bytes memory result)
    {
        return _executeSwapSafeApprove(tokenIn, tokenOut, callData, disableTokenIn);
    }

    function execute(bytes memory callData) external creditFacadeOnly returns (bytes memory result) {
        result = _execute(callData);
    }

    function approveToken(address token, uint256 amount) external creditFacadeOnly {
        _approveToken(token, amount);
    }

    fallback() external creditFacadeOnly {
        _execute(msg.data);
    }
}
