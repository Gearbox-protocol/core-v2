// SPDX-License-Identifier: MIT
// Gearbox Protocol. Generalized leverage for DeFi protocols
// (c) Gearbox Holdings, 2022
pragma solidity ^0.8.17;

import {MultiCall} from "../libraries/MultiCall.sol";
import {Balance, BalanceOps} from "../libraries/Balances.sol";
import {QuotaUpdate} from "../interfaces/IPoolQuotaKeeper.sol";
import {ICreditFacade, ICreditFacadeExtended} from "../interfaces/ICreditFacade.sol";

interface CreditFacadeMulticaller {}

library CreditFacadeCalls {
    function revertIfReceivedLessThan(CreditFacadeMulticaller creditFacade, Balance[] memory expectedBalances)
        internal
        pure
        returns (MultiCall memory)
    {
        return MultiCall({
            target: address(creditFacade),
            callData: abi.encodeCall(ICreditFacadeExtended.revertIfReceivedLessThan, (expectedBalances))
        });
    }

    function addCollateral(CreditFacadeMulticaller creditFacade, address borrower, address token, uint256 amount)
        internal
        pure
        returns (MultiCall memory)
    {
        return MultiCall({
            target: address(creditFacade),
            callData: abi.encodeCall(ICreditFacade.addCollateral, (borrower, token, amount))
        });
    }

    function increaseDebt(CreditFacadeMulticaller creditFacade, uint256 amount)
        internal
        pure
        returns (MultiCall memory)
    {
        return MultiCall({
            target: address(creditFacade),
            callData: abi.encodeCall(ICreditFacadeExtended.increaseDebt, (amount))
        });
    }

    function decreaseDebt(CreditFacadeMulticaller creditFacade, uint256 amount)
        internal
        pure
        returns (MultiCall memory)
    {
        return MultiCall({
            target: address(creditFacade),
            callData: abi.encodeCall(ICreditFacadeExtended.decreaseDebt, (amount))
        });
    }

    function enableToken(CreditFacadeMulticaller creditFacade, address token)
        internal
        pure
        returns (MultiCall memory)
    {
        return MultiCall({
            target: address(creditFacade),
            callData: abi.encodeCall(ICreditFacadeExtended.enableToken, (token))
        });
    }

    function disableToken(CreditFacadeMulticaller creditFacade, address token)
        internal
        pure
        returns (MultiCall memory)
    {
        return MultiCall({
            target: address(creditFacade),
            callData: abi.encodeCall(ICreditFacadeExtended.disableToken, (token))
        });
    }

    function updateQuotas(CreditFacadeMulticaller creditFacade, QuotaUpdate[] memory quotaUpdates)
        internal
        pure
        returns (MultiCall memory)
    {
        return MultiCall({
            target: address(creditFacade),
            callData: abi.encodeCall(ICreditFacadeExtended.updateQuotas, quotaUpdates)
        });
    }

    function setFullCheckParams(
        CreditFacadeMulticaller creditFacade,
        uint256[] memory collateralHints,
        uint16 minHealthFactor
    ) internal pure returns (MultiCall memory) {
        return MultiCall({
            target: address(creditFacade),
            callData: abi.encodeCall(ICreditFacadeExtended.setFullCheckParams, (collateralHints, minHealthFactor))
        });
    }
}
