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
import {IGauge, GaugeOpts} from "../interfaces/IGauge.sol";
import {IPoolQuotaKeeper, QuotaRateUpdate} from "../interfaces/IPoolQuotaKeeper.sol";
import {IvlGEAR} from "../interfaces/IvlGEAR.sol";

import {RAY, PERCENTAGE_FACTOR, SECONDS_PER_YEAR, MAX_WITHDRAW_FEE} from "../libraries/Constants.sol";
import {Errors} from "../libraries/Errors.sol";
import {Pool4626} from "./Pool4626.sol";

// EXCEPTIONS
import {ZeroAddressException} from "../interfaces/IErrors.sol";

import "forge-std/console.sol";

struct QuotaRateParams {
    uint16 minRiskRate;
    uint16 maxRate;
    uint96 totalVotesLpSide;
    uint96 totalVotesCaSide;
}

struct UserVotes {
    uint96 votesLpSide;
    uint96 votesCaSide;
}

/// @title Gauge fore new 4626 pools
contract Gauge is IGauge, ACLNonReentrantTrait {
    using EnumerableSet for EnumerableSet.AddressSet;
    using SafeERC20 for IERC20;

    /// @dev Address provider
    address public immutable addressProvider;

    /// @dev Address provider
    Pool4626 public immutable pool;

    /// @dev Mapping from token address to its rate parameters
    mapping(address => QuotaRateParams) public quotaRateParams;

    /// @dev Mapping from (user, token) to vote amounts committed by user to each side
    mapping(address => mapping(address => UserVotes)) userTokenVotes;

    /// @dev GEAR locking and voting contract
    IvlGEAR public immutable voter;

    /// @dev Epoch when the gauge was last updated
    uint16 public epochLU;

    //
    // CONSTRUCTOR
    //

    /// @dev Constructor
    /// @param opts Core pool options
    constructor(GaugeOpts memory opts) ACLNonReentrantTrait(opts.addressProvider) {
        // Additional check that receiver is not address(0)
        if (opts.addressProvider == address(0) || opts.pool == address(0)) {
            revert ZeroAddressException(); // F:[P4-02]
        }

        addressProvider = opts.addressProvider; // F:[P4-01]
        pool = Pool4626(payable(opts.pool)); // F:[P4-01]
        voter = IvlGEAR(opts.vlGEAR);
        epochLU = voter.getCurrentEpoch();
    }

    modifier onlyVoter() {
        if (msg.sender != address(voter)) {
            revert OnlyVoterException();
        }
        _;
    }

    function addQuotaToken(address token, uint16 _minRiskRate, uint16 _maxRate) external configuratorOnly {
        quotaRateParams[token] =
            QuotaRateParams({minRiskRate: _minRiskRate, maxRate: _maxRate, totalVotesLpSide: 0, totalVotesCaSide: 0});

        IPoolQuotaKeeper keeper = IPoolQuotaKeeper(pool.poolQuotaKeeper());
        keeper.addQuotaToken(token);
    }

    function changeQuotaTokenRateParams(address token, uint16 _minRiskRate, uint16 _maxRate)
        external
        configuratorOnly
    {
        QuotaRateParams memory qrp = quotaRateParams[token];
        qrp.minRiskRate = _minRiskRate;
        qrp.maxRate = _maxRate;
        quotaRateParams[token] = qrp;
    }

    function updateEpoch() external {
        _checkAndUpdateEpoch();
    }

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

    function vote(address user, uint96 votes, bytes memory extraData) external onlyVoter {
        (address token, bool lpSide) = abi.decode(extraData, (address, bool));
        _vote(user, votes, token, lpSide);
    }

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

    function unvote(address user, uint96 votes, bytes memory extraData) external onlyVoter {
        (address token, bool lpSide) = abi.decode(extraData, (address, bool));
        _unvote(user, votes, token, lpSide);
    }

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
}
