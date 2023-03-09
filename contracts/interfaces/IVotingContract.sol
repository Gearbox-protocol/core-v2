pragma solidity ^0.8.17;

interface IVotingContract {
    function vote(address user, uint96 votes, bytes memory extraData) external;
    function unvote(address user, uint96 votes, bytes memory extraData) external;
}
