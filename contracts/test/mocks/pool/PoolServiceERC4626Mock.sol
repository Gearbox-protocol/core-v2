// SPDX-License-Identifier: BUSL-1.1
// Gearbox Protocol. Generalized leverage for DeFi protocols
// (c) Gearbox Holdings, 2022
pragma solidity ^0.8.10;

import { ERC20 } from "@solmate/tokens/ERC20.sol";
import { ERC4626SafeMock } from "./base/ERC4626SafeMock.sol";
import { SafeTransferLib } from "@solmate/utils/SafeTransferLib.sol";

import { PoolServiceMock } from "./PoolServiceMock.sol";
import { Errors } from "../../../libraries/Errors.sol";

/// @title PoolServiceERC4626Mock
/// @author Tushar
/// @notice ERC4626 wrapper for Pool Service
contract PoolServiceERC4626Mock is ERC4626SafeMock {
    /// -----------------------------------------------------------------------
    /// Libraries usage
    /// -----------------------------------------------------------------------

    using SafeTransferLib for ERC20;

    /// -----------------------------------------------------------------------
    /// Immutable params
    /// -----------------------------------------------------------------------

    /// @notice The Pool Service Contract
    PoolServiceMock public immutable poolService;

    /// -----------------------------------------------------------------------
    /// Constructor
    /// -----------------------------------------------------------------------

    constructor(address poolService_, ERC20 asset_)
        ERC4626SafeMock(asset_, _vaultName(asset_), _vaultSymbol(asset_))
    {
        // check correct underlying to poolService mapping
        require(
            address(asset_) == PoolServiceMock(poolService_).underlyingToken(),
            Errors.W_POOL_INVALID_UNDERLYING
        );

        poolService = PoolServiceMock(poolService_);
    }

    /// -----------------------------------------------------------------------
    /// ERC4626 overrides
    /// -----------------------------------------------------------------------

    /// @dev Calculate totalAssets by converting the total diesel tokens to underlying amount
    function totalAssets() public view virtual override returns (uint256) {
        return asset.balanceOf(address(this));
    }

    /// @dev hook-like method to removeLiquidity through wrapper while withdraw/redeem
    function beforeWithdraw(
        uint256 assets,
        uint256 /*shares*/
    ) internal virtual override {
        /// -----------------------------------------------------------------------
        /// Withdraw assets from PoolService
        /// -----------------------------------------------------------------------

        // Added +1 to account for withdraw roundDown case
        poolService.removeLiquidity(
            poolService.toDiesel(assets) + 1,
            address(this)
        );
    }

    /// @dev hook-like method to addLiquidity through wrapper while deposit/mint
    function afterDeposit(
        uint256 assets,
        uint256 /*shares*/
    ) internal virtual override {
        /// -----------------------------------------------------------------------
        /// Deposit assets into PoolService
        /// -----------------------------------------------------------------------

        // approve to poolService
        asset.safeApprove(address(poolService), assets);

        // deposit into poolService
        poolService.addLiquidity(assets, address(this), 0);
    }

    /// -----------------------------------------------------------------------
    /// ERC20 metadata generation
    /// -----------------------------------------------------------------------

    function _vaultName(ERC20 asset_)
        internal
        view
        virtual
        returns (string memory vaultName)
    {
        vaultName = string(
            abi.encodePacked(
                "Gearbox_",
                asset_.symbol(),
                "_ERC4626-Wrapped_Pool_Service"
            )
        );
    }

    function _vaultSymbol(ERC20 asset_)
        internal
        view
        virtual
        returns (string memory vaultSymbol)
    {
        vaultSymbol = string(abi.encodePacked("w_ps_", asset_.symbol()));
    }
}
