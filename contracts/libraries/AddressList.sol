// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.10;

library AddressList {
    function includes(address[] memory array, address item)
        internal
        pure
        returns (bool)
    {
        uint256 len = array.length;

        for (uint256 i; i < len; ) {
            if (array[i] == item) return true;
            unchecked {
                ++i;
            }
        }

        return false;
    }

    function trim(address[] memory array)
        internal
        pure
        returns (address[] memory trimmed)
    {
        uint256 len = array.length;

        if (len == 0) return array;

        uint256 foundLen;
        while (array[foundLen] != address(0)) {
            unchecked {
                ++foundLen;
                if (foundLen == len) return array;
            }
        }

        if (foundLen > 0) return copy(array, foundLen);
    }

    function copy(address[] memory array, uint256 len)
        internal
        pure
        returns (address[] memory res)
    {
        res = new address[](len);
        for (uint256 i; i < len; ) {
            res[i] = array[i];
            unchecked {
                ++i;
            }
        }
    }

    function concat(address[] memory calls1, address[] memory calls2)
        internal
        pure
        returns (address[] memory res)
    {
        uint256 len1 = calls1.length;
        uint256 lenTotal = len1 + calls2.length;

        if (lenTotal == len1) return calls1;

        res = new address[](lenTotal);

        for (uint256 i; i < lenTotal; ) {
            res[i] = (i < len1) ? calls1[i] : calls2[i - len1];
            unchecked {
                ++i;
            }
        }
    }

    function append(address[] memory addrs, address newAddr)
        internal
        pure
        returns (address[] memory res)
    {
        address[] memory newAddrArray = new address[](1);
        newAddrArray[0] = newAddr;
        return concat(addrs, newAddrArray);
    }
}
