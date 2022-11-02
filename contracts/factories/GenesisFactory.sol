// SPDX-License-Identifier: BUSL-1.1
// Gearbox. Generalized leverage protocol that allows to take leverage and then use it across other DeFi protocols and platforms in a composable way.
// (c) Gearbox Holdings, 2022
pragma solidity ^0.8.10;

import { Ownable } from "@openzeppelin/contracts/access/Ownable.sol";

import { AddressProvider } from "../core/AddressProvider.sol";
import { ContractsRegister } from "../core/ContractsRegister.sol";
import { ACL } from "../core/ACL.sol";
import { DataCompressor } from "../core/DataCompressor.sol";
import { AccountFactory } from "../core/AccountFactory.sol";

import { WETHGateway } from "../core/WETHGateway.sol";
import { PriceOracle, PriceFeedConfig } from "../oracles/PriceOracle.sol";
import { GearToken } from "../tokens/GearToken.sol";

contract GenesisFactory is Ownable {
    AddressProvider public addressProvider;
    ACL public acl;
    PriceOracle public priceOracle;

    constructor(address wethToken, address treasury) {
        addressProvider = new AddressProvider(); // T:[GD-1]
        addressProvider.setWethToken(wethToken); // T:[GD-1]
        addressProvider.setTreasuryContract(treasury); // T:[GD-1]

        acl = new ACL(); // T:[GD-1]
        addressProvider.setACL(address(acl)); // T:[GD-1]

        ContractsRegister contractsRegister = new ContractsRegister(
            address(addressProvider)
        ); // T:[GD-1]
        addressProvider.setContractsRegister(address(contractsRegister)); // T:[GD-1]

        DataCompressor dataCompressor = new DataCompressor(
            address(addressProvider)
        ); // T:[GD-1]
        addressProvider.setDataCompressor(address(dataCompressor)); // T:[GD-1]

        PriceFeedConfig[] memory config;
        priceOracle = new PriceOracle(address(addressProvider), config); // T:[GD-1]
        addressProvider.setPriceOracle(address(priceOracle)); // T:[GD-1]

        AccountFactory accountFactory = new AccountFactory(
            address(addressProvider)
        ); // T:[GD-1]
        addressProvider.setAccountFactory(address(accountFactory)); // T:[GD-1]

        WETHGateway wethGateway = new WETHGateway(address(addressProvider)); // T:[GD-1]
        addressProvider.setWETHGateway(address(wethGateway)); // T:[GD-1]

        GearToken gearToken = new GearToken(address(this)); // T:[GD-1]
        addressProvider.setGearToken(address(gearToken)); // T:[GD-1]
        gearToken.transferOwnership(msg.sender); // T:[GD-1]
        addressProvider.transferOwnership(msg.sender); // T:[GD-1]
        acl.transferOwnership(msg.sender); // T:[GD-1]
    }

    function addPriceFeeds(PriceFeedConfig[] memory priceFeeds)
        external
        onlyOwner // T:[GD-3]
    {
        for (uint256 i = 0; i < priceFeeds.length; ++i) {
            priceOracle.addPriceFeed(
                priceFeeds[i].token,
                priceFeeds[i].priceFeed
            ); // T:[GD-4]
        }

        acl.transferOwnership(msg.sender); // T:[GD-4]
    }

    function claimACLOwnership() external onlyOwner {
        acl.claimOwnership();
    }

    function claimAddressProviderOwnership() external onlyOwner {
        addressProvider.claimOwnership();
    }
}
