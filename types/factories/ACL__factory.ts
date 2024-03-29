/* Autogenerated file. Do not edit manually. */
/* tslint:disable */
/* eslint-disable */
import { Signer, utils, Contract, ContractFactory, Overrides } from "ethers";
import type { Provider, TransactionRequest } from "@ethersproject/providers";
import type { PromiseOrValue } from "../common";
import type { ACL, ACLInterface } from "../ACL";

const _abi = [
  {
    inputs: [
      {
        internalType: "address",
        name: "addr",
        type: "address",
      },
    ],
    name: "AddressNotPausableAdminException",
    type: "error",
  },
  {
    inputs: [
      {
        internalType: "address",
        name: "addr",
        type: "address",
      },
    ],
    name: "AddressNotUnpausableAdminException",
    type: "error",
  },
  {
    anonymous: false,
    inputs: [
      {
        indexed: true,
        internalType: "address",
        name: "previousOwner",
        type: "address",
      },
      {
        indexed: true,
        internalType: "address",
        name: "newOwner",
        type: "address",
      },
    ],
    name: "OwnershipTransferred",
    type: "event",
  },
  {
    anonymous: false,
    inputs: [
      {
        indexed: true,
        internalType: "address",
        name: "newAdmin",
        type: "address",
      },
    ],
    name: "PausableAdminAdded",
    type: "event",
  },
  {
    anonymous: false,
    inputs: [
      {
        indexed: true,
        internalType: "address",
        name: "admin",
        type: "address",
      },
    ],
    name: "PausableAdminRemoved",
    type: "event",
  },
  {
    anonymous: false,
    inputs: [
      {
        indexed: true,
        internalType: "address",
        name: "newAdmin",
        type: "address",
      },
    ],
    name: "UnpausableAdminAdded",
    type: "event",
  },
  {
    anonymous: false,
    inputs: [
      {
        indexed: true,
        internalType: "address",
        name: "admin",
        type: "address",
      },
    ],
    name: "UnpausableAdminRemoved",
    type: "event",
  },
  {
    inputs: [
      {
        internalType: "address",
        name: "newAdmin",
        type: "address",
      },
    ],
    name: "addPausableAdmin",
    outputs: [],
    stateMutability: "nonpayable",
    type: "function",
  },
  {
    inputs: [
      {
        internalType: "address",
        name: "newAdmin",
        type: "address",
      },
    ],
    name: "addUnpausableAdmin",
    outputs: [],
    stateMutability: "nonpayable",
    type: "function",
  },
  {
    inputs: [],
    name: "claimOwnership",
    outputs: [],
    stateMutability: "nonpayable",
    type: "function",
  },
  {
    inputs: [
      {
        internalType: "address",
        name: "account",
        type: "address",
      },
    ],
    name: "isConfigurator",
    outputs: [
      {
        internalType: "bool",
        name: "",
        type: "bool",
      },
    ],
    stateMutability: "view",
    type: "function",
  },
  {
    inputs: [
      {
        internalType: "address",
        name: "addr",
        type: "address",
      },
    ],
    name: "isPausableAdmin",
    outputs: [
      {
        internalType: "bool",
        name: "",
        type: "bool",
      },
    ],
    stateMutability: "view",
    type: "function",
  },
  {
    inputs: [
      {
        internalType: "address",
        name: "addr",
        type: "address",
      },
    ],
    name: "isUnpausableAdmin",
    outputs: [
      {
        internalType: "bool",
        name: "",
        type: "bool",
      },
    ],
    stateMutability: "view",
    type: "function",
  },
  {
    inputs: [],
    name: "owner",
    outputs: [
      {
        internalType: "address",
        name: "",
        type: "address",
      },
    ],
    stateMutability: "view",
    type: "function",
  },
  {
    inputs: [
      {
        internalType: "address",
        name: "",
        type: "address",
      },
    ],
    name: "pausableAdminSet",
    outputs: [
      {
        internalType: "bool",
        name: "",
        type: "bool",
      },
    ],
    stateMutability: "view",
    type: "function",
  },
  {
    inputs: [],
    name: "pendingOwner",
    outputs: [
      {
        internalType: "address",
        name: "",
        type: "address",
      },
    ],
    stateMutability: "view",
    type: "function",
  },
  {
    inputs: [
      {
        internalType: "address",
        name: "admin",
        type: "address",
      },
    ],
    name: "removePausableAdmin",
    outputs: [],
    stateMutability: "nonpayable",
    type: "function",
  },
  {
    inputs: [
      {
        internalType: "address",
        name: "admin",
        type: "address",
      },
    ],
    name: "removeUnpausableAdmin",
    outputs: [],
    stateMutability: "nonpayable",
    type: "function",
  },
  {
    inputs: [],
    name: "renounceOwnership",
    outputs: [],
    stateMutability: "nonpayable",
    type: "function",
  },
  {
    inputs: [
      {
        internalType: "address",
        name: "newOwner",
        type: "address",
      },
    ],
    name: "transferOwnership",
    outputs: [],
    stateMutability: "nonpayable",
    type: "function",
  },
  {
    inputs: [
      {
        internalType: "address",
        name: "",
        type: "address",
      },
    ],
    name: "unpausableAdminSet",
    outputs: [
      {
        internalType: "bool",
        name: "",
        type: "bool",
      },
    ],
    stateMutability: "view",
    type: "function",
  },
  {
    inputs: [],
    name: "version",
    outputs: [
      {
        internalType: "uint256",
        name: "",
        type: "uint256",
      },
    ],
    stateMutability: "view",
    type: "function",
  },
] as const;

const _bytecode =
  "0x608060405234801561001057600080fd5b5061001a3361001f565b61006f565b600080546001600160a01b038381166001600160a01b0319831681178455604051919092169283917f8be0079c531659141344cd1fd0a4f28419497f9722a3daafe3b4186f6b6457e09190a35050565b6109278061007e6000396000f3fe608060405234801561001057600080fd5b50600436106100f55760003560e01c80637328181911610097578063ba306df111610066578063ba306df11461025d578063d4eb5db014610270578063e30c3978146102a9578063f2fde38b146102c957600080fd5b806373281819146101d5578063819ad68e146101f85780638da5cb5b1461020b578063adce758d1461024a57600080fd5b80634e71e0c8116100d35780634e71e0c81461018057806354fd4d50146101885780635f259aba1461019e578063715018a6146101cd57600080fd5b806335914829146100fa5780633a41ec64146101325780634910832f1461016b575b600080fd5b61011d6101083660046108b4565b60026020526000908152604090205460ff1681565b60405190151581526020015b60405180910390f35b61011d6101403660046108b4565b73ffffffffffffffffffffffffffffffffffffffff1660009081526002602052604090205460ff1690565b61017e6101793660046108b4565b6102dc565b005b61017e61035b565b610190600181565b604051908152602001610129565b61011d6101ac3660046108b4565b60005473ffffffffffffffffffffffffffffffffffffffff91821691161490565b61017e610453565b61011d6101e33660046108b4565b60036020526000908152604090205460ff1681565b61017e6102063660046108b4565b610467565b60005473ffffffffffffffffffffffffffffffffffffffff165b60405173ffffffffffffffffffffffffffffffffffffffff9091168152602001610129565b61017e6102583660046108b4565b6104e6565b61017e61026b3660046108b4565b6105d9565b61011d61027e3660046108b4565b73ffffffffffffffffffffffffffffffffffffffff1660009081526003602052604090205460ff1690565b6001546102259073ffffffffffffffffffffffffffffffffffffffff1681565b61017e6102d73660046108b4565b6106cc565b6102e46107be565b73ffffffffffffffffffffffffffffffffffffffff811660008181526002602052604080822080547fffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff00166001179055517fae26b1cfe9454ba87274a4e8330b6654684362d0f3d7bbd17f7449a1d38387c69190a250565b60015473ffffffffffffffffffffffffffffffffffffffff163314610407576040517f08c379a000000000000000000000000000000000000000000000000000000000815260206004820152602660248201527f436c61696d61626c653a2053656e646572206973206e6f742070656e64696e6760448201527f206f776e6572000000000000000000000000000000000000000000000000000060648201526084015b60405180910390fd5b6001546104299073ffffffffffffffffffffffffffffffffffffffff1661083f565b600180547fffffffffffffffffffffffff0000000000000000000000000000000000000000169055565b61045b6107be565b610465600061083f565b565b61046f6107be565b73ffffffffffffffffffffffffffffffffffffffff811660008181526003602052604080822080547fffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff00166001179055517fd400da6c0c0a894dacc0981730b88af0545d00272ee8fff1437bf560ff245fc49190a250565b6104ee6107be565b73ffffffffffffffffffffffffffffffffffffffff811660009081526003602052604090205460ff16610565576040517f57f592b700000000000000000000000000000000000000000000000000000000815273ffffffffffffffffffffffffffffffffffffffff821660048201526024016103fe565b73ffffffffffffffffffffffffffffffffffffffff811660008181526003602052604080822080547fffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff00169055517f1998397e7203f7baca9d6f41b9e4da6e768daac5caad4234fb9bf5869d2715459190a250565b6105e16107be565b73ffffffffffffffffffffffffffffffffffffffff811660009081526002602052604090205460ff16610658576040517fe116318900000000000000000000000000000000000000000000000000000000815273ffffffffffffffffffffffffffffffffffffffff821660048201526024016103fe565b73ffffffffffffffffffffffffffffffffffffffff811660008181526002602052604080822080547fffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff00169055517f28b01395b7e25d20552a0c8dc8ecd3b1d4abc986f14dad7885fd45b6fd73c8d99190a250565b6106d46107be565b73ffffffffffffffffffffffffffffffffffffffff8116610777576040517f08c379a000000000000000000000000000000000000000000000000000000000815260206004820152602860248201527f436c61696d61626c653a206e6577206f776e657220697320746865207a65726f60448201527f206164647265737300000000000000000000000000000000000000000000000060648201526084016103fe565b600180547fffffffffffffffffffffffff00000000000000000000000000000000000000001673ffffffffffffffffffffffffffffffffffffffff92909216919091179055565b60005473ffffffffffffffffffffffffffffffffffffffff163314610465576040517f08c379a000000000000000000000000000000000000000000000000000000000815260206004820181905260248201527f4f776e61626c653a2063616c6c6572206973206e6f7420746865206f776e657260448201526064016103fe565b6000805473ffffffffffffffffffffffffffffffffffffffff8381167fffffffffffffffffffffffff0000000000000000000000000000000000000000831681178455604051919092169283917f8be0079c531659141344cd1fd0a4f28419497f9722a3daafe3b4186f6b6457e09190a35050565b6000602082840312156108c657600080fd5b813573ffffffffffffffffffffffffffffffffffffffff811681146108ea57600080fd5b939250505056fea2646970667358221220381737e7a90f9e44efa08661160a9ff8f165507671ed2e9b068e00bfb4bdea3d64736f6c634300080a0033";

type ACLConstructorParams =
  | [signer?: Signer]
  | ConstructorParameters<typeof ContractFactory>;

const isSuperArgs = (
  xs: ACLConstructorParams
): xs is ConstructorParameters<typeof ContractFactory> => xs.length > 1;

export class ACL__factory extends ContractFactory {
  constructor(...args: ACLConstructorParams) {
    if (isSuperArgs(args)) {
      super(...args);
    } else {
      super(_abi, _bytecode, args[0]);
    }
    this.contractName = "ACL";
  }

  override deploy(
    overrides?: Overrides & { from?: PromiseOrValue<string> }
  ): Promise<ACL> {
    return super.deploy(overrides || {}) as Promise<ACL>;
  }
  override getDeployTransaction(
    overrides?: Overrides & { from?: PromiseOrValue<string> }
  ): TransactionRequest {
    return super.getDeployTransaction(overrides || {});
  }
  override attach(address: string): ACL {
    return super.attach(address) as ACL;
  }
  override connect(signer: Signer): ACL__factory {
    return super.connect(signer) as ACL__factory;
  }
  static readonly contractName: "ACL";

  public readonly contractName: "ACL";

  static readonly bytecode = _bytecode;
  static readonly abi = _abi;
  static createInterface(): ACLInterface {
    return new utils.Interface(_abi) as ACLInterface;
  }
  static connect(address: string, signerOrProvider: Signer | Provider): ACL {
    return new Contract(address, _abi, signerOrProvider) as ACL;
  }
}
