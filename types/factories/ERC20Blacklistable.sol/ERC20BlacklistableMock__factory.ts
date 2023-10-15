/* Autogenerated file. Do not edit manually. */
/* tslint:disable */
/* eslint-disable */
import {
  Signer,
  utils,
  Contract,
  ContractFactory,
  BigNumberish,
  Overrides,
} from "ethers";
import type { Provider, TransactionRequest } from "@ethersproject/providers";
import type { PromiseOrValue } from "../../common";
import type {
  ERC20BlacklistableMock,
  ERC20BlacklistableMockInterface,
} from "../../ERC20Blacklistable.sol/ERC20BlacklistableMock";

const _abi = [
  {
    inputs: [
      {
        internalType: "string",
        name: "name_",
        type: "string",
      },
      {
        internalType: "string",
        name: "symbol_",
        type: "string",
      },
      {
        internalType: "uint8",
        name: "decimals_",
        type: "uint8",
      },
    ],
    stateMutability: "nonpayable",
    type: "constructor",
  },
  {
    anonymous: false,
    inputs: [
      {
        indexed: true,
        internalType: "address",
        name: "owner",
        type: "address",
      },
      {
        indexed: true,
        internalType: "address",
        name: "spender",
        type: "address",
      },
      {
        indexed: false,
        internalType: "uint256",
        name: "value",
        type: "uint256",
      },
    ],
    name: "Approval",
    type: "event",
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
        name: "from",
        type: "address",
      },
      {
        indexed: true,
        internalType: "address",
        name: "to",
        type: "address",
      },
      {
        indexed: false,
        internalType: "uint256",
        name: "value",
        type: "uint256",
      },
    ],
    name: "Transfer",
    type: "event",
  },
  {
    inputs: [
      {
        internalType: "address",
        name: "owner",
        type: "address",
      },
      {
        internalType: "address",
        name: "spender",
        type: "address",
      },
    ],
    name: "allowance",
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
  {
    inputs: [
      {
        internalType: "address",
        name: "spender",
        type: "address",
      },
      {
        internalType: "uint256",
        name: "amount",
        type: "uint256",
      },
    ],
    name: "approve",
    outputs: [
      {
        internalType: "bool",
        name: "",
        type: "bool",
      },
    ],
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
    name: "balanceOf",
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
  {
    inputs: [],
    name: "decimals",
    outputs: [
      {
        internalType: "uint8",
        name: "",
        type: "uint8",
      },
    ],
    stateMutability: "view",
    type: "function",
  },
  {
    inputs: [
      {
        internalType: "address",
        name: "spender",
        type: "address",
      },
      {
        internalType: "uint256",
        name: "subtractedValue",
        type: "uint256",
      },
    ],
    name: "decreaseAllowance",
    outputs: [
      {
        internalType: "bool",
        name: "",
        type: "bool",
      },
    ],
    stateMutability: "nonpayable",
    type: "function",
  },
  {
    inputs: [
      {
        internalType: "address",
        name: "spender",
        type: "address",
      },
      {
        internalType: "uint256",
        name: "addedValue",
        type: "uint256",
      },
    ],
    name: "increaseAllowance",
    outputs: [
      {
        internalType: "bool",
        name: "",
        type: "bool",
      },
    ],
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
    name: "isBlackListed",
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
        name: "",
        type: "address",
      },
    ],
    name: "isBlacklisted",
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
        name: "to",
        type: "address",
      },
      {
        internalType: "uint256",
        name: "amount",
        type: "uint256",
      },
    ],
    name: "mint",
    outputs: [
      {
        internalType: "bool",
        name: "",
        type: "bool",
      },
    ],
    stateMutability: "nonpayable",
    type: "function",
  },
  {
    inputs: [],
    name: "name",
    outputs: [
      {
        internalType: "string",
        name: "",
        type: "string",
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
        name: "account",
        type: "address",
      },
      {
        internalType: "bool",
        name: "status",
        type: "bool",
      },
    ],
    name: "setBlackListed",
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
      {
        internalType: "bool",
        name: "status",
        type: "bool",
      },
    ],
    name: "setBlacklisted",
    outputs: [],
    stateMutability: "nonpayable",
    type: "function",
  },
  {
    inputs: [],
    name: "symbol",
    outputs: [
      {
        internalType: "string",
        name: "",
        type: "string",
      },
    ],
    stateMutability: "view",
    type: "function",
  },
  {
    inputs: [],
    name: "totalSupply",
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
  {
    inputs: [
      {
        internalType: "address",
        name: "recipient",
        type: "address",
      },
      {
        internalType: "uint256",
        name: "amount",
        type: "uint256",
      },
    ],
    name: "transfer",
    outputs: [
      {
        internalType: "bool",
        name: "",
        type: "bool",
      },
    ],
    stateMutability: "nonpayable",
    type: "function",
  },
  {
    inputs: [
      {
        internalType: "address",
        name: "from",
        type: "address",
      },
      {
        internalType: "address",
        name: "to",
        type: "address",
      },
      {
        internalType: "uint256",
        name: "amount",
        type: "uint256",
      },
    ],
    name: "transferFrom",
    outputs: [
      {
        internalType: "bool",
        name: "",
        type: "bool",
      },
    ],
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
] as const;

const _bytecode =
  "0x60a06040523480156200001157600080fd5b506040516200159d3803806200159d833981016040819052620000349162000258565b8251839083906200004d906003906020850190620000e5565b50805162000063906004906020840190620000e5565b505050620000806200007a6200008f60201b60201c565b62000093565b60ff16608052506200031a9050565b3390565b600580546001600160a01b038381166001600160a01b0319831681179093556040519116919082907f8be0079c531659141344cd1fd0a4f28419497f9722a3daafe3b4186f6b6457e090600090a35050565b828054620000f390620002dd565b90600052602060002090601f01602090048101928262000117576000855562000162565b82601f106200013257805160ff191683800117855562000162565b8280016001018555821562000162579182015b828111156200016257825182559160200191906001019062000145565b506200017092915062000174565b5090565b5b8082111562000170576000815560010162000175565b634e487b7160e01b600052604160045260246000fd5b600082601f830112620001b357600080fd5b81516001600160401b0380821115620001d057620001d06200018b565b604051601f8301601f19908116603f01168101908282118183101715620001fb57620001fb6200018b565b816040528381526020925086838588010111156200021857600080fd5b600091505b838210156200023c57858201830151818301840152908201906200021d565b838211156200024e5760008385830101525b9695505050505050565b6000806000606084860312156200026e57600080fd5b83516001600160401b03808211156200028657600080fd5b6200029487838801620001a1565b94506020860151915080821115620002ab57600080fd5b50620002ba86828701620001a1565b925050604084015160ff81168114620002d257600080fd5b809150509250925092565b600181811c90821680620002f257607f821691505b602082108114156200031457634e487b7160e01b600052602260045260246000fd5b50919050565b6080516112676200033660003960006101c301526112676000f3fe608060405234801561001057600080fd5b50600436106101515760003560e01c8063715018a6116100cd578063d01dd6d211610081578063e47d606011610066578063e47d6060146103b7578063f2fde38b146103da578063fe575a87146103ed57600080fd5b8063d01dd6d21461030d578063dd62ed3e1461037157600080fd5b806395d89b41116100b257806395d89b41146102df578063a457c2d7146102e7578063a9059cbb146102fa57600080fd5b8063715018a6146102af5780638da5cb5b146102b757600080fd5b8063313ce5671161012457806340c10f191161010957806340c10f19146102005780635cd8c0721461021357806370a082311461027957600080fd5b8063313ce567146101bc57806339509351146101ed57600080fd5b806306fdde0314610156578063095ea7b31461017457806318160ddd1461019757806323b872dd146101a9575b600080fd5b61015e610410565b60405161016b919061100b565b60405180910390f35b6101876101823660046110a7565b6104a2565b604051901515815260200161016b565b6002545b60405190815260200161016b565b6101876101b73660046110d1565b6104ba565b60405160ff7f000000000000000000000000000000000000000000000000000000000000000016815260200161016b565b6101876101fb3660046110a7565b6105c7565b61018761020e3660046110a7565b610613565b61027761022136600461110d565b73ffffffffffffffffffffffffffffffffffffffff91909116600090815260076020526040902080547fffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff0016911515919091179055565b005b61019b610287366004611149565b73ffffffffffffffffffffffffffffffffffffffff1660009081526020819052604090205490565b610277610630565b60055460405173ffffffffffffffffffffffffffffffffffffffff909116815260200161016b565b61015e610644565b6101876102f53660046110a7565b610653565b6101876103083660046110a7565b610724565b61027761031b36600461110d565b73ffffffffffffffffffffffffffffffffffffffff91909116600090815260066020526040902080547fffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff0016911515919091179055565b61019b61037f36600461116b565b73ffffffffffffffffffffffffffffffffffffffff918216600090815260016020908152604080832093909416825291909152205490565b6101876103c5366004611149565b60076020526000908152604090205460ff1681565b6102776103e8366004611149565b6107ff565b6101876103fb366004611149565b60066020526000908152604090205460ff1681565b60606003805461041f9061119e565b80601f016020809104026020016040519081016040528092919081815260200182805461044b9061119e565b80156104985780601f1061046d57610100808354040283529160200191610498565b820191906000526020600020905b81548152906001019060200180831161047b57829003601f168201915b5050505050905090565b6000336104b08185856108b6565b5060019392505050565b73ffffffffffffffffffffffffffffffffffffffff831660009081526006602052604081205460ff1680610513575073ffffffffffffffffffffffffffffffffffffffff831660009081526006602052604090205460ff165b156105a5576040517f08c379a000000000000000000000000000000000000000000000000000000000815260206004820152602a60248201527f546f6b656e207472616e73616374696f6e207769746820626c61636b6c69737460448201527f656420616464726573730000000000000000000000000000000000000000000060648201526084015b60405180910390fd5b336105b1858285610a69565b6105bc858585610b40565b506001949350505050565b33600081815260016020908152604080832073ffffffffffffffffffffffffffffffffffffffff871684529091528120549091906104b0908290869061060e9087906111f2565b6108b6565b600061061d610df3565b6106278383610e74565b50600192915050565b610638610df3565b6106426000610f94565b565b60606004805461041f9061119e565b33600081815260016020908152604080832073ffffffffffffffffffffffffffffffffffffffff8716845290915281205490919083811015610717576040517f08c379a000000000000000000000000000000000000000000000000000000000815260206004820152602560248201527f45524332303a2064656372656173656420616c6c6f77616e63652062656c6f7760448201527f207a65726f000000000000000000000000000000000000000000000000000000606482015260840161059c565b6105bc82868684036108b6565b3360009081526006602052604081205460ff1680610767575073ffffffffffffffffffffffffffffffffffffffff831660009081526006602052604090205460ff165b156107f4576040517f08c379a000000000000000000000000000000000000000000000000000000000815260206004820152602a60248201527f546f6b656e207472616e73616374696f6e207769746820626c61636b6c69737460448201527f6564206164647265737300000000000000000000000000000000000000000000606482015260840161059c565b610627338484610b40565b610807610df3565b73ffffffffffffffffffffffffffffffffffffffff81166108aa576040517f08c379a000000000000000000000000000000000000000000000000000000000815260206004820152602660248201527f4f776e61626c653a206e6577206f776e657220697320746865207a65726f206160448201527f6464726573730000000000000000000000000000000000000000000000000000606482015260840161059c565b6108b381610f94565b50565b73ffffffffffffffffffffffffffffffffffffffff8316610958576040517f08c379a0000000000000000000000000000000000000000000000000000000008152602060048201526024808201527f45524332303a20617070726f76652066726f6d20746865207a65726f2061646460448201527f7265737300000000000000000000000000000000000000000000000000000000606482015260840161059c565b73ffffffffffffffffffffffffffffffffffffffff82166109fb576040517f08c379a000000000000000000000000000000000000000000000000000000000815260206004820152602260248201527f45524332303a20617070726f766520746f20746865207a65726f20616464726560448201527f7373000000000000000000000000000000000000000000000000000000000000606482015260840161059c565b73ffffffffffffffffffffffffffffffffffffffff83811660008181526001602090815260408083209487168084529482529182902085905590518481527f8c5be1e5ebec7d5bd14f71427d1e84f3dd0314c0f7b2291e5b200ac8c7c3b925910160405180910390a3505050565b73ffffffffffffffffffffffffffffffffffffffff8381166000908152600160209081526040808320938616835292905220547fffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff8114610b3a5781811015610b2d576040517f08c379a000000000000000000000000000000000000000000000000000000000815260206004820152601d60248201527f45524332303a20696e73756666696369656e7420616c6c6f77616e6365000000604482015260640161059c565b610b3a84848484036108b6565b50505050565b73ffffffffffffffffffffffffffffffffffffffff8316610be3576040517f08c379a000000000000000000000000000000000000000000000000000000000815260206004820152602560248201527f45524332303a207472616e736665722066726f6d20746865207a65726f20616460448201527f6472657373000000000000000000000000000000000000000000000000000000606482015260840161059c565b73ffffffffffffffffffffffffffffffffffffffff8216610c86576040517f08c379a000000000000000000000000000000000000000000000000000000000815260206004820152602360248201527f45524332303a207472616e7366657220746f20746865207a65726f206164647260448201527f6573730000000000000000000000000000000000000000000000000000000000606482015260840161059c565b73ffffffffffffffffffffffffffffffffffffffff831660009081526020819052604090205481811015610d3c576040517f08c379a000000000000000000000000000000000000000000000000000000000815260206004820152602660248201527f45524332303a207472616e7366657220616d6f756e742065786365656473206260448201527f616c616e63650000000000000000000000000000000000000000000000000000606482015260840161059c565b73ffffffffffffffffffffffffffffffffffffffff808516600090815260208190526040808220858503905591851681529081208054849290610d809084906111f2565b925050819055508273ffffffffffffffffffffffffffffffffffffffff168473ffffffffffffffffffffffffffffffffffffffff167fddf252ad1be2c89b69c2b068fc378daa952ba7f163c4a11628f55a4df523b3ef84604051610de691815260200190565b60405180910390a3610b3a565b60055473ffffffffffffffffffffffffffffffffffffffff163314610642576040517f08c379a000000000000000000000000000000000000000000000000000000000815260206004820181905260248201527f4f776e61626c653a2063616c6c6572206973206e6f7420746865206f776e6572604482015260640161059c565b73ffffffffffffffffffffffffffffffffffffffff8216610ef1576040517f08c379a000000000000000000000000000000000000000000000000000000000815260206004820152601f60248201527f45524332303a206d696e7420746f20746865207a65726f206164647265737300604482015260640161059c565b8060026000828254610f0391906111f2565b909155505073ffffffffffffffffffffffffffffffffffffffff821660009081526020819052604081208054839290610f3d9084906111f2565b909155505060405181815273ffffffffffffffffffffffffffffffffffffffff8316906000907fddf252ad1be2c89b69c2b068fc378daa952ba7f163c4a11628f55a4df523b3ef9060200160405180910390a35050565b6005805473ffffffffffffffffffffffffffffffffffffffff8381167fffffffffffffffffffffffff0000000000000000000000000000000000000000831681179093556040519116919082907f8be0079c531659141344cd1fd0a4f28419497f9722a3daafe3b4186f6b6457e090600090a35050565b600060208083528351808285015260005b818110156110385785810183015185820160400152820161101c565b8181111561104a576000604083870101525b50601f017fffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffe016929092016040019392505050565b803573ffffffffffffffffffffffffffffffffffffffff811681146110a257600080fd5b919050565b600080604083850312156110ba57600080fd5b6110c38361107e565b946020939093013593505050565b6000806000606084860312156110e657600080fd5b6110ef8461107e565b92506110fd6020850161107e565b9150604084013590509250925092565b6000806040838503121561112057600080fd5b6111298361107e565b91506020830135801515811461113e57600080fd5b809150509250929050565b60006020828403121561115b57600080fd5b6111648261107e565b9392505050565b6000806040838503121561117e57600080fd5b6111878361107e565b91506111956020840161107e565b90509250929050565b600181811c908216806111b257607f821691505b602082108114156111ec577f4e487b7100000000000000000000000000000000000000000000000000000000600052602260045260246000fd5b50919050565b6000821982111561122c577f4e487b7100000000000000000000000000000000000000000000000000000000600052601160045260246000fd5b50019056fea2646970667358221220859d6cda35598d43b55772bdc699631678aedf02a02f3a26b165afc90d92f13464736f6c634300080a0033";

type ERC20BlacklistableMockConstructorParams =
  | [signer?: Signer]
  | ConstructorParameters<typeof ContractFactory>;

const isSuperArgs = (
  xs: ERC20BlacklistableMockConstructorParams
): xs is ConstructorParameters<typeof ContractFactory> => xs.length > 1;

export class ERC20BlacklistableMock__factory extends ContractFactory {
  constructor(...args: ERC20BlacklistableMockConstructorParams) {
    if (isSuperArgs(args)) {
      super(...args);
    } else {
      super(_abi, _bytecode, args[0]);
    }
    this.contractName = "ERC20BlacklistableMock";
  }

  override deploy(
    name_: PromiseOrValue<string>,
    symbol_: PromiseOrValue<string>,
    decimals_: PromiseOrValue<BigNumberish>,
    overrides?: Overrides & { from?: PromiseOrValue<string> }
  ): Promise<ERC20BlacklistableMock> {
    return super.deploy(
      name_,
      symbol_,
      decimals_,
      overrides || {}
    ) as Promise<ERC20BlacklistableMock>;
  }
  override getDeployTransaction(
    name_: PromiseOrValue<string>,
    symbol_: PromiseOrValue<string>,
    decimals_: PromiseOrValue<BigNumberish>,
    overrides?: Overrides & { from?: PromiseOrValue<string> }
  ): TransactionRequest {
    return super.getDeployTransaction(
      name_,
      symbol_,
      decimals_,
      overrides || {}
    );
  }
  override attach(address: string): ERC20BlacklistableMock {
    return super.attach(address) as ERC20BlacklistableMock;
  }
  override connect(signer: Signer): ERC20BlacklistableMock__factory {
    return super.connect(signer) as ERC20BlacklistableMock__factory;
  }
  static readonly contractName: "ERC20BlacklistableMock";

  public readonly contractName: "ERC20BlacklistableMock";

  static readonly bytecode = _bytecode;
  static readonly abi = _abi;
  static createInterface(): ERC20BlacklistableMockInterface {
    return new utils.Interface(_abi) as ERC20BlacklistableMockInterface;
  }
  static connect(
    address: string,
    signerOrProvider: Signer | Provider
  ): ERC20BlacklistableMock {
    return new Contract(
      address,
      _abi,
      signerOrProvider
    ) as ERC20BlacklistableMock;
  }
}