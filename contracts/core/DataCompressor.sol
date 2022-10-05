// SPDX-License-Identifier: BUSL-1.1
// Gearbox Protocol. Generalized leverage for DeFi protocols
// (c) Gearbox Holdings, 2021
pragma solidity ^0.8.10;
pragma experimental ABIEncoderV2;

import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { PercentageMath, PERCENTAGE_FACTOR } from "../libraries/PercentageMath.sol";

import { IDataCompressor } from "../interfaces/IDataCompressor.sol";
import { ICreditManager } from "../interfaces/V1/ICreditManager.sol";
import { ICreditManagerV2 } from "../interfaces/ICreditManagerV2.sol";
import { ICreditFacade } from "../interfaces/ICreditFacade.sol";
import { ICreditFilter } from "../interfaces/V1/ICreditFilter.sol";
import { ICreditConfigurator } from "../interfaces/ICreditConfigurator.sol";
import { ICreditAccount } from "../interfaces/ICreditAccount.sol";
import { IPoolService } from "../interfaces/IPoolService.sol";

import { IVersion } from "../interfaces/IVersion.sol";

import { AddressProvider } from "./AddressProvider.sol";
import { ContractsRegister } from "./ContractsRegister.sol";

import { CreditAccountData, CreditManagerData, PoolData, TokenInfo, TokenBalance, ContractAdapter } from "../libraries/Types.sol";

// EXCEPTIONS
import { ZeroAddressException } from "../interfaces/IErrors.sol";

/// @title Data compressor
/// @notice Collects data from various contracts for use in the dApp
/// Do not use for data from data compressor for state-changing functions
contract DataCompressor is IDataCompressor {
    using PercentageMath for uint256;

    /// @dev Address of the AddressProvider
    AddressProvider public immutable addressProvider;

    /// @dev Address of the ContractsRegister
    ContractsRegister public immutable contractsRegister;

    /// @dev Address of WETH
    address public immutable WETHToken;

    // Contract version
    uint256 public constant version = 2;

    /// @dev Prevents function usage for target contracts that are not Gearbox pools
    modifier targetIsRegisteredPool(address pool) {
        if (!contractsRegister.isPool(pool)) revert NotPoolException(); // T:[WG-1]
        _;
    }

    /// @dev Prevents function usage for target contracts that are not Gearbox Credit Managers
    modifier targetIsRegisteredCreditManager(address creditManager) {
        if (!contractsRegister.isCreditManager(creditManager))
            revert NotCreditManagerException(); // T:[WG-3]
        _;
    }

    constructor(address _addressProvider) {
        if (_addressProvider == address(0)) revert ZeroAddressException();

        addressProvider = AddressProvider(_addressProvider);
        contractsRegister = ContractsRegister(
            addressProvider.getContractsRegister()
        );
        WETHToken = addressProvider.getWethToken();
    }

    /// @dev Returns CreditAccountData for all opened accounts for particular borrower
    /// @param borrower Borrower address
    function getCreditAccountList(address borrower)
        external
        view
        returns (CreditAccountData[] memory result)
    {
        // Counts how many opened accounts a borrower has
        uint256 count;
        uint256 creditManagersLength = contractsRegister
            .getCreditManagersCount();

        for (uint256 i = 0; i < creditManagersLength; ) {
            unchecked {
                address creditManager = contractsRegister.creditManagers(i);
                if (hasOpenedCreditAccount(creditManager, borrower)) {
                    ++count;
                }
                ++i;
            }
        }

        result = new CreditAccountData[](count);

        // Get data & fill the array
        count = 0;
        for (uint256 i = 0; i < creditManagersLength; ) {
            address creditManager = contractsRegister.creditManagers(i);
            unchecked {
                if (hasOpenedCreditAccount(creditManager, borrower)) {
                    result[count] = getCreditAccountData(
                        creditManager,
                        borrower
                    );

                    count++;
                }

                ++i;
            }
        }
    }

    /// @dev Returns whether the borrower has an open credit account with the credit manager
    /// @param _creditManager Credit manager to check
    /// @param borrower Borrower to check
    function hasOpenedCreditAccount(address _creditManager, address borrower)
        public
        view
        targetIsRegisteredCreditManager(_creditManager)
        returns (bool)
    {
        return _hasOpenedCreditAccount(_creditManager, borrower);
    }

    /// @dev Returns CreditAccountData for a particular Credit Account account, based on creditManager and borrower
    /// @param _creditManager Credit manager address
    /// @param borrower Borrower address
    function getCreditAccountData(address _creditManager, address borrower)
        public
        view
        returns (CreditAccountData memory result)
    {
        (
            uint8 ver,
            ICreditManager creditManager,
            ICreditFilter creditFilter,
            ICreditManagerV2 creditManagerV2,
            ICreditFacade creditFacade,

        ) = getCreditContracts(_creditManager);

        address creditAccount = (ver == 1)
            ? creditManager.getCreditAccountOrRevert(borrower)
            : creditManagerV2.getCreditAccountOrRevert(borrower);

        result.version = ver;

        result.borrower = borrower;
        result.creditManager = _creditManager;
        result.addr = creditAccount;

        if (ver == 1) {
            result.underlying = creditManager.underlyingToken();
            result.totalValue = creditFilter.calcTotalValue(creditAccount);
            result.healthFactor = creditFilter.calcCreditAccountHealthFactor(
                creditAccount
            );

            try
                ICreditManager(creditManager).calcRepayAmount(borrower, false)
            returns (uint256 value) {
                result.repayAmount = value;
            } catch {}

            try
                ICreditManager(creditManager).calcRepayAmount(borrower, true)
            returns (uint256 value) {
                result.liquidationAmount = value;
            } catch {}

            try
                ICreditManager(creditManager)._calcClosePayments(
                    creditAccount,
                    result.totalValue,
                    false
                )
            returns (
                uint256,
                uint256,
                uint256 remainingFunds,
                uint256,
                uint256
            ) {
                result.canBeClosed = remainingFunds > 0;
            } catch {}

            result.borrowedAmount = ICreditAccount(creditAccount)
                .borrowedAmount();

            result.borrowedAmountPlusInterest = creditFilter
                .calcCreditAccountAccruedInterest(creditAccount);
        } else {
            result.underlying = creditManagerV2.underlying();
            (result.totalValue, ) = creditFacade.calcTotalValue(creditAccount);
            result.healthFactor = creditFacade.calcCreditAccountHealthFactor(
                creditAccount
            );

            (
                result.borrowedAmount,
                result.borrowedAmountPlusInterest,
                result.borrowedAmountPlusInterestAndFees
            ) = creditManagerV2.calcCreditAccountAccruedInterest(creditAccount);
        }

        address pool = address(
            (ver == 1) ? creditManager.poolService() : creditManagerV2.pool()
        );
        result.borrowRate = IPoolService(pool).borrowAPY_RAY();

        uint256 collateralTokenCount = (ver == 1)
            ? creditFilter.allowedTokensCount()
            : creditManagerV2.collateralTokensCount();

        result.enabledTokenMask = (ver == 1)
            ? creditFilter.enabledTokens(creditAccount)
            : creditManagerV2.enabledTokensMap(creditAccount);

        result.balances = new TokenBalance[](collateralTokenCount);
        for (uint256 i = 0; i < collateralTokenCount; ) {
            unchecked {
                TokenBalance memory balance;
                uint256 tokenMask = 1 << i;
                if (ver == 1) {
                    (balance.token, balance.balance, , ) = creditFilter
                        .getCreditAccountTokenById(creditAccount, i);
                    balance.isAllowed = creditFilter.isTokenAllowed(
                        balance.token
                    );
                } else {
                    (balance.token, ) = creditManagerV2.collateralTokens(i);
                    balance.balance = IERC20(balance.token).balanceOf(
                        creditAccount
                    );
                    balance.isAllowed = creditFacade.isTokenAllowed(
                        balance.token
                    );
                }
                balance.isEnabled = tokenMask & result.enabledTokenMask == 0
                    ? false
                    : true;

                result.balances[i] = balance;

                ++i;
            }
        }

        result.cumulativeIndexAtOpen = ICreditAccount(creditAccount)
            .cumulativeIndexAtOpen();

        result.since = ICreditAccount(creditAccount).since();
    }

    /// @dev Returns CreditManagerData for all Credit Managers
    function getCreditManagersList()
        external
        view
        returns (CreditManagerData[] memory result)
    {
        uint256 creditManagersCount = contractsRegister
            .getCreditManagersCount();

        result = new CreditManagerData[](creditManagersCount);

        for (uint256 i = 0; i < creditManagersCount; ) {
            address creditManager = contractsRegister.creditManagers(i);
            result[i] = getCreditManagerData(creditManager);
            unchecked {
                ++i;
            }
        }
    }

    /// @dev Returns CreditManagerData for a particular _creditManager
    /// @param _creditManager CreditManager address
    function getCreditManagerData(address _creditManager)
        public
        view
        returns (CreditManagerData memory result)
    {
        (
            uint8 ver,
            ICreditManager creditManager,
            ICreditFilter creditFilter,
            ICreditManagerV2 creditManagerV2,
            ICreditFacade creditFacade,
            ICreditConfigurator creditConfigurator
        ) = getCreditContracts(_creditManager);

        result.addr = _creditManager;
        result.version = ver;

        result.underlying = (ver == 1)
            ? creditManager.underlyingToken()
            : creditManagerV2.underlying();
        result.isWETH = result.underlying == WETHToken;

        {
            IPoolService pool = IPoolService(
                (ver == 1)
                    ? creditManager.poolService()
                    : creditManagerV2.pool()
            );
            result.pool = address(pool);
            result.canBorrow = pool.creditManagersCanBorrow(_creditManager);
            result.borrowRate = pool.borrowAPY_RAY();
            result.availableLiquidity = pool.availableLiquidity();
        }

        if (ver == 1) {
            result.minAmount = creditManager.minAmount();
            result.maxAmount = creditManager.maxAmount();
        } else {
            (result.minAmount, result.maxAmount) = creditFacade.limits();
        }
        {
            uint256 collateralTokenCount = (ver == 1)
                ? creditFilter.allowedTokensCount()
                : creditManagerV2.collateralTokensCount();

            result.collateralTokens = new address[](collateralTokenCount);
            result.liquidationThresholds = new uint256[](collateralTokenCount);
            unchecked {
                for (uint256 i = 0; i < collateralTokenCount; ++i) {
                    if (ver == 1) {
                        address token = creditFilter.allowedTokens(i);
                        result.collateralTokens[i] = token;
                        result.liquidationThresholds[i] = creditFilter
                            .liquidationThresholds(token);
                    } else {
                        (
                            result.collateralTokens[i],
                            result.liquidationThresholds[i]
                        ) = creditManagerV2.collateralTokens(i);
                    }
                }
            }
        }
        if (ver == 1) {
            uint256 allowedContractsCount = creditFilter
                .allowedContractsCount();

            result.adapters = new ContractAdapter[](allowedContractsCount);
            for (uint256 i = 0; i < allowedContractsCount; ) {
                address allowedContract = creditFilter.allowedContracts(i);

                result.adapters[i] = ContractAdapter({
                    allowedContract: allowedContract,
                    adapter: creditFilter.contractToAdapter(allowedContract)
                });
                unchecked {
                    ++i;
                }
            }
        } else {
            address[] memory allowedContracts = creditConfigurator
                .allowedContracts();
            uint256 len = allowedContracts.length;
            result.adapters = new ContractAdapter[](len);
            for (uint256 i = 0; i < len; ) {
                address allowedContract = allowedContracts[i];

                result.adapters[i] = ContractAdapter({
                    allowedContract: allowedContract,
                    adapter: creditManagerV2.contractToAdapter(allowedContract)
                });
                unchecked {
                    ++i;
                }
            }
        }

        if (ver == 1) {
            // VERSION 1 SPECIFIC FIELDS
            result.maxLeverageFactor = ICreditManager(creditManager)
                .maxLeverageFactor();
            result.maxEnabledTokensLength = 255;
            result.feeInterest = uint16(creditManager.feeInterest());
            result.feeLiquidation = uint16(creditManager.feeLiquidation());
            result.liquidationDiscount = uint16(creditManager.feeLiquidation());
        } else {
            // VERSION 2 SPECIFIC FIELDS
            result.creditFacade = address(creditFacade);
            result.creditConfigurator = creditManagerV2.creditConfigurator();
            result.degenNFT = creditFacade.degenNFT();
            (, result.isIncreaseDebtForbidden, ) = creditFacade.params(); // V2 only: true if increasing debt is forbidden
            result.forbiddenTokenMask = creditManagerV2.forbiddenTokenMask(); // V2 only: mask which forbids some particular tokens
            result.maxEnabledTokensLength = creditManagerV2
                .maxAllowedEnabledTokenLength(); // V2 only: a limit on enabled tokens imposed for security
            {
                (
                    result.feeInterest,
                    result.feeLiquidation,
                    result.liquidationDiscount,
                    result.feeLiquidationExpired,
                    result.liquidationDiscountExpired
                ) = creditManagerV2.fees();
            }
        }
    }

    /// @dev Returns PoolData for a particular pool
    /// @param _pool Pool address
    function getPoolData(address _pool)
        public
        view
        targetIsRegisteredPool(_pool)
        returns (PoolData memory result)
    {
        IPoolService pool = IPoolService(_pool);

        result.addr = _pool;
        result.expectedLiquidity = pool.expectedLiquidity();
        result.expectedLiquidityLimit = pool.expectedLiquidityLimit();
        result.availableLiquidity = pool.availableLiquidity();
        result.totalBorrowed = pool.totalBorrowed();
        result.dieselRate_RAY = pool.getDieselRate_RAY();
        result.linearCumulativeIndex = pool.calcLinearCumulative_RAY();
        result.borrowAPY_RAY = pool.borrowAPY_RAY();
        result.underlying = pool.underlyingToken();
        result.dieselToken = pool.dieselToken();
        result.dieselRate_RAY = pool.getDieselRate_RAY();
        result.withdrawFee = pool.withdrawFee();
        result.isWETH = result.underlying == WETHToken;
        result.timestampLU = pool._timestampLU();
        result.cumulativeIndex_RAY = pool._cumulativeIndex_RAY();

        uint256 dieselSupply = IERC20(result.dieselToken).totalSupply();
        uint256 totalLP = pool.fromDiesel(dieselSupply);
        result.depositAPY_RAY = totalLP == 0
            ? result.borrowAPY_RAY
            : (result.borrowAPY_RAY * result.totalBorrowed).percentMul(
                PERCENTAGE_FACTOR - result.withdrawFee
            ) / totalLP;

        result.version = uint8(pool.version());

        return result;
    }

    /// @dev Returns PoolData for all registered pools
    function getPoolsList() external view returns (PoolData[] memory result) {
        uint256 poolsLength = contractsRegister.getPoolsCount();

        result = new PoolData[](poolsLength);

        for (uint256 i = 0; i < poolsLength; ) {
            address pool = contractsRegister.pools(i);
            result[i] = getPoolData(pool);
            unchecked {
                ++i;
            }
        }
    }

    /// @dev Returns the adapter address for a particular creditManager and targetContract
    function getAdapter(address _creditManager, address _allowedContract)
        external
        view
        targetIsRegisteredCreditManager(_creditManager)
        returns (address adapter)
    {
        (
            uint8 ver,
            ,
            ICreditFilter creditFilter,
            ICreditManagerV2 creditManagerV2,
            ,

        ) = getCreditContracts(_creditManager);

        adapter = (ver == 1)
            ? creditFilter.contractToAdapter(_allowedContract)
            : creditManagerV2.contractToAdapter(_allowedContract);
    }

    /// @dev Internal implementation for hasOpenedCreditAccount
    function _hasOpenedCreditAccount(address creditManager, address borrower)
        internal
        view
        returns (bool)
    {
        return
            ICreditManagerV2(creditManager).creditAccounts(borrower) !=
            address(0);
    }

    /// @dev Retrieves all relevant credit contracts for a particular Credit Manager
    function getCreditContracts(address _creditManager)
        internal
        view
        targetIsRegisteredCreditManager(_creditManager)
        returns (
            uint8 ver,
            ICreditManager creditManager,
            ICreditFilter creditFilter,
            ICreditManagerV2 creditManagerV2,
            ICreditFacade creditFacade,
            ICreditConfigurator creditConfigurator
        )
    {
        ver = uint8(IVersion(_creditManager).version());
        if (ver == 1) {
            creditManager = ICreditManager(_creditManager);
            creditFilter = ICreditFilter(creditManager.creditFilter());
        } else {
            creditManagerV2 = ICreditManagerV2(_creditManager);
            creditFacade = ICreditFacade(creditManagerV2.creditFacade());
            creditConfigurator = ICreditConfigurator(
                creditManagerV2.creditConfigurator()
            );
        }
    }
}
