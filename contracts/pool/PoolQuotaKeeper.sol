// SPDX-License-Identifier: BUSL-1.1
// Gearbox Protocol. Generalized leverage for DeFi protocols
// (c) Gearbox Holdings, 2022
pragma solidity ^0.8.17;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {Address} from "@openzeppelin/contracts/utils/Address.sol";
import {IERC20Metadata} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {EnumerableSet} from "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";

import {IWETH} from "@gearbox-protocol/core-v2/contracts/interfaces/external/IWETH.sol";
import {IPriceOracleV2} from "@gearbox-protocol/core-v2/contracts/interfaces/IPriceOracle.sol";

import {AddressProvider} from "@gearbox-protocol/core-v2/contracts/core/AddressProvider.sol";
import {ContractsRegister} from "@gearbox-protocol/core-v2/contracts/core/ContractsRegister.sol";
import {ACLNonReentrantTrait} from "../core/ACLNonReentrantTrait.sol";

import {Pool4626} from "./Pool4626.sol";
import {
    IPoolQuotaKeeper,
    QuotaUpdate,
    QuotaRateUpdate,
    TokenLT,
    QuotaStatusChange,
    TokenQuotaParams,
    AccountQuota
} from "../interfaces/IPoolQuotaKeeper.sol";
import {ICreditManagerV2} from "../interfaces/ICreditManagerV2.sol";
import {IGauge} from "../interfaces/IGauge.sol";

import {RAY, SECONDS_PER_YEAR, MAX_WITHDRAW_FEE} from "@gearbox-protocol/core-v2/contracts/libraries/Constants.sol";
import {PERCENTAGE_FACTOR} from "@gearbox-protocol/core-v2/contracts/libraries/PercentageMath.sol";
import {Errors} from "@gearbox-protocol/core-v2/contracts/libraries/Errors.sol";

// EXCEPTIONS
import {ZeroAddressException} from "../interfaces/IErrors.sol";

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

    /// @dev Mapping from token address to its respective quota parameters
    mapping(address => TokenQuotaParams) public totalQuotas;

    /// @dev Timestamp of the last time quota rates were batch-updated
    uint256 lastQuotaRateUpdate;

    /// @dev Mapping from (user, token) to per-account quota parameters
    mapping(address => mapping(address => mapping(address => AccountQuota))) internal quotas;

    /// @dev Address of the gauge that determines quota rates
    IGauge public gauge;

    /// @dev Contract version
    uint256 public constant override version = 2_10;

    /// @dev Reverts if the function is called by non-gauge
    modifier gaugeOnly() {
        if (msg.sender != address(gauge)) revert GaugeOnlyException();
        _;
    }

    /// @dev Reverts if the function is called by non-Credit Manager
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
    constructor(address _pool) ACLNonReentrantTrait(address(Pool4626(_pool).addressProvider())) {
        // Additional check that receiver is not address(0)
        if (_pool == address(0)) {
            revert ZeroAddressException(); // F:[P4-02]
        }
        pool = Pool4626(_pool);
        underlying = Pool4626(_pool).asset();
    }

    /// @dev Updates credit account's quotas for multiple tokens
    /// @param creditAccount Address of credit account
    /// @param quotaUpdates Requested quota updates, see `QuotaUpdate`
    function updateQuotas(address creditAccount, QuotaUpdate[] memory quotaUpdates)
        external
        override
        creditManagerOnly
        returns (uint256 caQuotaInterestChange, QuotaStatusChange[] memory statusChanges, bool statusWasChanged)
    {
        uint256 len = quotaUpdates.length;
        int128 quotaRevenueChange;

        statusChanges = new QuotaStatusChange[](len);

        for (uint256 i; i < len;) {
            (int128 qic, uint256 cap, QuotaStatusChange statusChange) =
                _updateQuota(msg.sender, creditAccount, quotaUpdates[i].token, quotaUpdates[i].quotaChange); // F: [CMQ-03]

            quotaRevenueChange += qic;
            caQuotaInterestChange += cap;
            statusChanges[i] = statusChange;
            statusWasChanged = statusWasChanged || (statusChange != QuotaStatusChange.NOT_CHANGED); // F: [CMQ-03]
            unchecked {
                ++i;
            }
        }

        if (quotaRevenueChange != 0) {
            pool.changeQuotaRevenue(quotaRevenueChange);
        }
    }

    /// @dev Update function for a single quoted token
    function _updateQuota(address creditManager, address creditAccount, address token, int96 quotaChange)
        internal
        returns (int128 quotaRevenueChange, uint256 caQuotaInterestChange, QuotaStatusChange statusChange)
    {
        TokenQuotaParams storage q = totalQuotas[token];

        if (q.cumulativeIndexLU_RAY == 0) {
            revert TokenIsNotQuotedException();
        }

        AccountQuota storage quota = quotas[creditManager][creditAccount][token];
        int96 change;
        uint96 totalQuoted = q.totalQuoted;
        uint192 cumulativeIndexNow = _cumulativeIndexNow(q); // F: [CMQ-03]

        if (quota.quota > 1) {
            caQuotaInterestChange =
                _computeOutstandingQuotaInterest(quota.quota, cumulativeIndexNow, quota.cumulativeIndexLU); // F: [CMQ-03]
        }

        quota.cumulativeIndexLU = cumulativeIndexNow;

        if (quotaChange > 0) {
            uint96 limit = q.limit;
            if (totalQuoted > limit) {
                return (0, caQuotaInterestChange, QuotaStatusChange.NOT_CHANGED);
            }
            change = (totalQuoted + uint96(quotaChange) > limit)
                ? int96(limit - totalQuoted) // F: [CMQ-08,10]
                : quotaChange;
            q.totalQuoted = totalQuoted + uint96(change);

            if (quota.quota <= 1 && change > 0) {
                statusChange = QuotaStatusChange.ZERO_TO_POSITIVE; // F: [CMQ-03]
            }

            quota.quota += uint96(change);
        } else {
            change = quotaChange;
            q.totalQuoted = uint96(int96(totalQuoted) + change);

            if (quota.quota <= uint96(-change) + 1) {
                statusChange = QuotaStatusChange.POSITIVE_TO_ZERO; // F: [CMQ-03]
            }

            quota.quota -= uint96(-change); // F: [CMQ-03]
        }

        return (change * int16(q.rate), caQuotaInterestChange, statusChange); // F: [CMQ-03]
    }

    /// @dev Updates all quotas to zero when closing a credit account, and computes the final quota interest change
    /// @param creditAccount Address of the Credit Account being closed
    /// @param tokensLT Array of all active quoted tokens on the account
    function closeCreditAccount(address creditAccount, TokenLT[] memory tokensLT)
        external
        override
        creditManagerOnly
        returns (uint256 totalInterest)
    {
        int128 quotaRevenueChange;

        uint256 len = tokensLT.length;
        for (uint256 i; i < len;) {
            address token = tokensLT[i].token;

            (int128 qic, uint256 caqi) = _removeQuota(msg.sender, creditAccount, token); // F: [CMQ-06]

            quotaRevenueChange += qic; // F: [CMQ-06]
            totalInterest += caqi; // F: [CMQ-06]
            unchecked {
                ++i;
            }
        }

        /// TODO: check side effect of updating expectedLiquidity
        pool.changeQuotaRevenue(quotaRevenueChange);
    }

    /// @dev Internal function to zero the quota for a single quoted token
    function _removeQuota(address creditManager, address creditAccount, address token)
        internal
        returns (int128 quotaRevenueChange, uint256 caQuotaInterestChange)
    {
        AccountQuota storage quota = quotas[creditManager][creditAccount][token];
        uint96 quoted = quota.quota;

        if (quoted <= 1) return (0, 0);

        TokenQuotaParams storage tq = totalQuotas[token];
        uint192 cumulativeIndexNow = _cumulativeIndexNow(tq);

        caQuotaInterestChange = _computeOutstandingQuotaInterest(quoted, cumulativeIndexNow, quota.cumulativeIndexLU); // F: [CMQ-06]
        quota.cumulativeIndexLU = 0; // F: [CMQ-06]
        tq.totalQuoted -= quoted;
        quota.quota = 1; // F: [CMQ-06]

        return (-int128(uint128(quoted)) * int16(tq.rate), caQuotaInterestChange); // F: [CMQ-06]
    }

    /// @dev Computes the accrued quota interest and updates interest indexes
    /// @param creditAccount Address of the Credit Account to accrue interest for
    /// @param tokensLT Array of all active quoted tokens on the account
    function accrueQuotaInterest(address creditAccount, TokenLT[] memory tokensLT)
        external
        override
        creditManagerOnly
        returns (uint256 caQuotaInterestChange)
    {
        uint256 len = tokensLT.length;

        for (uint256 i; i < len;) {
            address token = tokensLT[i].token;
            AccountQuota storage q = quotas[msg.sender][creditAccount][token];

            uint96 quoted = q.quota;
            if (quoted > 1) {
                TokenQuotaParams storage tq = totalQuotas[token];
                uint192 cumulativeIndexNow = _cumulativeIndexNow(tq);
                caQuotaInterestChange +=
                    _computeOutstandingQuotaInterest(q.quota, cumulativeIndexNow, q.cumulativeIndexLU);
                q.cumulativeIndexLU = cumulativeIndexNow;
            }
            unchecked {
                ++i;
            }
        }
    }

    /// @dev Batch updates the quota rates and changes the combined quota revenue
    /// @param qUpdates Array of new rates for all quoted tokens
    function updateRates(QuotaRateUpdate[] memory qUpdates) external override gaugeOnly {
        uint256 len = qUpdates.length;

        if (len != quotaTokensSet.length()) {
            /// add needed tokens
        }

        uint256 deltaTimestamp_RAY = RAY * (block.timestamp - lastQuotaRateUpdate);
        uint128 quotaRevenue;
        for (uint256 i; i < len;) {
            address token = qUpdates[i].token;
            TokenQuotaParams storage tq = totalQuotas[token];
            uint16 rate = qUpdates[i].rate;

            tq.cumulativeIndexLU_RAY = uint192(
                (
                    uint256(tq.cumulativeIndexLU_RAY)
                        * (RAY + (rate * deltaTimestamp_RAY) / PERCENTAGE_FACTOR / SECONDS_PER_YEAR)
                ) / RAY
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

    /// @dev Registers a new quoted token in the keeper
    function addQuotaToken(address token) external gaugeOnly {
        TokenQuotaParams storage qp = totalQuotas[token];
        if (qp.cumulativeIndexLU_RAY != 0) {
            revert QuotedTokenIsAlreadyAdded();
        }

        quotaTokensSet.add(token);

        qp.cumulativeIndexLU_RAY = uint192(RAY);
        qp.rate = 0;
    }

    //
    // GETTERS
    //

    /// @dev Computes outstanding quota interest
    function outstandingQuotaInterest(address creditManager, address creditAccount, TokenLT[] memory tokensLT)
        external
        view
        override
        returns (uint256 caQuotaInterestChange)
    {
        uint256 len = tokensLT.length;

        for (uint256 i; i < len;) {
            address token = tokensLT[i].token;
            AccountQuota storage q = quotas[creditManager][creditAccount][token];

            uint96 quoted = q.quota;
            if (quoted > 1) {
                TokenQuotaParams storage tq = totalQuotas[token];
                uint192 cumulativeIndexNow = _cumulativeIndexNow(tq);
                caQuotaInterestChange +=
                    _computeOutstandingQuotaInterest(q.quota, cumulativeIndexNow, q.cumulativeIndexLU); // F: [CMQ-10]
            }
            unchecked {
                ++i;
            }
        }
    }

    /// @dev Internal function for outstanding quota interest computation
    function _computeOutstandingQuotaInterest(uint96 quoted, uint192 cumulativeIndexNow, uint192 cumulativeIndexLU)
        internal
        pure
        returns (uint256)
    {
        return (quoted * cumulativeIndexNow) / cumulativeIndexLU - quoted;
    }

    /// @dev Computes collateral value for quoted tokens on the account, as well as accrued quota interest
    function computeQuotedCollateralUSD(
        address creditManager,
        address creditAccount,
        address _priceOracle,
        TokenLT[] memory tokens
    ) external view override returns (uint256 value, uint256 totalQuotaInterest) {
        uint256 i;

        uint256 len = tokens.length;
        while (i < len && tokens[i].token != address(0)) {
            (uint256 currentUSD, uint256 outstandingInterest) =
                _getCollateralValue(creditManager, creditAccount, tokens[i].token, _priceOracle); // F: [CMQ-8]

            value += currentUSD * tokens[i].lt; // F: [CMQ-8]
            totalQuotaInterest += outstandingInterest; // F: [CMQ-8]

            unchecked {
                ++i;
            }
        }
    }

    /// @dev Gets the effective value (i.e., value in underlying included into TWV) for a quoted token on an account
    function _getCollateralValue(address creditManager, address creditAccount, address token, address _priceOracle)
        internal
        view
        returns (uint256 value, uint256 interest)
    {
        AccountQuota storage q = quotas[creditManager][creditAccount][token];

        if (q.quota > 1) {
            uint256 quotaValueUSD = IPriceOracleV2(_priceOracle).convertToUSD(q.quota, underlying); // F: [CMQ-8]
            uint256 balance = IERC20(token).balanceOf(creditAccount);
            if (balance > 1) {
                value = IPriceOracleV2(_priceOracle).convertToUSD(balance, token); // F: [CMQ-8]
                if (value > quotaValueUSD) value = quotaValueUSD; // F: [CMQ-8]
            }

            interest = _computeOutstandingQuotaInterest(q.quota, cumulativeIndex(token), q.cumulativeIndexLU); // F: [CMQ-8]
        }
    }

    /// @dev Returns cumulative index in RAY for a quoted token. Returns 0 for non-quoted tokens.
    function cumulativeIndex(address token) public view override returns (uint192) {
        return _cumulativeIndexNow(totalQuotas[token]);
    }

    function _cumulativeIndexNow(TokenQuotaParams storage tq) internal view returns (uint192) {
        return (
            tq.cumulativeIndexLU_RAY
                * uint192(
                    (
                        RAY
                            + (RAY_DIVIDED_BY_PERCENTAGE * (block.timestamp - lastQuotaRateUpdate) * tq.rate) / SECONDS_PER_YEAR
                    )
                )
        ) / uint192(RAY);
    }

    /// @dev Returns quota rate in PERCENTAGE FORMAT
    function getQuotaRate(address token) external view override returns (uint16) {
        return totalQuotas[token].rate;
    }

    /// @dev Returns an array of all quoted tokens
    function quotedTokens() external view override returns (address[] memory) {
        return quotaTokensSet.values();
    }

    /// @dev Returns whether a token is quoted
    function isQuotedToken(address token) external view override returns (bool) {
        return quotaTokensSet.contains(token);
    }

    /// @dev Returns quota parameters for a single (account, token) pair
    function getQuota(address creditManager, address creditAccount, address token)
        external
        view
        returns (AccountQuota memory)
    {
        return quotas[creditManager][creditAccount][token];
    }

    //
    // CONFIGURATION
    //

    /// @dev Sets a new gauge contract to compute quota rates
    /// @param newGauge The new contract's address
    function setGauge(address newGauge) external configuratorOnly {
        gauge = IGauge(newGauge);

        emit GaugeUpdated(newGauge);
    }

    /// @dev Adds a new Credit Manager to the set of allowed CM's
    /// @param creditManager Address of the new Credit Manager
    function addCreditManager(address creditManager) external configuratorOnly {
        creditManagerSet.add(creditManager);

        emit CreditManagerAdded(creditManager);
    }

    /// @dev Sets an upper limit on quotas for a token
    /// @param token Address of token to set the limit for
    /// @param limit The limit to set
    function setTokenLimit(address token, uint96 limit) external configuratorOnly {
        totalQuotas[token].limit = limit;

        emit TokenLimitSet(token, limit);
    }
}
