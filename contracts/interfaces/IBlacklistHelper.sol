// SPDX-License-Identifier: MIT
// Gearbox Protocol. Generalized leverage for DeFi protocols
// (c) Gearbox Holdings, 2022
pragma solidity ^0.8.10;

interface IBlacklistHelperEvents {
    /// @dev Emitted when a borrower's claimable balance is increased
    event ClaimableAdded(address underlying, address holder, uint256 amount);

    /// @dev Emitted when a Credit Facade is added to BlacklistHelper
    event CreditFacadeAdded(address creditFacade);

    /// @dev Emitted when a Credit Facade is removed from BlacklistHelper
    event CreditFacadeRemoved(address creditFacade);
}

interface IBlacklistHelperExceptions {
    /// @dev Thrown when an access-restricted function is called by non-CreditFacade
    error CreditFacadeOnlyException();

    /// @dev Thrown when attempting to add a Credit Facade that has non-blacklistable underlying
    error CreditFacadeNonBlacklistable();

    /// @dev Thrown when attempting to claim funds without having anything claimable
    error NothingToClaimException();
}

interface IBlacklistHelper is
    IBlacklistHelperEvents,
    IBlacklistHelperExceptions
{
    /// @dev Returns whether the account is blacklisted for a particular underlying
    function isBlacklisted(address underlying, address account)
        external
        view
        returns (bool);

    /// @dev Transfer the claimable balance of underlying for a sender to a specified address
    function claim(address underlying, address to) external;

    /// @dev Increases the claimable balance for an account
    /// @notice Assumes that the sender transfers the tokens in the same transaction, so doesn't
    ///         perform an explicit transferFrom()
    function addClaimable(
        address underlying,
        address holder,
        uint256 amount
    ) external;

    /// @dev Returns the amount claimable by an account
    /// @param underlying Underlying the get the amount for
    /// @param holder Acccount to to get the amount for
    function claimable(address underlying, address holder)
        external
        view
        returns (uint256);
}
