// SPDX-License-Identifier: BUSL-1.1
// Gearbox Protocol. Generalized leverage for DeFi protocols
// (c) Gearbox Holdings, 2022
pragma solidity ^0.8.10;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {Address} from "@openzeppelin/contracts/utils/Address.sol";
import {IERC20Metadata} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {EnumerableSet} from "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";

import {AddressProvider} from "../core/AddressProvider.sol";
import {ContractsRegister} from "../core/ContractsRegister.sol";
import {ACLNonReentrantTrait} from "../core/ACLNonReentrantTrait.sol";

// interfaces
import {IGauge, GaugeOpts, QuotaRateParams, UserVotes} from "../interfaces/IGauge.sol";
import {IPoolQuotaKeeper, QuotaRateUpdate} from "../interfaces/IPoolQuotaKeeper.sol";
import {IGearStaking} from "../interfaces/IGearStaking.sol";

import {RAY, PERCENTAGE_FACTOR, SECONDS_PER_YEAR, MAX_WITHDRAW_FEE} from "../libraries/Constants.sol";
import {Errors} from "../libraries/Errors.sol";
import {Pool4626} from "./Pool4626.sol";

// EXCEPTIONS
import {ZeroAddressException} from "../interfaces/IErrors.sol";

import "forge-std/console.sol";

/// @title Gauge fore new 4626 pools
contract Gauge is IGauge, ACLNonReentrantTrait {
    using EnumerableSet for EnumerableSet.AddressSet;
    using SafeERC20 for IERC20;

    /// @dev Address provider
    address public immutable addressProvider;

    /// @dev Address of the pool
    Pool4626 public immutable pool;

    /// @dev Mapping from token address to its rate parameters
    mapping(address => QuotaRateParams) public quotaRateParams;

    /// @dev Mapping from (user, token) to vote amounts committed by user to each side
    mapping(address => mapping(address => UserVotes)) userTokenVotes;

    /// @dev GEAR locking and voting contract
    IGearStaking public voter;

    /// @dev Epoch when the gauge was last updated
    uint16 public epochLU;

    //
    // CONSTRUCTOR
    //

    /// @dev Constructor
    /// @param opts Gauge options
    ///             * addressProvider - the AddressProvder contract
    ///             * pool - Address of the associated pool
    ///             * vote
    constructor(GaugeOpts memory opts) ACLNonReentrantTrait(opts.addressProvider) {
        // Additional check that receiver is not address(0)
        if (opts.addressProvider == address(0) || opts.pool == address(0)) {
            revert ZeroAddressException(); // F:[P4-02]
        }

        addressProvider = opts.addressProvider; // F:[P4-01]
        pool = Pool4626(payable(opts.pool)); // F:[P4-01]
        voter = IGearStaking(opts.gearStaking);
        epochLU = voter.getCurrentEpoch();
    }

    /// @dev Reverts if the function is called by an address other than the voter
    modifier onlyVoter() {
        if (msg.sender != address(voter)) {
            revert OnlyVoterException();
        }
        _;
    }

    /// @dev Rolls the new epoch and updates all quota rates
    function updateEpoch() external {
        _checkAndUpdateEpoch();
    }

    /// @dev IMPLEMENTATION: updateEpoch()
    function _checkAndUpdateEpoch() internal {
        uint16 epochNow = voter.getCurrentEpoch();
        if (epochNow > epochLU) {
            epochLU = epochNow;

            /// compute all compounded rates
            IPoolQuotaKeeper keeper = IPoolQuotaKeeper(pool.poolQuotaKeeper());

            /// update rates & cumulative indexes
            address[] memory tokens = keeper.quotedTokens();
            uint256 len = tokens.length;
            QuotaRateUpdate[] memory qUpdates = new QuotaRateUpdate[](len);

            for (uint256 i; i < len;) {
                address token = tokens[i];

                QuotaRateParams storage qrp = quotaRateParams[token];

                uint96 votesLpSide = qrp.totalVotesLpSide;
                uint96 votesCaSide = qrp.totalVotesCaSide;

                uint96 totalVotes = votesLpSide + votesCaSide;

                uint16 newRate = uint16(
                    totalVotes == 0
                        ? qrp.minRiskRate
                        : (qrp.minRiskRate * votesCaSide + qrp.maxRate * votesLpSide) / totalVotes
                );

                qUpdates[i] = QuotaRateUpdate({token: token, rate: newRate});

                unchecked {
                    ++i;
                }
            }

            keeper.updateRates(qUpdates);
        }
    }

    /// @dev Submits a vote to move the quota rate for a token
    /// @param user The user that submitted a vote
    /// @param votes Amount of staked GEAR the user voted with
    /// @param extraData Gauge specific parameters (encoded into extraData to adhere to a general VotingContract interface)
    ///                  * token - address of the token to vote for
    ///                  * lpSide - votes in favor of LPs (increasing rate) if true, or in favor of CAs (decreasing rate) if false
    function vote(address user, uint96 votes, bytes memory extraData) external onlyVoter {
        (address token, bool lpSide) = abi.decode(extraData, (address, bool));
        _vote(user, votes, token, lpSide);
    }

    /// @dev IMPLEMENTATION: vote
    function _vote(address user, uint96 votes, address token, bool lpSide) internal {
        _checkAndUpdateEpoch();

        QuotaRateParams storage qp = quotaRateParams[token];
        UserVotes storage uv = userTokenVotes[user][token];
        if (lpSide) {
            qp.totalVotesLpSide += votes;
            uv.votesLpSide += votes;
        } else {
            qp.totalVotesCaSide += votes;
            uv.votesCaSide += votes;
        }

        emit VoteFor(user, token, votes, lpSide);
    }

    /// @dev Removes the user's existing vote from the provided token and side
    /// @param user The user that submitted a vote
    /// @param votes Amount of staked GEAR to remove
    /// @param extraData Gauge specific parameters (encoded into extraData to adhere to a general VotingContract interface)
    ///                  * token - address of the token to unvote from
    ///                  * lpSide - whether the side unvoted from is LP side
    function unvote(address user, uint96 votes, bytes memory extraData) external onlyVoter {
        (address token, bool lpSide) = abi.decode(extraData, (address, bool));
        _unvote(user, votes, token, lpSide);
    }

    /// @dev IMPLEMENTATION: unvote
    function _unvote(address user, uint96 votes, address token, bool lpSide) internal {
        _checkAndUpdateEpoch();

        QuotaRateParams storage qp = quotaRateParams[token];
        UserVotes storage uv = userTokenVotes[user][token];
        if (lpSide) {
            qp.totalVotesLpSide -= votes;
            uv.votesLpSide -= votes;
        } else {
            qp.totalVotesCaSide -= votes;
            uv.votesCaSide -= votes;
        }

        emit UnvoteFrom(user, token, votes, lpSide);
    }

    //
    // CONFIGURATION
    //

    /// @dev Sets the GEAR staking contract, which is the only entity allowed to vote/unvote
    function setVoter(address newVoter) external configuratorOnly {
        voter = IGearStaking(newVoter);

        emit VoterUpdated(newVoter);
    }

    /// @dev Adds a new quoted token to the Gauge and PoolQuotaKeeper, and sets the initial rate params
    /// @param token Address of the token to add
    /// @param _minRiskRate The minimal interest rate paid on token's quotas
    /// @param _maxRate The maximal interest rate paid on token's quotas
    function addQuotaToken(address token, uint16 _minRiskRate, uint16 _maxRate) external configuratorOnly {
        quotaRateParams[token] =
            QuotaRateParams({minRiskRate: _minRiskRate, maxRate: _maxRate, totalVotesLpSide: 0, totalVotesCaSide: 0});

        IPoolQuotaKeeper keeper = IPoolQuotaKeeper(pool.poolQuotaKeeper());
        keeper.addQuotaToken(token);

        emit QuotaTokenAdded(token, _minRiskRate, _maxRate);
    }

    /// @dev Changes the rate params for a quoted token
    /// @param _minRiskRate The minimal interest rate paid on token's quotas
    /// @param _maxRate The maximal interest rate paid on token's quotas
    function changeQuotaTokenRateParams(address token, uint16 _minRiskRate, uint16 _maxRate)
        external
        configuratorOnly
    {
        QuotaRateParams memory qrp = quotaRateParams[token];
        qrp.minRiskRate = _minRiskRate;
        qrp.maxRate = _maxRate;
        quotaRateParams[token] = qrp;

        emit QuotaParametersChanged(token, _minRiskRate, _maxRate);
    }
}
