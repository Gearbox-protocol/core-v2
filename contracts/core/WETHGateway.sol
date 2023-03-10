// SPDX-License-Identifier: BUSL-1.1
// Gearbox Protocol. Generalized leverage for DeFi protocols
// (c) Gearbox Holdings, 2022
pragma solidity ^0.8.10;

import {Address} from "@openzeppelin/contracts/utils/Address.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

import {AddressProvider} from "@gearbox-protocol/core-v2/contracts/core/AddressProvider.sol";
import {ContractsRegister} from "@gearbox-protocol/core-v2/contracts/core/ContractsRegister.sol";

import {IPoolService} from "@gearbox-protocol/core-v2/contracts/interfaces/IPoolService.sol";
import {IPool4626} from "../interfaces/IPool4626.sol";

import {IWETH} from "@gearbox-protocol/core-v2/contracts/interfaces/external/IWETH.sol";
import {IWETHGateway} from "../interfaces/IWETHGateway.sol";
import {Errors} from "@gearbox-protocol/core-v2/contracts/libraries/Errors.sol";

/// @title WETHGateway
/// @notice Used for converting ETH <> WETH
contract WETHGateway is IWETHGateway {
    using SafeERC20 for IERC20;
    using Address for address payable;

    error RegisteredPoolsOnlyException();
    error WethPoolsOnlyException();
    error RegisteredCreditManagersOnly();
    error ReceiveIsNotAllowedException();

    address public immutable weth;
    ContractsRegister internal immutable cr;

    // Contract version
    uint256 public constant version = 3_00;

    /// @dev Checks that the pool is registered and the underlying token is WETH
    modifier wethPoolOnly(address pool) {
        if (!cr.isPool(pool)) revert RegisteredPoolsOnlyException(); // T:[WG-1]
        if (IPoolService(pool).underlyingToken() != weth) revert WethPoolsOnlyException(); // T:[WG-2]
        _;
    }

    /// @dev Checks that credit manager is registered
    modifier creditManagerOnly(address creditManager) {
        if (!cr.isCreditManager(creditManager)) revert RegisteredCreditManagersOnly(); // T:[WG-3]

        _;
    }

    /// @dev Measures WETH balance before and after function call and transfers
    /// difference to providced address
    modifier unwrapAndTransferWethTo(address to) {
        uint256 balanceBefore = IERC20(weth).balanceOf(address(this));

        _;

        uint256 diff = IERC20(weth).balanceOf(address(this)) - balanceBefore;

        if (diff > 0) {
            _unwrapWETH(to, diff);
        }
    }

    //
    // CONSTRUCTOR
    //

    /// @dev Constructor
    /// @param addressProvider Address Repository for upgradable contract model
    constructor(address addressProvider) {
        require(addressProvider != address(0), Errors.ZERO_ADDRESS_IS_NOT_ALLOWED);
        weth = AddressProvider(addressProvider).getWethToken();
        cr = ContractsRegister(AddressProvider(addressProvider).getContractsRegister());
    }

    /// FOR POOLS V3

    function deposit(address pool, address receiver)
        external
        payable
        override
        wethPoolOnly(pool)
        returns (uint256 shares)
    {
        IWETH(weth).deposit{value: msg.value}();

        _checkAllowance(pool, msg.value);
        return IPool4626(pool).deposit(msg.value, receiver);
    }

    function depositReferral(address pool, address receiver, uint16 referralCode)
        external
        payable
        override
        wethPoolOnly(pool)
        returns (uint256 shares)
    {
        IWETH(weth).deposit{value: msg.value}();

        _checkAllowance(pool, msg.value);
        return IPool4626(pool).depositReferral(msg.value, receiver, referralCode);
    }

    function mint(address pool, uint256 shares, address receiver)
        external
        payable
        override
        wethPoolOnly(pool)
        unwrapAndTransferWethTo(msg.sender)
        returns (uint256 assets)
    {
        IWETH(weth).deposit{value: msg.value}();

        _checkAllowance(pool, msg.value);
        assets = IPool4626(pool).mint(shares, receiver);
    }

    function withdraw(address pool, uint256 assets, address receiver, address owner)
        external
        override
        wethPoolOnly(pool)
        unwrapAndTransferWethTo(receiver)
        returns (uint256 shares)
    {
        return IPool4626(pool).withdraw(assets, address(this), owner);
    }

    function redeem(address pool, uint256 shares, address receiver, address owner)
        external
        payable
        override
        wethPoolOnly(pool)
        unwrapAndTransferWethTo(receiver)
        returns (uint256 assets)
    {
        return IPool4626(pool).redeem(shares, address(this), owner);
    }

    /// FOR POOLS V1

    /// @dev convert ETH to WETH and add liqudity to the pool
    /// @param pool Address of PoolService contract to add liquidity to. This pool must have WETH as an underlying.
    /// @param onBehalfOf The address that will receive the diesel token.
    /// @param referralCode Code used to log the transaction facilitator, for potential rewards. 0 if non-applicable.
    function addLiquidityETH(address pool, address onBehalfOf, uint16 referralCode)
        external
        payable
        override
        wethPoolOnly(pool) // T:[WG-1, 2]
    {
        IWETH(weth).deposit{value: msg.value}(); // T:[WG-8]

        _checkAllowance(pool, msg.value); // T:[WG-8]
        IPoolService(pool).addLiquidity(msg.value, onBehalfOf, referralCode); // T:[WG-8]
    }

    /// @dev Removes liquidity from the pool and converts WETH to ETH
    ///       - burns lp's diesel (LP) tokens
    ///       - unwraps WETH to ETH and sends to the LP
    /// @param pool Address of PoolService contract to withdraw liquidity from. This pool must have WETH as an underlying.
    /// @param amount Amount of Diesel tokens to send.
    /// @param to Address to transfer ETH to.
    function removeLiquidityETH(address pool, uint256 amount, address payable to)
        external
        override
        wethPoolOnly(pool) // T:[WG-1, 2]
    {
        IERC20(IPoolService(pool).dieselToken()).safeTransferFrom(msg.sender, address(this), amount); // T: [WG-9]

        uint256 amountGet = IPoolService(pool).removeLiquidity(amount, address(this)); // T: [WG-9]
        _unwrapWETH(to, amountGet); // T: [WG-9]
    }

    /// @dev Converts WETH to ETH, and sends to the passed address
    /// @param to Address to send ETH to
    /// @param amount Amount of WETH to unwrap
    function unwrapWETH(address to, uint256 amount)
        external
        override
        creditManagerOnly(msg.sender) // T:[WG-5]
    {
        _unwrapWETH(to, amount); // T: [WG-7]
    }

    /// @dev Internal implementation for unwrapETH
    function _unwrapWETH(address to, uint256 amount) internal {
        IWETH(weth).withdraw(amount); // T: [WG-7]
        payable(to).sendValue(amount); // T: [WG-7]
    }

    /// @dev Checks that the allowance is sufficient before a transaction, and sets to max if not
    /// @param spender Account that would spend WETH
    /// @param amount Amount to compare allowance with
    function _checkAllowance(address spender, uint256 amount) internal {
        if (IERC20(weth).allowance(address(this), spender) < amount) {
            IERC20(weth).approve(spender, type(uint256).max);
        }
    }

    /// @dev Only WETH contract is allowed to transfer ETH here. Prevent other addresses to send Ether to this contract.
    receive() external payable {
        if (msg.sender != address(weth)) revert ReceiveIsNotAllowedException(); // T:[WG-6]
    }
}
