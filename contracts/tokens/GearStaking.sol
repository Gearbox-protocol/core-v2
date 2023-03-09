// SPDX-License-Identifier: BUSL-1.1
// Gearbox Protocol. Generalized leverage for DeFi protocols
// (c) Gearbox Holdings, 2022
pragma solidity ^0.8.17;

import {SafeCast} from "@openzeppelin/contracts/utils/math/SafeCast.sol";

import {IGearToken} from "../interfaces/IGearToken.sol";
import {IAddressProvider} from "../interfaces/IAddressProvider.sol";
import {IVotingContract} from "../interfaces/IVotingContract.sol";
import {
    IGearStaking,
    UserVoteLockData,
    WithdrawalData,
    MultiVote,
    VotingContractStatus
} from "../interfaces/IGearStaking.sol";

import {ACLNonReentrantTrait} from "../core/ACLNonReentrantTrait.sol";

uint256 constant EPOCH_LENGTH = 7 days;

contract GearStaking is ACLNonReentrantTrait, IGearStaking {
    using SafeCast for uint256;

    /// @dev Address of the GEAR token
    IGearToken public immutable gear;

    /// @dev Mapping of user address to their total staked tokens and tokens available for voting
    mapping(address => UserVoteLockData) internal voteLockData;

    /// @dev Mapping of user address to their future withdrawal amounts
    mapping(address => WithdrawalData) internal withdrawalData;

    /// @dev Mapping of address to their status as allowed voting contract
    mapping(address => VotingContractStatus) public allowedVotingContract;

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

    /// @dev Returns the total amount of GEAR the user staked into staked GEAR
    function balanceOf(address user) external view returns (uint256) {
        return uint256(voteLockData[user].totalStaked);
    }

    /// @dev Returns the balance available for voting or withdrawal
    function availableBalance(address user) external view returns (uint256) {
        return uint256(voteLockData[user].available);
    }

    /// @dev Deposits an amount of GEAR into staked GEAR. Optionally, performs a sequence of vote changes according to
    ///      the passed `votes` array
    /// @param amount Amount of GEAR to deposit into staked GEAR
    /// @param votes Array of MultVote structs:
    ///              * votingContract - contract to submit a vote to
    ///              * voteAmount - amount of staked GEAR to add to or remove from a vote
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
    ///              * voteAmount - amount of staked GEAR to add to or remove from a vote
    ///              * isIncrease - whether to add or remove votes
    ///              * extraData - data specific to the voting contract that is decoded on recipient side
    function multivote(MultiVote[] memory votes) external nonReentrant {
        _multivote(msg.sender, votes);
    }

    /// @dev Schedules a withdrawal from staked GEAR into GEAR, which can be claimed in 4 epochs.
    ///      If there are any withdrawals available to claim, they are also claimed.
    ///      Optionally, performs a sequence of vote changes according to
    ///      the passed `votes` array.
    /// @param amount Amount of staked GEAR to withdraw into GEAR
    /// @param to Address to send claimable GEAR, if any
    /// @param votes Array of MultVote structs:
    ///              * votingContract - contract to submit a vote to
    ///              * voteAmount - amount of staked GEAR to add to or remove from a vote
    ///              * isIncrease - whether to add or remove votes
    ///              * extraData - data specific to the voting contract that is decoded on recipient side
    function withdraw(uint256 amount, address to, MultiVote[] memory votes) external nonReentrant {
        if (votes.length > 0) {
            _multivote(msg.sender, votes);
        }

        _processPendingWithdrawals(msg.sender, to);

        uint96 amount96 = amount.toUint96();
        voteLockData[msg.sender].available -= amount96;
        withdrawalData[msg.sender].withdrawalsPerEpoch[3] += amount96;

        emit GearWithdrawalScheduled(msg.sender, amount);
    }

    /// @dev Claims all of the caller's withdrawals that are mature
    /// @param to Address to send claimable GEAR, if any
    function claimWithdrawals(address to) external nonReentrant {
        _processPendingWithdrawals(msg.sender, to);
    }

    /// @dev Refreshes the user's withdrawal struct, shifting the withdrawal amounts based
    ///      on the number of epochs that passed since the last update. If there are any mature withdrawals,
    ///      sends the corresponding amounts to the user
    function _processPendingWithdrawals(address user, address to) internal {
        uint16 epochNow = getCurrentEpoch();

        WithdrawalData memory wd = withdrawalData[user];

        if (epochNow > wd.epochLU) {
            if (
                wd.withdrawalsPerEpoch[0] + wd.withdrawalsPerEpoch[1] + wd.withdrawalsPerEpoch[2]
                    + wd.withdrawalsPerEpoch[3] > 0
            ) {
                uint16 epochDiff = epochNow - wd.epochLU;
                uint256 totalClaimable = 0;

                // Epochs one, two, three and four in the struct are always relative
                // to epochLU, so the amounts are "shifted" by the number of epochs that passed
                // since epochLU, on each update. If some amount shifts beyond epoch one, it is mature,
                // so GEAR is sent to the user.

                for (uint256 i = 0; i < 4;) {
                    if (i < epochDiff) {
                        totalClaimable += wd.withdrawalsPerEpoch[i];
                    }

                    if (epochDiff < 4 && i < 4 - epochDiff) {
                        wd.withdrawalsPerEpoch[i] = wd.withdrawalsPerEpoch[i + epochDiff];
                    } else {
                        wd.withdrawalsPerEpoch[i] = 0;
                    }

                    unchecked {
                        ++i;
                    }
                }

                if (totalClaimable > 0) {
                    gear.transfer(to, totalClaimable);
                    emit GearWithdrawalClaimed(user, to, totalClaimable);
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

            if (currentVote.isIncrease) {
                if (allowedVotingContract[currentVote.votingContract] != VotingContractStatus.ALLOWED) {
                    revert VotingContractNotAllowedException();
                }

                IVotingContract(currentVote.votingContract).vote(user, currentVote.voteAmount, currentVote.extraData);
                vld.available -= currentVote.voteAmount;
            } else {
                if (allowedVotingContract[currentVote.votingContract] == VotingContractStatus.NOT_ALLOWED) {
                    revert VotingContractNotAllowedException();
                }

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
    /// @param status The new status of the contract:
    ///               * NOT_ALLOWED - cannot vote or unvote
    ///               * ALLOWED - can both vote and unvote
    ///               * UNVOTE_ONLY - can only unvote
    function setVotingContractStatus(address votingContract, VotingContractStatus status) external configuratorOnly {
        allowedVotingContract[votingContract] = status;
    }
}
