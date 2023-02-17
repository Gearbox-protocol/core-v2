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

import { IWETH } from "../interfaces/external/IWETH.sol";
import { IPriceOracleV2 } from "../interfaces/IPriceOracle.sol";
// import {IERC4626} from "@openzeppelin/contracts/interfaces/IERC4626.sol";

import { AddressProvider } from "../core/AddressProvider.sol";
import { ContractsRegister } from "../core/ContractsRegister.sol";
import { ACLNonReentrantTrait } from "../core/ACLNonReentrantTrait.sol";

import { Pool4626 } from "./Pool4626.sol";
import { IPoolQuotaKeeper, QuotaUpdate, QuotaRateUpdate, LimitTokenCalc } from "../interfaces/IPoolQuotaKeeper.sol";
import { ICreditManagerV2 } from "../interfaces/ICreditManagerV2.sol";
import { IGauge } from "../interfaces/IGauge.sol";

import { RAY, PERCENTAGE_FACTOR, SECONDS_PER_YEAR, MAX_WITHDRAW_FEE } from "../libraries/Constants.sol";
import { Errors } from "../libraries/Errors.sol";
import { FixedPointMathLib } from "../libraries/SolmateMath.sol";

// EXCEPTIONS
import { ZeroAddressException } from "../interfaces/IErrors.sol";

import "forge-std/console.sol";

/// Invariant: totalQuoted = sum of Quota.quota for particular asset

struct TotalQuota {
    uint96 totalQuoted;
    uint96 limit;
    uint16 rate; // current rate update
    uint192 cumulativeIndexLU_RAY; // max 10^57
}

struct Quota {
    uint96 quota;
    uint192 cumulativeIndexLU;
    uint40 quotaLU;
}

uint192 constant RAY_DIVIDED_BY_PERCENTAGE = uint192(RAY / PERCENTAGE_FACTOR);
uint192 constant SECONDS_PER_YEAR_192 = uint192(SECONDS_PER_YEAR);

/// @title Core pool contract compatible with ERC4626
/// @notice Implements pool & diesel token business logic

contract PoolQuotaKeeper is IPoolQuotaKeeper, ACLNonReentrantTrait {
    using EnumerableSet for EnumerableSet.AddressSet;

    /// @dev Address provider
    address public immutable underlying;

    /// @dev Address of the protocol treasury
    Pool4626 public immutable pool;

    /// @dev The list of all Credit Managers
    EnumerableSet.AddressSet internal creditManagerSet;

    /// @dev The list of all Credit Managers
    EnumerableSet.AddressSet internal quotaTokensSet;

    /// @dev
    mapping(address => TotalQuota) public totalQuotas;

    uint256 lastQuotaRateUpdate;

    mapping(address => mapping(address => mapping(address => Quota))) quotas;

    /// @dev IGauge
    IGauge public gauge;

    /// @dev Contract version
    uint256 public constant override version = 2_10;

    modifier gaugeOnly() {
        /// TODO: udpate exception
        if (msg.sender == address(gauge)) revert GaugeOnlyException(); // F:[P4-5]
        _;
    }

    modifier creditManagerOnly() {
        if (!creditManagerSet.contains(msg.sender)) {
            revert CreditManagerOnlyException();
        }
        _;
    }

    //
    // CONSTRUCTOR
    //

    /// @dev Constructor
    /// @param _pool Pool address
    constructor(address payable _pool)
        ACLNonReentrantTrait(address(Pool4626(_pool).addressProvider()))
    {
        // Additional check that receiver is not address(0)
        if (_pool == address(0)) {
            revert ZeroAddressException(); // F:[P4-02]
        }
        pool = Pool4626(_pool);
        underlying = Pool4626(_pool).asset();
    }

    /// CM only
    function updateQuotas(
        address creditAccount,
        QuotaUpdate[] memory quotaUpdates
    )
        external
        override
        creditManagerOnly
        returns (
            uint256 caPremiumChange,
            bool[] memory statusChanges,
            bool oneStatusWasChanged
        )
    {
        uint256 len = quotaUpdates.length;
        int128 quotaRevenueChange;

        statusChanges = new bool[](len);

        for (uint256 i; i < len; ) {
            (int128 qic, uint256 cap, bool statusChanged) = _updateQuota(
                msg.sender,
                creditAccount,
                quotaUpdates[i].token,
                quotaUpdates[i].quotaChange
            );

            quotaRevenueChange += qic;
            caPremiumChange += cap;
            statusChanges[i] = statusChanged;
            oneStatusWasChanged = oneStatusWasChanged || statusChanged;
            unchecked {
                ++i;
            }
        }

        pool.changeQuotaRevenue(quotaRevenueChange);
    }

    function _updateQuota(
        address creditManager,
        address creditAccount,
        address token,
        int96 quotaChange
    )
        internal
        returns (
            int128 quotaRevenueChange,
            uint256 caPremiumChange,
            bool quotaStatusChanged
        )
    {
        TotalQuota storage q = totalQuotas[token];

        /// TODO: add exception QuotaIsNotSupported
        if (q.cumulativeIndexLU_RAY == 0) {
            revert();
        }

        Quota storage quota = quotas[creditManager][creditAccount][token];
        int96 change;
        uint96 totalQuoted = q.totalQuoted;
        uint192 cumulativeIndexNow = _cumulativeIndexNow(q);

        /// UPDATE HERE ::: check quota.quota is "1"
        if (quota.quota > 1) {
            caPremiumChange = _calcPremium(quota, token);
        }

        quota.cumulativeIndexLU = cumulativeIndexNow;

        if (quotaChange > 0) {
            uint96 limit = q.limit;
            if (totalQuoted > limit) return (0, caPremiumChange, false);
            change = (totalQuoted + uint96(quotaChange) > limit)
                ? int96(limit - totalQuoted)
                : quotaChange;
            q.totalQuoted = totalQuoted + uint96(change);

            if (quota.quota == 0 && change > 0) {
                quotaStatusChanged = true;
            }

            quota.quota += uint96(change);
        } else {
            change = quotaChange;
            q.totalQuoted = uint96(int96(totalQuoted) + change);

            if (quota.quota == uint96(-change)) {
                quotaStatusChanged = true;
            }

            quota.quota -= uint96(-change);
        }

        return (change * int16(q.rate), caPremiumChange, quotaStatusChanged);
    }

    function _removeQuota(
        address creditManager,
        address creditAccount,
        address token
    ) internal returns (int128 quotaRevenueChange, uint256 caPremiumChange) {
        Quota storage quota = quotas[creditManager][creditAccount][token];
        uint96 quoted = quota.quota;

        /// UPDATE HERE: case "1"
        if (quoted <= 1) return (0, 0);

        TotalQuota storage q = totalQuotas[token];
        uint192 cumulativeIndexNow = _cumulativeIndexNow(q);

        /// TODO: check & move into internal function
        caPremiumChange = _calcPremium(quota, token);
        quota.cumulativeIndexLU = 0;
        q.totalQuoted -= quoted;
        quota.quota = 1; // TODO: "0" or "1"(?)

        return (-int128(uint128(quoted)) * int16(q.rate), caPremiumChange);
    }

    function updateRates(QuotaRateUpdate[] memory qUpdates)
        external
        override
        gaugeOnly
    {
        uint256 len = qUpdates.length;

        if (len != quotaTokensSet.length()) {
            /// add needed tokens
        }

        uint256 deltaTimestamp_RAY = RAY *
            (block.timestamp - lastQuotaRateUpdate);
        uint128 quotaRevenue;
        for (uint256 i; i < len; ) {
            address token = qUpdates[i].token;
            TotalQuota storage tq = totalQuotas[token];
            uint16 rate = qUpdates[i].rate;

            tq.cumulativeIndexLU_RAY = uint192(
                (uint256(tq.cumulativeIndexLU_RAY) *
                    (RAY +
                        (rate * deltaTimestamp_RAY) /
                        PERCENTAGE_FACTOR /
                        SECONDS_PER_YEAR)) / RAY
            );
            tq.rate = rate;

            quotaRevenue += rate * tq.totalQuoted;
            emit QuotaRateUpdated(token, rate);

            unchecked {
                ++i;
            }
        }
        pool.updateQuotaRevenue(quotaRevenue);
        lastQuotaRateUpdate = block.timestamp;
    }

    function computeOutstandingPremiums(
        address creditManager,
        address creditAccount,
        LimitTokenCalc[] memory tokens
    ) external view override returns (uint256 totalPremiums) {
        uint256 i;

        uint256 len = tokens.length;
        while (i < len && tokens[i].token != address(0)) {
            Quota storage q = quotas[creditManager][creditAccount][
                tokens[i].token
            ];

            totalPremiums += _calcPremium(q, tokens[i].token);
        }
    }

    function computeQuotedCollateralUSD(
        address creditManager,
        address creditAccount,
        address _priceOracle,
        LimitTokenCalc[] memory tokens
    ) external view override returns (uint256 value, uint256 premium) {
        uint256 i;

        uint256 len = tokens.length;
        while (i < len && tokens[i].token != address(0)) {
            (uint256 currentUSD, uint256 p) = _getCollateralValue(
                creditManager,
                creditAccount,
                tokens[i].token,
                _priceOracle
            );

            value += currentUSD * tokens[i].lt;
            premium += p;

            unchecked {
                ++i;
            }
        }

        value /= PERCENTAGE_FACTOR;
    }

    /// @dev Gets the effective value (i.e., value in underlying included into TWV) for a token on an account

    function _getCollateralValue(
        address creditManager,
        address creditAccount,
        address token,
        address _priceOracle
    ) internal view returns (uint256 value, uint256 premium) {
        Quota storage q = quotas[creditManager][creditAccount][token];

        /// TODO: check "1" problem
        if (q.quota > 1) {
            uint256 quotaValueUSD = IPriceOracleV2(_priceOracle).convertToUSD(
                q.quota,
                underlying
            );
            uint256 balance = IERC20(token).balanceOf(creditAccount);
            if (balance > 1) {
                value = IPriceOracleV2(_priceOracle).convertToUSD(
                    balance,
                    token
                );
                if (value > quotaValueUSD) value = quotaValueUSD;
            }

            premium = _calcPremium(q, token);
        }
    }

    function _calcPremium(Quota storage q, address token)
        internal
        view
        returns (uint256 premium)
    {
        premium =
            (q.quota * cumulativeIndex(token)) /
            q.cumulativeIndexLU -
            q.quota;
    }

    function closeCreditAccount(
        address creditAccount,
        LimitTokenCalc[] memory tokens
    ) external override creditManagerOnly returns (uint256 premiums) {
        int128 quotaRevenueChange;

        uint256 len = tokens.length;
        for (uint256 i; i < len; ) {
            address token = tokens[i].token;

            (int128 qic, uint256 cap) = _removeQuota(
                msg.sender,
                creditAccount,
                token
            );

            quotaRevenueChange += qic;
            premiums += cap;
            unchecked {
                ++i;
            }
        }

        /// TODO: check side effect of updating expectedLiquidity
        pool.changeQuotaRevenue(quotaRevenueChange);
    }

    //
    // GETTERS
    //
    function cumulativeIndex(address token)
        public
        view
        override
        returns (uint256)
    {
        return _cumulativeIndexNow(totalQuotas[token]);
    }

    function _cumulativeIndexNow(TotalQuota storage tq)
        internal
        view
        returns (uint192)
    {
        return
            tq.cumulativeIndexLU_RAY *
            uint192(
                (RAY +
                    (RAY_DIVIDED_BY_PERCENTAGE *
                        (block.timestamp - lastQuotaRateUpdate) *
                        tq.rate) /
                    SECONDS_PER_YEAR) / RAY
            );
    }

    function getQuotaRate(address token)
        external
        view
        override
        returns (uint16)
    {
        return totalQuotas[token].rate;
    }

    function _addQuotaToken(address token, uint16 _rate) external gaugeOnly {
        TotalQuota storage qp = totalQuotas[token];
        if (qp.cumulativeIndexLU_RAY != 0) {
            revert TokenQuotaIsAlreadyAdded();
        }

        quotaTokensSet.add(token);
        emit QuotaTokenAdded(token);

        qp.cumulativeIndexLU_RAY = uint192(RAY);

        // TODO: add here code to make updateQuotasRate correctly working
        // _updateQuotaRate(token, _rate);
        // pool.updateQuotas();
    }

    function quotedTokens() external view override returns (address[] memory) {
        return quotaTokensSet.values();
    }
}
