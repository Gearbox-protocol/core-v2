// SPDX-License-Identifier: MIT
// Gearbox Protocol. Generalized leverage for DeFi protocols
// (c) Gearbox Holdings, 2022
pragma solidity ^0.8.17;

enum VotingContractStatus {
    NOT_ALLOWED,
    ALLOWED,
    UNVOTE_ONLY
}

struct UserVoteLockData {
    uint96 totalStaked;
    uint96 available;
}

struct WithdrawalData {
    uint96[4] withdrawalsPerEpoch;
    uint16 epochLU;
}

struct MultiVote {
    address votingContract;
    uint96 voteAmount;
    bool isIncrease;
    bytes extraData;
}

interface IGearStakingExceptions {
    /// @dev Thrown when attempting to vote in a non-approved contract
    error VotingContractNotAllowedException();
}

interface IGearStakingEvents {
    /// @dev Emits when the user deposits GEAR into staked GEAR
    event GearDeposited(address indexed user, uint256 amount);

    /// @dev Emits when the user starts a withdrawal from staked GEAR
    event GearWithdrawalScheduled(address indexed user, uint256 amount);

    /// @dev Emits when the user claims a mature withdrawal from staked GEAR
    event GearWithdrawalClaimed(address indexed user, address to, uint256 amount);
}

interface IGearStaking is IGearStakingEvents, IGearStakingExceptions {
    /// @dev Returns the current global voting epoch
    function getCurrentEpoch() external view returns (uint16);

    /// @dev Deposits an amount of GEAR into staked GEAR. Optionally, performs a sequence of vote changes according to
    ///      the passed `votes` array
    /// @param amount Amount of GEAR to deposit into staked GEAR
    /// @param votes Array of MultVote structs:
    ///              * votingContract - contract to submit a vote to
    ///              * voteAmount - amount of staked GEAR to add to or remove from a vote
    ///              * isIncrease - whether to add or remove votes
    ///              * extraData - data specific to the voting contract that is decoded on recipient side
    function deposit(uint256 amount, MultiVote[] memory votes) external;

    /// @dev Performs a sequence of vote changes according to the passed array
    /// @param votes Array of MultVote structs:
    ///              * votingContract - contract to submit a vote to
    ///              * voteAmount - amount of staked GEAR to add to or remove from a vote
    ///              * isIncrease - whether to add or remove votes
    ///              * extraData - data specific to the voting contract that is decoded on recipient side
    function multivote(MultiVote[] memory votes) external;

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
    function withdraw(uint256 amount, address to, MultiVote[] memory votes) external;

    /// @dev Claims all of the caller's withdrawals that are mature
    /// @param to Address to send claimable GEAR, if any
    function claimWithdrawals(address to) external;

    //
    // GETTER
    //

    /// @dev The total amount staked by the user in staked GEAR
    function balanceOf(address user) external view returns (uint256);

    /// @dev The amount available to the user for voting or withdrawal
    function availableBalance(address user) external view returns (uint256);

    /// @dev Mapping of address to their status as allowed voting contract
    function allowedVotingContract(address c) external view returns (VotingContractStatus);
}
