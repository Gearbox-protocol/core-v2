// SPDX-License-Identifier: MIT
// Gearbox Protocol. Generalized leverage for DeFi protocols
// (c) Gearbox Holdings, 2022
pragma solidity ^0.8.10;

/// @title IBotList
interface IBotList {
    /// @dev Emits when a borrower enables or disables a bot for their account
    event BotApprovalChanged(
        address indexed borrower,
        address indexed bot,
        bool status
    );

    /// @dev Emits when a bot is forbidden system-wide
    event BotForbiddenStatusChanged(address indexed bot, bool status);

    /// @dev Sets approval from msg.sender to bot
    function setBotStatus(address bot, bool status) external;

    /// @dev Returns whether the bot is approved by the borrower
    function approvedBot(address borrower, address bot)
        external
        view
        returns (bool);

    /// @dev Returns whether the bot is forbidden by the borrower
    function forbiddenBot(address bot) external view returns (bool);
}
