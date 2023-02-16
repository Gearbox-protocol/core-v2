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
import { IPoolQuotaKeeper, QuotaUpdate } from "../interfaces/IPoolQuotaKeeper.sol";
import { ICreditManagerV2 } from "../interfaces/ICreditManagerV2.sol";
import { IGauge } from "../interfaces/IGauge.sol";

import { RAY, PERCENTAGE_FACTOR, SECONDS_PER_YEAR, MAX_WITHDRAW_FEE } from "../libraries/Constants.sol";
import { Errors } from "../libraries/Errors.sol";
import { FixedPointMathLib } from "../libraries/SolmateMath.sol";

// EXCEPTIONS
import { ZeroAddressException } from "../interfaces/IErrors.sol";

import "forge-std/console.sol";

struct TotalQuota {
    uint96 totalQuoted;
    uint96 limit;
    uint16 rate; // current rate update
}

struct Quota {
    uint96 quota;
    uint192 cumulativeIndexLU;
    uint40 quotaLU;
}

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
    ) external override creditManagerOnly {
        uint256 len = quotaUpdates.length;
        int128 quotaIndexChange;
        uint256 caPremiumchange;

        for (uint256 i; i < len; ) {
            (int128 qic, uint256 cap) = _updateQuota(
                msg.sender,
                creditAccount,
                quotaUpdates[i].token,
                quotaUpdates[i].quotaChange
            );

            quotaIndexChange += qic;
            caPremiumchange += caPremiumchange;
            unchecked {
                ++i;
            }
        }

        pool.updateQuotaIndex(quotaIndexChange);
    }

    function updateQuota(
        address creditAccount,
        address token,
        int96 quotaChange
    ) external override creditManagerOnly {
        (int128 quotaIndexChange, uint256 caPremiumchange) = _updateQuota(
            msg.sender,
            creditAccount,
            token,
            quotaChange
        );
        pool.updateQuotaIndex(quotaIndexChange);
    }

    function _updateQuota(
        address creditManager,
        address creditAccount,
        address token,
        int96 quotaChange
    ) internal returns (int128 quotaIndexChange, uint256 caPremiumchange) {
        TotalQuota storage q = totalQuotas[token];
        Quota storage quota = quotas[creditManager][creditAccount][token];

        int96 change;
        uint96 totalQuoted = q.totalQuoted;

        /// UPDATE HERE
        if (quota.quota > 0) {}

        if (quotaChange > 0) {
            uint96 limit = q.limit;
            if (totalQuoted > limit) return (0, 0);
            change = (totalQuoted + uint96(quotaChange) > limit)
                ? int96(limit - totalQuoted)
                : quotaChange;
            q.totalQuoted = totalQuoted + uint96(change);

            quota.quota += uint96(change);
        } else {
            change = quotaChange;
            q.totalQuoted = uint96(int96(totalQuoted) + change);
            quota.quota -= uint96(-change);
        }

        return (change * int16(q.rate), caPremiumchange);
    }

    function updateRates() external gaugeOnly {
        // pool.accumQuotas();
        // address[] memory quotaAddrs = quotaTokensSet.values();
        // uint256 quotasLen = quotaAddrs.length;
        // quotaIndex = 0;
        // for (uint256 i; i < quotasLen;) {
        //     address token = quotaAddrs[i];
        //     TotalQuota storage q = totalQuotas[token];
        //     q.rate = IGauge(gauge).getQuotaRate(token);
        //     quotaIndex += q.totalQuoted * q.rate;
        //     unchecked {
        //         ++i;
        //     }
        // }
        /// Add check that premiums are not higher than uint128
    }

    /// @dev Gets the effective value (i.e., value in underlying included into TWV) for a token on an account
    function _getCollateralValue(
        address creditManager,
        address creditAccount,
        address token,
        IPriceOracleV2 _priceOracle
    ) internal view returns (uint256 value) {
        uint256 quotaValue = _priceOracle.convertToUSD(
            quotas[creditManager][creditAccount][token].quota,
            underlying
        );
        if (quotaValue > 1) {
            uint256 balance = IERC20(token).balanceOf(creditAccount);
            if (balance > 1) {
                value = _priceOracle.convertToUSD(balance, token);
                if (quotaValue < value) return quotaValue;
            }
        }
    }
}
