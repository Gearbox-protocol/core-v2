// SPDX-License-Identifier: UNLICENSED
// Gearbox Protocol. Generalized leverage for DeFi protocols
// (c) Gearbox Holdings, 2022
pragma solidity ^0.8.10;

import "@forge-std/Script.sol";

import { ERC20 } from "@solmate/tokens/ERC20.sol";

import { PoolServiceERC4626 } from "../../../pool/ERC4626/PoolServiceERC4626.sol";
import { PoolService } from "../../../pool/PoolService.sol";

contract DeployPoolService4626Script is Script {
    address constant WETH_POOL_SERVICE =
        0xB03670c20F87f2169A7c4eBE35746007e9575901;
    address constant WSTETH_POOL_SERVICE =
        0xB8cf3Ed326bB0E51454361Fb37E9E8df6DC5C286;
    address constant USDC_POOL_SERVICE =
        0x86130bDD69143D8a4E5fc50bf4323D48049E98E4;
    address constant DAI_POOL_SERVICE =
        0x24946bCbBd028D5ABb62ad9B635EB1b1a67AF668;
    address constant WBTC_POOL_SERVICE =
        0xB2A015c71c17bCAC6af36645DEad8c572bA08A08;

    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(deployerPrivateKey);

        _deployERC4626PoolService(WETH_POOL_SERVICE);
        _deployERC4626PoolService(WSTETH_POOL_SERVICE);
        _deployERC4626PoolService(USDC_POOL_SERVICE);
        _deployERC4626PoolService(DAI_POOL_SERVICE);
        _deployERC4626PoolService(WBTC_POOL_SERVICE);

        vm.stopBroadcast();
    }

    function _deployERC4626PoolService(address poolService_) internal {
        new PoolServiceERC4626(poolService_, _underlyingToken(poolService_));
    }

    function _underlyingToken(address poolService_)
        internal
        view
        returns (ERC20 underlying)
    {
        PoolService poolService = PoolService(poolService_);
        underlying = ERC20(poolService.underlyingToken());
    }
}
