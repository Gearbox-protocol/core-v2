// SPDX-License-Identifier: BUSL-1.1
// Gearbox. Generalized leverage protocol that allows to take leverage and then use it across other DeFi protocols and platforms in a composable way.
// (c) Gearbox Holdings, 2022
pragma solidity ^0.8.10;

pragma abicoder v2;

import { ContractsRegister } from "../core/ContractsRegister.sol";

import { LinearInterestRateModel } from "../pool/LinearInterestRateModel.sol";
import { PoolService } from "../pool/PoolService.sol";

import { ContractUpgrader } from "../support/ContractUpgrader.sol";

struct PoolOpts {
    address addressProvider; // address of addressProvider contract
    address underlying; // address of underlying token for pool and creditManager
    uint256 U_optimal; // linear interest model parameter
    uint256 U_reserve; // linear interest model parameter
    uint256 R_base; // linear interest model parameter
    uint256 R_slope1; // linear interest model parameter
    uint256 R_slope2; // linear interest model parameter
    uint256 R_slope3; // linear interest model parameter
    uint256 expectedLiquidityLimit; // linear interest model parameter
    uint256 withdrawFee; // withdrawFee
}

contract PoolFactory is ContractUpgrader {
    PoolService public immutable pool;
    uint256 public withdrawFee;

    constructor(PoolOpts memory opts) ContractUpgrader(opts.addressProvider) {
        LinearInterestRateModel linearModel = new LinearInterestRateModel(
            opts.U_optimal,
            opts.U_reserve,
            opts.R_base,
            opts.R_slope1,
            opts.R_slope2,
            opts.R_slope3,
            false
        ); // T:[PD-1]

        pool = new PoolService(
            opts.addressProvider,
            opts.underlying,
            address(linearModel),
            opts.expectedLiquidityLimit
        );

        withdrawFee = opts.withdrawFee;
    }

    function _configure() internal override {
        ContractsRegister cr = ContractsRegister(
            addressProvider.getContractsRegister()
        );

        pool.setWithdrawFee(withdrawFee);

        cr.addPool(address(pool)); // T:[PD-2]
    }
}
