// SPDX-License-Identifier: UNLICENSED
// Gearbox Protocol. Generalized leverage for DeFi protocols
// (c) Gearbox Holdings, 2022
pragma solidity ^0.8.10;

import { IAddressProvider } from "../../interfaces/IAddressProvider.sol";
import { IDataCompressor } from "../../interfaces/IDataCompressor.sol";
import { ICreditManagerV2 } from "../../interfaces/ICreditManagerV2.sol";
import { ICreditFacade } from "../../interfaces/ICreditFacade.sol";
import { IPoolService } from "../../interfaces/IPoolService.sol";
import { IPriceOracleV2 } from "../../interfaces/IPriceOracle.sol";
import { IDegenNFT } from "../../interfaces/IDegenNFT.sol";

import { IERC20Metadata } from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/utils/Strings.sol";

import { CreditManagerData, CreditAccountData } from "../../libraries/Types.sol";
import { Balance, BalanceOps } from "../../libraries/Balances.sol";
import { MultiCall, MultiCallOps } from "../../libraries/MultiCall.sol";
import { AddressList } from "../../libraries/AddressList.sol";
import { PERCENTAGE_FACTOR } from "../../libraries/PercentageMath.sol";
import { Test } from "forge-std/Test.sol";

import "../lib/constants.sol";

address constant ADDRESS_PROVIDER = 0xcF64698AFF7E5f27A11dff868AF228653ba53be0;
address constant MAINNET_USDC = 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48;
address constant MAINNET_WETH = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;
address constant MAINNET_DAI = 0x6B175474E89094C44Da98b954EedeAC495271d0F;
address constant MAINNET_FRAX = 0x853d955aCEf822Db058eb8505911ED77F175b99e;

// minimum available liquidity in pool in usd
uint256 constant MIN_POOL_LIQ_USD = 1e14;

// copied from router repo
struct RouterResult {
    uint256 amount;
    uint256 gasUsage;
    MultiCall[] calls;
}

interface IRouter {
    // copied from router repo
    function findOpenStrategyPath(
        address creditManager,
        Balance[] calldata balances,
        address target,
        address[] calldata connectors,
        uint256 slippage
    ) external returns (Balance[] memory, RouterResult memory);
}

contract RouterLiveTest is Test {
    using BalanceOps for Balance[];
    using MultiCallOps for MultiCall[];
    using AddressList for address[];

    // cm -> tokens
    mapping(address => mapping(address => bool)) expectedReverts;

    IAddressProvider addressProvider;
    IDataCompressor dataCompressor;
    IPriceOracleV2 oracle;
    IRouter router;

    constructor() {
        addressProvider = IAddressProvider(ADDRESS_PROVIDER);
        dataCompressor = IDataCompressor(addressProvider.getDataCompressor());
        router = IRouter(addressProvider.getLeveragedActions());
        oracle = IPriceOracleV2(addressProvider.getPriceOracle());

        // DAI
        expectedReverts[0x672461Bfc20DD783444a830Ad4c38b345aB6E2f7][
            0x4e3FBD56CD56c3e72c1403e103b45Db9da5B9D2B
        ] = true; // cvx
        // USDC
        expectedReverts[0x95357303f995e184A7998dA6C6eA35cC728A1900][
            0x4e3FBD56CD56c3e72c1403e103b45Db9da5B9D2B
        ] = true; // cvx
        // WETH
        expectedReverts[0x5887ad4Cb2352E7F01527035fAa3AE0Ef2cE2b9B][
            0x4e3FBD56CD56c3e72c1403e103b45Db9da5B9D2B
        ] = true; // cvx
        // wstETH
        expectedReverts[0xe0bCE4460795281d39c91da9B0275BcA968293de][
            0x056Fd409E1d7A124BD7017459dFEa2F387b6d5Cd
        ] = true; // gusd
        expectedReverts[0xe0bCE4460795281d39c91da9B0275BcA968293de][
            0x4e3FBD56CD56c3e72c1403e103b45Db9da5B9D2B
        ] = true; // cvx
        expectedReverts[0xe0bCE4460795281d39c91da9B0275BcA968293de][
            0xD533a949740bb3306d119CC777fa900bA034cd52
        ] = true; // crv
        // WBTC
        expectedReverts[0xc62BF8a7889AdF1c5Dc4665486c7683ae6E74e0F][
            0x4e3FBD56CD56c3e72c1403e103b45Db9da5B9D2B
        ] = true; // cvx
        expectedReverts[0xc62BF8a7889AdF1c5Dc4665486c7683ae6E74e0F][
            0xD533a949740bb3306d119CC777fa900bA034cd52
        ] = true; // crv
        // FRAX
        expectedReverts[0xA3E1e0d58FE8dD8C9dd48204699a1178f1B274D8][
            0xae7ab96520DE3A18E5e111B5EaAb095312D7fE84
        ] = true; // stETH
        expectedReverts[0xA3E1e0d58FE8dD8C9dd48204699a1178f1B274D8][
            0xD533a949740bb3306d119CC777fa900bA034cd52
        ] = true; // crv
        expectedReverts[0xA3E1e0d58FE8dD8C9dd48204699a1178f1B274D8][
            0x4e3FBD56CD56c3e72c1403e103b45Db9da5B9D2B
        ] = true; // cvx
        expectedReverts[0xA3E1e0d58FE8dD8C9dd48204699a1178f1B274D8][
            0xaF314b088B53835d5cF4e4CB81beABa5934a61fe
        ] = true; // stkcvxFRAX3CRV-f - pidToPhantomToken missing
        expectedReverts[0xA3E1e0d58FE8dD8C9dd48204699a1178f1B274D8][
            0x0A1D4A25d0390899b90bCD22E1Ef155003EA76d7
        ] = true; // stkcvxLUSD3CRV-f - pidToPhantomToken missing
        expectedReverts[0xA3E1e0d58FE8dD8C9dd48204699a1178f1B274D8][
            0x7e1992A7F28dAA5f6a2d34e2cd40f962f37B172C
        ] = true; // stkcvxcrvPlain3andSUSD - pidToPhantomToken missing
        expectedReverts[0xA3E1e0d58FE8dD8C9dd48204699a1178f1B274D8][
            0xbAc7a431146aeAf3F57A16b9954f332Fd292F270
        ] = true; // stkcvx3Crv - pidToPhantomToken missing
        expectedReverts[0xA3E1e0d58FE8dD8C9dd48204699a1178f1B274D8][
            0x276187f24D41745513cbE2Bd5dFC33a4d8CDc9ed
        ] = true; // stkcvxcrvFRAX - pidToPhantomToken missing
        expectedReverts[0xA3E1e0d58FE8dD8C9dd48204699a1178f1B274D8][
            0xe15B7D80a51e1fe54aC355CaBE848Efce5289BDB
        ] = true; // stkcvxsteCRV - pidToPhantomToken missing
    }

    function test_live_router_can_open_ca() public {
        CreditManagerData[] memory cmList = dataCompressor
            .getCreditManagersList();
        for (uint256 i = 0; i < cmList.length; ++i) {
            if (cmList[i].version == 2) {
                _testSingleCm(cmList[i]);
            }
        }
    }

    function _testSingleCm(CreditManagerData memory cmData) internal {
        ICreditManagerV2 cm = ICreditManagerV2(cmData.addr);
        ICreditFacade cf = ICreditFacade(cmData.creditFacade);

        // allow USER to open CA
        // this is not included in snapshot and not rolled back
        IDegenNFT dnft = IDegenNFT(cf.degenNFT());
        vm.prank(dnft.minter());
        dnft.mint(USER, 30);

        address underlying = cm.underlying();
        string memory underlyingSymbol = IERC20Metadata(underlying).symbol();
        (uint128 accountAmount, ) = cf.limits();

        emit log_named_string(
            "---- testing cm",
            string(
                abi.encodePacked(
                    underlyingSymbol,
                    " ",
                    Strings.toHexString(address(cm)),
                    " min borrow ",
                    Strings.toString(accountAmount)
                )
            )
        );

        // this is not included in snapshot and not rolled back
        _maybeTopUpPool(cmData);

        // this is not included in snapshot and not rolled back
        deal(underlying, USER, 1000 * accountAmount, false);
        vm.prank(USER);
        IERC20(cmData.underlying).approve(cmData.addr, type(uint256).max);

        uint256 tokenCount = cm.collateralTokensCount();
        for (uint256 i = 0; i < tokenCount; ++i) {
            (address tokenOut, uint16 lt) = cm.collateralTokens(i);

            if (tokenOut == underlying) continue;
            string memory symbol = IERC20Metadata(tokenOut).symbol();

            if (!cf.isTokenAllowed(tokenOut) || lt <= 1) {
                continue;
            }

            emit log_named_string(
                "testing token",
                string(
                    abi.encodePacked(
                        symbol,
                        " ",
                        Strings.toHexString(tokenOut),
                        " lt ",
                        Strings.toString(lt)
                    )
                )
            );

            _testToken(cmData, tokenOut, accountAmount, lt);
        }
    }

    function _testToken(
        CreditManagerData memory cmData,
        address tokenOut,
        uint256 borrowed,
        uint16 lt
    ) internal {
        ICreditManagerV2 cm = ICreditManagerV2(cmData.addr);
        ICreditFacade cf = ICreditFacade(cmData.creditFacade);

        // this is assuming lossless conversion
        // x = 1/(lt * (1-slippage)) - 1
        // uint256 collateral = ((PERCENTAGE_FACTOR * borrowed)) / lt - borrowed;
        uint256 collateral = 5 * borrowed;

        Balance[] memory expectedBalances = _getBalances(cm);
        expectedBalances.setBalance(cmData.underlying, collateral + borrowed);

        address[] memory connectors = _getConnectors(cm);

        (, RouterResult memory res) = router.findOpenStrategyPath(
            cmData.addr,
            expectedBalances,
            tokenOut,
            connectors,
            50
        );

        MultiCall[] memory calls = new MultiCall[](1);
        calls[0] = MultiCall({
            target: cmData.creditFacade,
            callData: abi.encodeWithSelector(
                ICreditFacade.addCollateral.selector,
                USER,
                cmData.underlying,
                collateral
            )
        });
        calls = calls.concat(res.calls);

        uint256 tokenSnapshot = vm.snapshot();

        vm.prank(USER);
        if (expectedReverts[cmData.addr][tokenOut]) {
            vm.expectRevert();
            emit log_string("reverted as expected");
        }
        cf.openCreditAccountMulticall(borrowed, USER, calls, 0);

        vm.revertTo(tokenSnapshot);
    }

    // check available liquidity in pool for this cm and mock-deposit some if it's low
    function _maybeTopUpPool(CreditManagerData memory cmData) internal {
        IPoolService pool = IPoolService(cmData.pool);
        uint256 available = pool.availableLiquidity();
        address underlying = pool.underlyingToken();
        string memory symbol = IERC20Metadata(underlying).symbol();
        uint256 availableUSD = oracle.convertToUSD(available, underlying);
        // if pool has < 1m USD in underlying, deal them to a friend and deposit to pool
        if (availableUSD < MIN_POOL_LIQ_USD) {
            uint256 mil = oracle.convertFromUSD(MIN_POOL_LIQ_USD, underlying);
            deal(underlying, FRIEND, mil, false);
            vm.prank(FRIEND);
            IERC20(underlying).approve(cmData.pool, type(uint256).max);
            vm.prank(FRIEND);
            pool.addLiquidity(mil, FRIEND, 0);

            emit log_named_string(
                "deposited to pool",
                string(
                    abi.encodePacked(
                        symbol,
                        " ",
                        Strings.toHexString(uint160(address(pool)), 20)
                    )
                )
            );
        } else {
            emit log_named_string(
                "pool has enough available liquidity",
                string(
                    abi.encodePacked(
                        symbol,
                        " ",
                        Strings.toHexString(uint160(address(pool)), 20)
                    )
                )
            );
        }
    }

    function _getConnectors(ICreditManagerV2 cm)
        internal
        view
        returns (address[] memory connectors)
    {
        address[] memory potentialConnectors = new address[](4);
        connectors = new address[](3);
        potentialConnectors[0] = MAINNET_USDC;
        potentialConnectors[1] = MAINNET_WETH;
        potentialConnectors[2] = MAINNET_DAI;
        // potentialConnectors[3] = MAINNET_FRAX;

        uint256 numConnectors;

        for (uint256 i = 0; i < potentialConnectors.length; ++i) {
            if (cm.tokenMasksMap(potentialConnectors[i]) == 0) continue;
            connectors[numConnectors] = potentialConnectors[i];
            ++numConnectors;
        }

        connectors = connectors.trim();
    }

    function _getBalances(ICreditManagerV2 cm)
        internal
        view
        returns (Balance[] memory balances)
    {
        uint256 tokenCount = cm.collateralTokensCount();
        balances = new Balance[](tokenCount);

        for (uint256 i = 0; i < tokenCount; ++i) {
            (address token, ) = cm.collateralTokens(i);
            balances[i].token = token;
        }
    }
}
