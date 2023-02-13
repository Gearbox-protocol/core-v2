// SPDX-License-Identifier: BUSL-1.1
// Gearbox. Generalized leverage protocol that allows to take leverage and then use it across other DeFi protocols and platforms in a composable way.
// (c) Gearbox Holdings, 2022
pragma solidity ^0.8.10;

import { Address } from "@openzeppelin/contracts/utils/Address.sol";

import { ACLNonReentrantTrait } from "../core/ACLNonReentrantTrait.sol";
import { IBotList } from "../interfaces/IBotList.sol";

import { ZeroAddressException, AddressIsNotContractException } from "../interfaces/IErrors.sol";

/// @title BotList
/// @dev Used to store a mapping of borrowers => bots. A separate contract is used for transferability when
///      changing Credit Facades
contract BotList is ACLNonReentrantTrait, IBotList {
    using Address for address;

    /// @dev Mapping from (borrower, bot) to bot approval status
    mapping(address => mapping(address => bool)) public approvedBot;

    /// @dev Whether the bot is forbidden system-wide
    mapping(address => bool) public forbiddenBot;

    constructor(address _addressProvider)
        ACLNonReentrantTrait(_addressProvider)
    {}

    /// @dev Adds or removes allowance for a bot to execute multicalls on behalf of sender
    /// @param bot Bot address
    /// @param status Whether allowance is added or removed
    function setBotStatus(address bot, bool status) external {
        if (bot == address(0)) {
            revert ZeroAddressException();
        }

        if (!bot.isContract() && status) {
            revert AddressIsNotContractException(bot);
        }

        approvedBot[msg.sender][bot] = status;

        emit BotApprovalChanged(msg.sender, bot, status);
    }

    /// @dev Forbids the bot system-wide if it is known to be compromised
    function setBotForbiddenStatus(address bot, bool status)
        external
        configuratorOnly
    {
        forbiddenBot[bot] = status;
        emit BotForbiddenStatusChanged(bot, status);
    }
}
