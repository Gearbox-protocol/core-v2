// SPDX-License-Identifier: UNLICENSED
// Gearbox Protocol. Generalized leverage for DeFi protocols
// (c) Gearbox Holdings, 2022
pragma solidity ^0.8.10;

import { ERC20 } from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import { CreditFacade } from "../../credit/CreditFacade.sol";
import { CreditManager } from "../../credit/CreditManager.sol";
import { CreditConfigurator, CreditManagerOpts, CollateralToken } from "../../credit/CreditConfigurator.sol";
import { ICreditManagerV2, ICreditManagerV2Events } from "../../interfaces/ICreditManagerV2.sol";
import { ICreditConfiguratorEvents } from "../../interfaces/ICreditConfigurator.sol";
import { IAdapter } from "../../interfaces/adapters/IAdapter.sol";
import { UniversalAdapter } from "../../adapters/UniversalAdapter.sol";
import { BotList } from "../../support/BotList.sol";

//
import { PercentageMath, PERCENTAGE_FACTOR } from "../../libraries/PercentageMath.sol";
import "../../libraries/Constants.sol";
import { AddressList } from "../../libraries/AddressList.sol";

// EXCEPTIONS
import { ICreditConfiguratorExceptions } from "../../interfaces/ICreditConfigurator.sol";
import { ZeroAddressException, AddressIsNotContractException, CallerNotConfiguratorException, IncorrectPriceFeedException, IncorrectTokenContractException, CallerNotPausableAdminException, CallerNotUnPausableAdminException, CallerNotControllerException } from "../../interfaces/IErrors.sol";
import { ICreditManagerV2Exceptions } from "../../interfaces/ICreditManagerV2.sol";

// TEST
import "../lib/constants.sol";

// MOCKS
import { AdapterMock } from "../mocks/adapters/AdapterMock.sol";
import { TargetContractMock } from "../mocks/adapters/TargetContractMock.sol";

// SUITES
import { TokensTestSuite } from "../suites/TokensTestSuite.sol";
import { Tokens } from "../config/Tokens.sol";
import { CreditFacadeTestSuite } from "../suites/CreditFacadeTestSuite.sol";
import { CreditConfig } from "../config/CreditConfig.sol";

import { CollateralTokensItem } from "../config/CreditConfig.sol";

/// @title CreditConfiguratorTest
/// @notice Designed for unit test purposes only
contract CreditConfiguratorTest is
    DSTest,
    ICreditManagerV2Events,
    ICreditConfiguratorEvents,
    ICreditConfiguratorExceptions
{
    using AddressList for address[];

    CheatCodes evm = CheatCodes(HEVM_ADDRESS);

    TokensTestSuite tokenTestSuite;
    CreditFacadeTestSuite cct;

    CreditManager public creditManager;
    CreditFacade public creditFacade;
    CreditConfigurator public creditConfigurator;
    address underlying;

    AdapterMock adapter1;
    AdapterMock adapterDifferentCM;

    address DUMB_COMPARTIBLE_CONTRACT;
    address TARGET_CONTRACT;

    function setUp() public {
        tokenTestSuite = new TokensTestSuite();
        tokenTestSuite.topUpWETH{ value: 100 * WAD }();

        CreditConfig creditConfig = new CreditConfig(
            tokenTestSuite,
            Tokens.DAI
        );

        cct = new CreditFacadeTestSuite(creditConfig);

        underlying = cct.underlying();
        creditManager = cct.creditManager();
        creditFacade = cct.creditFacade();
        creditConfigurator = cct.creditConfigurator();

        TARGET_CONTRACT = address(new TargetContractMock());

        adapter1 = new AdapterMock(address(creditManager), TARGET_CONTRACT);
        adapterDifferentCM = new AdapterMock(address(this), TARGET_CONTRACT);

        DUMB_COMPARTIBLE_CONTRACT = address(adapter1);
    }

    //
    // HELPERS
    //
    function _compareParams(
        uint16 feeInterest,
        uint16 feeLiquidation,
        uint16 liquidationDiscount,
        uint16 feeLiquidationExpired,
        uint16 liquidationDiscountExpired
    ) internal {
        (
            uint16 feeInterest2,
            uint16 feeLiquidation2,
            uint16 liquidationDiscount2,
            uint16 feeLiquidationExpired2,
            uint16 liquidationDiscountExpired2
        ) = creditManager.fees();

        assertEq(feeInterest2, feeInterest, "Incorrect feeInterest");
        assertEq(feeLiquidation2, feeLiquidation, "Incorrect feeLiquidation");
        assertEq(
            liquidationDiscount2,
            liquidationDiscount,
            "Incorrect liquidationDiscount"
        );
        assertEq(
            feeLiquidationExpired2,
            feeLiquidationExpired,
            "Incorrect feeLiquidationExpired"
        );
        assertEq(
            liquidationDiscountExpired2,
            liquidationDiscountExpired,
            "Incorrect liquidationDiscountExpired"
        );
    }

    function _getAddress(bytes memory bytecode, uint256 _salt)
        public
        view
        returns (address)
    {
        bytes32 hash = keccak256(
            abi.encodePacked(
                bytes1(0xff),
                address(this),
                _salt,
                keccak256(bytecode)
            )
        );

        // NOTE: cast last 20 bytes of hash to address
        return address(uint160(uint256(hash)));
    }

    function _deploy(bytes memory bytecode, uint256 _salt) public payable {
        address addr;

        /*
        NOTE: How to call create2
        create2(v, p, n, s)
        create new contract with code at memory p to p + n
        and send v wei
        and return the new address
        where new address = first 20 bytes of keccak256(0xff + address(this) + s + keccak256(mem[p…(p+n)))
              s = big-endian 256-bit value
        */
        assembly {
            addr := create2(
                callvalue(), // wei sent with current call
                // Actual code starts after skipping the first 32 bytes
                add(bytecode, 0x20),
                mload(bytecode), // Load the size of code contained in the first 32 bytes
                _salt // Salt from function arguments
            )

            if iszero(extcodesize(addr)) {
                revert(0, 0)
            }
        }
    }

    ///
    ///
    ///  TESTS
    ///
    ///

    /// @dev [CC-1]: constructor sets correct values
    function test_CC_01_constructor_sets_correct_values() public {
        assertEq(
            address(creditConfigurator.creditManager()),
            address(creditManager),
            "Incorrect creditManager"
        );

        assertEq(
            address(creditConfigurator.creditFacade()),
            address(creditFacade),
            "Incorrect creditFacade"
        );

        assertEq(
            address(creditConfigurator.underlying()),
            address(creditManager.underlying()),
            "Incorrect underlying"
        );

        assertEq(
            address(creditConfigurator.addressProvider()),
            address(cct.addressProvider()),
            "Incorrect addressProvider"
        );

        // CREDIT MANAGER PARAMS

        (
            uint16 feeInterest,
            uint16 feeLiquidation,
            uint16 liquidationDiscount,
            uint16 feeLiquidationExpired,
            uint16 liquidationDiscountExpired
        ) = creditManager.fees();

        assertEq(feeInterest, DEFAULT_FEE_INTEREST, "Incorrect feeInterest");

        assertEq(
            feeLiquidation,
            DEFAULT_FEE_LIQUIDATION,
            "Incorrect feeLiquidation"
        );

        assertEq(
            liquidationDiscount,
            PERCENTAGE_FACTOR - DEFAULT_LIQUIDATION_PREMIUM,
            "Incorrect liquidationDiscount"
        );

        assertEq(
            feeLiquidationExpired,
            DEFAULT_FEE_LIQUIDATION_EXPIRED,
            "Incorrect feeLiquidationExpired"
        );

        assertEq(
            liquidationDiscountExpired,
            PERCENTAGE_FACTOR - DEFAULT_LIQUIDATION_PREMIUM_EXPIRED,
            "Incorrect liquidationDiscountExpired"
        );

        assertEq(
            address(creditConfigurator.addressProvider()),
            address(cct.addressProvider()),
            "Incorrect address provider"
        );

        CollateralTokensItem[8] memory collateralTokenOpts = [
            CollateralTokensItem({
                token: Tokens.DAI,
                liquidationThreshold: DEFAULT_UNDERLYING_LT
            }),
            CollateralTokensItem({
                token: Tokens.USDC,
                liquidationThreshold: 9000
            }),
            CollateralTokensItem({
                token: Tokens.USDT,
                liquidationThreshold: 8800
            }),
            CollateralTokensItem({
                token: Tokens.WETH,
                liquidationThreshold: 8300
            }),
            CollateralTokensItem({
                token: Tokens.LINK,
                liquidationThreshold: 7300
            }),
            CollateralTokensItem({
                token: Tokens.CRV,
                liquidationThreshold: 7300
            }),
            CollateralTokensItem({
                token: Tokens.CVX,
                liquidationThreshold: 7300
            }),
            CollateralTokensItem({
                token: Tokens.STETH,
                liquidationThreshold: 7300
            })
        ];

        uint256 len = collateralTokenOpts.length;

        // Allowed Tokens
        assertEq(
            creditManager.collateralTokensCount(),
            len,
            "Incorrect quantity of allowed tokens"
        );

        for (uint256 i = 0; i < len; i++) {
            (address token, uint16 lt) = creditManager.collateralTokens(i);

            assertEq(
                token,
                tokenTestSuite.addressOf(collateralTokenOpts[i].token),
                "Incorrect token address"
            );

            assertEq(
                lt,
                collateralTokenOpts[i].liquidationThreshold,
                "Incorrect liquidation threshold"
            );
        }

        assertEq(
            address(creditManager.creditFacade()),
            address(creditFacade),
            "Incorrect creditFacade"
        );

        assertEq(
            address(creditManager.priceOracle()),
            address(cct.priceOracle()),
            "Incorrect creditFacade"
        );

        // CREDIT FACADE PARAMS
        (uint128 minBorrowedAmount, uint128 maxBorrowedAmount) = creditFacade
            .limits();

        assertEq(
            minBorrowedAmount,
            cct.minBorrowedAmount(),
            "Incorrect minBorrowedAmount"
        );

        assertEq(
            maxBorrowedAmount,
            cct.maxBorrowedAmount(),
            "Incorrect maxBorrowedAmount"
        );

        (
            uint128 maxBorrowedAmountPerBlock,
            bool isIncreaseDebtForbidden,
            uint40 expirationDate
        ) = creditFacade.params();

        assertEq(
            maxBorrowedAmountPerBlock,
            DEFAULT_LIMIT_PER_BLOCK_MULTIPLIER * cct.maxBorrowedAmount(),
            "Incorrect  maxBorrowedAmountPerBlock"
        );

        assertTrue(
            isIncreaseDebtForbidden == false,
            "Incorrect isIncreaseDebtForbidden "
        );

        assertEq(expirationDate, 0, "Incorrect expiration date");
    }

    /// @dev [CC-1A]: constructor emits all events
    function test_CC_01A_constructor_emits_all_events() public {
        CollateralToken[] memory cTokens = new CollateralToken[](1);

        cTokens[0] = CollateralToken({
            token: tokenTestSuite.addressOf(Tokens.USDC),
            liquidationThreshold: 6000
        });

        CreditManagerOpts memory creditOpts = CreditManagerOpts({
            minBorrowedAmount: uint128(50 * WAD),
            maxBorrowedAmount: uint128(150000 * WAD),
            collateralTokens: cTokens,
            degenNFT: address(0),
            blacklistHelper: address(0),
            expirable: false
        });

        creditManager = new CreditManager(address(cct.poolMock()));
        creditFacade = new CreditFacade(
            address(creditManager),
            creditOpts.degenNFT,
            creditOpts.blacklistHelper,
            creditOpts.expirable
        );

        address priceOracleAddress = address(creditManager.priceOracle());
        address usdcToken = tokenTestSuite.addressOf(Tokens.USDC);

        bytes memory configuratorByteCode = abi.encodePacked(
            type(CreditConfigurator).creationCode,
            abi.encode(creditManager, creditFacade, creditOpts)
        );

        address creditConfiguratorAddr = _getAddress(configuratorByteCode, 0);

        creditManager.setConfigurator(creditConfiguratorAddr);

        evm.expectEmit(true, false, false, true);
        emit TokenLiquidationThresholdUpdated(
            underlying,
            DEFAULT_UNDERLYING_LT
        );

        evm.expectEmit(false, false, false, false);
        emit FeesUpdated(
            DEFAULT_FEE_INTEREST,
            DEFAULT_FEE_LIQUIDATION,
            DEFAULT_LIQUIDATION_PREMIUM,
            DEFAULT_FEE_LIQUIDATION_EXPIRED,
            DEFAULT_LIQUIDATION_PREMIUM_EXPIRED
        );

        evm.expectEmit(true, false, false, false);
        emit TokenAllowed(usdcToken);

        evm.expectEmit(true, false, false, true);
        emit TokenLiquidationThresholdUpdated(usdcToken, 6000);

        evm.expectEmit(true, false, false, false);
        emit CreditFacadeUpgraded(address(creditFacade));

        evm.expectEmit(true, false, false, false);
        emit PriceOracleUpgraded(priceOracleAddress);

        evm.expectEmit(false, false, false, true);
        emit LimitPerBlockUpdated(
            uint128(150000 * WAD * DEFAULT_LIMIT_PER_BLOCK_MULTIPLIER)
        );

        evm.expectEmit(false, false, false, true);
        emit LimitsUpdated(uint128(50 * WAD), uint128(150000 * WAD));

        _deploy(configuratorByteCode, 0);
    }

    /// @dev [CC-2]: all functions revert if called non-configurator
    function test_CC_02_all_functions_revert_if_called_non_configurator()
        public
    {
        evm.startPrank(USER);

        // Token mgmt

        evm.expectRevert(CallerNotConfiguratorException.selector);
        creditConfigurator.addCollateralToken(DUMB_ADDRESS, 1);

        evm.expectRevert(CallerNotConfiguratorException.selector);
        creditConfigurator.allowToken(DUMB_ADDRESS);

        // Contract mgmt

        evm.expectRevert(CallerNotConfiguratorException.selector);
        creditConfigurator.allowContract(DUMB_ADDRESS, DUMB_ADDRESS);

        // Credit manager mgmt

        evm.expectRevert(CallerNotConfiguratorException.selector);
        creditConfigurator.setFees(0, 0, 0, 0, 0);

        // Upgrades
        evm.expectRevert(CallerNotConfiguratorException.selector);
        creditConfigurator.upgradePriceOracle();

        evm.expectRevert(CallerNotConfiguratorException.selector);
        creditConfigurator.upgradeCreditFacade(DUMB_ADDRESS, false);

        evm.expectRevert(CallerNotConfiguratorException.selector);
        creditConfigurator.upgradeCreditConfigurator(DUMB_ADDRESS);

        evm.expectRevert(CallerNotConfiguratorException.selector);
        creditConfigurator.setBotList(FRIEND);

        evm.stopPrank();
    }

    function test_CC_02A_setIncreaseDebtForbidden_reverts_on_non_pausable_unpausable_admin()
        public
    {
        evm.expectRevert(CallerNotPausableAdminException.selector);
        creditConfigurator.setIncreaseDebtForbidden(true);

        evm.expectRevert(CallerNotPausableAdminException.selector);
        creditConfigurator.setIncreaseDebtForbidden(false);

        evm.prank(CONFIGURATOR);
        creditConfigurator.setIncreaseDebtForbidden(true);

        evm.prank(CONFIGURATOR);
        creditConfigurator.setIncreaseDebtForbidden(false);
    }

    function test_CC_02B_controllerOnly_functions_revert_on_non_controller()
        public
    {
        evm.expectRevert(CallerNotControllerException.selector);
        creditConfigurator.setLiquidationThreshold(DUMB_ADDRESS, uint16(0));

        evm.expectRevert(CallerNotControllerException.selector);
        creditConfigurator.forbidToken(DUMB_ADDRESS);

        evm.expectRevert(CallerNotControllerException.selector);
        creditConfigurator.forbidContract(DUMB_ADDRESS);

        evm.expectRevert(CallerNotControllerException.selector);
        creditConfigurator.setLimits(0, 0);

        evm.expectRevert(CallerNotControllerException.selector);
        creditConfigurator.setLimitPerBlock(0);

        evm.expectRevert(CallerNotControllerException.selector);
        creditConfigurator.setMaxEnabledTokens(1);
    }

    //
    // TOKEN MANAGEMENT
    //

    /// @dev [CC-3]: addCollateralToken reverts for zero address or in priceFeed
    function test_CC_03_addCollateralToken_reverts_for_zero_address_or_in_priceFeed()
        public
    {
        evm.startPrank(CONFIGURATOR);

        evm.expectRevert(ZeroAddressException.selector);
        creditConfigurator.addCollateralToken(address(0), 9300);

        evm.expectRevert(
            abi.encodeWithSelector(
                AddressIsNotContractException.selector,
                DUMB_ADDRESS
            )
        );
        creditConfigurator.addCollateralToken(DUMB_ADDRESS, 9300);

        evm.expectRevert(IncorrectTokenContractException.selector);
        creditConfigurator.addCollateralToken(address(this), 9300);

        address unknownPricefeedToken = address(
            new ERC20("TWPF", "Token without priceFeed")
        );

        evm.expectRevert(IncorrectPriceFeedException.selector);
        creditConfigurator.addCollateralToken(unknownPricefeedToken, 9300);

        evm.stopPrank();
    }

    /// @dev [CC-4]: addCollateralToken adds new token to creditManager
    function test_CC_04_addCollateralToken_adds_new_token_to_creditManager_and_set_lt()
        public
    {
        uint256 tokensCountBefore = creditManager.collateralTokensCount();

        address cLINKToken = tokenTestSuite.addressOf(Tokens.LUNA);

        evm.expectEmit(true, false, false, false);
        emit TokenAllowed(cLINKToken);

        evm.prank(CONFIGURATOR);
        creditConfigurator.addCollateralToken(cLINKToken, 8800);

        assertEq(
            creditManager.collateralTokensCount(),
            tokensCountBefore + 1,
            "Incorrect tokens count"
        );

        (address token, ) = creditManager.collateralTokens(tokensCountBefore);

        assertEq(token, cLINKToken, "Token is not added to list");

        assertTrue(
            creditManager.tokenMasksMap(cLINKToken) > 0,
            "Incorrect token mask"
        );

        assertEq(
            creditManager.liquidationThresholds(cLINKToken),
            8800,
            "Threshold wasn't set"
        );
    }

    /// @dev [CC-5]: setLiquidationThreshold reverts for underling token and incorrect values
    function test_CC_05_setLiquidationThreshold_reverts_for_underling_token_and_incorrect_values()
        public
    {
        evm.startPrank(CONFIGURATOR);

        evm.expectRevert(SetLTForUnderlyingException.selector);
        creditConfigurator.setLiquidationThreshold(underlying, 1);

        address usdcToken = tokenTestSuite.addressOf(Tokens.USDC);

        uint16 maxAllowedLT = creditManager.liquidationThresholds(underlying);
        evm.expectRevert(IncorrectLiquidationThresholdException.selector);
        creditConfigurator.setLiquidationThreshold(usdcToken, maxAllowedLT + 1);

        evm.stopPrank();
    }

    /// @dev [CC-6]: setLiquidationThreshold sets liquidation threshold in creditManager
    function test_CC_06_setLiquidationThreshold_sets_liquidation_threshold_in_creditManager()
        public
    {
        address usdcToken = tokenTestSuite.addressOf(Tokens.USDC);
        uint16 newLT = 24;

        evm.expectEmit(true, false, false, true);
        emit TokenLiquidationThresholdUpdated(usdcToken, newLT);

        evm.prank(CONFIGURATOR);
        creditConfigurator.setLiquidationThreshold(usdcToken, newLT);

        assertEq(creditManager.liquidationThresholds(usdcToken), newLT);
    }

    /// @dev [CC-7]: allowToken and forbidToken reverts for unknown or underlying token
    function test_CC_07_allowToken_and_forbidToken_reverts_for_unknown_or_underlying_token()
        public
    {
        evm.startPrank(CONFIGURATOR);

        evm.expectRevert(
            ICreditManagerV2Exceptions.TokenNotAllowedException.selector
        );
        creditConfigurator.allowToken(DUMB_ADDRESS);

        evm.expectRevert(
            ICreditManagerV2Exceptions.TokenNotAllowedException.selector
        );
        creditConfigurator.allowToken(underlying);

        evm.expectRevert(
            ICreditManagerV2Exceptions.TokenNotAllowedException.selector
        );
        creditConfigurator.forbidToken(DUMB_ADDRESS);

        evm.expectRevert(
            ICreditManagerV2Exceptions.TokenNotAllowedException.selector
        );
        creditConfigurator.forbidToken(underlying);

        evm.stopPrank();
    }

    /// @dev [CC-8]: allowToken doesn't change forbidden mask if its already allowed
    function test_CC_08_allowToken_doesnt_change_forbidden_mask_if_its_already_allowed()
        public
    {
        address usdcToken = tokenTestSuite.addressOf(Tokens.USDC);
        uint256 forbiddenMask = creditManager.forbiddenTokenMask();

        evm.prank(CONFIGURATOR);
        creditConfigurator.allowToken(usdcToken);

        assertEq(
            creditManager.forbiddenTokenMask(),
            forbiddenMask,
            "Incorrect forbidden mask"
        );
    }

    /// @dev [CC-9]: allowToken allows token if it was forbidden
    function test_CC_09_allows_token_if_it_was_forbidden() public {
        address usdcToken = tokenTestSuite.addressOf(Tokens.USDC);
        uint256 tokenMask = creditManager.tokenMasksMap(usdcToken);

        evm.prank(address(creditConfigurator));
        creditManager.setForbidMask(tokenMask);

        evm.expectEmit(true, false, false, false);
        emit TokenAllowed(usdcToken);

        evm.prank(CONFIGURATOR);
        creditConfigurator.allowToken(usdcToken);

        assertEq(
            creditManager.forbiddenTokenMask(),
            0,
            "Incorrect forbidden mask"
        );
    }

    /// @dev [CC-10]: forbidToken doesn't change forbidden mask if its already forbidden
    function test_CC_10_forbidToken_doesnt_change_forbidden_mask_if_its_already_forbidden()
        public
    {
        address usdcToken = tokenTestSuite.addressOf(Tokens.USDC);
        uint256 tokenMask = creditManager.tokenMasksMap(usdcToken);

        evm.prank(address(creditConfigurator));
        creditManager.setForbidMask(tokenMask);

        uint256 forbiddenMask = creditManager.forbiddenTokenMask();

        evm.prank(CONFIGURATOR);
        creditConfigurator.forbidToken(usdcToken);

        assertEq(
            creditManager.forbiddenTokenMask(),
            forbiddenMask,
            "Incorrect forbidden mask"
        );
    }

    /// @dev [CC-11]: forbidToken forbids token and enable IncreaseDebtForbidden mode if it was allowed
    function test_CC_11_forbidToken_forbids_token_if_it_was_allowed() public {
        address usdcToken = tokenTestSuite.addressOf(Tokens.USDC);
        uint256 tokenMask = creditManager.tokenMasksMap(usdcToken);

        evm.prank(address(creditConfigurator));
        creditManager.setForbidMask(0);

        evm.expectEmit(true, false, false, false);
        emit TokenForbidden(usdcToken);

        evm.prank(CONFIGURATOR);
        creditConfigurator.forbidToken(usdcToken);

        assertEq(
            creditManager.forbiddenTokenMask(),
            tokenMask,
            "Incorrect forbidden mask"
        );
    }

    //
    // CONFIGURATION: CONTRACTS & ADAPTERS MANAGEMENT
    //

    /// @dev [CC-12]: allowContract and forbidContract reverts for zero address
    function test_CC_12_allowContract_and_forbidContract_reverts_for_zero_address()
        public
    {
        evm.startPrank(CONFIGURATOR);

        evm.expectRevert(ZeroAddressException.selector);
        creditConfigurator.allowContract(address(0), address(this));

        evm.expectRevert(ZeroAddressException.selector);
        creditConfigurator.allowContract(address(this), address(0));

        evm.expectRevert(ZeroAddressException.selector);
        creditConfigurator.forbidContract(address(0));

        evm.stopPrank();
    }

    /// @dev [CC-12A]: allowContract reverts for non contract addresses
    function test_CC_12A_allowContract_reverts_for_non_contract_addresses()
        public
    {
        evm.startPrank(CONFIGURATOR);

        evm.expectRevert(
            abi.encodeWithSelector(
                AddressIsNotContractException.selector,
                DUMB_ADDRESS
            )
        );
        creditConfigurator.allowContract(address(this), DUMB_ADDRESS);

        evm.expectRevert(
            abi.encodeWithSelector(
                AddressIsNotContractException.selector,
                DUMB_ADDRESS
            )
        );
        creditConfigurator.allowContract(DUMB_ADDRESS, address(this));

        evm.stopPrank();
    }

    /// @dev [CC-12B]: allowContract reverts for non compartible adapter contract
    function test_CC_12B_allowContract_reverts_for_non_compartible_adapter_contract()
        public
    {
        evm.startPrank(CONFIGURATOR);

        // Should be reverted, cause undelring token has no .creditManager() method
        evm.expectRevert(IncompatibleContractException.selector);
        creditConfigurator.allowContract(address(this), underlying);

        // Should be reverted, cause it's conncted to another creditManager
        evm.expectRevert(IncompatibleContractException.selector);
        creditConfigurator.allowContract(
            address(this),
            address(adapterDifferentCM)
        );

        evm.stopPrank();
    }

    /// @dev [CC-13]: allowContract reverts for creditManager and creditFacade contracts
    function test_CC_13_allowContract_reverts_for_creditManager_and_creditFacade_contracts()
        public
    {
        evm.startPrank(CONFIGURATOR);

        evm.expectRevert(
            CreditManagerOrFacadeUsedAsTargetContractsException.selector
        );
        creditConfigurator.allowContract(
            address(creditManager),
            DUMB_COMPARTIBLE_CONTRACT
        );

        evm.expectRevert(
            CreditManagerOrFacadeUsedAsTargetContractsException.selector
        );
        creditConfigurator.allowContract(
            DUMB_COMPARTIBLE_CONTRACT,
            address(creditFacade)
        );

        evm.expectRevert(
            CreditManagerOrFacadeUsedAsTargetContractsException.selector
        );
        creditConfigurator.allowContract(
            address(creditFacade),
            DUMB_COMPARTIBLE_CONTRACT
        );

        evm.stopPrank();
    }

    /// @dev [CC-14]: allowContract: adapter could not be used twice
    function test_CC_14_allowContract_adapter_cannot_be_used_twice() public {
        evm.startPrank(CONFIGURATOR);

        creditConfigurator.allowContract(
            DUMB_COMPARTIBLE_CONTRACT,
            address(adapter1)
        );

        evm.expectRevert(AdapterUsedTwiceException.selector);
        creditConfigurator.allowContract(
            address(adapterDifferentCM),
            address(adapter1)
        );

        evm.stopPrank();
    }

    /// @dev [CC-15]: allowContract allows targetContract <-> adapter and emits event
    function test_CC_15_allowContract_allows_targetContract_adapter_and_emits_event()
        public
    {
        address[] memory allowedContracts = creditConfigurator
            .allowedContracts();
        uint256 allowedContractCount = allowedContracts.length;

        evm.prank(CONFIGURATOR);

        evm.expectEmit(true, true, false, false);
        emit ContractAllowed(TARGET_CONTRACT, address(adapter1));

        assertTrue(
            !allowedContracts.includes(TARGET_CONTRACT),
            "Contract already added"
        );

        creditConfigurator.allowContract(TARGET_CONTRACT, address(adapter1));

        assertEq(
            creditManager.adapterToContract(address(adapter1)),
            TARGET_CONTRACT,
            "adapterToContract wasn't udpated"
        );

        assertEq(
            creditManager.contractToAdapter(TARGET_CONTRACT),
            address(adapter1),
            "contractToAdapter wasn't udpated"
        );

        allowedContracts = creditConfigurator.allowedContracts();

        assertEq(
            allowedContracts.length,
            allowedContractCount + 1,
            "Incorrect allowed contracts count"
        );

        assertTrue(
            allowedContracts.includes(TARGET_CONTRACT),
            "Target contract wasnt found"
        );
    }

    /// @dev [CC-15A]: allowContract allows universal adapter for universal contract
    function test_CC_15A_allowContract_allows_universal_contract() public {
        evm.prank(CONFIGURATOR);

        evm.expectEmit(true, true, false, false);
        emit ContractAllowed(UNIVERSAL_CONTRACT, address(adapter1));

        creditConfigurator.allowContract(UNIVERSAL_CONTRACT, address(adapter1));

        assertEq(
            creditManager.universalAdapter(),
            address(adapter1),
            "Universal adapter wasn't updated"
        );
    }

    /// @dev [CC-15A]: allowContract removes existing adapter
    function test_CC_15A_allowContract_removes_old_adapter_if_it_exists()
        public
    {
        evm.prank(CONFIGURATOR);
        creditConfigurator.allowContract(TARGET_CONTRACT, address(adapter1));

        AdapterMock adapter2 = new AdapterMock(
            address(creditManager),
            TARGET_CONTRACT
        );

        evm.prank(CONFIGURATOR);
        creditConfigurator.allowContract(TARGET_CONTRACT, address(adapter2));

        assertEq(
            creditManager.contractToAdapter(TARGET_CONTRACT),
            address(adapter2),
            "Incorrect adapter"
        );

        assertEq(
            creditManager.adapterToContract(address(adapter2)),
            TARGET_CONTRACT,
            "Incorrect target contract for new adapter"
        );

        assertEq(
            creditManager.adapterToContract(address(adapter1)),
            address(0),
            "Old adapter was not removed"
        );
    }

    /// @dev [CC-16]: forbidContract reverts for unknown contract
    function test_CC_16_forbidContract_reverts_for_unknown_contract() public {
        evm.expectRevert(ContractIsNotAnAllowedAdapterException.selector);

        evm.prank(CONFIGURATOR);
        creditConfigurator.forbidContract(TARGET_CONTRACT);
    }

    /// @dev [CC-17]: forbidContract forbids contract and emits event
    function test_CC_17_forbidContract_forbids_contract_and_emits_event()
        public
    {
        evm.startPrank(CONFIGURATOR);
        creditConfigurator.allowContract(
            DUMB_COMPARTIBLE_CONTRACT,
            address(adapter1)
        );

        address[] memory allowedContracts = creditConfigurator
            .allowedContracts();

        uint256 allowedContractCount = allowedContracts.length;

        assertTrue(
            allowedContracts.includes(DUMB_COMPARTIBLE_CONTRACT),
            "Target contract wasnt found"
        );

        evm.expectEmit(true, false, false, false);
        emit ContractForbidden(DUMB_COMPARTIBLE_CONTRACT);

        creditConfigurator.forbidContract(DUMB_COMPARTIBLE_CONTRACT);

        //
        allowedContracts = creditConfigurator.allowedContracts();

        assertEq(
            creditManager.adapterToContract(address(adapter1)),
            address(0),
            "CreditManager wasn't udpated"
        );

        assertEq(
            creditManager.contractToAdapter(DUMB_COMPARTIBLE_CONTRACT),
            address(0),
            "CreditFacade wasn't udpated"
        );

        assertEq(
            allowedContracts.length,
            allowedContractCount - 1,
            "Incorrect allowed contracts count"
        );

        assertTrue(
            !allowedContracts.includes(DUMB_COMPARTIBLE_CONTRACT),
            "Target contract wasn't removed"
        );

        evm.stopPrank();
    }

    //
    // CREDIT MANAGER MGMT
    //

    /// @dev [CC-18]: setLimits reverts if minAmount > maxAmount or maxBorrowedAmount > blockLimit
    function test_CC_18_setLimits_reverts_if_minAmount_gt_maxAmount_or_maxBorrowedAmount_gt_blockLimit()
        public
    {
        (uint128 minBorrowedAmount, uint128 maxBorrowedAmount) = creditFacade
            .limits();

        evm.expectRevert(IncorrectLimitsException.selector);

        evm.prank(CONFIGURATOR);
        creditConfigurator.setLimits(maxBorrowedAmount, minBorrowedAmount);

        (uint128 blockLimit, , ) = creditFacade.params();
        evm.expectRevert(IncorrectLimitsException.selector);

        evm.prank(CONFIGURATOR);
        creditConfigurator.setLimits(minBorrowedAmount, blockLimit + 1);
    }

    /// @dev [CC-19]: setLimits sets limits
    function test_CC_19_setLimits_sets_limits() public {
        (uint128 minBorrowedAmount, uint128 maxBorrowedAmount) = creditFacade
            .limits();
        uint128 newMinBorrowedAmount = minBorrowedAmount + 1000;
        uint128 newMaxBorrowedAmount = maxBorrowedAmount + 1000;

        evm.expectEmit(false, false, false, true);
        emit LimitsUpdated(newMinBorrowedAmount, newMaxBorrowedAmount);
        evm.prank(CONFIGURATOR);
        creditConfigurator.setLimits(
            newMinBorrowedAmount,
            newMaxBorrowedAmount
        );
        (minBorrowedAmount, maxBorrowedAmount) = creditFacade.limits();
        assertEq(
            minBorrowedAmount,
            newMinBorrowedAmount,
            "Incorrect minBorrowedAmount"
        );
        assertEq(
            maxBorrowedAmount,
            newMaxBorrowedAmount,
            "Incorrect maxBorrowedAmount"
        );
    }

    /// @dev [CC-23]: setFees reverts for incorrect fees
    function test_CC_23_setFees_reverts_for_incorrect_fees() public {
        (
            ,
            uint16 feeLiquidation,
            ,
            uint16 feeLiquidationExpired,

        ) = creditManager.fees();

        evm.expectRevert(IncorrectFeesException.selector);

        evm.prank(CONFIGURATOR);
        creditConfigurator.setFees(PERCENTAGE_FACTOR, feeLiquidation, 0, 0, 0);

        evm.expectRevert(IncorrectFeesException.selector);

        evm.prank(CONFIGURATOR);
        creditConfigurator.setFees(
            PERCENTAGE_FACTOR - 1,
            feeLiquidation,
            PERCENTAGE_FACTOR - feeLiquidation,
            0,
            0
        );

        evm.expectRevert(IncorrectFeesException.selector);

        evm.prank(CONFIGURATOR);
        creditConfigurator.setFees(
            PERCENTAGE_FACTOR - 1,
            feeLiquidation,
            PERCENTAGE_FACTOR - feeLiquidation - 1,
            feeLiquidationExpired,
            PERCENTAGE_FACTOR - feeLiquidationExpired
        );
    }

    /// @dev [CC-25]: setFees updates LT for underlying and for all tokens which bigger than new LT
    function test_CC_25_setFees_updates_LT_for_underlying_and_for_all_tokens_which_bigger_than_new_LT()
        public
    {
        evm.startPrank(CONFIGURATOR);

        (uint16 feeInterest, , , , ) = creditManager.fees();

        address usdcToken = tokenTestSuite.addressOf(Tokens.USDC);
        address wethToken = tokenTestSuite.addressOf(Tokens.WETH);
        creditConfigurator.setLiquidationThreshold(
            usdcToken,
            creditManager.liquidationThresholds(underlying)
        );

        uint256 expectedLT = PERCENTAGE_FACTOR -
            DEFAULT_LIQUIDATION_PREMIUM -
            2 *
            DEFAULT_FEE_LIQUIDATION;

        uint256 wethLTBefore = creditManager.liquidationThresholds(wethToken);

        evm.expectEmit(true, false, false, true);
        emit TokenLiquidationThresholdUpdated(usdcToken, uint16(expectedLT));

        evm.expectEmit(true, false, false, true);
        emit TokenLiquidationThresholdUpdated(underlying, uint16(expectedLT));

        creditConfigurator.setFees(
            feeInterest,
            2 * DEFAULT_FEE_LIQUIDATION,
            DEFAULT_LIQUIDATION_PREMIUM,
            DEFAULT_FEE_LIQUIDATION_EXPIRED,
            DEFAULT_LIQUIDATION_PREMIUM_EXPIRED
        );

        assertEq(
            creditManager.liquidationThresholds(underlying),
            expectedLT,
            "Incorrect LT for underlying token"
        );

        assertEq(
            creditManager.liquidationThresholds(usdcToken),
            expectedLT,
            "Incorrect USDC for underlying token"
        );

        assertEq(
            creditManager.liquidationThresholds(wethToken),
            wethLTBefore,
            "Incorrect WETH for underlying token"
        );
    }

    /// @dev [CC-26]: setFees sets fees and doesn't change others
    function test_CC_26_setFees_sets_fees_and_doesnt_change_others() public {
        (
            uint16 feeInterest,
            uint16 feeLiquidation,
            uint16 liquidationDiscount,
            uint16 feeLiquidationExpired,
            uint16 liquidationDiscountExpired
        ) = creditManager.fees();

        uint16 newFeeInterest = (feeInterest * 3) / 2;
        uint16 newFeeLiquidation = feeLiquidation * 2;
        uint16 newLiquidationPremium = (PERCENTAGE_FACTOR -
            liquidationDiscount) * 2;
        uint16 newFeeLiquidationExpired = feeLiquidationExpired * 2;
        uint16 newLiquidationPremiumExpired = (PERCENTAGE_FACTOR -
            liquidationDiscountExpired) * 2;

        evm.expectEmit(false, false, false, true);
        emit FeesUpdated(
            newFeeInterest,
            newFeeLiquidation,
            newLiquidationPremium,
            newFeeLiquidationExpired,
            newLiquidationPremiumExpired
        );

        evm.prank(CONFIGURATOR);
        creditConfigurator.setFees(
            newFeeInterest,
            newFeeLiquidation,
            newLiquidationPremium,
            newFeeLiquidationExpired,
            newLiquidationPremiumExpired
        );

        _compareParams(
            newFeeInterest,
            newFeeLiquidation,
            PERCENTAGE_FACTOR - newLiquidationPremium,
            newFeeLiquidationExpired,
            PERCENTAGE_FACTOR - newLiquidationPremiumExpired
        );
    }

    //
    // CONTRACT UPGRADES
    //

    /// @dev [CC-28]: upgradePriceOracle upgrades priceOracleCorrectly and doesnt change facade
    function test_CC_28_upgradePriceOracle_upgrades_priceOracleCorrectly_and_doesnt_change_facade()
        public
    {
        evm.startPrank(CONFIGURATOR);
        cct.addressProvider().setPriceOracle(DUMB_ADDRESS);

        evm.expectEmit(true, false, false, false);
        emit PriceOracleUpgraded(DUMB_ADDRESS);

        creditConfigurator.upgradePriceOracle();

        assertEq(address(creditManager.priceOracle()), DUMB_ADDRESS);
        evm.stopPrank();
    }

    /// @dev [CC-29]: upgradePriceOracle upgrades priceOracleCorrectly and doesnt change facade
    function test_CC_29_upgradeCreditFacade_upgradeCreditConfigurator_reverts_for_incompatible_contracts()
        public
    {
        evm.startPrank(CONFIGURATOR);

        evm.expectRevert(ZeroAddressException.selector);
        creditConfigurator.upgradeCreditFacade(address(0), false);

        evm.expectRevert(ZeroAddressException.selector);
        creditConfigurator.upgradeCreditConfigurator(address(0));

        evm.expectRevert(
            abi.encodeWithSelector(
                AddressIsNotContractException.selector,
                DUMB_ADDRESS
            )
        );
        creditConfigurator.upgradeCreditFacade(DUMB_ADDRESS, false);

        evm.expectRevert(
            abi.encodeWithSelector(
                AddressIsNotContractException.selector,
                DUMB_ADDRESS
            )
        );
        creditConfigurator.upgradeCreditConfigurator(DUMB_ADDRESS);

        evm.expectRevert(IncompatibleContractException.selector);
        creditConfigurator.upgradeCreditFacade(underlying, false);

        evm.expectRevert(IncompatibleContractException.selector);
        creditConfigurator.upgradeCreditConfigurator(underlying);

        evm.expectRevert(IncompatibleContractException.selector);
        creditConfigurator.upgradeCreditFacade(
            address(adapterDifferentCM),
            false
        );

        evm.expectRevert(IncompatibleContractException.selector);
        creditConfigurator.upgradeCreditConfigurator(
            address(adapterDifferentCM)
        );
    }

    /// @dev [CC-30]: upgradeCreditFacade upgrades creditFacade and doesnt change priceOracle
    function test_CC_30_upgradeCreditFacade_upgrades_creditFacade_and_doesnt_change_priceOracle()
        public
    {
        for (uint256 id = 0; id < 2; id++) {
            bool isIDF = id != 0;
            for (uint256 ex = 0; ex < 2; ex++) {
                bool isExpirable = ex != 0;
                for (uint256 ms = 0; ms < 2; ms++) {
                    bool migrateSettings = ms != 0;

                    setUp();

                    if (isExpirable) {
                        CreditFacade initialCf = new CreditFacade(
                            address(creditManager),
                            address(0),
                            address(0),
                            true
                        );

                        evm.prank(CONFIGURATOR);
                        creditConfigurator.upgradeCreditFacade(
                            address(initialCf),
                            migrateSettings
                        );

                        evm.prank(CONFIGURATOR);
                        creditConfigurator.setExpirationDate(
                            uint40(block.timestamp + 1)
                        );

                        creditFacade = initialCf;
                    }

                    CreditFacade cf = new CreditFacade(
                        address(creditManager),
                        address(0),
                        address(0),
                        isExpirable
                    );

                    evm.prank(CONFIGURATOR);
                    creditConfigurator.setIncreaseDebtForbidden(isIDF);

                    (
                        uint128 limitPerBlock,
                        bool isIncreaseDebtFobidden,
                        uint40 expirationDate
                    ) = creditFacade.params();
                    (
                        uint128 minBorrowedAmount,
                        uint128 maxBorrowedAmount
                    ) = creditFacade.limits();

                    evm.expectEmit(true, false, false, false);
                    emit CreditFacadeUpgraded(address(cf));

                    evm.prank(CONFIGURATOR);
                    creditConfigurator.upgradeCreditFacade(
                        address(cf),
                        migrateSettings
                    );

                    assertEq(
                        address(creditManager.priceOracle()),
                        cct.addressProvider().getPriceOracle()
                    );

                    assertEq(
                        address(creditManager.creditFacade()),
                        address(cf)
                    );
                    assertEq(
                        address(creditConfigurator.creditFacade()),
                        address(cf)
                    );

                    (
                        uint128 limitPerBlock2,
                        bool isIncreaseDebtFobidden2,
                        uint40 expirationDate2
                    ) = cf.params();
                    (
                        uint128 minBorrowedAmount2,
                        uint128 maxBorrowedAmount2
                    ) = cf.limits();

                    assertEq(
                        limitPerBlock2,
                        migrateSettings ? limitPerBlock : 0,
                        "Incorrwect limitPerBlock"
                    );
                    assertEq(
                        minBorrowedAmount2,
                        migrateSettings ? minBorrowedAmount : 0,
                        "Incorrwect minBorrowedAmount"
                    );
                    assertEq(
                        maxBorrowedAmount2,
                        migrateSettings ? maxBorrowedAmount : 0,
                        "Incorrwect maxBorrowedAmount"
                    );

                    assertTrue(
                        isIncreaseDebtFobidden2 ==
                            (migrateSettings ? isIncreaseDebtFobidden : false),
                        "Incorrect isIncreaseDebtFobidden"
                    );

                    assertEq(
                        expirationDate2,
                        migrateSettings ? expirationDate : 0,
                        "Incorrect expirationDate"
                    );
                }
            }
        }
    }

    /// @dev [CC-30A]: uupgradeCreditFacade transfers bot list
    function test_CC_30A_botList_is_transferred_on_CreditFacade_upgrade()
        public
    {
        for (uint256 ms = 0; ms < 2; ms++) {
            bool migrateSettings = ms != 0;

            setUp();

            address botList = address(
                new BotList(address(cct.addressProvider()))
            );

            evm.prank(CONFIGURATOR);
            creditConfigurator.setBotList(botList);

            CreditFacade cf = new CreditFacade(
                address(creditManager),
                address(0),
                address(0),
                false
            );

            evm.prank(CONFIGURATOR);
            creditConfigurator.upgradeCreditFacade(
                address(cf),
                migrateSettings
            );

            address botList2 = cf.botList();

            assertEq(
                botList2,
                migrateSettings ? botList : address(0),
                "Bot list was not transferred"
            );
        }
    }

    /// @dev [CC-31]: uupgradeCreditConfigurator upgrades creditConfigurator
    function test_CC_31_upgradeCreditConfigurator_upgrades_creditConfigurator()
        public
    {
        evm.expectEmit(true, false, false, false);
        emit CreditConfiguratorUpgraded(DUMB_COMPARTIBLE_CONTRACT);

        evm.prank(CONFIGURATOR);
        creditConfigurator.upgradeCreditConfigurator(DUMB_COMPARTIBLE_CONTRACT);

        assertEq(
            address(creditManager.creditConfigurator()),
            DUMB_COMPARTIBLE_CONTRACT
        );
    }

    /// @dev [CC-32]: setIncreaseDebtForbidden sets IncreaseDebtForbidden
    function test_CC_32_setIncreaseDebtForbidden_sets_IncreaseDebtForbidden()
        public
    {
        for (uint256 id = 0; id < 2; id++) {
            bool isIDF = id != 0;
            for (uint256 ii = 0; ii < 2; ii++) {
                bool initialIDF = ii != 0;

                setUp();

                evm.prank(CONFIGURATOR);
                creditConfigurator.setIncreaseDebtForbidden(initialIDF);

                (, bool isIncreaseDebtFobidden, ) = creditFacade.params();

                if (isIncreaseDebtFobidden != isIDF) {
                    evm.expectEmit(false, false, false, true);
                    emit IncreaseDebtForbiddenModeChanged(isIDF);
                }

                evm.prank(CONFIGURATOR);
                creditConfigurator.setIncreaseDebtForbidden(isIDF);

                (, isIncreaseDebtFobidden, ) = creditFacade.params();

                assertTrue(
                    isIncreaseDebtFobidden == isIDF,
                    "Incorrect isIncreaseDebtFobidden"
                );
            }
        }
    }

    /// @dev [CC-33]: setLimitPerBlock reverts if it lt maxLimit otherwise sets limitPerBlock
    function test_CC_33_setLimitPerBlock_reverts_if_it_lt_maxLimit_otherwise_sets_limitPerBlock()
        public
    {
        (, uint128 maxBorrowedAmount) = creditFacade.limits();

        evm.prank(CONFIGURATOR);
        evm.expectRevert(IncorrectLimitsException.selector);
        creditConfigurator.setLimitPerBlock(maxBorrowedAmount - 1);

        uint128 newLimitBlock = (maxBorrowedAmount * 12) / 10;

        evm.expectEmit(false, false, false, true);
        emit LimitPerBlockUpdated(newLimitBlock);

        evm.prank(CONFIGURATOR);
        creditConfigurator.setLimitPerBlock(newLimitBlock);

        (uint128 maxBorrowedAmountPerBlock, , ) = creditFacade.params();

        assertEq(
            maxBorrowedAmountPerBlock,
            newLimitBlock,
            "Incorrect new limits block"
        );
    }

    /// @dev [CC-34]: setExpirationDate reverts if the new expiration date is stale, otherwise sets it
    function test_CC_34_setExpirationDate_reverts_on_incorrect_newExpirationDate_otherwise_sets()
        public
    {
        cct.testFacadeWithExpiration();
        creditFacade = cct.creditFacade();

        (, , uint40 expirationDate) = creditFacade.params();

        evm.prank(CONFIGURATOR);
        evm.expectRevert(IncorrectExpirationDateException.selector);
        creditConfigurator.setExpirationDate(expirationDate);

        evm.warp(block.timestamp + 10);

        evm.prank(CONFIGURATOR);
        evm.expectRevert(IncorrectExpirationDateException.selector);
        creditConfigurator.setExpirationDate(expirationDate + 1);

        uint40 newExpirationDate = uint40(block.timestamp + 1);

        evm.expectEmit(false, false, false, true);
        emit ExpirationDateUpdated(newExpirationDate);

        evm.prank(CONFIGURATOR);
        creditConfigurator.setExpirationDate(newExpirationDate);

        (, , expirationDate) = creditFacade.params();

        assertEq(
            expirationDate,
            newExpirationDate,
            "Incorrect new expirationDate"
        );
    }

    /// @dev [CC-37]: setMaxEnabledTokens works correctly and emits event
    function test_CC_37_setMaxEnabledTokens_works_correctly() public {
        evm.expectRevert(CallerNotControllerException.selector);
        creditConfigurator.setMaxEnabledTokens(255);

        evm.expectEmit(false, false, false, true);
        emit MaxEnabledTokensUpdated(255);

        evm.prank(CONFIGURATOR);
        creditConfigurator.setMaxEnabledTokens(255);

        assertEq(
            creditManager.maxAllowedEnabledTokenLength(),
            255,
            "Credit manager max enabled tokens incorrect"
        );
    }

    /// @dev [CC-38]: addEmergencyLiquidator works correctly and emits event
    function test_CC_38_addEmergencyLiquidator_works_correctly() public {
        evm.expectRevert(CallerNotConfiguratorException.selector);
        creditConfigurator.addEmergencyLiquidator(DUMB_ADDRESS);

        evm.expectEmit(false, false, false, true);
        emit EmergencyLiquidatorAdded(DUMB_ADDRESS);

        evm.prank(CONFIGURATOR);
        creditConfigurator.addEmergencyLiquidator(DUMB_ADDRESS);

        assertTrue(
            creditManager.canLiquidateWhilePaused(DUMB_ADDRESS),
            "Credit manager emergency liquidator status incorrect"
        );
    }

    /// @dev [CC-39]: removeEmergencyLiquidator works correctly and emits event
    function test_CC_39_removeEmergencyLiquidator_works_correctly() public {
        evm.expectRevert(CallerNotConfiguratorException.selector);
        creditConfigurator.removeEmergencyLiquidator(DUMB_ADDRESS);

        evm.prank(CONFIGURATOR);
        creditConfigurator.addEmergencyLiquidator(DUMB_ADDRESS);

        evm.expectEmit(false, false, false, true);
        emit EmergencyLiquidatorRemoved(DUMB_ADDRESS);

        evm.prank(CONFIGURATOR);
        creditConfigurator.removeEmergencyLiquidator(DUMB_ADDRESS);

        assertTrue(
            !creditManager.canLiquidateWhilePaused(DUMB_ADDRESS),
            "Credit manager emergency liquidator status incorrect"
        );
    }

    /// @dev [CC-40]: forbidAdapter works correctly and emits event
    function test_CC_40_forbidAdapter_works_correctly() public {
        evm.expectRevert(CallerNotConfiguratorException.selector);
        creditConfigurator.forbidAdapter(DUMB_ADDRESS);

        evm.prank(CONFIGURATOR);
        creditConfigurator.allowContract(TARGET_CONTRACT, address(adapter1));

        evm.expectEmit(true, false, false, false);
        emit AdapterForbidden(address(adapter1));

        evm.prank(CONFIGURATOR);
        creditConfigurator.forbidAdapter(address(adapter1));

        assertEq(
            creditManager.adapterToContract(address(adapter1)),
            address(0),
            "Adapter to contract link was not removed"
        );

        assertEq(
            creditManager.contractToAdapter(TARGET_CONTRACT),
            address(adapter1),
            "Contract to adapter link was removed"
        );
    }

    /// @dev [CC-41]: allowedContracts migrate correctly
    function test_CC_41_allowedContracts_are_migrated_correctly_for_new_CC()
        public
    {
        evm.prank(CONFIGURATOR);
        creditConfigurator.allowContract(TARGET_CONTRACT, address(adapter1));

        CollateralToken[] memory cTokens;

        CreditManagerOpts memory creditOpts = CreditManagerOpts({
            minBorrowedAmount: uint128(50 * WAD),
            maxBorrowedAmount: uint128(150000 * WAD),
            collateralTokens: cTokens,
            degenNFT: address(0),
            blacklistHelper: address(0),
            expirable: false
        });

        CreditConfigurator newCC = new CreditConfigurator(
            creditManager,
            creditFacade,
            creditOpts
        );

        assertEq(
            creditConfigurator.allowedContracts().length,
            newCC.allowedContracts().length,
            "Incorrect new allowed contracts array"
        );

        uint256 len = newCC.allowedContracts().length;

        for (uint256 i = 0; i < len; ) {
            assertEq(
                creditConfigurator.allowedContracts()[i],
                newCC.allowedContracts()[i],
                "Allowed contracts migrated incorrectly"
            );

            unchecked {
                ++i;
            }
        }
    }
}
