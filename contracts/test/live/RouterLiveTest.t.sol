// SPDX-License-Identifier: UNLICENSED
// Gearbox Protocol. Generalized leverage for DeFi protocols
// (c) Gearbox Holdings, 2022
pragma solidity ^0.8.10;

import { IAddressProvider } from "../../interfaces/IAddressProvider.sol";
import { IDataCompressor } from "../../interfaces/IDataCompressor.sol";
import { ICreditManagerV2 } from "../../interfaces/ICreditManagerV2.sol";
import { ICreditFacade } from "../../interfaces/ICreditFacade.sol";
import { IDegenNFT } from "../../interfaces/IDegenNFT.sol";

import { IERC20Metadata } from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import { CreditManagerData } from "../../libraries/Types.sol";
import { Balance, BalanceOps } from "../../libraries/Balances.sol";
import { MultiCall, MultiCallOps } from "../../libraries/MultiCall.sol";
import { AddressList } from "../../libraries/AddressList.sol";
import { Test } from "forge-std/Test.sol";

import "../lib/constants.sol";

address constant ADDRESS_PROVIDER = 0xcF64698AFF7E5f27A11dff868AF228653ba53be0;
address constant MAINNET_USDC = 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48;
address constant MAINNET_WETH = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;
address constant MAINNET_DAI = 0x6B175474E89094C44Da98b954EedeAC495271d0F;
address constant MAINNET_FRAX = 0x853d955aCEf822Db058eb8505911ED77F175b99e;

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

    IAddressProvider addressProvider;
    IDataCompressor dataCompressor;
    IRouter router;

    constructor() {
        addressProvider = IAddressProvider(ADDRESS_PROVIDER);
        dataCompressor = IDataCompressor(addressProvider.getDataCompressor());
        router = IRouter(addressProvider.getLeveragedActions());
    }

    function _testSingleCm(CreditManagerData memory cmData) internal {
        ICreditManagerV2 cm = ICreditManagerV2(cmData.addr);
        ICreditFacade cf = ICreditFacade(cmData.creditFacade);

        IDegenNFT dnft = IDegenNFT(cf.degenNFT());
        vm.prank(dnft.minter());
        dnft.mint(USER, 30);

        address underlying = cm.underlying();
        string memory underlyingSymbol = IERC20Metadata(underlying).symbol();
        emit log_named_string("testing cm", underlyingSymbol);
        emit log_named_address("cm underlying", underlying);
        emit log_named_address("cm address", address(cm));

        uint256 accountAmount = (underlying == MAINNET_DAI)
            ? DAI_ACCOUNT_AMOUNT
            : (underlying == MAINNET_USDC)
            ? USDC_ACCOUNT_AMOUNT
            : WETH_ACCOUNT_AMOUNT;
        emit log_named_uint("accountAmount", accountAmount);
        deal(underlying, USER, accountAmount);

        uint256 tokenCount = cm.collateralTokensCount();

        for (uint256 i = 0; i < tokenCount; ++i) {
            (address tokenOut, ) = cm.collateralTokens(i);

            if (tokenOut == cm.underlying()) continue;

            _testToken(cm, tokenOut, accountAmount);
        }
    }

    function _testToken(
        ICreditManagerV2 cm,
        address tokenOut,
        uint256 accountAmount
    ) internal {
        string memory symbol = IERC20Metadata(tokenOut).symbol();
        emit log_named_string("testing token", symbol);

        Balance[] memory expectedBalances = new Balance[](1);
        expectedBalances[0] = Balance({
            token: cm.underlying(),
            balance: accountAmount
        });

        address[] memory connectors = _getConnectors(cm);

        (, RouterResult memory res) = router.findOpenStrategyPath(
            address(cm),
            expectedBalances,
            tokenOut,
            connectors,
            0
        );

        MultiCall[] memory calls = new MultiCall[](1);
        calls[0] = MultiCall({
            target: cm.creditFacade(),
            callData: abi.encodeWithSelector(
                ICreditFacade.addCollateral.selector,
                USER,
                cm.underlying(),
                accountAmount
            )
        });
        calls = calls.concat(res.calls);

        vm.prank(USER);
        IERC20(cm.underlying()).approve(address(cm), type(uint256).max);

        ICreditFacade cf = ICreditFacade(cm.creditFacade());
        cf.openCreditAccountMulticall(accountAmount, USER, calls, 0);
    }

    function test_live_router_can_open_ca() public {
        CreditManagerData[] memory cmList = dataCompressor
            .getCreditManagersList();
        uint256 snapshot = vm.snapshot();

        for (uint256 i = 0; i < cmList.length; ++i) {
            if (cmList[i].version == 2) {
                _testSingleCm(cmList[i]);
                vm.revertTo(snapshot);
            }
        }
    }

    // copied from router
    function _getConnectors(ICreditManagerV2 cm)
        internal
        view
        returns (address[] memory connectors)
    {
        address[] memory potentialConnectors = new address[](4);
        connectors = new address[](4);
        potentialConnectors[0] = MAINNET_USDC;
        potentialConnectors[1] = MAINNET_WETH;
        potentialConnectors[2] = MAINNET_DAI;
        potentialConnectors[3] = MAINNET_FRAX;

        uint256 numConnectors;

        for (uint256 i = 0; i < potentialConnectors.length; ++i) {
            if (cm.tokenMasksMap(potentialConnectors[i]) == 0) continue;
            connectors[numConnectors] = potentialConnectors[i];
            ++numConnectors;
        }

        connectors = connectors.trim();
    }
}
