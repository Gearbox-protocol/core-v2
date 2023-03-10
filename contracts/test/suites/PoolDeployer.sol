// SPDX-License-Identifier: UNLICENSED
// Gearbox Protocol. Generalized leverage for DeFi protocols
// (c) Gearbox Holdings, 2022
pragma solidity ^0.8.10;

import {AddressProvider} from "@gearbox-protocol/core-v2/contracts/core/AddressProvider.sol";
import {IPriceOracleV2Ext} from "@gearbox-protocol/core-v2/contracts/interfaces/IPriceOracle.sol";
import {PriceFeedConfig} from "@gearbox-protocol/core-v2/contracts/oracles/PriceOracle.sol";
import {ACL} from "@gearbox-protocol/core-v2/contracts/core/ACL.sol";
import {ContractsRegister} from "@gearbox-protocol/core-v2/contracts/core/ContractsRegister.sol";
import {AccountFactory} from "@gearbox-protocol/core-v2/contracts/core/AccountFactory.sol";
import {GenesisFactory} from "@gearbox-protocol/core-v2/contracts/factories/GenesisFactory.sol";
import {PoolFactory, PoolOpts} from "@gearbox-protocol/core-v2/contracts/factories/PoolFactory.sol";

import {CreditManagerOpts, CollateralToken} from "../../credit/CreditConfigurator.sol";
import {PoolServiceMock} from "../mocks/pool/PoolServiceMock.sol";
import {PoolQuotaKeeper} from "../../pool/PoolQuotaKeeper.sol";

import "../lib/constants.sol";

import {ITokenTestSuite} from "../interfaces/ITokenTestSuite.sol";

struct PoolCreditOpts {
    PoolOpts poolOpts;
    CreditManagerOpts creditOpts;
}

// struct CollateralTokensItem {
//     Tokens token;
//     uint16 liquidationThreshold;
// }

/// @title CreditManagerTestSuite
/// @notice Deploys contract for unit testing of CreditManager.sol
contract PoolDeployer is DSTest {
    CheatCodes evm = CheatCodes(HEVM_ADDRESS);

    AddressProvider public addressProvider;
    GenesisFactory public gp;
    AccountFactory public af;
    PoolServiceMock public poolMock;
    PoolQuotaKeeper public poolQuotaKeeper;
    ContractsRegister public cr;
    ACL public acl;

    IPriceOracleV2Ext public priceOracle;

    address public underlying;

    constructor(
        ITokenTestSuite tokenTestSuite,
        address _underlying,
        address wethToken,
        uint256 initialBalance,
        PriceFeedConfig[] memory priceFeeds
    ) {
        new Roles();

        gp = new GenesisFactory(wethToken, DUMB_ADDRESS);

        gp.acl().claimOwnership();
        gp.addressProvider().claimOwnership();

        gp.acl().addPausableAdmin(CONFIGURATOR);
        gp.acl().addUnpausableAdmin(CONFIGURATOR);

        gp.acl().transferOwnership(address(gp));
        gp.claimACLOwnership();

        gp.addPriceFeeds(priceFeeds);
        gp.acl().claimOwnership();

        addressProvider = gp.addressProvider();
        af = AccountFactory(addressProvider.getAccountFactory());

        priceOracle = IPriceOracleV2Ext(addressProvider.getPriceOracle());

        acl = ACL(addressProvider.getACL());

        cr = ContractsRegister(addressProvider.getContractsRegister());

        underlying = _underlying;

        poolMock = new PoolServiceMock(
            address(gp.addressProvider()),
            underlying
        );

        tokenTestSuite.mint(_underlying, address(poolMock), initialBalance);

        cr.addPool(address(poolMock));

        poolQuotaKeeper = new PoolQuotaKeeper(payable(address(poolMock)));

        poolMock.setPoolQuotaKeeper(address(poolQuotaKeeper));
    }
}
