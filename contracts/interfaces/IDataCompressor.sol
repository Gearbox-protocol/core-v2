// SPDX-License-Identifier: MIT
// Gearbox Protocol. Generalized leverage for DeFi protocols
// (c) Gearbox Holdings, 2022
pragma solidity ^0.8.10;

import { CreditAccountData, CreditManagerData, PoolData, TokenInfo } from "../libraries/Types.sol";
import { IVersion } from "./IVersion.sol";

interface IDataCompressorExceptions {
    /// @dev Thrown if attempting to get data on a contract that is not a registered
    ///      Credit Manager
    error NotCreditManagerException();

    /// @dev Thrown if attempting the get data on a contract that is not a registered
    ///      pool
    error NotPoolException();
}

interface IDataCompressor is IDataCompressorExceptions, IVersion {
    /// @dev Returns CreditAccountData for all opened accounts for particular borrower
    /// @param borrower Borrower address
    function getCreditAccountList(address borrower)
        external
        view
        returns (CreditAccountData[] memory);

    /// @dev Returns whether the borrower has an open credit account with the credit manager
    /// @param creditManager Credit manager to check
    /// @param borrower Borrower to check
    function hasOpenedCreditAccount(address creditManager, address borrower)
        external
        view
        returns (bool);

    /// @dev Returns CreditAccountData for a particular Credit Account account, based on creditManager and borrower
    /// @param _creditManager Credit manager address
    /// @param borrower Borrower address
    function getCreditAccountData(address _creditManager, address borrower)
        external
        view
        returns (CreditAccountData memory);

    /// @dev Returns CreditManagerData for all Credit Managers
    function getCreditManagersList()
        external
        view
        returns (CreditManagerData[] memory);

    /// @dev Returns CreditManagerData for a particular _creditManager
    /// @param _creditManager CreditManager address
    function getCreditManagerData(address _creditManager)
        external
        view
        returns (CreditManagerData memory);

    /// @dev Returns PoolData for a particular pool
    /// @param _pool Pool address
    function getPoolData(address _pool) external view returns (PoolData memory);

    /// @dev Returns PoolData for all registered pools
    function getPoolsList() external view returns (PoolData[] memory);

    /// @dev Returns the adapter address for a particular creditManager and targetContract
    function getAdapter(address _creditManager, address _allowedContract)
        external
        view
        returns (address adapter);
}
