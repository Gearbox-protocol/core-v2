// SPDX-License-Identifier: BUSL-1.1
// Gearbox Protocol. Generalized leverage for DeFi protocols
// (c) Gearbox Holdings, 2022
pragma solidity ^0.8.10;

import { Pool4626 } from "./Pool4626.sol";
import { USDT_Transfer } from "../libraries/USDT_Transfer.sol";
import { IPool4626, Pool4626Opts } from "../interfaces/IPool4626.sol";

/// @title Core pool contract compatible with ERC4626
/// @notice Implements pool & dieselUSDT_Transferogic

contract Pool4626_USDT is Pool4626, USDT_Transfer {
    constructor(Pool4626Opts memory opts)
        Pool4626(opts)
        USDT_Transfer(opts.underlyingToken)
    {
        // Additional check that receiver is not address(0)
    }

    function _safeUnderlyingTransfer(address to, uint256 amount)
        internal
        override
        returns (uint256)
    {
        return _safeUSDTTransfer(to, amount);
    }

    function _amountWithFee(uint256 amount)
        internal
        view
        override
        returns (uint256)
    {
        return _amountUSDTWithFee(amount);
    }
}
