// SPDX-License-Identifier: UNLICENSED
// Gearbox Protocol. Generalized leverage for DeFi protocols
// (c) Gearbox Holdings, 2022
pragma solidity ^0.8.10;

import { Address } from "@openzeppelin/contracts/utils/Address.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { SafeERC20 } from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import { CreditManager, ClosureAction } from "../../../credit/CreditManager.sol";

/// @title Credit Manager Internal
/// @notice It encapsulates business logic for managing credit accounts
///
/// More info: https://dev.gearbox.fi/developers/credit/credit_manager
contract CreditManagerTestInternal is CreditManager {
    using SafeERC20 for IERC20;
    using Address for address payable;

    /// @dev Constructor
    /// @param _poolService Address of pool service
    constructor(address _poolService) CreditManager(_poolService) {}

    function setCumulativeDropAtFastCheck(address creditAccount, uint16 value)
        external
    {
        cumulativeDropAtFastCheckRAY[creditAccount] = value;
    }

    function calcNewCumulativeIndexPrincipalPreserving(
        uint256 borrowedAmount,
        uint256 delta,
        uint256 cumulativeIndexNow,
        uint256 cumulativeIndexOpen
    ) external pure returns (uint256 newCumulativeIndex) {
        newCumulativeIndex = _calcNewCumulativeIndexPrincipalPreserving(
            borrowedAmount,
            delta,
            cumulativeIndexNow,
            cumulativeIndexOpen
        );
    }

    function calcNewCumulativeIndexInterestPreserving(
        uint256 borrowedAmount,
        uint256 delta,
        uint256 cumulativeIndexNow,
        uint256 cumulativeIndexOpen,
        bool isIncrease
    ) external pure returns (uint256 newCumulativeIndex) {
        newCumulativeIndex = _calcNewCumulativeIndexInterestPreserving(
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
        uint256 borrowedAmountWithInterest,
        uint256 borrowedAmountWithInterestAndFees
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
                borrowedAmountWithInterest,
                borrowedAmountWithInterestAndFees
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

    function getMaxIndex(uint256 mask) external pure returns (uint256 index) {
        index = _getMaxIndex(mask);
    }

    function getSlotBytes(uint256 slotNum)
        external
        view
        returns (bytes32 slotVal)
    {
        assembly {
            slotVal := sload(slotNum)
        }
    }
}
