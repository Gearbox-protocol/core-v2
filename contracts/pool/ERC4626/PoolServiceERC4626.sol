// SPDX-License-Identifier: BUSL-1.1
// Gearbox Protocol. Generalized leverage for DeFi protocols
// (c) Gearbox Holdings, 2022
pragma solidity ^0.8.10;

import { ERC20 } from "@solmate/tokens/ERC20.sol";
import { ERC4626Safe } from "./base/ERC4626Safe.sol";
import { SafeTransferLib } from "@solmate/utils/SafeTransferLib.sol";

import { PoolService } from "../../pool/PoolService.sol";
import { Errors } from "../../libraries/Errors.sol";

/// @title PoolServiceERC4626
/// @author Tushar
/// @notice ERC4626 wrapper for Pool Service
contract PoolServiceERC4626 is ERC4626Safe {
    /// -----------------------------------------------------------------------
    /// Libraries usage
    /// -----------------------------------------------------------------------

    using SafeTransferLib for ERC20;

    /// -----------------------------------------------------------------------
    /// Immutable params
    /// -----------------------------------------------------------------------

    /// @notice The Pool Service Contract
    PoolService public immutable poolService;

    /// @notice The Diesel Token Contract
    ERC20 public immutable dieselToken;

    /// -----------------------------------------------------------------------
    /// Constructor
    /// -----------------------------------------------------------------------

    constructor(address poolService_, ERC20 asset_)
        ERC4626Safe(asset_, _vaultName(asset_), _vaultSymbol(asset_))
    {
        require(poolService_ != address(0), Errors.ZERO_ADDRESS_IS_NOT_ALLOWED);

        // check correct underlying to poolService mapping
        require(
            address(asset_) == PoolService(poolService_).underlyingToken(),
            Errors.W_POOL_INVALID_UNDERLYING
        );

        poolService = PoolService(poolService_);
        dieselToken = ERC20(PoolService(poolService_).dieselToken());
    }

    /// -----------------------------------------------------------------------
    /// ERC4626 overrides
    /// -----------------------------------------------------------------------

    /// @dev Calculate totalAssets by converting the total diesel tokens to underlying amount
    function totalAssets() public view virtual override returns (uint256) {
        uint256 _totalDieselTokens = dieselToken.balanceOf(address(this));

        // roundUp to account for fromDiesel() ReoundDown
        return
            _totalDieselTokens == 0
                ? 0
                : poolService.fromDiesel(_totalDieselTokens) + 1;
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

    /// @dev maximum amount of underlying assets depositable. Pause-aware
    function maxDeposit(address) public view override returns (uint256) {
        if (poolService.paused()) {
            return 0;
        }
        return
            poolService.expectedLiquidityLimit() -
            poolService.expectedLiquidity();
    }

    /// @dev maximum amount of underlying shares mintable. Pause-aware
    function maxMint(address) public view override returns (uint256) {
        if (poolService.paused()) {
            return 0;
        }
        return
            convertToShares(
                poolService.expectedLiquidityLimit() -
                    poolService.expectedLiquidity()
            );
    }

    /// @dev maximum amount of underlying assets withdrawable. Pause-aware
    function maxWithdraw(address owner) public view override returns (uint256) {
        if (poolService.paused()) {
            return 0;
        }
        return convertToAssets(balanceOf[owner]);
    }

    /// @dev maximum amount of underlying shares redeemable. Pause-aware
    function maxRedeem(address owner) public view override returns (uint256) {
        if (poolService.paused()) {
            return 0;
        }
        return balanceOf[owner];
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
