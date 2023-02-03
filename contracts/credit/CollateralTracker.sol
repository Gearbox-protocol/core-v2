// SPDX-License-Identifier: BUSL-1.1
// Gearbox Protocol. Generalized leverage for DeFi protocols
// (c) Gearbox Holdings, 2022
pragma solidity ^0.8.10;

// CONTRACTS
import { ACLTrait } from "../core/ACLTrait.sol";
import { AddressProvider } from "../core/AddressProvider.sol";

// INTERFACES
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { ICollateralTracker, CollateralSetting } from "../interfaces/ICollateralTracker.sol";
import { ICreditAccount } from "../interfaces/ICreditAccount.sol";
import { IContractsRegister } from "../interfaces/IContractsRegister.sol";
import { CallerNotCreditManagerException } from "../interfaces/IErrors.sol";

uint256 constant MAX_INT = type(uint256).max;

contract CollateralTracker is ICollateralTracker, ACLTrait {
    IContractsRegister immutable contractsRegister;

    /// @dev Mapping holding collateral amounts for each creditAccount and token
    ///      The key is computed as keccak(creditAccount, creditAccount.since)
    ///      to initialize newly opened accounts with zeroed collateral amounts
    mapping(bytes32 => mapping(address => uint256)) collateralAmounts;

    /// @dev Mapping holding collateral totals for each token in the system
    mapping(address => uint256) collateralTotals;

    /// @dev Mapping holding collateral limits for each token in the system
    mapping(address => uint256) collateralLimits;

    constructor(address addressProvider) ACLTrait(addressProvider) {
        contractsRegister = IContractsRegister(
            AddressProvider(addressProvider).getContractsRegister()
        );
    }

    modifier creditManagerOnly() {
        if (!contractsRegister.isCreditManager(msg.sender)) {
            revert CallerNotCreditManagerException();
        }
        _;
    }

    function setCollateralLimit(address token, uint256 limit)
        external
        configuratorOnly
    {
        collateralLimits[token] = limit;
    }

    function _collateralize(
        bytes32 key,
        address token,
        uint256 amount
    ) internal {
        uint256 prevCollateral = collateralAmounts[key][token];

        if (amount == prevCollateral) return;

        collateralAmounts[key][token] = amount;

        if (amount > prevCollateral) {
            collateralTotals[token] += amount - prevCollateral;
            if (collateralTotals[token] > collateralLimits[token]) {
                revert LimitViolatedException();
            }
        } else {
            collateralTotals[token] -= prevCollateral - amount;
        }
    }

    function collateralize(
        address creditAccount,
        address token,
        uint256 amount
    ) external creditManagerOnly {
        bytes32 key = keccak256(
            abi.encode(creditAccount, ICreditAccount(creditAccount).since())
        );

        _collateralize(key, token, amount);
    }

    function collateralizeAll(address creditAccount, address token)
        external
        creditManagerOnly
    {
        bytes32 key = keccak256(
            abi.encode(creditAccount, ICreditAccount(creditAccount).since())
        );
        uint256 balance = IERC20(token).balanceOf(creditAccount);

        _collateralize(key, token, balance);
    }

    function decollateralizeAll(address creditAccount, address token)
        external
        creditManagerOnly
    {
        bytes32 key = keccak256(
            abi.encode(creditAccount, ICreditAccount(creditAccount).since())
        );

        _decollateralizeAll(key, token);
    }

    function _decollateralizeAll(bytes32 key, address token) internal {
        uint256 prevCollateral = collateralAmounts[key][token];
        collateralAmounts[key][token] = 0;
        collateralTotals[token] -= prevCollateral;
    }

    function batchCollateralize(
        address creditAccount,
        CollateralSetting[] memory settings
    ) external creditManagerOnly {
        bytes32 key = keccak256(
            abi.encode(creditAccount, ICreditAccount(creditAccount).since())
        );

        uint256 len = settings.length;

        for (uint256 i = 0; i < len; ) {
            if (settings[i].amount == MAX_INT) {
                uint256 balance = IERC20(settings[i].token).balanceOf(
                    creditAccount
                );

                _collateralize(key, settings[i].token, balance);
            } else if (settings[i].amount == 0) {
                _decollateralizeAll(key, settings[i].token);
            } else {
                _collateralize(key, settings[i].token, settings[i].amount);
            }

            unchecked {
                ++i;
            }
        }
    }
}
