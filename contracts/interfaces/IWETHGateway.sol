// SPDX-License-Identifier: MIT
// Gearbox Protocol. Generalized leverage for DeFi protocols
// (c) Gearbox Holdings, 2022
pragma solidity ^0.8.10;

interface IWETHGateway {
    /// @dev POOL V3:
    function deposit(address pool, address receiver) external payable returns (uint256 shares);

    function depositReferral(address pool, address receiver, uint16 referralCode)
        external
        payable
        returns (uint256 shares);

    function mint(address pool, uint256 shares, address receiver) external payable returns (uint256 assets);

    function withdraw(address pool, uint256 assets, address receiver, address owner)
        external
        returns (uint256 shares);

    function redeem(address pool, uint256 shares, address receiver, address owner)
        external
        payable
        returns (uint256 assets);

    /// @dev POOL V1:

    /// @dev Converts ETH to WETH and add liqudity to the pool
    /// @param pool Address of PoolService contract to add liquidity to. This pool must have WETH as an underlying.
    /// @param onBehalfOf The address that will receive the diesel token.
    /// @param referralCode Code used to log the transaction facilitator, for potential rewards. 0 if non-applicable.
    function addLiquidityETH(address pool, address onBehalfOf, uint16 referralCode) external payable;

    /// @dev Removes liquidity from the pool and converts WETH to ETH
    ///       - burns lp's diesel (LP) tokens
    ///       - unwraps WETH to ETH and sends to the LP
    /// @param pool Address of PoolService contract to withdraw liquidity from. This pool must have WETH as an underlying.
    /// @param amount Amount of Diesel tokens to send.
    /// @param to Address to transfer ETH to.
    function removeLiquidityETH(address pool, uint256 amount, address payable to) external;

    /// @dev Converts WETH to ETH, and sends to the passed address
    /// @param to Address to send ETH to
    /// @param amount Amount of WETH to unwrap
    function unwrapWETH(address to, uint256 amount) external;
}
