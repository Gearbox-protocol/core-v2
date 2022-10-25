// SPDX-License-Identifier: BUSL-1.1
// Gearbox Protocol. Generalized leverage for DeFi protocols
// (c) Gearbox Holdings, 2022
pragma solidity ^0.8.10;
pragma abicoder v2;

import { EnumerableSet } from "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";
import { Clones } from "@openzeppelin/contracts/proxy/Clones.sol";
import { IAccountFactory } from "../interfaces/IAccountFactory.sol";
import { ICreditAccount } from "../interfaces/ICreditAccount.sol";

import { AddressProvider } from "./AddressProvider.sol";
import { ContractsRegister } from "./ContractsRegister.sol";
import { CreditAccount } from "../credit/CreditAccount.sol";
import { ACLTrait } from "./ACLTrait.sol";
import { ReentrancyGuard } from "@openzeppelin/contracts/security/ReentrancyGuard.sol";

import { Errors } from "../libraries/Errors.sol";

/// @title Abstract reusable credit accounts factory
/// @notice Creates, holds & lends credit accounts to Credit Managers
contract AccountFactory is IAccountFactory, ACLTrait, ReentrancyGuard {
    using EnumerableSet for EnumerableSet.AddressSet;

    //
    //     head
    //      ⬇
    //    -------       -------        -------        -------
    //   |  CA1  | ->  |  CA2  |  ->  |  CA3  |  ->  |  CA4  |  ->  address(0)
    //    -------       -------        -------        -------
    //                                                   ⬆
    //                                                  tail
    //

    /// @dev Credit account linked list
    mapping(address => address) private _nextCreditAccount;

    /// @dev Head of linked list
    address public override head;

    /// @dev Tail of linked list
    address public override tail;

    /// @dev Address of master credit account for cloning
    address public immutable masterCreditAccount;

    /// @dev Set of all Credit Accounts
    EnumerableSet.AddressSet private creditAccountsSet;

    /// @dev Contracts register
    ContractsRegister public immutable _contractsRegister;

    /// @dev Contract version
    uint256 public constant version = 1;

    /// @dev Modifier restricting access to Credit Managers registered in the system
    modifier creditManagerOnly() {
        require(
            _contractsRegister.isCreditManager(msg.sender),
            Errors.REGISTERED_CREDIT_ACCOUNT_MANAGERS_ONLY
        );
        _;
    }

    /**
     * @dev constructor
     * After the constructor is executed, the list should look as follows
     *
     *     head
     *      ⬇
     *    -------
     *   |  CA1  | ->   address(0)
     *    -------
     *      ⬆
     *     tail
     *
     * @param addressProvider Address of address repository
     */
    constructor(address addressProvider) ACLTrait(addressProvider) {
        require(
            addressProvider != address(0),
            Errors.ZERO_ADDRESS_IS_NOT_ALLOWED
        );

        _contractsRegister = ContractsRegister(
            AddressProvider(addressProvider).getContractsRegister()
        ); // T:[AF-1]

        masterCreditAccount = address(new CreditAccount()); // T:[AF-1]
        CreditAccount(masterCreditAccount).initialize(); // T:[AF-1]

        addCreditAccount(); // T:[AF-1]
        head = tail; // T:[AF-1]
        _nextCreditAccount[address(0)] = address(0); // T:[AF-1]
    }

    /**
     * @dev Provides a new credit account to a Credit Manager
     *
     *   Before:
     *  ---------
     *
     *     head
     *      ⬇
     *    -------       -------        -------        -------
     *   |  CA1  | ->  |  CA2  |  ->  |  CA3  |  ->  |  CA4  |  ->  address(0)
     *    -------       -------        -------        -------
     *                                                   ⬆
     *                                                  tail
     *
     *   After:
     *  ---------
     *
     *    head
     *     ⬇
     *   -------        -------        -------
     *  |  CA2  |  ->  |  CA3  |  ->  |  CA4  |  ->  address(0)
     *   -------        -------        -------
     *                                    ⬆
     *                                   tail
     *
     *
     *   -------
     *  |  CA1  |  ->  address(0)
     *   -------
     *
     *  If the taken Credit Account is the last one, creates a new one
     *
     *    head
     *     ⬇
     *   -------
     *  |  CA2  |  ->   address(0)     =>    _addNewCreditAccount()
     *   -------
     *     ⬆
     *    tail
     *
     * @return Address of credit account
     */
    function takeCreditAccount(
        uint256 _borrowedAmount,
        uint256 _cumulativeIndexAtOpen
    )
        external
        override
        creditManagerOnly // T:[AF-12]
        returns (address)
    {
        // Create a new credit account if there are none in stock
        _checkStock(); // T:[AF-3]

        address result = head;
        head = _nextCreditAccount[head]; // T:[AF-2]
        _nextCreditAccount[result] = address(0); // T:[AF-2]

        // Connect the account to a Credit Manager
        ICreditAccount(result).connectTo(
            msg.sender,
            _borrowedAmount,
            _cumulativeIndexAtOpen
        ); // T:[AF-11, 14]

        emit InitializeCreditAccount(result, msg.sender); // T:[AF-5]
        return result; // T:[AF-14]
    }

    /**
     * @dev Retrieves the Credit Account from the Credit Manager and adds it to the stock
     *
     *   Before:
     *  ---------
     *
     *     head
     *      ⬇
     *    -------       -------        -------        -------
     *   |  CA1  | ->  |  CA2  |  ->  |  CA3  |  ->  |  CA4  |  ->  address(0)
     *    -------       -------        -------        -------
     *                                                   ⬆
     *                                                  tail
     *
     *   After:
     *  ---------
     *
     *     head
     *      ⬇
     *    -------       -------        -------        -------       ---------------
     *   |  CA1  | ->  |  CA2  |  ->  |  CA3  |  ->  |  CA4  |  -> |  usedAccount  |  ->  address(0)
     *    -------       -------        -------        -------       ---------------
     *                                                                     ⬆
     *                                                                    tail
     *
     *
     * @param usedAccount Address of returned credit account
     */
    function returnCreditAccount(address usedAccount)
        external
        override
        creditManagerOnly // T:[AF-12]
    {
        require(
            creditAccountsSet.contains(usedAccount),
            Errors.AF_EXTERNAL_ACCOUNTS_ARE_FORBIDDEN
        );
        require(
            ICreditAccount(usedAccount).since() != block.number,
            Errors.AF_CANT_CLOSE_CREDIT_ACCOUNT_IN_THE_SAME_BLOCK
        ); // T:[CM-20]

        _nextCreditAccount[tail] = usedAccount; // T:[AF-7]
        tail = usedAccount; // T:[AF-7]
        emit ReturnCreditAccount(usedAccount); // T:[AF-8]
    }

    /// @dev Gets the next available credit account after the passed one, or address(0) if the passed account is the tail
    /// @param creditAccount Credit Account previous to the one to retrieve
    function getNext(address creditAccount)
        external
        view
        override
        returns (address)
    {
        return _nextCreditAccount[creditAccount];
    }

    /**
     * @dev Deploys a new Credit Account and sets it as a list's tail
     *
     *   Before:
     *  ---------
     *
     *     head
     *      ⬇
     *    -------       -------        -------        -------
     *   |  CA1  | ->  |  CA2  |  ->  |  CA3  |  ->  |  CA4  |  ->  address(0)
     *    -------       -------        -------        -------
     *                                                   ⬆
     *                                                  tail
     *
     *   After:
     *  ---------
     *
     *     head
     *      ⬇
     *    -------       -------        -------        -------       --------------
     *   |  CA1  | ->  |  CA2  |  ->  |  CA3  |  ->  |  CA4  |  -> |  newAccount  |  ->  address(0)
     *    -------       -------        -------        -------       --------------
     *                                                                    ⬆
     *                                                                   tail
     *
     *
     */
    function addCreditAccount() public {
        address clonedAccount = Clones.clone(masterCreditAccount); // T:[AF-2]
        ICreditAccount(clonedAccount).initialize();
        _nextCreditAccount[tail] = clonedAccount; // T:[AF-2]
        tail = clonedAccount; // T:[AF-2]
        creditAccountsSet.add(clonedAccount); // T:[AF-10, 16]
        emit NewCreditAccount(clonedAccount);
    }

    /// @dev Removes an unused Credit Account from the list forever and connects it to the "to" parameter
    /// @param prev Credit Account before the taken one in the linked list
    /// @param creditAccount Credit Account to take
    /// @param to Address to connect the taken Credit Account to
    function takeOut(
        address prev,
        address creditAccount,
        address to
    )
        external
        configuratorOnly // T:[AF-13]
    {
        _checkStock();

        if (head == creditAccount) {
            address prevHead = head;
            head = _nextCreditAccount[head]; // T:[AF-21] it exists because _checkStock() was called;
            _nextCreditAccount[prevHead] = address(0); // T:[AF-21]
        } else {
            require(
                _nextCreditAccount[prev] == creditAccount,
                Errors.AF_CREDIT_ACCOUNT_NOT_IN_STOCK
            ); // T:[AF-15]

            // updates tail if the last CA is taken
            if (creditAccount == tail) {
                tail = prev; // T:[AF-22]
            }

            _nextCreditAccount[prev] = _nextCreditAccount[creditAccount]; // T:[AF-16]
            _nextCreditAccount[creditAccount] = address(0); // T:[AF-16]
        }
        ICreditAccount(creditAccount).connectTo(to, 0, 0); // T:[AF-16, 21]
        creditAccountsSet.remove(creditAccount); // T:[AF-16]
        emit TakeForever(creditAccount, to); // T:[AF-16, 21]
    }

    /**
     * @dev Checks available accounts in stock and deploy a new one if only one remains
     *
     *   If:
     *  ---------
     *
     *     head
     *      ⬇
     *    -------
     *   |  CA1  | ->   address(0)
     *    -------
     *      ⬆
     *     tail
     *
     *   Then:
     *  ---------
     *
     *     head
     *      ⬇
     *    -------       --------------
     *   |  CA1  | ->  |  newAccount  |  ->  address(0)
     *    -------       --------------
     *                       ⬆
     *                      tail
     *
     */
    function _checkStock() internal {
        // T:[AF-9]
        if (_nextCreditAccount[head] == address(0)) {
            addCreditAccount(); // T:[AF-3]
        }
    }

    /// @dev Cancels token allowance from a Credit Acocunt to a target contract
    /// @param account Address of credit account to be cancelled allowance
    /// @param token Address of token for allowance
    /// @param targetContract Address of contract to cancel allowance
    function cancelAllowance(
        address account,
        address token,
        address targetContract
    )
        external
        configuratorOnly // T:[AF-13]
    {
        ICreditAccount(account).cancelAllowance(token, targetContract); // T:[AF-20]
    }

    //
    // GETTERS
    //

    /// @dev Returns the number of unused credit accounts in stock
    function countCreditAccountsInStock()
        external
        view
        override
        returns (uint256)
    {
        uint256 count = 0;
        address pointer = head;
        while (pointer != address(0)) {
            pointer = _nextCreditAccount[pointer];
            count++;
        }
        return count;
    }

    /// @dev Returns the number of deployed credit accounts
    function countCreditAccounts() external view override returns (uint256) {
        return creditAccountsSet.length(); // T:[AF-10]
    }

    /// @dev Returns the credit account address under the passed id
    /// @param id The index of the requested CA
    function creditAccounts(uint256 id)
        external
        view
        override
        returns (address)
    {
        return creditAccountsSet.at(id);
    }

    /// @dev Returns whether the Credit Account is registered with this factory
    /// @param addr Address of the Credit Account to check
    function isCreditAccount(address addr) external view returns (bool) {
        return creditAccountsSet.contains(addr); // T:[AF-16]
    }
}
