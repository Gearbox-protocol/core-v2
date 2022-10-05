// SPDX-License-Identifier: GPL-2.0-or-later
// Gearbox Protocol. Generalized leverage for DeFi protocols
// (c) Gearbox Holdings, 2021
pragma solidity ^0.8.10;

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

    /// @dev RISKY FAST CHECK, IT APPROVES MAX ALLOWANCE FOR EXTERNAL SC
    /// Could be used with proven major contracts like Uniswap or Curve
    function executeMaxAllowanceFastCheck(
        address tokenIn,
        address tokenOut,
        bytes memory callData,
        bool allowTokenIn,
        bool disableTokenIn
    ) external returns (bytes memory result) {
        result = _executeMaxAllowanceFastCheck(
            tokenIn,
            tokenOut,
            callData,
            allowTokenIn,
            disableTokenIn
        );
    }

    /// @dev Keeps maximum allowance for third-party protocol
    /// Should be used for prime protocols proven wit time like Uniswap & Curve
    function executeMaxAllowanceFastCheck(
        address creditAccount,
        address tokenIn,
        address tokenOut,
        bytes memory callData,
        bool allowTokenIn,
        bool disableTokenIn
    ) external returns (bytes memory result) {
        result = _executeMaxAllowanceFastCheck(
            creditAccount,
            tokenIn,
            tokenOut,
            callData,
            allowTokenIn,
            disableTokenIn
        );
    }

    function safeExecuteFastCheck(
        address tokenIn,
        address tokenOut,
        bytes memory callData,
        bool allowTokenIn,
        bool disableTokenIn
    ) external returns (bytes memory result) {
        result = _safeExecuteFastCheck(
            tokenIn,
            tokenOut,
            callData,
            allowTokenIn,
            disableTokenIn
        );
    }

    function safeExecuteFastCheck(
        address creditAccount,
        address tokenIn,
        address tokenOut,
        bytes memory callData,
        bool allowTokenIn,
        bool disableTokenIn
    ) external returns (bytes memory result) {
        result = _safeExecuteFastCheck(
            creditAccount,
            tokenIn,
            tokenOut,
            callData,
            allowTokenIn,
            disableTokenIn
        );
    }

    function execute(bytes memory callData)
        external
        returns (bytes memory result)
    {
        result = _execute(callData);
    }

    function fullCheck(address creditAccount) external {
        _fullCheck(creditAccount);
    }

    fallback() external {
        address creditAccount = creditManager.getCreditAccountOrRevert(
            msg.sender
        );

        _execute(msg.data);
        _fullCheck(creditAccount);
    }
}
