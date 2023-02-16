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

struct Quota {
    uint96 totalQuoted;
    uint96 limit;
    uint16 rate; // current rate update
}

/// @title Core pool contract compatible with ERC4626
/// @notice Implements pool & diesel token business logic
contract PoolQuotaKeeper is IPoolQuotaKeeper, ACLNonReentrantTrait {
    using EnumerableSet for EnumerableSet.AddressSet;

    /// @dev Address provider
    // address public immutable override addressProvider;

    /// @dev Address of the protocol treasury
    Pool4626 public immutable pool;

    /// @dev The list of all Credit Managers
    EnumerableSet.AddressSet internal creditManagerSet;

    /// @dev The list of all Credit Managers
    EnumerableSet.AddressSet internal quotaTokensSet;

    /// @dev
    mapping(address => Quota) public quotas;

    /// @dev IGauge
    IGauge public gauge;

    uint128 public quotaIndex;

    /// @dev Contract version
    uint256 public constant override version = 2_10;

    modifier gaugeOnly() {
        /// TODO: udpate exception
        if (msg.sender == address(gauge)) revert GaugeOnlyException(); // F:[P4-5]
        _;
    }

    modifier creditManagerWithActiveDebtOnly() {
        if (!creditManagerSet.contains(msg.sender)) {
            /// todo: add correct exception ??
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
        // addressProvider = opts.addressProvider; // F:[P4-01]
        // underlyingToken = opts.underlyingToken; // F:[P4-01]
        // _decimals = IERC20Metadata(opts.underlyingToken).decimals(); // F:[P4-01]

        // treasuryAddress = AddressProvider(opts.addressProvider).getTreasuryContract(); // F:[P4-01]

        // timestampLU = uint64(block.timestamp); // F:[P4-01]
        // cumulativeIndexLU_RAY = uint128(RAY); // F:[P4-01]

        // interestRateModel = IInterestRateModel(opts.interestRateModel);
        // emit NewInterestRateModel(opts.interestRateModel); // F:[P4-03]

        // _setExpectedLiquidityLimit(opts.expectedLiquidityLimit); // F:[P4-01, 03]
        // _setTotalBorrowedLimit(opts.expectedLiquidityLimit); // F:[P4-03]
        // supportQuotaPremiums = opts.supportQuotaPremiums; // F:[P4-01]
        // wethAddress = AddressProvider(opts.addressProvider).getWethToken(); // F:[P4-01]
    }

    /// CM only
    function updateQuota(
        address creditAccount,
        address token,
        int96 quotaChange
    ) external override creditManagerWithActiveDebtOnly {
        // _accumQuotas();
        _updateQuota(token, quotaChange);
    }

    /// CM only
    function updateQuotas(
        address creditAccount,
        QuotaUpdate[] memory quotaUpdates
    ) external override creditManagerWithActiveDebtOnly {
        // _accumQuotas();
        uint256 len = quotaUpdates.length;
        // changes = new int96[](len);
        unchecked {
            for (uint256 i; i < len; ++i) {
                // changes[i] =
                _updateQuota(
                    quotaUpdates[i].token,
                    quotaUpdates[i].quotaChange
                );
            }
        }
    }

    function _updateQuota(address token, int96 quotaChange)
        internal
        returns (int96 change)
    {
        Quota storage q = quotas[token];

        uint96 totalQuoted = q.totalQuoted;
        if (quotaChange > 0) {
            uint96 limit = q.limit;
            if (totalQuoted > limit) return 0;
            change = (totalQuoted + uint96(quotaChange) > limit)
                ? int96(limit - totalQuoted)
                : quotaChange;
            q.totalQuoted = totalQuoted + uint96(change);
        } else {
            change = quotaChange;
            q.totalQuoted = uint96(int96(totalQuoted) + change);
        }

        quotaIndex = uint128(int128(quotaIndex) + change * int16(q.rate));
    }

    function updateQuotas() external gaugeOnly {
        // pool.accumQuotas();
        address[] memory quotaAddrs = quotaTokensSet.values();
        uint256 quotasLen = quotaAddrs.length;
        quotaIndex = 0;
        for (uint256 i; i < quotasLen; ) {
            address token = quotaAddrs[i];
            Quota storage q = quotas[token];
            q.rate = IGauge(gauge).getQuotaRate(token);
            quotaIndex += q.totalQuoted * q.rate;

            unchecked {
                ++i;
            }
        }

        /// Add check that premiums are not higher than uint128
    }
}
