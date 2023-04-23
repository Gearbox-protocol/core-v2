// This program is free software: you can redistribute it and/or modify
// it under the terms of the GNU General Public License as published by
// the Free Software Foundation, either version 3 of the License, or
// (at your option) any later version.

// This program is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
// GNU General Public License for more details.

// You should have received a copy of the GNU General Public License
// along with this program.  If not, see <http://www.gnu.org/licenses/>.

pragma solidity >=0.5.0;

import { StdStorage, stdStorage } from "./stdStorage.sol";

/*//////////////////////////////////////////////////////////////////////////
                                STD-ERRORS
//////////////////////////////////////////////////////////////////////////*/

library stdError {
    bytes public constant assertionError =
        abi.encodeWithSignature("Panic(uint256)", 0x01);
    bytes public constant arithmeticError =
        abi.encodeWithSignature("Panic(uint256)", 0x11);
    bytes public constant divisionError =
        abi.encodeWithSignature("Panic(uint256)", 0x12);
    bytes public constant enumConversionError =
        abi.encodeWithSignature("Panic(uint256)", 0x21);
    bytes public constant encodeStorageError =
        abi.encodeWithSignature("Panic(uint256)", 0x22);
    bytes public constant popError =
        abi.encodeWithSignature("Panic(uint256)", 0x31);
    bytes public constant indexOOBError =
        abi.encodeWithSignature("Panic(uint256)", 0x32);
    bytes public constant memOverflowError =
        abi.encodeWithSignature("Panic(uint256)", 0x41);
    bytes public constant zeroVarError =
        abi.encodeWithSignature("Panic(uint256)", 0x51);
}

contract DSTest {
    using stdStorage for StdStorage;

    event log(string);
    event logs(bytes);

    event log_address(address);
    event log_bytes32(bytes32);
    event log_int(int256);
    event log_uint(uint256);
    event log_bytes(bytes);
    event log_string(string);

    event log_named_address(string key, address val);
    event log_named_bytes32(string key, bytes32 val);
    event log_named_decimal_int(string key, int256 val, uint256 decimals);
    event log_named_decimal_uint(string key, uint256 val, uint256 decimals);
    event log_named_int(string key, int256 val);
    event log_named_uint(string key, uint256 val);
    event log_named_bytes(string key, bytes val);
    event log_named_string(string key, string val);

    uint256 private constant UINT256_MAX =
        115792089237316195423570985008687907853269984665640564039457584007913129639935;

    bool public IS_TEST = true;
    bool private _failed;

    address constant HEVM_ADDRESS =
        address(bytes20(uint160(uint256(keccak256("hevm cheat code")))));

    StdStorage internal stdstore;

    modifier mayRevert() {
        _;
    }
    modifier testopts(string memory) {
        _;
    }

    function failed() public returns (bool) {
        if (_failed) {
            return _failed;
        } else {
            bool globalFailed = false;
            if (hasHEVMContext()) {
                (, bytes memory retdata) = HEVM_ADDRESS.call(
                    abi.encodePacked(
                        bytes4(keccak256("load(address,bytes32)")),
                        abi.encode(HEVM_ADDRESS, bytes32("failed"))
                    )
                );
                globalFailed = abi.decode(retdata, (bool));
            }
            return globalFailed;
        }
    }

    function fail() internal {
        if (hasHEVMContext()) {
            (bool status, ) = HEVM_ADDRESS.call(
                abi.encodePacked(
                    bytes4(keccak256("store(address,bytes32,bytes32)")),
                    abi.encode(
                        HEVM_ADDRESS,
                        bytes32("failed"),
                        bytes32(uint256(0x01))
                    )
                )
            );
            status; // Silence compiler warnings
        }
        _failed = true;
    }

    function hasHEVMContext() internal view returns (bool) {
        uint256 hevmCodeSize = 0;
        assembly {
            hevmCodeSize := extcodesize(
                0x7109709ECfa91a80626fF3989D68f67F5b1DD12D
            )
        }
        return hevmCodeSize > 0;
    }

    modifier logs_gas() {
        uint256 startGas = gasleft();
        _;
        uint256 endGas = gasleft();
        emit log_named_uint("gas", startGas - endGas);
    }

    function assertTrue(bool condition) internal {
        if (!condition) {
            emit log("Error: Assertion Failed");
            fail();
        }
    }

    function assertTrue(bool condition, string memory err) internal {
        if (!condition) {
            emit log_named_string("Error", err);
            assertTrue(condition);
        }
    }

    function assertEq(address a, address b) internal {
        if (a != b) {
            emit log("Error: a == b not satisfied [address]");
            emit log_named_address("  Expected", b);
            emit log_named_address("    Actual", a);
            fail();
        }
    }

    function assertEq(
        address a,
        address b,
        string memory err
    ) internal {
        if (a != b) {
            emit log_named_string("Error", err);
            assertEq(a, b);
        }
    }

    function assertEq(bytes32 a, bytes32 b) internal {
        if (a != b) {
            emit log("Error: a == b not satisfied [bytes32]");
            emit log_named_bytes32("  Expected", b);
            emit log_named_bytes32("    Actual", a);
            fail();
        }
    }

    function assertEq(
        bytes32 a,
        bytes32 b,
        string memory err
    ) internal {
        if (a != b) {
            emit log_named_string("Error", err);
            assertEq(a, b);
        }
    }

    function assertEq32(bytes32 a, bytes32 b) internal {
        assertEq(a, b);
    }

    function assertEq32(
        bytes32 a,
        bytes32 b,
        string memory err
    ) internal {
        assertEq(a, b, err);
    }

    function assertEq(int256 a, int256 b) internal {
        if (a != b) {
            emit log("Error: a == b not satisfied [int]");
            emit log_named_int("  Expected", b);
            emit log_named_int("    Actual", a);
            fail();
        }
    }

    function assertEq(
        int256 a,
        int256 b,
        string memory err
    ) internal {
        if (a != b) {
            emit log_named_string("Error", err);
            assertEq(a, b);
        }
    }

    function assertEq(uint256 a, uint256 b) internal {
        if (a != b) {
            emit log("Error: a == b not satisfied [uint]");
            emit log_named_uint("  Expected", b);
            emit log_named_uint("    Actual", a);
            fail();
        }
    }

    function assertEq(
        uint256 a,
        uint256 b,
        string memory err
    ) internal {
        if (a != b) {
            emit log_named_string("Error", err);
            assertEq(a, b);
        }
    }

    function assertEqDecimal(
        int256 a,
        int256 b,
        uint256 decimals
    ) internal {
        if (a != b) {
            emit log("Error: a == b not satisfied [decimal int]");
            emit log_named_decimal_int("  Expected", b, decimals);
            emit log_named_decimal_int("    Actual", a, decimals);
            fail();
        }
    }

    function assertEqDecimal(
        int256 a,
        int256 b,
        uint256 decimals,
        string memory err
    ) internal {
        if (a != b) {
            emit log_named_string("Error", err);
            assertEqDecimal(a, b, decimals);
        }
    }

    function assertEqDecimal(
        uint256 a,
        uint256 b,
        uint256 decimals
    ) internal {
        if (a != b) {
            emit log("Error: a == b not satisfied [decimal uint]");
            emit log_named_decimal_uint("  Expected", b, decimals);
            emit log_named_decimal_uint("    Actual", a, decimals);
            fail();
        }
    }

    function assertEqDecimal(
        uint256 a,
        uint256 b,
        uint256 decimals,
        string memory err
    ) internal {
        if (a != b) {
            emit log_named_string("Error", err);
            assertEqDecimal(a, b, decimals);
        }
    }

    function assertGt(uint256 a, uint256 b) internal {
        if (a <= b) {
            emit log("Error: a > b not satisfied [uint]");
            emit log_named_uint("  Value a", a);
            emit log_named_uint("  Value b", b);
            fail();
        }
    }

    function assertGt(
        uint256 a,
        uint256 b,
        string memory err
    ) internal {
        if (a <= b) {
            emit log_named_string("Error", err);
            assertGt(a, b);
        }
    }

    function assertGt(int256 a, int256 b) internal {
        if (a <= b) {
            emit log("Error: a > b not satisfied [int]");
            emit log_named_int("  Value a", a);
            emit log_named_int("  Value b", b);
            fail();
        }
    }

    function assertGt(
        int256 a,
        int256 b,
        string memory err
    ) internal {
        if (a <= b) {
            emit log_named_string("Error", err);
            assertGt(a, b);
        }
    }

    function assertGtDecimal(
        int256 a,
        int256 b,
        uint256 decimals
    ) internal {
        if (a <= b) {
            emit log("Error: a > b not satisfied [decimal int]");
            emit log_named_decimal_int("  Value a", a, decimals);
            emit log_named_decimal_int("  Value b", b, decimals);
            fail();
        }
    }

    function assertGtDecimal(
        int256 a,
        int256 b,
        uint256 decimals,
        string memory err
    ) internal {
        if (a <= b) {
            emit log_named_string("Error", err);
            assertGtDecimal(a, b, decimals);
        }
    }

    function assertGtDecimal(
        uint256 a,
        uint256 b,
        uint256 decimals
    ) internal {
        if (a <= b) {
            emit log("Error: a > b not satisfied [decimal uint]");
            emit log_named_decimal_uint("  Value a", a, decimals);
            emit log_named_decimal_uint("  Value b", b, decimals);
            fail();
        }
    }

    function assertGtDecimal(
        uint256 a,
        uint256 b,
        uint256 decimals,
        string memory err
    ) internal {
        if (a <= b) {
            emit log_named_string("Error", err);
            assertGtDecimal(a, b, decimals);
        }
    }

    function assertGe(uint256 a, uint256 b) internal {
        if (a < b) {
            emit log("Error: a >= b not satisfied [uint]");
            emit log_named_uint("  Value a", a);
            emit log_named_uint("  Value b", b);
            fail();
        }
    }

    function assertGe(
        uint256 a,
        uint256 b,
        string memory err
    ) internal {
        if (a < b) {
            emit log_named_string("Error", err);
            assertGe(a, b);
        }
    }

    function assertGe(int256 a, int256 b) internal {
        if (a < b) {
            emit log("Error: a >= b not satisfied [int]");
            emit log_named_int("  Value a", a);
            emit log_named_int("  Value b", b);
            fail();
        }
    }

    function assertGe(
        int256 a,
        int256 b,
        string memory err
    ) internal {
        if (a < b) {
            emit log_named_string("Error", err);
            assertGe(a, b);
        }
    }

    function assertGeDecimal(
        int256 a,
        int256 b,
        uint256 decimals
    ) internal {
        if (a < b) {
            emit log("Error: a >= b not satisfied [decimal int]");
            emit log_named_decimal_int("  Value a", a, decimals);
            emit log_named_decimal_int("  Value b", b, decimals);
            fail();
        }
    }

    function assertGeDecimal(
        int256 a,
        int256 b,
        uint256 decimals,
        string memory err
    ) internal {
        if (a < b) {
            emit log_named_string("Error", err);
            assertGeDecimal(a, b, decimals);
        }
    }

    function assertGeDecimal(
        uint256 a,
        uint256 b,
        uint256 decimals
    ) internal {
        if (a < b) {
            emit log("Error: a >= b not satisfied [decimal uint]");
            emit log_named_decimal_uint("  Value a", a, decimals);
            emit log_named_decimal_uint("  Value b", b, decimals);
            fail();
        }
    }

    function assertGeDecimal(
        uint256 a,
        uint256 b,
        uint256 decimals,
        string memory err
    ) internal {
        if (a < b) {
            emit log_named_string("Error", err);
            assertGeDecimal(a, b, decimals);
        }
    }

    function assertLt(uint256 a, uint256 b) internal {
        if (a >= b) {
            emit log("Error: a < b not satisfied [uint]");
            emit log_named_uint("  Value a", a);
            emit log_named_uint("  Value b", b);
            fail();
        }
    }

    function assertLt(
        uint256 a,
        uint256 b,
        string memory err
    ) internal {
        if (a >= b) {
            emit log_named_string("Error", err);
            assertLt(a, b);
        }
    }

    function assertLt(int256 a, int256 b) internal {
        if (a >= b) {
            emit log("Error: a < b not satisfied [int]");
            emit log_named_int("  Value a", a);
            emit log_named_int("  Value b", b);
            fail();
        }
    }

    function assertLt(
        int256 a,
        int256 b,
        string memory err
    ) internal {
        if (a >= b) {
            emit log_named_string("Error", err);
            assertLt(a, b);
        }
    }

    function assertLtDecimal(
        int256 a,
        int256 b,
        uint256 decimals
    ) internal {
        if (a >= b) {
            emit log("Error: a < b not satisfied [decimal int]");
            emit log_named_decimal_int("  Value a", a, decimals);
            emit log_named_decimal_int("  Value b", b, decimals);
            fail();
        }
    }

    function assertLtDecimal(
        int256 a,
        int256 b,
        uint256 decimals,
        string memory err
    ) internal {
        if (a >= b) {
            emit log_named_string("Error", err);
            assertLtDecimal(a, b, decimals);
        }
    }

    function assertLtDecimal(
        uint256 a,
        uint256 b,
        uint256 decimals
    ) internal {
        if (a >= b) {
            emit log("Error: a < b not satisfied [decimal uint]");
            emit log_named_decimal_uint("  Value a", a, decimals);
            emit log_named_decimal_uint("  Value b", b, decimals);
            fail();
        }
    }

    function assertLtDecimal(
        uint256 a,
        uint256 b,
        uint256 decimals,
        string memory err
    ) internal {
        if (a >= b) {
            emit log_named_string("Error", err);
            assertLtDecimal(a, b, decimals);
        }
    }

    function assertLe(uint256 a, uint256 b) internal {
        if (a > b) {
            emit log("Error: a <= b not satisfied [uint]");
            emit log_named_uint("  Value a", a);
            emit log_named_uint("  Value b", b);
            fail();
        }
    }

    function assertLe(
        uint256 a,
        uint256 b,
        string memory err
    ) internal {
        if (a > b) {
            emit log_named_string("Error", err);
            assertLe(a, b);
        }
    }

    function assertLe(int256 a, int256 b) internal {
        if (a > b) {
            emit log("Error: a <= b not satisfied [int]");
            emit log_named_int("  Value a", a);
            emit log_named_int("  Value b", b);
            fail();
        }
    }

    function assertLe(
        int256 a,
        int256 b,
        string memory err
    ) internal {
        if (a > b) {
            emit log_named_string("Error", err);
            assertLe(a, b);
        }
    }

    function assertLeDecimal(
        int256 a,
        int256 b,
        uint256 decimals
    ) internal {
        if (a > b) {
            emit log("Error: a <= b not satisfied [decimal int]");
            emit log_named_decimal_int("  Value a", a, decimals);
            emit log_named_decimal_int("  Value b", b, decimals);
            fail();
        }
    }

    function assertLeDecimal(
        int256 a,
        int256 b,
        uint256 decimals,
        string memory err
    ) internal {
        if (a > b) {
            emit log_named_string("Error", err);
            assertLeDecimal(a, b, decimals);
        }
    }

    function assertLeDecimal(
        uint256 a,
        uint256 b,
        uint256 decimals
    ) internal {
        if (a > b) {
            emit log("Error: a <= b not satisfied [decimal uint]");
            emit log_named_decimal_uint("  Value a", a, decimals);
            emit log_named_decimal_uint("  Value b", b, decimals);
            fail();
        }
    }

    function assertLeDecimal(
        uint256 a,
        uint256 b,
        uint256 decimals,
        string memory err
    ) internal {
        if (a > b) {
            emit log_named_string("Error", err);
            assertGeDecimal(a, b, decimals);
        }
    }

    function assertEq(string memory a, string memory b) internal {
        if (keccak256(abi.encodePacked(a)) != keccak256(abi.encodePacked(b))) {
            emit log("Error: a == b not satisfied [string]");
            emit log_named_string("  Expected", b);
            emit log_named_string("    Actual", a);
            fail();
        }
    }

    function assertEq(
        string memory a,
        string memory b,
        string memory err
    ) internal {
        if (keccak256(abi.encodePacked(a)) != keccak256(abi.encodePacked(b))) {
            emit log_named_string("Error", err);
            assertEq(a, b);
        }
    }

    function assertApproxEqAbs(
        uint256 a,
        uint256 b,
        uint256 maxDelta
    ) internal virtual {
        uint256 realDelta = delta(a, b);

        if (realDelta > maxDelta) {
            emit log("Error: a ~= b not satisfied [uint]");
            emit log_named_uint("      Left", a);
            emit log_named_uint("     Right", b);
            emit log_named_uint(" Max Delta", maxDelta);
            emit log_named_uint("     Delta", realDelta);
            fail();
        }
    }

    function assertApproxEqAbs(
        uint256 a,
        uint256 b,
        uint256 maxDelta,
        string memory err
    ) internal virtual {
        uint256 realDelta = delta(a, b);

        if (realDelta > maxDelta) {
            emit log_named_string("Error", err);
            assertApproxEqAbs(a, b, maxDelta);
        }
    }

    function delta(uint256 a, uint256 b) internal pure returns (uint256) {
        return a > b ? a - b : b - a;
    }

    function _bound(
        uint256 x,
        uint256 min,
        uint256 max
    ) internal pure virtual returns (uint256 result) {
        require(
            min <= max,
            "StdUtils bound(uint256,uint256,uint256): Max is less than min."
        );
        // If x is between min and max, return x directly. This is to ensure that dictionary values
        // do not get shifted if the min is nonzero. More info: https://github.com/foundry-rs/forge-std/issues/188
        if (x >= min && x <= max) return x;

        uint256 size = max - min + 1;

        // If the value is 0, 1, 2, 3, wrap that to min, min+1, min+2, min+3. Similarly for the UINT256_MAX side.
        // This helps ensure coverage of the min/max values.
        if (x <= 3 && size > x) return min + x;
        if (x >= UINT256_MAX - 3 && size > UINT256_MAX - x)
            return max - (UINT256_MAX - x);

        // Otherwise, wrap x into the range [min, max], i.e. the range is inclusive.
        if (x > max) {
            uint256 diff = x - max;
            uint256 rem = diff % size;
            if (rem == 0) return max;
            result = min + rem - 1;
        } else if (x < min) {
            uint256 diff = min - x;
            uint256 rem = diff % size;
            if (rem == 0) return min;
            result = max - rem + 1;
        }
    }

    function bound(
        uint256 x,
        uint256 min,
        uint256 max
    ) internal view virtual returns (uint256 result) {
        result = _bound(x, min, max);
    }

    function checkEq0(bytes memory a, bytes memory b)
        internal
        pure
        returns (bool ok)
    {
        ok = true;
        if (a.length == b.length) {
            for (uint256 i = 0; i < a.length; i++) {
                if (a[i] != b[i]) {
                    ok = false;
                }
            }
        } else {
            ok = false;
        }
    }

    function assertEq0(bytes memory a, bytes memory b) internal {
        if (!checkEq0(a, b)) {
            emit log("Error: a == b not satisfied [bytes]");
            emit log_named_bytes("  Expected", b);
            emit log_named_bytes("    Actual", a);
            fail();
        }
    }

    function assertEq0(
        bytes memory a,
        bytes memory b,
        string memory err
    ) internal {
        if (!checkEq0(a, b)) {
            emit log_named_string("Error", err);
            assertEq0(a, b);
        }
    }

    function dealToken(
        address token,
        address to,
        uint256 give,
        bool adjust
    ) internal {
        // get current balance
        (, bytes memory balData) = token.call(
            abi.encodeWithSelector(0x70a08231, to)
        );
        uint256 prevBal = abi.decode(balData, (uint256));

        // update balance
        stdstore.target(token).sig(0x70a08231).with_key(to).checked_write(give);

        // update total supply
        if (adjust) {
            (, bytes memory totSupData) = token.call(
                abi.encodeWithSelector(0x18160ddd)
            );
            uint256 totSup = abi.decode(totSupData, (uint256));
            if (give < prevBal) {
                totSup -= (prevBal - give);
            } else {
                totSup += (give - prevBal);
            }
            stdstore.target(token).sig(0x18160ddd).checked_write(totSup);
        }
    }
}
