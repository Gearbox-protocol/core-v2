// SPDX-License-Identifier: MIT
// Gearbox Protocol. Generalized leverage for DeFi protocols
// (c) Gearbox Holdings, 2022
pragma solidity ^0.8.10;

/// @title Errors library
library Errors {
    //
    // COMMON
    //
    string public constant ZERO_ADDRESS_IS_NOT_ALLOWED = "Z0";
    string public constant NOT_IMPLEMENTED = "NI";
    string public constant REGISTERED_CREDIT_ACCOUNT_MANAGERS_ONLY = "CP";
    string public constant REGISTERED_POOLS_ONLY = "RP";

    //
    // POOL
    //
    string public constant POOL_CONNECTED_CREDIT_MANAGERS_ONLY = "PS0";
    string public constant POOL_INCOMPATIBLE_CREDIT_ACCOUNT_MANAGER = "PS1";
    string public constant POOL_MORE_THAN_EXPECTED_LIQUIDITY_LIMIT = "PS2";
    string public constant POOL_INCORRECT_WITHDRAW_FEE = "PS3";
    string public constant POOL_CANT_ADD_CREDIT_MANAGER_TWICE = "PS4";

    //
    // ACCOUNT FACTORY
    //
    string public constant AF_CANT_CLOSE_CREDIT_ACCOUNT_IN_THE_SAME_BLOCK = "AF1";
    string public constant AF_MINING_IS_FINISHED = "AF2";
    string public constant AF_CREDIT_ACCOUNT_NOT_IN_STOCK = "AF3";
    string public constant AF_EXTERNAL_ACCOUNTS_ARE_FORBIDDEN = "AF4";

    //
    // ADDRESS PROVIDER
    //
    string public constant AS_ADDRESS_NOT_FOUND = "AP1";

    //
    // CONTRACTS REGISTER
    //
    string public constant CR_POOL_ALREADY_ADDED = "CR1";
    string public constant CR_CREDIT_MANAGER_ALREADY_ADDED = "CR2";

    //
    // CREDIT ACCOUNT
    //
    string public constant CA_CONNECTED_CREDIT_MANAGER_ONLY = "CA1";
    string public constant CA_FACTORY_ONLY = "CA2";

    //
    // ACL
    //
    string public constant ACL_CALLER_NOT_PAUSABLE_ADMIN = "ACL1";
    string public constant ACL_CALLER_NOT_CONFIGURATOR = "ACL2";
}
