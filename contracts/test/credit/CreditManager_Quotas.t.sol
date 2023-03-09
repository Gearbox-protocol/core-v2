// SPDX-License-Identifier: UNLICENSED
// Gearbox Protocol. Generalized leverage for DeFi protocols
// (c) Gearbox Holdings, 2022
pragma solidity ^0.8.10;

import {IAddressProvider} from "../../interfaces/IAddressProvider.sol";
import {ACL} from "../../core/ACL.sol";

import {AccountFactory} from "../../core/AccountFactory.sol";
import {ICreditAccount} from "../../interfaces/ICreditAccount.sol";
import {
    ICreditManagerV2,
    ICreditManagerV2Events,
    ICreditManagerV2Exceptions,
    ClosureAction,
    CollateralTokenData
} from "../../interfaces/ICreditManagerV2.sol";
import {
    IPoolQuotaKeeper,
    QuotaUpdate,
    TokenLT,
    QuotaStatusChange,
    IPoolQuotaKeeperExceptions,
    AccountQuota
} from "../../interfaces/IPoolQuotaKeeper.sol";
import {IPriceOracleV2, IPriceOracleV2Ext} from "../../interfaces/IPriceOracle.sol";

import {CreditManager, UNIVERSAL_CONTRACT} from "../../credit/CreditManager.sol";

import {IPoolService} from "../../interfaces/IPoolService.sol";

import {IWETH} from "../../interfaces/external/IWETH.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {ERC20Mock} from "../mocks/token/ERC20Mock.sol";
import {PERCENTAGE_FACTOR} from "../../libraries/Constants.sol";

// TESTS

import "../lib/constants.sol";

import {BalanceHelper} from "../helpers/BalanceHelper.sol";

// EXCEPTIONS

// MOCKS
import {PriceFeedMock} from "../mocks/oracles/PriceFeedMock.sol";
import {PoolServiceMock} from "../mocks/pool/PoolServiceMock.sol";
import {PoolQuotaKeeper} from "../../pool/PoolQuotaKeeper.sol";
import {TargetContractMock} from "../mocks/adapters/TargetContractMock.sol";
import {ERC20ApproveRestrictedRevert, ERC20ApproveRestrictedFalse} from "../mocks/token/ERC20ApproveRestricted.sol";

// SUITES
import {TokensTestSuite} from "../suites/TokensTestSuite.sol";
import {Tokens} from "../config/Tokens.sol";
import {CreditManagerTestSuite} from "../suites/CreditManagerTestSuite.sol";
import {GenesisFactory} from "../../factories/GenesisFactory.sol";
import {CreditManagerTestInternal} from "../mocks/credit/CreditManagerTestInternal.sol";

import {CreditConfig} from "../config/CreditConfig.sol";

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

        tokenTestSuite.topUpWETH{value: 100 * WAD}();
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

    function expectTokenIsEnabled(address creditAccount, Tokens t, bool expectedState) internal {
        bool state = creditManager.tokenMasksMap(tokenTestSuite.addressOf(t))
            & creditManager.enabledTokensMap(creditAccount) != 0;
        assertTrue(
            state == expectedState,
            string(
                abi.encodePacked(
                    "Token ",
                    tokenTestSuite.symbols(t),
                    state ? " enabled as not expetcted" : " not enabled as expected "
                )
            )
        );
    }

    function mintBalance(address creditAccount, Tokens t, uint256 amount, bool enable) internal {
        tokenTestSuite.mint(t, creditAccount, amount);
        if (enable) {
            creditManager.checkAndEnableToken(tokenTestSuite.addressOf(t));
        }
    }

    function _makeTokenLimited(address token, uint16 rate, uint96 limit) internal {
        cms.makeTokenLimited(token, rate, limit);
    }

    function _addManyLimitedTokens(uint256 numTokens, uint96 quota)
        internal
        returns (QuotaUpdate[] memory quotaChanges)
    {
        quotaChanges = new QuotaUpdate[](numTokens);

        for (uint256 i = 0; i < numTokens; i++) {
            ERC20Mock t = new ERC20Mock("new token", "nt", 18);
            PriceFeedMock pf = new PriceFeedMock(10**8, 8);

            evm.startPrank(CONFIGURATOR);
            creditManager.addToken(address(t));
            IPriceOracleV2Ext(address(priceOracle)).addPriceFeed(address(t), address(pf));
            creditManager.setLiquidationThreshold(address(t), 8000);
            evm.stopPrank();

            _makeTokenLimited(address(t), 100, type(uint96).max);

            quotaChanges[i] = QuotaUpdate({token: address(t), quotaChange: int96(quota)});
        }
    }

    ///
    ///
    ///  TESTS
    ///
    ///

    /// @dev [CMQ-1]: constructor correctly sets supportsQuotas based on pool
    function test_CMQ_01_constructor_correctly_sets_quota_related_params() public {
        assertTrue(creditManager.supportsQuotas(), "Credit Manager does not support quotas");
    }

    /// @dev [CMQ-2]: setLimitedMask works correctly
    function test_CMQ_02_setLimitedMask_works_correctly() public {
        uint256 usdcMask = creditManager.tokenMasksMap(tokenTestSuite.addressOf(Tokens.USDC));
        uint256 linkMask = creditManager.tokenMasksMap(tokenTestSuite.addressOf(Tokens.LINK));

        uint256 limitedTokenMask = creditManager.limitedTokenMask();

        evm.expectRevert(CreditConfiguratorOnlyException.selector);
        creditManager.setLimitedMask(limitedTokenMask | usdcMask);

        evm.prank(CONFIGURATOR);
        creditManager.setLimitedMask(limitedTokenMask | usdcMask);

        assertEq(creditManager.limitedTokenMask(), usdcMask | linkMask, "New limited mask is incorrect");
    }

    /// @dev [CMQ-3]: updateQuotas works correctly
    function test_CMQ_03_updateQuotas_works_correctly() public {
        _makeTokenLimited(tokenTestSuite.addressOf(Tokens.USDT), 500, uint96(1_000_000 * WAD));

        (,,, address creditAccount) = _openCreditAccount();

        QuotaUpdate[] memory quotaUpdates = new QuotaUpdate[](2);
        quotaUpdates[0] = QuotaUpdate({token: tokenTestSuite.addressOf(Tokens.LINK), quotaChange: 100000});
        quotaUpdates[1] = QuotaUpdate({token: tokenTestSuite.addressOf(Tokens.USDT), quotaChange: 200000});

        evm.expectRevert(CreditFacadeOnlyException.selector);
        evm.prank(FRIEND);
        creditManager.updateQuotas(creditAccount, quotaUpdates);

        evm.expectCall(
            address(poolQuotaKeeper), abi.encodeCall(IPoolQuotaKeeper.updateQuotas, (creditAccount, quotaUpdates))
        );

        creditManager.updateQuotas(creditAccount, quotaUpdates);

        expectTokenIsEnabled(creditAccount, Tokens.LINK, true);
        expectTokenIsEnabled(creditAccount, Tokens.USDT, true);

        evm.warp(block.timestamp + 60 * 60 * 24 * 365);

        quotaUpdates[0] = QuotaUpdate({token: tokenTestSuite.addressOf(Tokens.LINK), quotaChange: -100000});
        quotaUpdates[1] = QuotaUpdate({token: tokenTestSuite.addressOf(Tokens.USDT), quotaChange: -100000});

        creditManager.updateQuotas(creditAccount, quotaUpdates);

        expectTokenIsEnabled(creditAccount, Tokens.LINK, false);
        expectTokenIsEnabled(creditAccount, Tokens.USDT, true);

        assertEq(
            creditManager.cumulativeQuotaInterest(creditAccount),
            (100000 * 1000 + 200000 * 500) / PERCENTAGE_FACTOR,
            "Cumulative quota interest was not updated correctly"
        );

        quotaUpdates[0] = QuotaUpdate({token: tokenTestSuite.addressOf(Tokens.USDC), quotaChange: -100000});

        evm.expectRevert(UnknownQuotaException.selector);
        creditManager.updateQuotas(creditAccount, quotaUpdates);
    }

    /// @dev [CMQ-4]: Quotas are handled correctly on debt decrease: amount < quota interest case
    function test_CMQ_04_quotas_are_handled_correctly_at_repayment_partial_case() public {
        _makeTokenLimited(tokenTestSuite.addressOf(Tokens.USDT), 500, uint96(1_000_000 * WAD));

        (,,, address creditAccount) = _openCreditAccount();

        QuotaUpdate[] memory quotaUpdates = new QuotaUpdate[](2);
        quotaUpdates[0] =
            QuotaUpdate({token: tokenTestSuite.addressOf(Tokens.LINK), quotaChange: int96(uint96(100 * WAD))});
        quotaUpdates[1] =
            QuotaUpdate({token: tokenTestSuite.addressOf(Tokens.USDT), quotaChange: int96(uint96(200 * WAD))});

        evm.expectCall(
            address(poolQuotaKeeper), abi.encodeCall(IPoolQuotaKeeper.updateQuotas, (creditAccount, quotaUpdates))
        );

        creditManager.updateQuotas(creditAccount, quotaUpdates);

        evm.warp(block.timestamp + 60 * 60 * 24 * 365);

        uint256 amountRepaid = 15 * WAD;

        (uint16 feeInterest,,,,) = creditManager.fees();

        uint256 expectedQuotaInterestRepaid = (amountRepaid * PERCENTAGE_FACTOR) / (PERCENTAGE_FACTOR + feeInterest);

        (,, uint256 totalDebtBefore) = creditManager.calcCreditAccountAccruedInterest(creditAccount);

        creditManager.manageDebt(creditAccount, amountRepaid, false);

        assertEq(
            creditManager.cumulativeQuotaInterest(creditAccount),
            20 * WAD - expectedQuotaInterestRepaid + 1,
            "Cumulative quota interest was not updated correctly"
        );

        (,, uint256 totalDebtAfter) = creditManager.calcCreditAccountAccruedInterest(creditAccount);

        assertEq(totalDebtAfter, totalDebtBefore - amountRepaid + 1, "Debt updated incorrectly");
    }

    /// @dev [CMQ-5]: Quotas are handled correctly on debt decrease: amount >= quota interest case
    function test_CMQ_05_quotas_are_handled_correctly_at_repayment_full_case() public {
        _makeTokenLimited(tokenTestSuite.addressOf(Tokens.USDT), 500, uint96(1_000_000 * WAD));

        (,,, address creditAccount) = _openCreditAccount();

        QuotaUpdate[] memory quotaUpdates = new QuotaUpdate[](2);
        quotaUpdates[0] =
            QuotaUpdate({token: tokenTestSuite.addressOf(Tokens.LINK), quotaChange: int96(uint96(100 * WAD))});
        quotaUpdates[1] =
            QuotaUpdate({token: tokenTestSuite.addressOf(Tokens.USDT), quotaChange: int96(uint96(200 * WAD))});

        evm.expectCall(
            address(poolQuotaKeeper), abi.encodeCall(IPoolQuotaKeeper.updateQuotas, (creditAccount, quotaUpdates))
        );

        creditManager.updateQuotas(creditAccount, quotaUpdates);

        evm.warp(block.timestamp + 60 * 60 * 24 * 365);

        uint256 amountRepaid = 35 * WAD;

        (,, uint256 totalDebtBefore) = creditManager.calcCreditAccountAccruedInterest(creditAccount);

        creditManager.manageDebt(creditAccount, amountRepaid, false);

        assertEq(
            creditManager.cumulativeQuotaInterest(creditAccount),
            1,
            "Cumulative quota interest was not updated correctly"
        );

        (,, uint256 totalDebtAfter) = creditManager.calcCreditAccountAccruedInterest(creditAccount);

        uint256 totalDebtAfterExpected = totalDebtBefore - amountRepaid + 1;
        uint256 diff = totalDebtAfterExpected > totalDebtAfter
            ? totalDebtAfterExpected - totalDebtAfter
            : totalDebtAfter - totalDebtAfterExpected;

        assertLe(diff, 1, "Debt updated incorrectly");
    }

    /// @dev [CMQ-6]: Quotas are disabled on closing an account
    function test_CMQ_06_quotas_are_disabled_on_close_account_and_all_quota_fees_are_repaid() public {
        _makeTokenLimited(tokenTestSuite.addressOf(Tokens.USDT), 500, uint96(1_000_000 * WAD));

        (uint256 borrowedAmount,,, address creditAccount) = _openCreditAccount();

        QuotaUpdate[] memory quotaUpdates = new QuotaUpdate[](2);
        quotaUpdates[0] =
            QuotaUpdate({token: tokenTestSuite.addressOf(Tokens.LINK), quotaChange: int96(uint96(100 * WAD))});
        quotaUpdates[1] =
            QuotaUpdate({token: tokenTestSuite.addressOf(Tokens.USDT), quotaChange: int96(uint96(200 * WAD))});

        evm.expectCall(
            address(poolQuotaKeeper), abi.encodeCall(IPoolQuotaKeeper.updateQuotas, (creditAccount, quotaUpdates))
        );

        creditManager.updateQuotas(creditAccount, quotaUpdates);

        evm.warp(block.timestamp + 60 * 60 * 24 * 365);

        tokenTestSuite.mint(Tokens.DAI, creditAccount, borrowedAmount);

        evm.expectCall(
            tokenTestSuite.addressOf(Tokens.DAI),
            abi.encodeCall(
                IERC20.transfer,
                (address(poolMock), ((borrowedAmount * (PERCENTAGE_FACTOR + 3000)) / PERCENTAGE_FACTOR) + 30 * WAD)
            )
        );

        creditManager.closeCreditAccount(USER, ClosureAction.CLOSE_ACCOUNT, 0, USER, USER, 0, false);

        AccountQuota memory quota =
            poolQuotaKeeper.getQuota(address(creditManager), creditAccount, tokenTestSuite.addressOf(Tokens.LINK));

        assertEq(uint256(quota.quota), 1, "Quota was not set to 0");
        assertEq(uint256(quota.cumulativeIndexLU), 0, "Cumulative index was not updated");

        quota = poolQuotaKeeper.getQuota(address(creditManager), creditAccount, tokenTestSuite.addressOf(Tokens.USDT));
        assertEq(uint256(quota.quota), 1, "Quota was not set to 0");
        assertEq(uint256(quota.cumulativeIndexLU), 0, "Cumulative index was not updated");
    }

    /// @dev [CMQ-7] enableToken, disableToken and changeEnabledTokens do nothing for limited tokens
    function test_CMQ_07_enable_disable_changeEnabled_do_nothing_for_limited_tokens() public {
        (,,, address creditAccount) = _openCreditAccount();
        creditManager.transferAccountOwnership(USER, address(this));

        creditManager.checkAndEnableToken(tokenTestSuite.addressOf(Tokens.LINK));
        expectTokenIsEnabled(creditAccount, Tokens.LINK, false);

        creditManager.changeEnabledTokens(creditManager.tokenMasksMap(tokenTestSuite.addressOf(Tokens.LINK)), 0);
        expectTokenIsEnabled(creditAccount, Tokens.LINK, false);

        QuotaUpdate[] memory quotaUpdates = new QuotaUpdate[](1);
        quotaUpdates[0] =
            QuotaUpdate({token: tokenTestSuite.addressOf(Tokens.LINK), quotaChange: int96(uint96(100 * WAD))});

        creditManager.updateQuotas(creditAccount, quotaUpdates);

        creditManager.disableToken(tokenTestSuite.addressOf(Tokens.LINK));
        expectTokenIsEnabled(creditAccount, Tokens.LINK, true);

        creditManager.changeEnabledTokens(0, creditManager.tokenMasksMap(tokenTestSuite.addressOf(Tokens.LINK)));
        expectTokenIsEnabled(creditAccount, Tokens.LINK, true);
    }

    /// @dev [CMQ-8]: fullCollateralCheck fuzzing test with quotas
    function test_CMQ_08_fullCollateralCheck_fuzzing_test_quotas(
        uint128 borrowedAmount,
        uint128 daiBalance,
        uint128 usdcBalance,
        uint128 linkBalance,
        uint128 wethBalance,
        uint96 usdcQuota,
        uint96 linkQuota,
        bool enableWETH,
        uint16 minHealthFactor
    ) public {
        _makeTokenLimited(tokenTestSuite.addressOf(Tokens.USDC), 500, uint96(1_000_000 * WAD));

        evm.assume(borrowedAmount > WAD);
        evm.assume(usdcQuota < type(uint96).max / 2);
        evm.assume(linkQuota < type(uint96).max / 2);

        minHealthFactor = 10000 + (minHealthFactor % 20000);

        tokenTestSuite.mint(Tokens.DAI, address(poolMock), borrowedAmount);

        (,,, address creditAccount) = cms.openCreditAccount(borrowedAmount);
        creditManager.transferAccountOwnership(USER, address(this));

        if (daiBalance > borrowedAmount) {
            tokenTestSuite.mint(Tokens.DAI, creditAccount, daiBalance - borrowedAmount);
        } else {
            tokenTestSuite.burn(Tokens.DAI, creditAccount, borrowedAmount - daiBalance);
        }

        expectBalance(Tokens.DAI, creditAccount, daiBalance);

        {
            QuotaUpdate[] memory quotaUpdates = new QuotaUpdate[](2);
            quotaUpdates[0] =
                QuotaUpdate({token: tokenTestSuite.addressOf(Tokens.LINK), quotaChange: int96(uint96(linkQuota))});
            quotaUpdates[1] =
                QuotaUpdate({token: tokenTestSuite.addressOf(Tokens.USDC), quotaChange: int96(uint96(usdcQuota))});

            creditManager.updateQuotas(creditAccount, quotaUpdates);
        }

        mintBalance(creditAccount, Tokens.WETH, wethBalance, enableWETH);
        mintBalance(creditAccount, Tokens.USDC, usdcBalance, false);
        mintBalance(creditAccount, Tokens.LINK, linkBalance, false);

        uint256 twvUSD = (
            tokenTestSuite.balanceOf(Tokens.DAI, creditAccount) * tokenTestSuite.prices(Tokens.DAI)
                * creditConfig.lt(Tokens.DAI)
        ) / WAD;

        {
            uint256 valueUsdc =
                (tokenTestSuite.balanceOf(Tokens.USDC, creditAccount) * tokenTestSuite.prices(Tokens.USDC)) / (10 ** 6);

            uint256 quotaUsdc = usdcQuota > 1_000_000 * WAD ? 1_000_000 * WAD : usdcQuota;

            quotaUsdc = (quotaUsdc * tokenTestSuite.prices(Tokens.DAI)) / WAD;

            uint256 tvIncrease = valueUsdc < quotaUsdc ? valueUsdc : quotaUsdc;

            twvUSD += tvIncrease * creditConfig.lt(Tokens.USDC);
        }

        {
            uint256 valueLink =
                (tokenTestSuite.balanceOf(Tokens.LINK, creditAccount) * tokenTestSuite.prices(Tokens.LINK)) / WAD;

            uint256 quotaLink = linkQuota > 1_000_000 * WAD ? 1_000_000 * WAD : linkQuota;

            quotaLink = (quotaLink * tokenTestSuite.prices(Tokens.DAI)) / WAD;

            uint256 tvIncrease = valueLink < quotaLink ? valueLink : quotaLink;

            twvUSD += tvIncrease * creditConfig.lt(Tokens.LINK);
        }

        twvUSD += !enableWETH
            ? 0
            : (
                tokenTestSuite.balanceOf(Tokens.WETH, creditAccount) * tokenTestSuite.prices(Tokens.WETH)
                    * creditConfig.lt(Tokens.WETH)
            ) / WAD;

        (,, uint256 borrowedAmountWithInterestAndFees) = creditManager.calcCreditAccountAccruedInterest(creditAccount);

        uint256 debtUSD =
            (borrowedAmountWithInterestAndFees * minHealthFactor * tokenTestSuite.prices(Tokens.DAI)) / WAD;

        bool shouldRevert = twvUSD < debtUSD;

        if (shouldRevert) {
            evm.expectRevert(NotEnoughCollateralException.selector);
        }

        creditManager.fullCollateralCheck(creditAccount, new uint256[](0), minHealthFactor);
    }

    /// @dev [CMQ-9]: fullCollateralCheck does not check non-limited tokens if limited are enough to cover debt
    function test_CMQ_09_fullCollateralCheck_skips_normal_tokens_if_limited_tokens_cover_debt() public {
        _makeTokenLimited(tokenTestSuite.addressOf(Tokens.USDC), 500, uint96(1_000_000 * WAD));

        tokenTestSuite.mint(Tokens.DAI, address(poolMock), 1_250_000 * WAD);

        (,,, address creditAccount) = cms.openCreditAccount(1_250_000 * WAD);
        creditManager.transferAccountOwnership(USER, address(this));

        {
            QuotaUpdate[] memory quotaUpdates = new QuotaUpdate[](2);
            quotaUpdates[0] =
                QuotaUpdate({token: tokenTestSuite.addressOf(Tokens.LINK), quotaChange: int96(uint96(1_000_000 * WAD))});
            quotaUpdates[1] =
                QuotaUpdate({token: tokenTestSuite.addressOf(Tokens.USDC), quotaChange: int96(uint96(1_000_000 * WAD))});

            creditManager.updateQuotas(creditAccount, quotaUpdates);
        }

        mintBalance(creditAccount, Tokens.USDC, RAY, false);
        mintBalance(creditAccount, Tokens.LINK, RAY, false);

        evm.prank(CONFIGURATOR);
        creditManager.addToken(DUMB_ADDRESS);

        creditManager.checkAndEnableToken(DUMB_ADDRESS);

        uint256 revertMask = creditManager.tokenMasksMap(DUMB_ADDRESS);

        uint256[] memory collateralHints = new uint256[](1);
        collateralHints[0] = revertMask;

        creditManager.fullCollateralCheck(creditAccount, collateralHints, 10000);
    }

    /// @dev [CMQ-10]: calcCreditAccountAccruedInterest correctly counts quota interest
    function test_CMQ_10_calcCreditAccountAccruedInterest_correctly_includes_quota_interest(
        uint96 quotaLink,
        uint96 quotaUsdt
    ) public {
        _makeTokenLimited(tokenTestSuite.addressOf(Tokens.USDT), 500, uint96(1_000_000 * WAD));

        (uint256 borrowedAmount, uint256 cumulativeIndexAtOpen, uint256 cumulativeIndexAtClose, address creditAccount) =
            _openCreditAccount();

        evm.assume(quotaLink < type(uint96).max / 2);
        evm.assume(quotaUsdt < type(uint96).max / 2);

        QuotaUpdate[] memory quotaUpdates = new QuotaUpdate[](2);
        quotaUpdates[0] =
            QuotaUpdate({token: tokenTestSuite.addressOf(Tokens.LINK), quotaChange: int96(uint96(quotaLink))});
        quotaUpdates[1] =
            QuotaUpdate({token: tokenTestSuite.addressOf(Tokens.USDT), quotaChange: int96(uint96(quotaUsdt))});

        quotaLink = quotaLink > 1_000_000 * WAD ? uint96(1_000_000 * WAD) : quotaLink;
        quotaUsdt = quotaUsdt > 1_000_000 * WAD ? uint96(1_000_000 * WAD) : quotaUsdt;

        evm.expectCall(
            address(poolQuotaKeeper), abi.encodeCall(IPoolQuotaKeeper.updateQuotas, (creditAccount, quotaUpdates))
        );

        creditManager.updateQuotas(creditAccount, quotaUpdates);

        evm.warp(block.timestamp + 60 * 60 * 24 * 365);

        (,, uint256 totalDebt) = creditManager.calcCreditAccountAccruedInterest(creditAccount);

        uint256 expectedTotalDebt = (borrowedAmount * cumulativeIndexAtClose) / cumulativeIndexAtOpen;
        expectedTotalDebt += (quotaLink * 1000 + quotaUsdt * 500) / PERCENTAGE_FACTOR;

        (uint16 feeInterest,,,,) = creditManager.fees();

        expectedTotalDebt += ((expectedTotalDebt - borrowedAmount) * feeInterest) / PERCENTAGE_FACTOR;

        uint256 diff = expectedTotalDebt > totalDebt ? expectedTotalDebt - totalDebt : totalDebt - expectedTotalDebt;

        assertLe(diff, 2, "Total debt not equal");
    }

    /// @dev [CMQ-11] updateQuotas reverts on too many enabled tokens
    function test_CMQ_11_updateQuotas_reverts_on_too_many_tokens_enabled() public {
        (,,, address creditAccount) = _openCreditAccount();

        uint256 maxTokens = creditManager.maxAllowedEnabledTokenLength();

        QuotaUpdate[] memory quotaUpdates = _addManyLimitedTokens(maxTokens + 1, 100);

        evm.expectRevert(TooManyEnabledTokensException.selector);
        creditManager.updateQuotas(creditAccount, quotaUpdates);
    }
}
