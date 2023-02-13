// SPDX-License-Identifier: BUSL-1.1
// Gearbox. Generalized leverage protocol that allows to take leverage and then use it across other DeFi protocols and platforms in a composable way.
// (c) Gearbox Holdings, 2022
pragma solidity ^0.8.10;

import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { SafeERC20 } from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

import { ACLNonReentrantTrait } from "../core/ACLNonReentrantTrait.sol";
import { IBlacklistHelper } from "../interfaces/IBlacklistHelper.sol";
import { ICreditFacade } from "../interfaces/ICreditFacade.sol";

interface IBlacklistableUSDC {
    function isBlacklisted(address _account) external view returns (bool);
}

interface IBlacklistableUSDT {
    function isBlackListed(address _account) external view returns (bool);
}

/// @title Blacklist Helper
/// @dev A contract used to enable successful liquidations when the borrower is blacklisted
///      while simultaneously allowing them to recover their funds under a different address
contract BlacklistHelper is ACLNonReentrantTrait, IBlacklistHelper {
    using SafeERC20 for IERC20;

    /// @dev Address of USDC
    address public immutable usdc;

    /// @dev Address of USDT
    address public immutable usdt;

    /// @dev mapping from address to supported Credit Facade status
    mapping(address => bool) public isSupportedCreditFacade;

    /// @dev mapping from (underlying, account) to amount available to claim
    mapping(address => mapping(address => uint256)) public claimable;

    /// @dev Restricts calls to Credit Facades only
    modifier creditFacadeOnly() {
        if (!isSupportedCreditFacade[msg.sender]) {
            revert CreditFacadeOnlyException();
        }
        _;
    }

    /// @param _addressProvider Address of the address provider
    /// @param _usdc Address of USDC
    /// @param _usdt Address of USDT
    constructor(
        address _addressProvider,
        address _usdc,
        address _usdt
    ) ACLNonReentrantTrait(_addressProvider) {
        usdc = _usdc;
        usdt = _usdt;
    }

    /// @dev Returns whether the account is blacklisted for a particular underlying token
    /// @param underlying Underlying token to check
    /// @param _account Account to check
    /// @notice Used to consolidate different `isBlacklisted` functions under the same interface
    function isBlacklisted(address underlying, address _account)
        external
        view
        returns (bool)
    {
        if (underlying == usdc) {
            return IBlacklistableUSDC(usdc).isBlacklisted(_account);
        } else if (underlying == usdt) {
            return IBlacklistableUSDT(usdt).isBlackListed(_account);
        } else {
            return false;
        }
    }

    /// @dev Increases the underlying balance available to claim by the account
    /// @param underlying Underlying to increase balance for
    /// @param holder Account to increase balance for
    /// @param amount Incremented amount
    /// @notice Can only be called by Credit Facades when liquidating a blacklisted borrower
    ///         Expects the underlying to be transferred directly to this contract in the same transaction
    function addClaimable(
        address underlying,
        address holder,
        uint256 amount
    ) external creditFacadeOnly {
        claimable[underlying][holder] += amount;
    }

    /// @dev Transfer the sender's current claimable balance in underlying to a specified address
    /// @param underlying Underlying to transfer
    /// @param to Recipient address
    function claim(address underlying, address to) external {
        uint256 amount = claimable[underlying][msg.sender];

        if (amount < 2) {
            revert NothingToClaimException();
        }

        claimable[underlying][msg.sender] = 0;

        IERC20(underlying).safeTransfer(to, amount);
    }

    /// @dev Adds a new Credit Facade to `supported` list
    /// @param _creditFacade Address of the Credit Facade
    function addCreditFacade(address _creditFacade) external configuratorOnly {
        if (!ICreditFacade(_creditFacade).isBlacklistableUnderlying()) {
            revert CreditFacadeNonBlacklistable();
        }

        isSupportedCreditFacade[_creditFacade] = true;
    }

    /// @dev Removes a Credit Facade from the `supported` list
    /// @param _creditFacade Address of the Credit Facade
    function removeCreditFacade(address _creditFacade)
        external
        configuratorOnly
    {
        isSupportedCreditFacade[_creditFacade] = false;
    }
}
