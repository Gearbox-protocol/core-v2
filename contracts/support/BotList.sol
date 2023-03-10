// SPDX-License-Identifier: BUSL-1.1
// Gearbox. Generalized leverage protocol that allows to take leverage and then use it across other DeFi protocols and platforms in a composable way.
// (c) Gearbox Holdings, 2022
pragma solidity ^0.8.10;

import {Address} from "@openzeppelin/contracts/utils/Address.sol";
import {SafeCast} from "@openzeppelin/contracts/utils/math/SafeCast.sol";

import {ACLNonReentrantTrait} from "../core/ACLNonReentrantTrait.sol";
import {IBotList, BotFunding} from "../interfaces/IBotList.sol";
import {IAddressProvider} from "@gearbox-protocol/core-v2/contracts/interfaces/IAddressProvider.sol";

import {ZeroAddressException, AddressIsNotContractException} from "../interfaces/IErrors.sol";
import {PERCENTAGE_FACTOR} from "@gearbox-protocol/core-v2/contracts/libraries/PercentageMath.sol";

uint256 constant SECONDS_PER_WEEK = 3600 * 24 * 7;

/// @title BotList
/// @dev Used to store a mapping of borrowers => bots. A separate contract is used for transferability when
///      changing Credit Facades
contract BotList is ACLNonReentrantTrait, IBotList {
    using SafeCast for uint256;
    using Address for address;
    using Address for address payable;

    /// @dev Mapping from (borrower, bot) to bot approval status
    mapping(address => mapping(address => bool)) public approvedBot;

    /// @dev Whether the bot is forbidden system-wide
    mapping(address => bool) public forbiddenBot;

    /// @dev Mapping of (borrower, bot) to bot funding parameters
    mapping(address => mapping(address => BotFunding)) public botFunding;

    /// @dev A fee (in PERCENTAGE_FACTOR format) charged by the DAO on bot payments
    uint16 public daoFee = 0;

    /// @dev Address of the DAO treasury
    address public immutable treasury;

    constructor(address _addressProvider) ACLNonReentrantTrait(_addressProvider) {
        treasury = IAddressProvider(_addressProvider).getTreasuryContract();
    }

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

        if (forbiddenBot[bot] && status) {
            revert InvalidBotException();
        }

        approvedBot[msg.sender][bot] = status;

        emit BotApprovalChanged(msg.sender, bot, status);
    }

    /// @dev Adds funds to user's balance for a particular bot. The entire sent value in ETH is added
    /// @param bot Address of the bot to fund
    function increaseBotFunding(address bot) external payable nonReentrant {
        if (msg.value == 0) {
            revert AmountCantBeZeroException();
        }

        if (forbiddenBot[bot] || !approvedBot[msg.sender][bot]) {
            revert InvalidBotException();
        }

        uint72 newRemainingFunds = botFunding[msg.sender][bot].remainingFunds + msg.value.toUint72();

        botFunding[msg.sender][bot].remainingFunds = newRemainingFunds;

        emit BotFundingChanged(msg.sender, bot, newRemainingFunds);
    }

    /// @dev Removes funds from the user's balance for a particular bot. The funds are sent to the user.
    /// @param bot Address of the bot to remove funds from
    /// @param decreaseAmount Amount to remove
    function decreaseBotFunding(address bot, uint72 decreaseAmount) external nonReentrant {
        if (decreaseAmount == 0) {
            revert AmountCantBeZeroException();
        }

        uint72 newRemainingFunds = botFunding[msg.sender][bot].remainingFunds - decreaseAmount;

        botFunding[msg.sender][bot].remainingFunds = newRemainingFunds;
        payable(msg.sender).sendValue(decreaseAmount);

        emit BotFundingChanged(msg.sender, bot, newRemainingFunds);
    }

    /// @dev Sets the amount that can be pull by the bot per week
    /// @param bot Address of the bot to set allowance for
    /// @param allowanceAmount Amount of weekly allowance
    function setWeeklyBotAllowance(address bot, uint72 allowanceAmount) external nonReentrant {
        BotFunding memory bf = botFunding[msg.sender][bot];

        bf.maxWeeklyAllowance = allowanceAmount;
        bf.remainingWeeklyAllowance =
            bf.remainingWeeklyAllowance > allowanceAmount ? allowanceAmount : bf.remainingWeeklyAllowance;

        botFunding[msg.sender][bot] = bf;

        emit BotWeeklyAllowanceChanged(msg.sender, bot, allowanceAmount);
    }

    /// @dev Takes payment from the user to the bot for performed services
    /// @param payer Address of the paying user
    /// @param paymentAmount Amount to pull
    function pullPayment(address payer, uint72 paymentAmount) external nonReentrant {
        if (paymentAmount == 0) {
            revert AmountCantBeZeroException();
        }

        BotFunding memory bf = botFunding[payer][msg.sender];

        if (block.timestamp >= bf.allowanceLU + SECONDS_PER_WEEK) {
            bf.allowanceLU = uint40(block.timestamp);
            bf.remainingWeeklyAllowance = bf.maxWeeklyAllowance;
        }

        uint72 feeAmount = daoFee * paymentAmount / PERCENTAGE_FACTOR;

        bf.remainingWeeklyAllowance -= paymentAmount + feeAmount;
        bf.remainingFunds -= paymentAmount + feeAmount;

        botFunding[payer][msg.sender] = bf;

        payable(msg.sender).sendValue(paymentAmount);
        if (feeAmount > 0) payable(treasury).sendValue(feeAmount);

        emit BotPaymentPulled(payer, msg.sender, paymentAmount, feeAmount);
    }

    //
    // CONFIGURATION
    //

    /// @dev Forbids the bot system-wide if it is known to be compromised
    function setBotForbiddenStatus(address bot, bool status) external configuratorOnly {
        forbiddenBot[bot] = status;
        emit BotForbiddenStatusChanged(bot, status);
    }

    /// @dev Sets the DAO fee on bot payments
    /// @param newFee The new fee value
    function setDAOFee(uint16 newFee) external configuratorOnly {
        daoFee = newFee;

        emit NewBotDAOFee(newFee);
    }
}
