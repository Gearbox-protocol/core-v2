// SPDX-License-Identifier: GPL-2.0-or-later
// Gearbox Protocol. Generalized leverage for DeFi protocols
// (c) Gearbox Holdings, 2022
pragma solidity ^0.8.10;

/// @title DataType library

struct Exchange {
    address[] path;
    uint256 amountOutMin;
}

struct TokenBalance {
    address token;
    uint256 balance;
    bool isAllowed;
    bool isEnabled;
}

struct ContractAdapter {
    address allowedContract;
    address adapter;
}

struct CreditAccountData {
    address addr;
    address borrower;
    bool inUse;
    address creditManager;
    address underlying;
    uint256 borrowedAmountPlusInterest;
    uint256 borrowedAmountPlusInterestAndFees;
    uint256 totalValue;
    uint256 healthFactor;
    uint256 borrowRate;
    TokenBalance[] balances;
    uint256 repayAmount; // for v1 accounts only
    uint256 liquidationAmount; // for v1 accounts only
    bool canBeClosed; // for v1 accounts only
    uint256 borrowedAmount;
    uint256 cumulativeIndexAtOpen;
    uint256 since;
    uint8 version;
    uint256 enabledTokenMask;
}

struct CreditManagerData {
    address addr;
    address underlying;
    address pool;
    bool isWETH;
    bool canBorrow;
    uint256 borrowRate;
    uint256 minAmount;
    uint256 maxAmount;
    uint256 maxLeverageFactor; // for V1 only
    uint256 availableLiquidity;
    address[] collateralTokens;
    ContractAdapter[] adapters;
    uint256[] liquidationThresholds;
    uint8 version;
    address creditFacade; // V2 only: address of creditFacade
    address creditConfigurator; // V2 only: address of creditConfigurator
    bool isDegenMode; // V2 only: true if contract is in Degen mode
    address degenNFT; // V2 only: degenNFT, address(0) if not in degen mode
    bool isIncreaseDebtForbidden; // V2 only: true if increasing debt is forbidden
    uint256 forbiddenTokenMask; // V2 only: mask which forbids some particular tokens
    uint8 maxEnabledTokensLength; // V2 only: in V1 as many tokens as the CM can support (256)
    uint16 feeInterest; // Interest fee protocol charges: fee = interest accrues * feeInterest
    uint16 feeLiquidation; // Liquidation fee protocol charges: fee = totalValue * feeLiquidation
    uint16 liquidationDiscount; // Miltiplier to get amount which liquidator should pay: amount = totalValue * liquidationDiscount
    uint16 feeLiquidationExpired; // Liquidation fee protocol charges on expired accounts
    uint16 liquidationDiscountExpired; // Multiplier for the amount the liquidator has to pay when closing an expired account
}

struct PoolData {
    address addr;
    bool isWETH;
    address underlying;
    address dieselToken;
    uint256 linearCumulativeIndex;
    uint256 availableLiquidity;
    uint256 expectedLiquidity;
    uint256 expectedLiquidityLimit;
    uint256 totalBorrowed;
    uint256 depositAPY_RAY;
    uint256 borrowAPY_RAY;
    uint256 dieselRate_RAY;
    uint256 withdrawFee;
    uint256 cumulativeIndex_RAY;
    uint256 timestampLU;
    uint8 version;
}

struct TokenInfo {
    address addr;
    string symbol;
    uint8 decimals;
}

struct AddressProviderData {
    address contractRegister;
    address acl;
    address priceOracle;
    address traderAccountFactory;
    address dataCompressor;
    address farmingFactory;
    address accountMiner;
    address treasuryContract;
    address gearToken;
    address wethToken;
    address wethGateway;
}

struct MiningApproval {
    address token;
    address swapContract;
}
