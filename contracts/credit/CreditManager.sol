// SPDX-License-Identifier: BUSL-1.1
// Gearbox Protocol. Generalized leverage for DeFi protocols
// (c) Gearbox Holdings, 2022
pragma solidity ^0.8.10;

// BASE CONTRACT

import { CreditManagerCommon } from "./CreditManagerCommon.sol";

// LIBRARIES
import { Address } from "@openzeppelin/contracts/utils/Address.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { SafeERC20 } from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import { SafeCast } from "@openzeppelin/contracts/utils/math/SafeCast.sol";

import { ACLTrait } from "../core/ACLTrait.sol";

// INTERFACES
import { IAccountFactory } from "../interfaces/IAccountFactory.sol";
import { ICreditAccount } from "../interfaces/ICreditAccount.sol";
import { IPoolService } from "../interfaces/IPoolService.sol";
import { IWETHGateway } from "../interfaces/IWETHGateway.sol";
import { ICreditManagerV2, ClosureAction } from "../interfaces/ICreditManagerV2.sol";
import { IAddressProvider } from "../interfaces/IAddressProvider.sol";
import { IPriceOracleV2 } from "../interfaces/IPriceOracle.sol";

// CONSTANTS
import { RAY } from "../libraries/Constants.sol";
import { PERCENTAGE_FACTOR } from "../libraries/PercentageMath.sol";
import { DEFAULT_FEE_INTEREST, DEFAULT_FEE_LIQUIDATION, DEFAULT_LIQUIDATION_PREMIUM, LEVERAGE_DECIMALS, ALLOWANCE_THRESHOLD, UNIVERSAL_CONTRACT } from "../libraries/Constants.sol";

uint256 constant ADDR_BIT_SIZE = 160;
uint256 constant INDEX_PRECISION = 10**9;

struct Slot1 {
    /// @dev Interest fee charged by the protocol: fee = interest accrued * feeInterest
    uint16 feeInterest;
    /// @dev Liquidation fee charged by the protocol: fee = totalValue * feeLiquidation
    uint16 feeLiquidation;
    /// @dev Multiplier used to compute the total value of funds during liquidation.
    /// At liquidation, the borrower's funds are discounted, and the pool is paid out of discounted value
    /// The liquidator takes the difference between the discounted and actual values as premium.
    uint16 liquidationDiscount;
    /// @dev Liquidation fee charged by the protocol during liquidation by expiry. Typically lower than feeLiquidation.
    uint16 feeLiquidationExpired;
    /// @dev Multiplier used to compute the total value of funds during liquidation by expiry. Typically higher than
    /// liquidationDiscount (meaning lower premium).
    uint16 liquidationDiscountExpired;
    /// @dev Price oracle used to evaluate assets on Credit Accounts.
    IPriceOracleV2 priceOracle;
    /// @dev Liquidation threshold for the underlying token.
    uint16 ltUnderlying;
}

/// @title Credit Manager
/// @notice Encapsulates the business logic for managing Credit Accounts
///
/// More info: https://dev.gearbox.fi/developers/credit/credit_manager
contract CreditManager is ICreditManagerV2, CreditManagerCommon {
    using SafeERC20 for IERC20;
    using Address for address payable;
    using SafeCast for uint256;

    /// @dev Map of token's bit mask to its address and LT compressed into a single uint256
    /// @notice Use collateralTokens(uint256 i) to get uncompressed values.
    mapping(uint256 => uint256) internal collateralTokensCompressed;

    /// @dev Bit mask encoding a set of forbidden tokens
    uint256 public override forbiddenTokenMask;

    constructor(address _pool) CreditManagerCommon(_pool) {}

    //
    // CREDIT ACCOUNT MANAGEMENT
    //

    function _beforeCloseCreditAccount(address creditAccount)
        internal
        override
    {}

    function _afterCloseCreditAccount(address creditAccount)
        internal
        override
    {}

    function _getIncreaseDebtResults(
        address,
        uint256 borrowedAmount,
        uint256 increaseAmount,
        uint256 cumulativeIndexNow,
        uint256 cumulativeIndexOpen
    )
        internal
        pure
        override
        returns (uint256 newBorrowedAmount, uint256 newCumulativeIndex)
    {
        newBorrowedAmount = borrowedAmount + increaseAmount;

        newCumulativeIndex = _calcNewCumulativeIndexInterestPreserving(
            borrowedAmount,
            increaseAmount,
            cumulativeIndexNow,
            cumulativeIndexOpen,
            true
        );
    }

    function _getDecreaseDebtResults(
        address,
        uint256 borrowedAmount,
        uint256 decreaseAmount,
        uint256 cumulativeIndexNow,
        uint256 cumulativeIndexOpen
    )
        internal
        view
        override
        returns (
            uint256 repaidAmount,
            uint256 profitAmount,
            uint256 newBorrowedAmount,
            uint256 newCumulativeIndex
        )
    {
        // Computes the interest accrued thus far
        uint256 interestAccrued = (borrowedAmount * cumulativeIndexNow) /
            cumulativeIndexOpen -
            borrowedAmount; // F:[CM-21]

        // Computes profit, taken as a percentage of the interest rate
        profitAmount =
            (interestAccrued * slot1.feeInterest) /
            PERCENTAGE_FACTOR; // F:[CM-21]

        if (decreaseAmount >= interestAccrued + profitAmount) {
            // If the amount covers all of the interest and fees, they are
            // paid first, and the remainder is used to pay the principal
            newBorrowedAmount =
                borrowedAmount +
                interestAccrued +
                profitAmount -
                decreaseAmount;

            repaidAmount = decreaseAmount - interestAccrued - profitAmount;

            // Since interest is fully repaid, the Credit Account's cumulativeIndexAtOpen
            // is set to the current cumulative index - which means interest starts accruing
            // on the new principal from zero
            newCumulativeIndex = IPoolService(pool).calcLinearCumulative_RAY(); // F:[CM-21]
        } else {
            // If the amount is not enough to cover interest and fees,
            // it is split between the two pro-rata. Since the fee is the percentage
            // of interest, this ensures that the new fee is consistent with the
            // new pending interest
            uint256 amountToInterest = (decreaseAmount * PERCENTAGE_FACTOR) /
                (PERCENTAGE_FACTOR + slot1.feeInterest);
            uint256 amountToFees = decreaseAmount - amountToInterest;

            // Since interest and fees are paid out first, the principal
            // remains unchanged
            newBorrowedAmount = borrowedAmount;

            repaidAmount = 0;
            profitAmount = amountToFees;

            newCumulativeIndex = _calcNewCumulativeIndexPrincipalPreserving(
                borrowedAmount,
                amountToInterest,
                cumulativeIndexNow,
                cumulativeIndexOpen
            );
        }
    }

    //
    // COLLATERAL VALIDITY AND ACCOUNT HEALTH CHECKS
    //

    function _checkToken(
        address,
        address,
        uint256 tokenMask
    ) internal view override {
        if (tokenMask == 0 || forbiddenTokenMask & tokenMask != 0)
            revert TokenNotAllowedException();
    }

    function _afterEnableToken(
        address creditAccount,
        address token,
        uint256 tokenMask
    ) internal override {}

    function _getEffectiveValueChanges(
        address tokenIn,
        address tokenOut,
        uint256 balanceInBefore,
        uint256 balanceOutBefore,
        uint256 balanceInAfter,
        uint256 balanceOutAfter
    )
        internal
        view
        override
        returns (uint256 amountInCollateral, uint256 amountOutCollateral)
    {
        (amountInCollateral, amountOutCollateral) = slot1.priceOracle.fastCheck(
            balanceInBefore - balanceInAfter,
            tokenIn,
            balanceOutAfter - balanceOutBefore,
            tokenOut
        ); // F:[CM-34]
    }

    function _afterFastCollateralCheck(address creditAccount)
        internal
        override
    {
        _checkAndOptimizeEnabledTokens(creditAccount);
    }

    function _afterFullCollateralCheck(address creditAccount)
        internal
        override
    {}

    function _getValueInUnderlying(
        address token,
        IPriceOracleV2 _priceOracle,
        uint256 balance
    ) internal view override returns (uint256 value) {
        value = _priceOracle.convertToUSD(balance, token);
    }

    function _additionalTokenChecksAndEffects(address creditAccount)
        internal
        override
    {}

    function _afterDisableToken(
        address creditAccount,
        address token,
        uint256 tokenMask
    ) internal override {}

    //
    // GETTERS
    //

    function _getBaseTokenData(uint256 tokenMask)
        internal
        view
        override
        returns (address token, uint16 liquidationThreshold)
    {
        // The underlying is a special case and its mask is always 1
        if (tokenMask == 1) {
            token = underlying; // F:[CM-47]
            liquidationThreshold = slot1.ltUnderlying;
        } else {
            // The address and LT of a collateral token are compressed into a single uint256
            // The first 160 bits of the number is the address, and any bits after that are interpreted as LT
            uint256 collateralTokenCompressed = collateralTokensCompressed[
                tokenMask
            ]; // F:[CM-47]

            // Unsafe downcasting is justified, since the right 160 bits of collateralTokenCompressed
            // always stores the uint160 encoded address and the extra bits need to be cut
            token = address(uint160(collateralTokenCompressed)); // F:[CM-47]
            liquidationThreshold = (collateralTokenCompressed >> ADDR_BIT_SIZE)
                .toUint16(); // F:[CM-47]
        }
    }

    function _calcCreditAccountAccruedInterestInternal(address creditAccount)
        internal
        view
        override
        returns (
            uint256 borrowedAmount,
            uint256 borrowedAmountWithInterest,
            uint256 borrowedAmountWithInterestAndFees
        )
    {
        uint256 cumulativeIndexAtOpen_RAY;
        uint256 cumulativeIndexNow_RAY;
        (
            borrowedAmount,
            cumulativeIndexAtOpen_RAY,
            cumulativeIndexNow_RAY
        ) = _getCreditAccountParameters(creditAccount); // F:[CM-49]

        // Interest is never stored and is always computed dynamically
        // as the difference between the current cumulative index of the pool
        // and the cumulative index recorded in the Credit Account
        borrowedAmountWithInterest =
            (borrowedAmount * cumulativeIndexNow_RAY) /
            cumulativeIndexAtOpen_RAY; // F:[CM-49]

        // Fees are computed as a percentage of interest
        borrowedAmountWithInterestAndFees =
            borrowedAmountWithInterest +
            ((borrowedAmountWithInterest - borrowedAmount) *
                slot1.feeInterest) /
            PERCENTAGE_FACTOR; // F: [CM-49]
    }

    //
    // CONFIGURATION
    //

    function _setBaseTokenData(
        uint256 tokenMask,
        address token,
        uint16 liquidationThreshold
    ) internal override {
        // Token address and liquidation threshold are encoded into a single uint256
        collateralTokensCompressed[tokenMask] =
            uint256(uint160(token)) |
            (uint256(liquidationThreshold) << 160);
    }

    function setForbidMask(uint256 newForbiddenMask)
        external
        creditConfiguratorOnly
    {
        forbiddenTokenMask = newForbiddenMask;
    }
}
