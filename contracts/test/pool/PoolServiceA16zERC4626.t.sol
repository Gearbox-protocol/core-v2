// SPDX-License-Identifier: UNLICENSED
// Gearbox Protocol. Generalized leverage for DeFi protocols
// (c) Gearbox Holdings, 2022
pragma solidity ^0.8.10;

import "./a16z/ERC4626.test.sol";

import { MockERC20 } from "@solmate/test/utils/mocks/MockERC20.sol";
import { PoolServiceMock } from "../mocks/pool/PoolServiceMock.sol";
import { PoolServiceERC4626Mock } from "../mocks/pool/PoolServiceERC4626Mock.sol";

contract PoolServiceA16zERC4626 is ERC4626Test {
    function setUp() public override {
        _underlying_ = address(new MockERC20("MockERC20", "MockERC20", 18));
        _vault_ = address(
            new PoolServiceERC4626Mock(
                address(new PoolServiceMock(_underlying_, _underlying_)),
                MockERC20(_underlying_)
            )
        );

        _delta_ = 10; // delta of 10 wei of underlying to account for immaterial implementation specific differences
        _vaultMayBeEmpty = true;
        _unlimitedAmount = true;
    }

    // NOTE: The following test is relaxed to consider only smaller values (of type uint120),
    // since maxWithdraw() fails with large values (due to overflow).
    // Ref: https://github.com/daejunpark/solmate/pull/1/files#diff-037db1b692f5923b1296f45fd7114e4e2abfe41a7cbd50e62d1caf262cc16fd7R21

    function test_maxWithdraw(Init memory init) public override {
        init = clamp(init, type(uint120).max);
        super.test_maxWithdraw(init);
    }

    function clamp(Init memory init, uint256 max)
        internal
        pure
        returns (Init memory)
    {
        for (uint256 i = 0; i < N; i++) {
            init.share[i] = init.share[i] % max;
            init.asset[i] = init.asset[i] % max;
        }
        init.yield = init.yield % int256(max);
        return init;
    }
}
