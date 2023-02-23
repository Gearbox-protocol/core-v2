// SPDX-License-Identifier: UNLICENSED
// Gearbox Protocol. Generalized leverage for DeFi protocols
// (c) Gearbox Holdings, 2022
pragma solidity ^0.8.10;

import { Address } from "@openzeppelin/contracts/utils/Address.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { SafeERC20 } from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import { CreditManager, ClosureAction } from "../../../credit/CreditManager.sol";
import { IPriceOracleV2 } from "../../../interfaces/IPriceOracle.sol";
import { IPoolQuotaKeeper, QuotaUpdate, TokenLT, QuotaStatusChange } from "../../../interfaces/IPoolQuotaKeeper.sol";
import { CollateralTokenData } from "../../../interfaces/ICreditManagerV2.sol";

/// @title Credit Manager Internal
/// @notice It encapsulates business logic for managing credit accounts
///
/// More info: https://dev.gearbox.fi/developers/credit/credit_manager
contract CreditManagerTestInternal is CreditManager {
    using SafeERC20 for IERC20;
    using Address for address payable;

    address[] public fullCheckOrder;

    /// @dev Constructor
    /// @param _poolService Address of pool service
    constructor(address _poolService) CreditManager(_poolService) {}

    function setCumulativeDropAtFastCheck(address creditAccount, uint16 value)
        external
    {
        // cumulativeDropAtFastCheckRAY[creditAccount] = value;
    }

    function calcNewCumulativeIndex(
        uint256 borrowedAmount,
        uint256 delta,
        uint256 cumulativeIndexNow,
        uint256 cumulativeIndexOpen,
        bool isIncrease
    ) external pure returns (uint256 newCumulativeIndex) {
        newCumulativeIndex = _calcNewCumulativeIndex(
            borrowedAmount,
            delta,
            cumulativeIndexNow,
            cumulativeIndexOpen,
            isIncrease
        );
    }

    function calcClosePaymentsPure(
        uint256 totalValue,
        ClosureAction closureActionType,
        uint256 borrowedAmount,
        uint256 borrowedAmountWithInterest
    )
        external
        view
        returns (
            uint256 amountToPool,
            uint256 remainingFunds,
            uint256 profit,
            uint256 loss
        )
    {
        return
            calcClosePayments(
                totalValue,
                closureActionType,
                borrowedAmount,
                borrowedAmountWithInterest
            );
    }

    function transferAssetsTo(
        address creditAccount,
        address to,
        bool convertWETH,
        uint256 enabledTokenMask
    ) external {
        _transferAssetsTo(creditAccount, to, convertWETH, enabledTokenMask);
    }

    function safeTokenTransfer(
        address creditAccount,
        address token,
        address to,
        uint256 amount,
        bool convertToETH
    ) external {
        _safeTokenTransfer(creditAccount, token, to, amount, convertToETH);
    }

    // function disableToken(address creditAccount, address token) external override {
    //     _disableToken(creditAccount, token);
    // }

    function getCreditAccountParameters(address creditAccount)
        external
        view
        returns (
            uint256 borrowedAmount,
            uint256 cumulativeIndexAtOpen,
            uint256 cumulativeIndexNow
        )
    {
        return _getCreditAccountParameters(creditAccount);
    }

    function collateralTokensInternal()
        external
        view
        returns (address[] memory collateralTokensAddr)
    {
        uint256 len = collateralTokensCount;
        collateralTokensAddr = new address[](len);
        for (uint256 i = 0; i < len; i++) {
            (collateralTokensAddr[i], ) = collateralTokens(i);
        }
    }

    function collateralTokensDataExt(uint256 tokenMask)
        external
        view
        returns (CollateralTokenData memory)
    {
        return collateralTokensData[tokenMask];
    }

    // function getMaxIndex(uint256 mask) external pure returns (uint256 index) {
    //     index = _getMaxIndex(mask);
    // }

    function getSlotBytes(uint256 slotNum)
        external
        view
        returns (bytes32 slotVal)
    {
        assembly {
            slotVal := sload(slotNum)
        }
    }

    /// @dev IMPLEMENTATION: fullCollateralCheck
    function _fullCollateralCheck(
        address creditAccount,
        uint256[] memory collateralHints,
        uint16 minHealthFactor
    ) internal override {
        IPriceOracleV2 _priceOracle = slot1.priceOracle;

        uint256 enabledTokenMask = enabledTokensMap[creditAccount];
        uint256 checkedTokenMask = enabledTokenMask;
        uint256 borrowAmountPlusInterestRateUSD;

        uint256 twvUSD;

        {
            uint256 quotaInterest;
            if (supportsQuotas) {
                TokenLT[] memory tokens = getLimitedTokens(creditAccount);

                if (tokens.length > 0) {
                    /// If credit account has any connected token - then check that
                    (twvUSD, quotaInterest) = poolQuotaKeeper()
                        .computeQuotedCollateralUSD(
                            address(this),
                            creditAccount,
                            address(_priceOracle),
                            tokens
                        );

                    checkedTokenMask = checkedTokenMask & (~limitedTokenMask);
                }

                quotaInterest += cumulativeQuotaInterest[creditAccount];
            }

            // The total weighted value of a Credit Account has to be compared
            // with the entire debt sum, including interest and fees
            (
                ,
                ,
                uint256 borrowedAmountWithInterestAndFees
            ) = _calcCreditAccountAccruedInterest(creditAccount, quotaInterest);

            borrowAmountPlusInterestRateUSD = _priceOracle.convertToUSD(
                borrowedAmountWithInterestAndFees * minHealthFactor,
                underlying
            );

            // If quoted tokens fully cover the debt, we can stop here
            // after performing some additional cleanup
            if (twvUSD >= borrowAmountPlusInterestRateUSD) {
                _afterFullCheck(creditAccount, enabledTokenMask, false);

                return;
            }
        }

        _checkNonLimitedTokensAndSaveOrder(
            creditAccount,
            enabledTokenMask,
            checkedTokenMask,
            twvUSD,
            borrowAmountPlusInterestRateUSD,
            collateralHints,
            _priceOracle
        );
    }

    function _checkNonLimitedTokensAndSaveOrder(
        address creditAccount,
        uint256 enabledTokenMask,
        uint256 checkedTokenMask,
        uint256 twvUSD,
        uint256 borrowAmountPlusInterestRateUSD,
        uint256[] memory collateralHints,
        IPriceOracleV2 _priceOracle
    ) internal {
        fullCheckOrder = new address[](0);

        uint256 tokenMask;
        bool atLeastOneTokenWasDisabled;

        uint256 len = collateralHints.length;
        uint256 i;

        // TODO: add test that we check all values and it's always reachable
        while (checkedTokenMask != 0) {
            unchecked {
                tokenMask = (i < len) ? collateralHints[i] : 1 << (i - len);
            }

            // CASE enabledTokenMask & tokenMask == 0 F:[CM-38]
            if (checkedTokenMask & tokenMask != 0) {
                (
                    address token,
                    uint16 liquidationThreshold
                ) = collateralTokensByMask(tokenMask);

                fullCheckOrder.push(token);

                uint256 balance = IERC20(token).balanceOf(creditAccount);

                // Collateral calculations are only done if there is a non-zero balance
                if (balance > 1) {
                    twvUSD +=
                        _priceOracle.convertToUSD(balance, token) *
                        liquidationThreshold;

                    // Full collateral check evaluates a Credit Account's health factor lazily;
                    // Once the TWV computed thus far exceeds the debt, the check is considered
                    // successful, and the function returns without evaluating any further collateral
                    if (twvUSD >= borrowAmountPlusInterestRateUSD) {
                        // The _afterFullCheck hook does some cleanup, such as disabling
                        // zero-balance tokens
                        _afterFullCheck(
                            creditAccount,
                            enabledTokenMask,
                            atLeastOneTokenWasDisabled
                        );

                        return; // F:[CM-40]
                    }
                    // Zero-balance tokens are disabled; this is done by flipping the
                    // bit in enabledTokenMask, which is then written into storage at the
                    // very end, to avoid redundant storage writes
                } else {
                    enabledTokenMask &= ~tokenMask; // F:[CM-39]
                    atLeastOneTokenWasDisabled = true; // F:[CM-39]
                }
            }

            checkedTokenMask = checkedTokenMask & (~tokenMask);
            unchecked {
                ++i;
            }
        }
        revert NotEnoughCollateralException();
    }
}
