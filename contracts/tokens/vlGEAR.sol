// SPDX-License-Identifier: BUSL-1.1
// Gearbox Protocol. Generalized leverage for DeFi protocols
// (c) Gearbox Holdings, 2022
pragma solidity ^0.8.17;

import {SafeCast} from "@openzeppelin/contracts/utils/math/SafeCast.sol";

import {IGearToken} from "../interfaces/IGearToken.sol";
import {IAddressProvider} from "../interfaces/IAddressProvider.sol";
import {IVotingContract} from "../interfaces/IVotingContract.sol";
import {IvlGEAR, UserVoteLockData, WithdrawalData, MultiVote} from "../interfaces/IvlGEAR.sol";

import {ACLNonReentrantTrait} from "../core/ACLNonReentrantTrait.sol";

uint256 constant EPOCH_LENGTH = 7 days;

contract vlGEAR is ACLNonReentrantTrait, IvlGEAR {
    using SafeCast for uint256;

    /// @dev Address of the GEAR token
    IGearToken public immutable gear;

    /// @dev Mapping of user address to their total staked tokens and tokens available for voting
    mapping(address => UserVoteLockData) internal voteLockData;

    /// @dev Mapping of user address to their future withdrawal amounts
    mapping(address => WithdrawalData) internal withdrawalData;

    /// @dev Mapping of address to their status as allowed voting contract
    mapping(address => bool) public allowedVotingContract;

    /// @dev Timestamp of the first epoch of voting
    uint256 immutable firstEpochTimestamp;

    constructor(address _addressProvider, uint256 _firstEpochTimestamp) ACLNonReentrantTrait(_addressProvider) {
        gear = IGearToken(IAddressProvider(_addressProvider).getGearToken());
        firstEpochTimestamp = _firstEpochTimestamp;
    }

    /// @dev Returns the current global voting epoch
    function getCurrentEpoch() public view returns (uint16) {
        if (block.timestamp < firstEpochTimestamp) return 0;
        return uint16((block.timestamp - firstEpochTimestamp) / EPOCH_LENGTH) + 1;
    }

    /// @dev Returns the total amount of GEAR the user staked into vlGEAR
    function balanceOf(address user) external view returns (uint256) {
        return uint256(voteLockData[user].totalStaked);
    }

    /// @dev Returns the balance available for voting or withdrawal
    function availableBalance(address user) external view returns (uint256) {
        return uint256(voteLockData[user].available);
    }

    /// @dev Deposits an amount of GEAR into vlGEAR. Optionally, performs a sequence of vote changes according to
    ///      the passed `votes` array
    /// @param amount Amount of GEAR to deposit into vlGEAR
    /// @param votes Array of MultVote structs:
    ///              * votingContract - contract to submit a vote to
    ///              * voteAmount - amount of vlGEAR to add to or remove from a vote
    ///              * isIncrease - whether to add or remove votes
    ///              * extraData - data specific to the voting contract that is decoded on recipient side
    function deposit(uint256 amount, MultiVote[] memory votes) external nonReentrant {
        gear.transferFrom(msg.sender, address(this), amount);

        {
            uint96 amount96 = amount.toUint96();

            UserVoteLockData memory vld = voteLockData[msg.sender];

            vld.totalStaked += amount96;
            vld.available += amount96;

            voteLockData[msg.sender] = vld;
        }

        emit GearDeposited(msg.sender, amount);

        if (votes.length > 0) {
            _multivote(msg.sender, votes);
        }
    }

    /// @dev Performs a sequence of vote changes according to the passed array
    /// @param votes Array of MultVote structs:
    ///              * votingContract - contract to submit a vote to
    ///              * voteAmount - amount of vlGEAR to add to or remove from a vote
    ///              * isIncrease - whether to add or remove votes
    ///              * extraData - data specific to the voting contract that is decoded on recipient side
    function multivote(MultiVote[] memory votes) external nonReentrant {
        _multivote(msg.sender, votes);
    }

    /// @dev Schedules a withdrawal from vlGEAR into GEAR, which can be claimed in 4 epochs.
    ///      If there are any withdrawals available to claim, they are also claimed.
    ///      Optionally, performs a sequence of vote changes according to
    ///      the passed `votes` array.
    /// @param amount Amount of vlGEAR to withdraw into GEAR
    /// @param votes Array of MultVote structs:
    ///              * votingContract - contract to submit a vote to
    ///              * voteAmount - amount of vlGEAR to add to or remove from a vote
    ///              * isIncrease - whether to add or remove votes
    ///              * extraData - data specific to the voting contract that is decoded on recipient side
    function withdraw(uint256 amount, MultiVote[] memory votes) external nonReentrant {
        if (votes.length > 0) {
            _multivote(msg.sender, votes);
        }

        _processPendingWithdrawals(msg.sender);

        uint96 amount96 = amount.toUint96();
        voteLockData[msg.sender].available -= amount96;
        withdrawalData[msg.sender].withdrawalsEpochFour += amount96;

        emit GearWithdrawalScheduled(msg.sender, amount);
    }

    /// @dev Claims all of the caller's withdrawals that are mature
    function claimWithdrawals() external nonReentrant {
        _processPendingWithdrawals(msg.sender);
    }

    /// @dev Refreshes the user's withdrawal struct, shifting the withdrawal amounts based
    ///      on the number of epochs that passed since the last update. If there are any mature withdrawals,
    ///      sends the corresponding amounts to the user
    function _processPendingWithdrawals(address user) internal {
        uint16 epochNow = getCurrentEpoch();

        WithdrawalData memory wd = withdrawalData[user];

        if (epochNow > wd.epochLU) {
            if (
                wd.withdrawalsEpochOne + wd.withdrawalsEpochTwo + wd.withdrawalsEpochThree + wd.withdrawalsEpochFour > 0
            ) {
                uint16 epochDiff = epochNow - wd.epochLU;
                uint256 totalClaimable = 0;

                // Epochs one, two, three and four in the struct are always relative
                // to epochLU, so the amounts are "shifted" by the number of epochs that passed
                // since epochLU, on each update. If some amounts shifts beyond epoch one, it is mature,
                // so GEAR is sent to the user.

                if (epochDiff == 1) {
                    totalClaimable = wd.withdrawalsEpochOne;
                    wd.withdrawalsEpochOne = wd.withdrawalsEpochTwo;
                    wd.withdrawalsEpochTwo = wd.withdrawalsEpochThree;
                    wd.withdrawalsEpochThree = wd.withdrawalsEpochFour;
                    wd.withdrawalsEpochFour = 0;
                } else if (epochDiff == 2) {
                    totalClaimable = wd.withdrawalsEpochOne + wd.withdrawalsEpochTwo;
                    wd.withdrawalsEpochOne = wd.withdrawalsEpochThree;
                    wd.withdrawalsEpochTwo = wd.withdrawalsEpochFour;
                    wd.withdrawalsEpochThree = 0;
                    wd.withdrawalsEpochFour = 0;
                } else if (epochDiff == 3) {
                    totalClaimable = wd.withdrawalsEpochOne + wd.withdrawalsEpochTwo + wd.withdrawalsEpochThree;
                    wd.withdrawalsEpochOne = wd.withdrawalsEpochFour;
                    wd.withdrawalsEpochTwo = 0;
                    wd.withdrawalsEpochThree = 0;
                    wd.withdrawalsEpochFour = 0;
                } else if (epochDiff > 3) {
                    totalClaimable = wd.withdrawalsEpochOne + wd.withdrawalsEpochTwo + wd.withdrawalsEpochThree
                        + wd.withdrawalsEpochFour;
                    wd.withdrawalsEpochOne = 0;
                    wd.withdrawalsEpochTwo = 0;
                    wd.withdrawalsEpochThree = 0;
                    wd.withdrawalsEpochFour = 0;
                }

                if (totalClaimable > 0) {
                    gear.transfer(user, totalClaimable);
                    emit GearWithdrawalClaimed(user, totalClaimable);
                }

                voteLockData[user].totalStaked -= totalClaimable.toUint96();
            }

            wd.epochLU = epochNow;
            withdrawalData[user] = wd;
        }
    }

    /// @dev Performs a sequence of vote changes based on the passed array
    function _multivote(address user, MultiVote[] memory votes) internal {
        uint256 len = votes.length;

        UserVoteLockData memory vld = voteLockData[user];

        for (uint256 i = 0; i < len;) {
            MultiVote memory currentVote = votes[i];

            if (!allowedVotingContract[currentVote.votingContract]) {
                revert VotingContractNotAllowedException();
            }

            if (currentVote.isIncrease) {
                IVotingContract(currentVote.votingContract).vote(user, currentVote.voteAmount, currentVote.extraData);
                vld.available -= currentVote.voteAmount;
            } else {
                IVotingContract(currentVote.votingContract).unvote(user, currentVote.voteAmount, currentVote.extraData);
                vld.available += currentVote.voteAmount;
            }

            unchecked {
                ++i;
            }
        }

        voteLockData[user] = vld;
    }

    //
    // CONFIGURATION
    //

    /// @dev Sets the status of contract as an allowed voting contract
    /// @param votingContract Address to set the status for
    /// @param status The new status of the contract
    function setVotingContractStatus(address votingContract, bool status) external configuratorOnly {
        allowedVotingContract[votingContract] = status;
    }
}
