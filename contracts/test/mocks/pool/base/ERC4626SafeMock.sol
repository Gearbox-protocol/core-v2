// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity >=0.8.0;

import { ERC20 } from "@solmate/tokens/ERC20.sol";
import { ERC4626Safe } from "../../../../pool/ERC4626/base/ERC4626Safe.sol";

abstract contract ERC4626SafeMock is ERC4626Safe {
    uint256 public beforeWithdrawHookCalledCounter = 0;
    uint256 public afterDepositHookCalledCounter = 0;

    constructor(
        ERC20 _underlying,
        string memory _name,
        string memory _symbol
    ) ERC4626Safe(_underlying, _name, _symbol) {
        // burn the shares minted in ERC4626Safe constructor to correctly account for a16z tests
        _burn(address(0), 100000);
    }
}
