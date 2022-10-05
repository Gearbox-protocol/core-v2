// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.10;

interface ILidoOracle {
    function getLastCompletedReportDelta()
        external
        view
        returns (
            uint256 postTotalPooledEther,
            uint256 preTotalPooledEther,
            uint256 timeElapsed
        );
}
