// SPDX-License-Identifier: BUSL-1.1
// Gearbox. Generalized leverage protocol that allows to take leverage and then use it across other DeFi protocols and platforms in a composable way.
// (c) Gearbox Holdings, 2022
pragma solidity ^0.8.10;
pragma abicoder v2;

import { ERC20 } from "@solmate/tokens/ERC20.sol";

import { ERC4626Safe } from "../pool/ERC4626/base/ERC4626Safe.sol";
import { PoolService } from "../pool/PoolService.sol";
import { PoolOpts } from "./PoolFactory.sol";
import { LinearInterestRateModel } from "../pool/LinearInterestRateModel.sol";
import { ContractsRegister } from "../core/ContractsRegister.sol";
import { AddressProvider } from "../core/AddressProvider.sol";
import { PoolServiceERC4626 } from "../pool/ERC4626/PoolServiceERC4626.sol";

/// @title PoolERC4626Factory
/// @author Tushar
/// @notice ERC4626Factory for PoolService
contract PoolERC4626Factory {
    /// @notice Emitted when a new PoolServiceERC4626 has been created
    /// @param asset The base asset used by the PoolServiceERC4626
    /// @param poolService The PoolService that was created
    /// @param poolService4626 The PoolServiceERC4626 that was created
    /// @param linearModel The LinearInterestRateModel that was created
    event CreatePoolServiceERC4626(
        ERC20 indexed asset,
        PoolService poolService,
        PoolServiceERC4626 poolService4626,
        LinearInterestRateModel linearModel
    );

    /// @dev Create PoolServiceERC4626 while creating LinearInterestRateModel, PoolService. Sourced from PoolFactory.sol
    function createPoolERC4626(PoolOpts memory opts)
        external
        virtual
        returns (PoolServiceERC4626 poolService4626, PoolService poolService)
    {
        LinearInterestRateModel linearModel = new LinearInterestRateModel(
            opts.U_optimal,
            opts.R_base,
            opts.R_slope1,
            opts.R_slope2
        );

        poolService = new PoolService(
            opts.addressProvider,
            opts.underlying,
            address(linearModel),
            opts.expectedLiquidityLimit
        );

        poolService.setWithdrawFee(opts.withdrawFee);

        ContractsRegister cr = ContractsRegister(
            AddressProvider(opts.addressProvider).getContractsRegister()
        );

        cr.addPool(address(poolService));

        poolService4626 = new PoolServiceERC4626{ salt: bytes32(0) }(
            address(poolService),
            ERC20(opts.underlying)
        );

        emit CreatePoolServiceERC4626(
            ERC20(opts.underlying),
            poolService,
            poolService4626,
            linearModel
        );
    }

    /// @dev Create PoolServiceERC4626 from an existing poolService
    /// @param poolService_ Address of poolService
    function createPoolERC4626(address poolService_)
        external
        virtual
        returns (PoolServiceERC4626 poolService4626)
    {
        PoolService poolService = PoolService(poolService_);

        poolService4626 = new PoolServiceERC4626{ salt: bytes32(0) }(
            address(poolService),
            ERC20(poolService.underlyingToken())
        );
    }
}
