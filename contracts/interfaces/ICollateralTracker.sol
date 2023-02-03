// SPDX-License-Identifier: MIT
// Gearbox Protocol. Generalized leverage for DeFi protocols
// (c) Gearbox Holdings, 2022
pragma solidity ^0.8.10;

struct CollateralSetting {
    address token;
    uint256 amount;
}

interface ICollateralTrackerErrors {
    error LimitViolatedException();
}

interface ICollateralTracker is ICollateralTrackerErrors {
    function collateralize(
        address creditAccount,
        address token,
        uint256 amount
    ) external;

    function collateralizeAll(address creditAccount, address token) external;

    function decollateralizeAll(address creditAccount, address token) external;

    function batchCollateralize(
        address creditAccount,
        CollateralSetting[] memory settings
    ) external;
}
