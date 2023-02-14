// SPDX-License-Identifier: BUSL-1.1
// Gearbox Protocol. Generalized leverage for DeFi protocols
// (c) Gearbox Holdings, 2022
pragma solidity ^0.8.10;

import { ERC20 } from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { Address } from "@openzeppelin/contracts/utils/Address.sol";
import { IERC20Metadata } from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import { SafeERC20 } from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import { EnumerableSet } from "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";

import { AddressProvider } from "../core/AddressProvider.sol";
import { ContractsRegister } from "../core/ContractsRegister.sol";
import { ACLNonReentrantTrait } from "../core/ACLNonReentrantTrait.sol";

import { IGauge, GaugeOpts } from "../interfaces/IGauge.sol";

import { RAY, PERCENTAGE_FACTOR, SECONDS_PER_YEAR, MAX_WITHDRAW_FEE } from "../libraries/Constants.sol";
import { Errors } from "../libraries/Errors.sol";
import { Pool4626 } from "./Pool4626.sol";

// EXCEPTIONS
import { ZeroAddressException } from "../interfaces/IErrors.sol";

import "forge-std/console.sol";

uint192 constant RAY_DIVIDED_BY_PERCENTAGE = uint192(RAY / PERCENTAGE_FACTOR);
uint192 constant SECONDS_PER_YEAR_192 = uint192(SECONDS_PER_YEAR);

struct QuotaParams {
    uint16 rate; // in PERCENTAGE_FACTOR format 10_000 = 100%
    uint192 cumulativeIndexLU_RAY; // max 10^57
    uint40 lastUpdate; // enough to store timestamp for next 35K years
}

struct QuotaRateParams {
    uint16 minRiskRate; // set by risk dao
    uint16 maxRate; // set by dao voting
    uint96 votesLpSide;
    uint96 votesCaSide;
}

struct Stake {
    uint96 deposited;
    uint96 unstaking;
    uint96 voted;
    uint16 unstakedInEpoch;
}

/// @title Gauge fore new 4626 pools
contract Gauge is IGauge, ACLNonReentrantTrait {
    using EnumerableSet for EnumerableSet.AddressSet;
    using SafeERC20 for IERC20;

    /// @dev Address provider
    address public immutable addressProvider;

    /// @dev Address provider
    Pool4626 public immutable pool;

    /// @dev Timestamp when the first epoch started
    uint256 public immutable firstEpochTimestamp;

    /// @dev Gear token
    IERC20 public immutable gearToken;

    uint256 constant epochLength = 7 days;

    uint16 public currentEpoch;

    /// @dev
    mapping(address => QuotaParams) public quotaParams;

    mapping(address => QuotaRateParams) public quotaRateParams;

    /// @dev The list of all Credit Managers
    EnumerableSet.AddressSet internal quotaTokenSet;

    /// timelock for GEAR per epoch
    mapping(address => Stake) public stakes;

    //
    // CONSTRUCTOR
    //

    /// @dev Constructor
    /// @param opts Core pool options
    constructor(GaugeOpts memory opts)
        ACLNonReentrantTrait(opts.addressProvider)
    {
        // Additional check that receiver is not address(0)
        if (opts.addressProvider == address(0) || opts.pool == address(0)) {
            revert ZeroAddressException(); // F:[P4-02]
        }

        addressProvider = opts.addressProvider; // F:[P4-01]
        pool = Pool4626(payable(opts.pool)); // F:[P4-01]
        firstEpochTimestamp = opts.firstEpochTimestamp;
        gearToken = IERC20(opts.gearToken);
    }

    function cumulativeIndex(address token)
        external
        view
        override
        returns (uint256)
    {
        return _cumulativeIndexNow(quotaParams[token]);
    }

    function _cumulativeIndexNow(QuotaParams storage qp)
        internal
        view
        returns (uint192)
    {
        return
            qp.cumulativeIndexLU_RAY +
            (RAY_DIVIDED_BY_PERCENTAGE *
                uint192((block.timestamp - qp.lastUpdate) * qp.rate)) /
            SECONDS_PER_YEAR_192;
    }

    function _updateQuotaRate(address token, uint16 _rate) internal {
        QuotaParams storage qp = quotaParams[token];
        qp.cumulativeIndexLU_RAY = uint192(
            (qp.cumulativeIndexLU_RAY *
                (RAY +
                    (RAY_DIVIDED_BY_PERCENTAGE *
                        uint192((block.timestamp - qp.lastUpdate) * qp.rate)) /
                    SECONDS_PER_YEAR_192)) / RAY
        );
        qp.lastUpdate = uint40(block.timestamp);
        qp.rate = _rate;

        emit QuotaRateUpdated(token, _rate);
    }

    function getQuotaRate(address token) external view returns (uint256) {
        return quotaParams[token].rate;
    }

    function addQuotaToken(address token, uint16 _rate)
        external
        configuratorOnly
    {
        QuotaParams storage qp = quotaParams[token];
        if (qp.lastUpdate != 0) {
            revert TokenQuotaIsAlreadyAdded();
        }

        quotaTokenSet.add(token);

        qp.cumulativeIndexLU_RAY = uint192(RAY);
        qp.rate = _rate;
        qp.lastUpdate = uint40(block.timestamp);
        pool.updateQuotas();
    }

    function updateEpoch() external {
        _checkAndUpdateEpoch();
    }

    function _checkAndUpdateEpoch() internal {
        uint16 epochNow = uint16(
            (block.timestamp - firstEpochTimestamp) / epochLength
        );
        if (epochNow > currentEpoch) {
            currentEpoch = epochNow;

            /// compute all compounded rates
            Pool4626(pool).updateQuotas();

            /// update rates & cumulative indexes
            address[] memory tokens = quotaTokenSet.values();
            uint256 len = tokens.length;
            for (uint256 i; i < len; ) {
                address token = tokens[i];

                QuotaRateParams storage qrp = quotaRateParams[token];

                uint96 votesLpSide = qrp.votesLpSide;
                uint96 votesCaSide = qrp.votesCaSide;

                uint96 totalVotes = votesLpSide + votesCaSide;

                uint16 newRate = uint16(
                    totalVotes == 0
                        ? qrp.minRiskRate
                        : (qrp.minRiskRate *
                            votesCaSide +
                            qrp.maxRate *
                            votesLpSide) / totalVotes
                );

                _updateQuotaRate(token, newRate);

                unchecked {
                    ++i;
                }
            }
        }
    }

    function deposit(uint96 amount, address receiver) external nonReentrant {
        // Transfer from
        // add depositred
        Stake storage stake = stakes[msg.sender];
        stake.deposited += amount;

        gearToken.safeTransferFrom(msg.sender, address(this), amount);
        emit Deposit(msg.sender, receiver, amount);
    }

    function vote(
        address token,
        uint96 votes,
        bool lpSide
    ) external nonReentrant {
        _checkAndUpdateEpoch();
        Stake storage stake = stakes[msg.sender];
        if (votes > stake.deposited + stake.unstaking) {
            revert NotEnoughBalance();
        }

        unchecked {
            if (stake.unstaking > 0) {
                if (stake.unstaking > votes) {
                    stake.unstaking -= votes;
                } else {
                    stake.unstaking = 0;
                    stake.deposited -= votes - stake.unstaking;
                }
            } else {
                stake.deposited -= votes;
                stake.voted += votes;
            }
        }

        QuotaRateParams storage qp = quotaRateParams[token];
        if (lpSide) {
            qp.votesLpSide += votes;
        } else {
            qp.votesCaSide += votes;
        }

        // emit
        emit VoteFor(token, votes, lpSide);
    }

    function unvote(
        address token,
        uint96 votes,
        bool lpSide
    ) external nonReentrant {
        _checkAndUpdateEpoch();
        Stake storage stake = stakes[msg.sender];

        if (votes > stake.deposited) {
            revert NotEnoughBalance();
        }

        if (stake.unstaking > 0 && stake.unstakedInEpoch < currentEpoch) {
            stake.deposited += stake.unstaking;
            stake.unstaking = 0;
        }

        unchecked {
            stake.unstaking += votes;
            stake.voted -= votes;
            stake.unstakedInEpoch = currentEpoch;
        }

        QuotaRateParams storage qp = quotaRateParams[token];
        if (lpSide) {
            qp.votesLpSide -= votes;
        } else {
            qp.votesCaSide -= votes;
        }

        emit UnvoteFrom(token, votes, lpSide);
    }

    function withdraw(uint96 amount, address receiver) external nonReentrant {
        _checkAndUpdateEpoch();
        Stake storage stake = stakes[msg.sender];
        if (amount > stake.deposited) {
            revert NotEnoughBalance();
        }

        unchecked {
            stake.deposited -= amount;
        }

        gearToken.transfer(receiver, amount);

        // emit event
        emit Withdraw(msg.sender, receiver, amount);
    }
}
