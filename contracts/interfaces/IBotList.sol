// SPDX-License-Identifier: MIT
// Gearbox Protocol. Generalized leverage for DeFi protocols
// (c) Gearbox Holdings, 2022
pragma solidity ^0.8.10;

struct BotFunding {
    uint72 remainingFunds;
    uint72 maxWeeklyAllowance;
    uint72 remainingWeeklyAllowance;
    uint40 allowanceLU;
}

interface IBotListExceptions {
    /// @dev Thrown when attempting to pass a zero amount to a funding-related operation
    error AmountCantBeZeroException();

    /// @dev Thrown when attempting to fund a bot that is forbidden or not directly allowed by the user
    error InvalidBotException();
}

interface IBotListEvents {
    /// @dev Emits when a borrower enables or disables a bot for their account
    event BotApprovalChanged(address indexed borrower, address indexed bot, bool status);

    /// @dev Emits when a bot is forbidden system-wide
    event BotForbiddenStatusChanged(address indexed bot, bool status);

    /// @dev Emits when the amount of remaining funds for a bot is changed by the user
    event BotFundingChanged(address indexed payer, address indexed bot, uint72 newRemainingFunds);

    /// @dev Emits when the allowed weekly amount of bot's spending is changed by the user
    event BotWeeklyAllowanceChanged(address indexed payer, address indexed bot, uint72 newWeeklyAllowance);

    /// @dev Emits when the bot pull payment for performed services
    event BotPaymentPulled(address indexed payer, address indexed bot, uint72 paymentAmount, uint72 daoFeeAmount);

    /// @dev Emits when the DAO sets a new fee on bot payments
    event NewBotDAOFee(uint16 newFee);
}

/// @title IBotList
interface IBotList is IBotListEvents, IBotListExceptions {
    /// @dev Sets approval from msg.sender to bot
    function setBotStatus(address bot, bool status) external;

    /// @dev Returns whether the bot is approved by the borrower
    function approvedBot(address borrower, address bot) external view returns (bool);

    /// @dev Returns whether the bot is forbidden by the borrower
    function forbiddenBot(address bot) external view returns (bool);

    /// @dev Adds funds to user's balance for a particular bot. The entire sent value in ETH is added
    /// @param bot Address of the bot to fund
    function increaseBotFunding(address bot) external payable;

    /// @dev Removes funds from the user's balance for a particular bot. The funds are sent to the user.
    /// @param bot Address of the bot to remove funds from
    /// @param decreaseAmount Amount to remove
    function decreaseBotFunding(address bot, uint72 decreaseAmount) external;

    /// @dev Sets the amount that can be pull by the bot per week
    /// @param bot Address of the bot to set allowance for
    /// @param allowanceAmount Amount of weekly allowance
    function setWeeklyBotAllowance(address bot, uint72 allowanceAmount) external;

    /// @dev Takes payment from the user to the bot for performed services
    /// @param payer Address of the paying user
    /// @param paymentAmount Amount to pull
    function pullPayment(address payer, uint72 paymentAmount) external;
}
