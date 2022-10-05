// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.10;

interface ICurveRegistry {
    function get_pool_from_lp_token(address token)
        external
        view
        returns (address);

    function get_n_coins(address pool) external view returns (uint256);

    function get_lp_token(address pool) external view returns (address);
}
