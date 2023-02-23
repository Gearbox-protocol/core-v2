// SPDX-License-Identifier: UNLICENSED
// Gearbox Protocol. Generalized leverage for DeFi protocols
// (c) Gearbox Holdings, 2022
pragma solidity ^0.8.10;

import { IAddressProvider } from "../../interfaces/IAddressProvider.sol";
import { ACL } from "../../core/ACL.sol";

import { AccountFactory } from "../../core/AccountFactory.sol";
import { ICreditAccount } from "../../interfaces/ICreditAccount.sol";
import { ICreditManagerV2, ICreditManagerV2Events, ICreditManagerV2Exceptions, ClosureAction, CollateralTokenData } from "../../interfaces/ICreditManagerV2.sol";
import { IPoolQuotaKeeper, QuotaUpdate, TokenLT, QuotaStatusChange, IPoolQuotaKeeperExceptions } from "../../interfaces/IPoolQuotaKeeper.sol";
import { IPriceOracleV2, IPriceOracleV2Ext } from "../../interfaces/IPriceOracle.sol";

import { CreditManager, UNIVERSAL_CONTRACT } from "../../credit/CreditManager.sol";

import { IPoolService } from "../../interfaces/IPoolService.sol";

import { IWETH } from "../../interfaces/external/IWETH.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { ERC20Mock } from "../mocks/token/ERC20Mock.sol";
import { PercentageMath, PERCENTAGE_FACTOR } from "../../libraries/PercentageMath.sol";

// TESTS

import "../lib/constants.sol";

import { BalanceHelper } from "../helpers/BalanceHelper.sol";

// EXCEPTIONS

// MOCKS
import { PriceFeedMock } from "../mocks/oracles/PriceFeedMock.sol";
import { PoolServiceMock } from "../mocks/pool/PoolServiceMock.sol";
import { PoolQuotaKeeper } from "../../pool/PoolQuotaKeeper.sol";
import { TargetContractMock } from "../mocks/adapters/TargetContractMock.sol";
import { ERC20ApproveRestrictedRevert, ERC20ApproveRestrictedFalse } from "../mocks/token/ERC20ApproveRestricted.sol";

// SUITES
import { TokensTestSuite } from "../suites/TokensTestSuite.sol";
import { Tokens } from "../config/Tokens.sol";
import { CreditManagerTestSuite } from "../suites/CreditManagerTestSuite.sol";
import { GenesisFactory } from "../../factories/GenesisFactory.sol";
import { CreditManagerTestInternal } from "../mocks/credit/CreditManagerTestInternal.sol";

import { CreditConfig } from "../config/CreditConfig.sol";

contract CreditManagerQuotasTest is
    DSTest,
    ICreditManagerV2Events,
    ICreditManagerV2Exceptions,
    IPoolQuotaKeeperExceptions,
    BalanceHelper
{
    CheatCodes evm = CheatCodes(HEVM_ADDRESS);

    CreditManagerTestSuite cms;

    IAddressProvider addressProvider;
    IWETH wethToken;
    GenesisFactory gp;
    AccountFactory af;
    CreditManager creditManager;
    PoolServiceMock poolMock;
    PoolQuotaKeeper poolQuotaKeeper;
    IPriceOracleV2 priceOracle;
    ACL acl;
    address underlying;

    CreditConfig creditConfig;

    function setUp() public {
        tokenTestSuite = new TokensTestSuite();

        tokenTestSuite.topUpWETH{ value: 100 * WAD }();
        _connectCreditManagerSuite(Tokens.DAI, false);

        address link = tokenTestSuite.addressOf(Tokens.LINK);

        _makeTokenLimited(link, 1000, uint96(1_000_000 * WAD));
    }

    ///
    /// HELPERS

    function _connectCreditManagerSuite(Tokens t, bool internalSuite) internal {
        creditConfig = new CreditConfig(tokenTestSuite, t);
        cms = new CreditManagerTestSuite(creditConfig, internalSuite, true);

        gp = cms.gp();
        acl = cms.acl();

        addressProvider = cms.addressProvider();
        af = cms.af();

        poolMock = cms.poolMock();
        poolQuotaKeeper = cms.poolQuotaKeeper();

        creditManager = cms.creditManager();

        priceOracle = creditManager.priceOracle();
        underlying = creditManager.underlying();
    }

    /// @dev Opens credit account for testing management functions
    function _openCreditAccount()
        internal
        returns (
            uint256 borrowedAmount,
            uint256 cumulativeIndexAtOpen,
            uint256 cumulativeIndexAtClose,
            address creditAccount
        )
    {
        return cms.openCreditAccount();
    }

    function expectTokenIsEnabled(Tokens t, bool expectedState) internal {
        address creditAccount = creditManager.getCreditAccountOrRevert(USER);

        bool state = creditManager.tokenMasksMap(tokenTestSuite.addressOf(t)) &
            creditManager.enabledTokensMap(creditAccount) !=
            0;
        assertTrue(
            state == expectedState,
            string(
                abi.encodePacked(
                    "Token ",
                    tokenTestSuite.symbols(t),
                    state
                        ? " enabled as not expetcted"
                        : " not enabled as expected "
                )
            )
        );
    }

    function expectFullCollateralCheck() internal {
        address creditAccount = creditManager.getCreditAccountOrRevert(USER);

        (, , uint256 borrowedAmountWithInterestAndFees) = creditManager
            .calcCreditAccountAccruedInterest(creditAccount);

        evm.expectCall(
            address(priceOracle),
            abi.encodeWithSelector(
                IPriceOracleV2.convertToUSD.selector,
                borrowedAmountWithInterestAndFees * PERCENTAGE_FACTOR,
                underlying
            )
        );
    }

    function mintBalance(
        Tokens t,
        uint256 amount,
        bool enable
    ) internal {
        address creditAccount = creditManager.getCreditAccountOrRevert(USER);

        tokenTestSuite.mint(t, creditAccount, amount);
        if (enable) {
            creditManager.checkAndEnableToken(
                creditAccount,
                tokenTestSuite.addressOf(t)
            );
        }
    }

    function isTokenEnabled(Tokens t) internal view returns (bool) {
        address creditAccount = creditManager.getCreditAccountOrRevert(USER);
        return
            creditManager.enabledTokensMap(creditAccount) &
                creditManager.tokenMasksMap(tokenTestSuite.addressOf(t)) !=
            0;
    }

    function _addAndEnableTokens(
        address creditAccount,
        uint256 numTokens,
        uint256 balance
    ) internal {
        for (uint256 i = 0; i < numTokens; i++) {
            ERC20Mock t = new ERC20Mock("new token", "nt", 18);
            PriceFeedMock pf = new PriceFeedMock(10**8, 8);

            evm.startPrank(CONFIGURATOR);
            creditManager.addToken(address(t));
            IPriceOracleV2Ext(address(priceOracle)).addPriceFeed(
                address(t),
                address(pf)
            );
            creditManager.setLiquidationThreshold(address(t), 8000);
            evm.stopPrank();

            t.mint(creditAccount, balance);

            creditManager.checkAndEnableToken(creditAccount, address(t));
        }
    }

    function _getRandomBits(
        uint256 ones,
        uint256 zeros,
        uint256 randomValue
    ) internal pure returns (bool[] memory result, uint256 breakPoint) {
        if ((ones + zeros) == 0) {
            result = new bool[](0);
            breakPoint = 0;
            return (result, breakPoint);
        }

        uint256 onesCurrent = ones;
        uint256 zerosCurrent = zeros;

        result = new bool[](ones + zeros);
        uint256 i = 0;

        while (onesCurrent + zerosCurrent > 0) {
            uint256 rand = uint256(keccak256(abi.encodePacked(randomValue))) %
                (onesCurrent + zerosCurrent);
            if (rand < onesCurrent) {
                result[i] = true;
                onesCurrent--;
            } else {
                result[i] = false;
                zerosCurrent--;
            }

            i++;
        }

        if (ones > 0) {
            uint256 breakpointCounter = (uint256(
                keccak256(abi.encodePacked(randomValue))
            ) % (ones)) + 1;

            for (uint256 j = 0; j < result.length; j++) {
                if (result[j]) {
                    breakpointCounter--;
                }

                if (breakpointCounter == 0) {
                    breakPoint = j;
                    break;
                }
            }
        }
    }

    function enableTokensMoreThanLimit(address creditAccount) internal {
        uint256 maxAllowedEnabledTokenLength = creditManager
            .maxAllowedEnabledTokenLength();
        _addAndEnableTokens(creditAccount, maxAllowedEnabledTokenLength, 2);
    }

    function prepareForEnabledUnderlyingCase(address creditAccount) internal {
        uint256 daiBalance = tokenTestSuite.balanceOf(
            Tokens.DAI,
            creditAccount
        );

        tokenTestSuite.burn(Tokens.DAI, creditAccount, daiBalance);

        tokenTestSuite.mint(Tokens.USDC, creditAccount, daiBalance * 10);

        creditManager.checkAndEnableToken(
            creditAccount,
            tokenTestSuite.addressOf(Tokens.USDC)
        );

        uint256 maxAllowedEnabledTokenLength = creditManager
            .maxAllowedEnabledTokenLength();
        _addAndEnableTokens(creditAccount, maxAllowedEnabledTokenLength - 1, 2);
    }

    function prepareForEnabledTokenOptimization(
        address creditAccount,
        bool[] memory tokenTypes,
        uint256 enabledTokensNum,
        uint256 zeroTokensNum,
        uint256 breakPoint
    ) internal returns (uint256) {
        if (enabledTokensNum == 0) {
            return 1;
        }

        bool setBreakpoint;

        if (enabledTokensNum != zeroTokensNum) {
            // When there are more enabled tokens than zero tokens, we have a breakpoint other than underlying

            uint256 daiBalance = tokenTestSuite.balanceOf(
                Tokens.DAI,
                creditAccount
            );
            tokenTestSuite.burn(Tokens.DAI, creditAccount, daiBalance);
            setBreakpoint = true;
        } else {
            // When there is the same number of enabled and zero tokens, only the underlying will be checked in fullCheck,
            // hence all tokens + underlying will remain enabled before optimizer is run

            enabledTokensNum += 1;
        }

        for (uint256 i = 0; i < tokenTypes.length; i++) {
            if ((i == breakPoint) && setBreakpoint) {
                _addAndEnableTokens(creditAccount, 1, RAY);
            } else if (tokenTypes[i]) {
                _addAndEnableTokens(creditAccount, 1, 2);
            } else {
                _addAndEnableTokens(creditAccount, 1, 1);
                if ((i > breakPoint) && setBreakpoint) {
                    enabledTokensNum--;
                }
            }
        }

        return enabledTokensNum;
    }

    function calcEnabledTokens(address creditAccount)
        internal
        view
        returns (uint256)
    {
        uint256 enabledMask = creditManager.enabledTokensMap(creditAccount);

        uint256 tokensEnabled;

        uint256 tokenMask;
        unchecked {
            for (uint256 i; i < 256; ++i) {
                tokenMask = 1 << i;
                if (enabledMask & tokenMask != 0) {
                    ++tokensEnabled;
                }

                if (tokenMask >= enabledMask) {
                    break;
                }
            }
        }

        return tokensEnabled;
    }

    function _openAccountAndTransferToCF()
        internal
        returns (address creditAccount)
    {
        (, , , creditAccount) = _openCreditAccount();
        creditManager.transferAccountOwnership(USER, address(this));
    }

    function _baseFullCollateralCheck(address creditAccount) internal {
        creditManager.fullCollateralCheck(
            creditAccount,
            new uint256[](0),
            10000
        );
    }

    function _makeTokenLimited(
        address token,
        uint16 rate,
        uint96 limit
    ) internal {
        cms.makeTokenLimited(token, rate, limit);
    }

    ///
    ///
    ///  TESTS
    ///
    ///

    /// @dev [CMQ-01]: constructor correctly sets supportsQuotas based on pool
    function test_CMQ_01_constructor_correctly_sets_quota_related_params()
        public
    {
        assertTrue(
            creditManager.supportsQuotas(),
            "Credit Manager does not support quotas"
        );
    }

    /// @dev [CMQ-02]: setLimitedMask works correctly
    function test_CMQ_02_setLimitedMask_works_correctly() public {
        uint256 usdcMask = creditManager.tokenMasksMap(
            tokenTestSuite.addressOf(Tokens.USDC)
        );
        uint256 linkMask = creditManager.tokenMasksMap(
            tokenTestSuite.addressOf(Tokens.LINK)
        );

        uint256 limitedTokenMask = creditManager.limitedTokenMask();

        evm.expectRevert(CreditConfiguratorOnlyException.selector);
        creditManager.setLimitedMask(limitedTokenMask | usdcMask);

        evm.prank(CONFIGURATOR);
        creditManager.setLimitedMask(limitedTokenMask | usdcMask);

        assertEq(
            creditManager.limitedTokenMask(),
            usdcMask | linkMask,
            "New limited mask is incorrect"
        );
    }

    /// @dev [CMQ-03]: updateQuotas works correctly
    function test_CMQ_03_updateQuotas_works_correctly() public {
        _makeTokenLimited(
            tokenTestSuite.addressOf(Tokens.USDT),
            500,
            uint96(1_000_000 * WAD)
        );

        (, , , address creditAccount) = _openCreditAccount();

        QuotaUpdate[] memory quotaUpdates = new QuotaUpdate[](2);
        quotaUpdates[0] = QuotaUpdate({
            token: tokenTestSuite.addressOf(Tokens.LINK),
            quotaChange: 100000
        });
        quotaUpdates[1] = QuotaUpdate({
            token: tokenTestSuite.addressOf(Tokens.USDT),
            quotaChange: 200000
        });

        evm.expectCall(
            address(poolQuotaKeeper),
            abi.encodeCall(
                IPoolQuotaKeeper.updateQuotas,
                (creditAccount, quotaUpdates)
            )
        );

        creditManager.updateQuotas(creditAccount, quotaUpdates);

        assertTrue(
            isTokenEnabled(Tokens.LINK),
            "LINK was not enabled despite positive quota"
        );

        assertTrue(
            isTokenEnabled(Tokens.USDT),
            "USDT was not enabled despite positive quota"
        );

        evm.warp(block.timestamp + 60 * 60 * 24 * 365);

        quotaUpdates[0] = QuotaUpdate({
            token: tokenTestSuite.addressOf(Tokens.LINK),
            quotaChange: -100000
        });
        quotaUpdates[1] = QuotaUpdate({
            token: tokenTestSuite.addressOf(Tokens.USDT),
            quotaChange: -100000
        });

        creditManager.updateQuotas(creditAccount, quotaUpdates);

        assertTrue(
            !isTokenEnabled(Tokens.LINK),
            "LINK was not disabled despite zeroing quota"
        );

        assertTrue(
            isTokenEnabled(Tokens.USDT),
            "USDT was not disabled despite positive quota"
        );

        assertEq(
            creditManager.cumulativeQuotaInterest(creditAccount),
            (100000 * 1000 + 200000 * 500) / PERCENTAGE_FACTOR,
            "Cumulative quota interest was not updated correctly"
        );

        quotaUpdates[0] = QuotaUpdate({
            token: tokenTestSuite.addressOf(Tokens.USDC),
            quotaChange: -100000
        });

        evm.expectRevert(UnknownQuotaException.selector);
        creditManager.updateQuotas(creditAccount, quotaUpdates);
    }
}
