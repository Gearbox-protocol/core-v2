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

/// @title Gauge fore new 4626 pools
contract Gauge is IGauge, ACLNonReentrantTrait {
    using EnumerableSet for EnumerableSet.AddressSet;

    /// @dev Address provider
    address public immutable addressProvider;

    /// @dev Address provider
    Pool4626 public immutable pool;

    /// @dev Timestamp when the first epoch started
    uint256 public immutable firstEpochTimestamp;

    uint256 constant epochLength = 7 days;

    uint16 public currentEpoch;

    /// @dev
    mapping(address => QuotaParams) public quotaParams;

    mapping(address => QuotaRateParams) public quotaRateParams;

    /// @dev The list of all Credit Managers
    EnumerableSet.AddressSet internal quotaTokenSet;

    /// timelock for GEAR per epoch

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
    }

    function cumulativeIndex(address token)
        external
        view
        override
        returns (uint256)
    {
        QuotaParams storage qp = quotaParams[token];
        return
            qp.cumulativeIndexLU_RAY +
            (RAY * uint256(qp.rate) * (block.timestamp - qp.lastUpdate)) /
            SECONDS_PER_YEAR /
            PERCENTAGE_FACTOR;
    }

    function _updateBorrowRate(address token, uint16 _rate) internal {
        QuotaParams storage qp = quotaParams[token];
        qp.cumulativeIndexLU_RAY = uint192(
            qp.cumulativeIndexLU_RAY +
                (RAY * uint256(qp.rate) * (block.timestamp - qp.lastUpdate)) /
                SECONDS_PER_YEAR /
                PERCENTAGE_FACTOR
        );
        qp.lastUpdate = uint40(block.timestamp);
        qp.rate = _rate;
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
                QuotaParams storage qp = quotaParams[token];
                QuotaRateParams storage quotaRateParam = quotaRateParams[token];

                uint96 votesLpSide = quotaRateParam.votesLpSide;
                uint96 votesCaSide = quotaRateParam.votesCaSide;
                uint96 totalVotes = votesLpSide + votesCaSide;

                uint16 newRate = uint16(
                    totalVotes == 0
                        ? quotaRateParam.minRiskRate
                        : (quotaRateParam.minRiskRate *
                            votesCaSide +
                            quotaRateParam.maxRate *
                            votesLpSide) / totalVotes
                );

                _updateBorrowRate(token, newRate);

                unchecked {
                    ++i;
                }
            }
        }
    }
}
