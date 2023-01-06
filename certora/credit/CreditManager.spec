
function ZERO_ADDRESS() returns address {
    return 0x0000000000000000000000000000000000000000;
}

function collateralTokensByMaskPartial(env e, uint256 mask) returns address {
    address token;
    uint16 lt;
    token, lt = collateralTokensByMask(e, mask);
    return token;
}


invariant tokenMasksMapIsExactInverseOfCollateralTokensByMask(env e, uint256 mask, address token)
    tokenMasksMap(e, token) == mask <=> collateralTokensByMaskPartial(e, mask) == token

invariant adapterToContractIsInverseOfContractToAdapterForNonZeroValues(env e, address adapter)
    adapterToContract(e, adapter) != ZERO_ADDRESS() => contractToAdapter(e, adapterToContract(e, adapter)) == adapter

invariant contractToAdapterIsInverseOfAdapterToContract(env e, address contract)
    contractToAdapter(e, contract) != ZERO_ADDRESS() => adapterToContract(e, contractToAdapter(e, contract)) == contract

invariant tokenMasksMapIsInverseOfCollateralTokensByMaskForNonZeroValues(env e, address token)
    tokenMasksMap(e, token) != 0 => collateralTokensByMaskPartial(e, tokenMasksMap(e, token)) == token
    {
        preserved addToken(address addedToken) with (env e2) {
            require addedToken != underlying(e2);
        }
        preserved {
            requireInvariant collateralTokensWithIdMoreThanCollateralTokenCountMustBeZero(e, tokenMasksMap(e, token));
        }
    }

invariant collateralTokensByMaskIsInverseOfTokenMasksMap(env e, uint256 mask)
    collateralTokensByMaskPartial(e, mask) != ZERO_ADDRESS() => tokenMasksMap(e, collateralTokensByMaskPartial(e, mask)) == mask
    {
        preserved {
            requireInvariant collateralTokensWithIdMoreThanCollateralTokenCountMustBeZero(e, mask);
        }
    }

invariant collateralTokensWithIdMoreThanCollateralTokenCountMustBeZero(env e, uint256 mask)
    mask > 1 << (collateralTokensCount(e) - 1) => collateralTokensByMaskPartial(e, mask) == ZERO_ADDRESS()


rule onlyConfiguratorChangesParameters(env e, method f) 
filtered {
    f -> !f.isView && !f.isPure
}
{

    uint8 maxAllowedEnabledTokenLength = maxAllowedEnabledTokenLength(e);
    address creditFacade = creditFacade(e);
    address creditConfigurator = creditConfigurator(e);
    address priceOracle = priceOracle(e);
    uint256 collateralTokensCount = collateralTokensCount(e);
    uint256 forbiddenTokenMask = forbiddenTokenMask(e);

    calldataarg d;

    f(e, d);

    uint8 maxAllowedEnabledTokenLength_ = maxAllowedEnabledTokenLength(e);
    address creditFacade_ = creditFacade(e);
    address creditConfigurator_ = creditConfigurator(e);
    address priceOracle_ = priceOracle(e);
    uint256 collateralTokensCount_ = collateralTokensCount(e);
    uint256 forbiddenTokenMask_ = forbiddenTokenMask(e);

    assert maxAllowedEnabledTokenLength != maxAllowedEnabledTokenLength_ 
          || creditFacade != creditFacade_ 
          || creditConfigurator != creditConfigurator_ 
          || collateralTokensCount != collateralTokensCount_
          || priceOracle != priceOracle_
          || forbiddenTokenMask != forbiddenTokenMask_
          => e.msg.sender == creditConfigurator;

}

rule onlyConfiguratorAddsTokensWithAddToken(env e, method f)
filtered {
    f -> !f.isView && !f.isPure
}
{
    uint256 collateralTokensCount = collateralTokensCount(e);
    address creditConfigurator = creditConfigurator(e);

    address token;
    uint16 lt;

    token, lt = collateralTokens(e, collateralTokensCount);

    require token == ZERO_ADDRESS();

    calldataarg d;

    f(e,d);

    address token_;
    uint16 lt_;

    token_, lt_ = collateralTokens(e, collateralTokensCount);

    assert token_ != ZERO_ADDRESS()
           => e.msg.sender == creditConfigurator 
           && f.selector == addToken(address).selector 
           && lt_ == 0;
}

rule onlyConfiguratorChangesLiquidationThresholdWithSetLiquidationThreshold(env e, method f)
filtered {
    f -> !f.isView && !f.isPure
}
{
    uint256 tokenId;
    address token;
    uint16 lt;
    token, lt = collateralTokens(e, tokenId);

    require token != ZERO_ADDRESS();
    requireInvariant collateralTokensWithIdMoreThanCollateralTokenCountMustBeZero(e, tokenId);
    requireInvariant tokenMasksMapIsInverseOfCollateralTokensByMaskForNonZeroValues(e, token);
    require tokenMasksMap(e, token) == 1 << tokenId;

    address creditConfigurator = creditConfigurator(e);

    calldataarg d;
    f(e,d);

    assert liquidationThresholds(e, token) != lt
           => e.msg.sender == creditConfigurator 
           && f.selector == setLiquidationThreshold(address,uint16).selector;

}