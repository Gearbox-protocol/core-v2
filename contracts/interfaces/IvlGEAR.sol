// SPDX-License-Identifier: MIT
// Gearbox Protocol. Generalized leverage for DeFi protocols
// (c) Gearbox Holdings, 2022
pragma solidity ^0.8.17;

struct UserVoteLockData {
    uint96 totalStaked;
    uint96 available;
}

struct WithdrawalData {
    uint96 withdrawalsEpochOne;
    uint96 withdrawalsEpochTwo;
    uint96 withdrawalsEpochThree;
    uint96 withdrawalsEpochFour;
    uint16 epochLU;
}

struct MultiVote {
    address votingContract;
    uint96 voteAmount;
    bool isIncrease;
    bytes extraData;
}

interface IvlGEARExceptions {
    /// @dev Thrown when attempting to vote in a non-approved contract
    error VotingContractNotAllowedException();
}

interface IvlGEAREvents {
    /// @dev Emits when the user deposits GEAR into vlGEAR
    event GearDeposited(address indexed user, uint256 amount);

    /// @dev Emits when the user starts a withdrawal from vlGEAR
    event GearWithdrawalScheduled(address indexed user, uint256 amount);

    /// @dev Emits when the user claims a mature withdrawal from vlGEAR
    event GearWithdrawalClaimed(address indexed user, uint256 amount);
}

interface IvlGEAR is IvlGEAREvents, IvlGEARExceptions {
    /// @dev Returns the current global voting epoch
    function getCurrentEpoch() external view returns (uint16);

    /// @dev Deposits an amount of GEAR into vlGEAR. Optionally, performs a sequence of vote changes according to
    ///      the passed `votes` array
    /// @param amount Amount of GEAR to deposit into vlGEAR
    /// @param votes Array of MultVote structs:
    ///              * votingContract - contract to submit a vote to
    ///              * voteAmount - amount of vlGEAR to add to or remove from a vote
    ///              * isIncrease - whether to add or remove votes
    ///              * extraData - data specific to the voting contract that is decoded on recipient side
    function deposit(uint256 amount, MultiVote[] memory votes) external;

    /// @dev Performs a sequence of vote changes according to the passed array
    /// @param votes Array of MultVote structs:
    ///              * votingContract - contract to submit a vote to
    ///              * voteAmount - amount of vlGEAR to add to or remove from a vote
    ///              * isIncrease - whether to add or remove votes
    ///              * extraData - data specific to the voting contract that is decoded on recipient side
    function multivote(MultiVote[] memory votes) external;

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
    function withdraw(uint256 amount, MultiVote[] memory votes) external;

    /// @dev Claims all of the caller's withdrawals that are mature
    function claimWithdrawals() external;

    //
    // GETTER
    //

    /// @dev The total amount staked by the user in vlGEAR
    function balanceOf(address user) external view returns (uint256);

    /// @dev The amount available to the user for voting or withdrawal
    function availableBalance(address user) external view returns (uint256);

    /// @dev Mapping of address to their status as allowed voting contract
    function allowedVotingContract(address c) external view returns (bool);
}
