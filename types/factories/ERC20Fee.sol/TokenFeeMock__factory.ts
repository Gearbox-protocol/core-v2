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
  TokenFeeMock,
  TokenFeeMockInterface,
} from "../../ERC20Fee.sol/TokenFeeMock";

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
        internalType: "uint256",
        name: "fee_",
        type: "uint256",
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
    inputs: [],
    name: "fee",
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
    outputs: [],
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
        name: "sender",
        type: "address",
      },
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
  "0x60806040523480156200001157600080fd5b506040516200147838038062001478833981016040819052620000349162000399565b8251839083906200004d90600390602085019062000226565b5080516200006390600490602084019062000226565b505050620000806200007a620000eb60201b60201c565b620000ef565b620000963369d3c21bcecceda100000062000141565b60068190556127108110620000e25760405162461bcd60e51b815260206004820152600d60248201526c496e636f72726563742066656560981b60448201526064015b60405180910390fd5b50505062000470565b3390565b600580546001600160a01b038381166001600160a01b0319831681179093556040519116919082907f8be0079c531659141344cd1fd0a4f28419497f9722a3daafe3b4186f6b6457e090600090a35050565b6001600160a01b038216620001995760405162461bcd60e51b815260206004820152601f60248201527f45524332303a206d696e7420746f20746865207a65726f2061646472657373006044820152606401620000d9565b8060026000828254620001ad91906200040c565b90915550506001600160a01b03821660009081526020819052604081208054839290620001dc9084906200040c565b90915550506040518181526001600160a01b038316906000907fddf252ad1be2c89b69c2b068fc378daa952ba7f163c4a11628f55a4df523b3ef9060200160405180910390a35050565b828054620002349062000433565b90600052602060002090601f016020900481019282620002585760008555620002a3565b82601f106200027357805160ff1916838001178555620002a3565b82800160010185558215620002a3579182015b82811115620002a357825182559160200191906001019062000286565b50620002b1929150620002b5565b5090565b5b80821115620002b15760008155600101620002b6565b634e487b7160e01b600052604160045260246000fd5b600082601f830112620002f457600080fd5b81516001600160401b0380821115620003115762000311620002cc565b604051601f8301601f19908116603f011681019082821181831017156200033c576200033c620002cc565b816040528381526020925086838588010111156200035957600080fd5b600091505b838210156200037d57858201830151818301840152908201906200035e565b838211156200038f5760008385830101525b9695505050505050565b600080600060608486031215620003af57600080fd5b83516001600160401b0380821115620003c757600080fd5b620003d587838801620002e2565b94506020860151915080821115620003ec57600080fd5b50620003fb86828701620002e2565b925050604084015190509250925092565b600082198211156200042e57634e487b7160e01b600052601160045260246000fd5b500190565b600181811c908216806200044857607f821691505b602082108114156200046a57634e487b7160e01b600052602260045260246000fd5b50919050565b610ff880620004806000396000f3fe608060405234801561001057600080fd5b50600436106101005760003560e01c8063715018a611610097578063a9059cbb11610066578063a9059cbb14610223578063dd62ed3e14610236578063ddca3f431461027c578063f2fde38b1461028557600080fd5b8063715018a6146101d85780638da5cb5b146101e057806395d89b4114610208578063a457c2d71461021057600080fd5b8063313ce567116100d3578063313ce5671461016b578063395093511461017a57806340c10f191461018d57806370a08231146101a257600080fd5b806306fdde0314610105578063095ea7b31461012357806318160ddd1461014657806323b872dd14610158575b600080fd5b61010d610298565b60405161011a9190610d41565b60405180910390f35b610136610131366004610ddd565b61032a565b604051901515815260200161011a565b6002545b60405190815260200161011a565b610136610166366004610e07565b610342565b6040516012815260200161011a565b610136610188366004610ddd565b61037f565b6101a061019b366004610ddd565b6103cb565b005b61014a6101b0366004610e43565b73ffffffffffffffffffffffffffffffffffffffff1660009081526020819052604090205490565b6101a06103e1565b60055460405173ffffffffffffffffffffffffffffffffffffffff909116815260200161011a565b61010d6103f5565b61013661021e366004610ddd565b610404565b610136610231366004610ddd565b6104e5565b61014a610244366004610e65565b73ffffffffffffffffffffffffffffffffffffffff918216600090815260016020908152604080832093909416825291909152205490565b61014a60065481565b6101a0610293366004610e43565b610520565b6060600380546102a790610e98565b80601f01602080910402602001604051908101604052809291908181526020018280546102d390610e98565b80156103205780601f106102f557610100808354040283529160200191610320565b820191906000526020600020905b81548152906001019060200180831161030357829003601f168201915b5050505050905090565b6000336103388185856105d7565b5060019392505050565b600654600090612710906103569082610f1b565b6103609084610f32565b61036a9190610f6f565b915061037784848461078a565b949350505050565b33600081815260016020908152604080832073ffffffffffffffffffffffffffffffffffffffff8716845290915281205490919061033890829086906103c6908790610faa565b6105d7565b6103d36107a3565b6103dd8282610824565b5050565b6103e96107a3565b6103f36000610944565b565b6060600480546102a790610e98565b33600081815260016020908152604080832073ffffffffffffffffffffffffffffffffffffffff87168452909152812054909190838110156104cd576040517f08c379a000000000000000000000000000000000000000000000000000000000815260206004820152602560248201527f45524332303a2064656372656173656420616c6c6f77616e63652062656c6f7760448201527f207a65726f00000000000000000000000000000000000000000000000000000060648201526084015b60405180910390fd5b6104da82868684036105d7565b506001949350505050565b6000610517336006548590612710906104fe9082610f1b565b6105089087610f32565b6105129190610f6f565b6109bb565b50600192915050565b6105286107a3565b73ffffffffffffffffffffffffffffffffffffffff81166105cb576040517f08c379a000000000000000000000000000000000000000000000000000000000815260206004820152602660248201527f4f776e61626c653a206e6577206f776e657220697320746865207a65726f206160448201527f646472657373000000000000000000000000000000000000000000000000000060648201526084016104c4565b6105d481610944565b50565b73ffffffffffffffffffffffffffffffffffffffff8316610679576040517f08c379a0000000000000000000000000000000000000000000000000000000008152602060048201526024808201527f45524332303a20617070726f76652066726f6d20746865207a65726f2061646460448201527f726573730000000000000000000000000000000000000000000000000000000060648201526084016104c4565b73ffffffffffffffffffffffffffffffffffffffff821661071c576040517f08c379a000000000000000000000000000000000000000000000000000000000815260206004820152602260248201527f45524332303a20617070726f766520746f20746865207a65726f20616464726560448201527f737300000000000000000000000000000000000000000000000000000000000060648201526084016104c4565b73ffffffffffffffffffffffffffffffffffffffff83811660008181526001602090815260408083209487168084529482529182902085905590518481527f8c5be1e5ebec7d5bd14f71427d1e84f3dd0314c0f7b2291e5b200ac8c7c3b925910160405180910390a3505050565b600033610798858285610c70565b6104da8585856109bb565b60055473ffffffffffffffffffffffffffffffffffffffff1633146103f3576040517f08c379a000000000000000000000000000000000000000000000000000000000815260206004820181905260248201527f4f776e61626c653a2063616c6c6572206973206e6f7420746865206f776e657260448201526064016104c4565b73ffffffffffffffffffffffffffffffffffffffff82166108a1576040517f08c379a000000000000000000000000000000000000000000000000000000000815260206004820152601f60248201527f45524332303a206d696e7420746f20746865207a65726f20616464726573730060448201526064016104c4565b80600260008282546108b39190610faa565b909155505073ffffffffffffffffffffffffffffffffffffffff8216600090815260208190526040812080548392906108ed908490610faa565b909155505060405181815273ffffffffffffffffffffffffffffffffffffffff8316906000907fddf252ad1be2c89b69c2b068fc378daa952ba7f163c4a11628f55a4df523b3ef9060200160405180910390a35050565b6005805473ffffffffffffffffffffffffffffffffffffffff8381167fffffffffffffffffffffffff0000000000000000000000000000000000000000831681179093556040519116919082907f8be0079c531659141344cd1fd0a4f28419497f9722a3daafe3b4186f6b6457e090600090a35050565b73ffffffffffffffffffffffffffffffffffffffff8316610a5e576040517f08c379a000000000000000000000000000000000000000000000000000000000815260206004820152602560248201527f45524332303a207472616e736665722066726f6d20746865207a65726f20616460448201527f647265737300000000000000000000000000000000000000000000000000000060648201526084016104c4565b73ffffffffffffffffffffffffffffffffffffffff8216610b01576040517f08c379a000000000000000000000000000000000000000000000000000000000815260206004820152602360248201527f45524332303a207472616e7366657220746f20746865207a65726f206164647260448201527f657373000000000000000000000000000000000000000000000000000000000060648201526084016104c4565b73ffffffffffffffffffffffffffffffffffffffff831660009081526020819052604090205481811015610bb7576040517f08c379a000000000000000000000000000000000000000000000000000000000815260206004820152602660248201527f45524332303a207472616e7366657220616d6f756e742065786365656473206260448201527f616c616e6365000000000000000000000000000000000000000000000000000060648201526084016104c4565b73ffffffffffffffffffffffffffffffffffffffff808516600090815260208190526040808220858503905591851681529081208054849290610bfb908490610faa565b925050819055508273ffffffffffffffffffffffffffffffffffffffff168473ffffffffffffffffffffffffffffffffffffffff167fddf252ad1be2c89b69c2b068fc378daa952ba7f163c4a11628f55a4df523b3ef84604051610c6191815260200190565b60405180910390a35b50505050565b73ffffffffffffffffffffffffffffffffffffffff8381166000908152600160209081526040808320938616835292905220547fffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff8114610c6a5781811015610d34576040517f08c379a000000000000000000000000000000000000000000000000000000000815260206004820152601d60248201527f45524332303a20696e73756666696369656e7420616c6c6f77616e636500000060448201526064016104c4565b610c6a84848484036105d7565b600060208083528351808285015260005b81811015610d6e57858101830151858201604001528201610d52565b81811115610d80576000604083870101525b50601f017fffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffe016929092016040019392505050565b803573ffffffffffffffffffffffffffffffffffffffff81168114610dd857600080fd5b919050565b60008060408385031215610df057600080fd5b610df983610db4565b946020939093013593505050565b600080600060608486031215610e1c57600080fd5b610e2584610db4565b9250610e3360208501610db4565b9150604084013590509250925092565b600060208284031215610e5557600080fd5b610e5e82610db4565b9392505050565b60008060408385031215610e7857600080fd5b610e8183610db4565b9150610e8f60208401610db4565b90509250929050565b600181811c90821680610eac57607f821691505b60208210811415610ee6577f4e487b7100000000000000000000000000000000000000000000000000000000600052602260045260246000fd5b50919050565b7f4e487b7100000000000000000000000000000000000000000000000000000000600052601160045260246000fd5b600082821015610f2d57610f2d610eec565b500390565b6000817fffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff0483118215151615610f6a57610f6a610eec565b500290565b600082610fa5577f4e487b7100000000000000000000000000000000000000000000000000000000600052601260045260246000fd5b500490565b60008219821115610fbd57610fbd610eec565b50019056fea2646970667358221220ef1b2a5687b3e0f52b437edf9e1f475fbb613bc811e8760a562e6600cac477cc64736f6c634300080a0033";

type TokenFeeMockConstructorParams =
  | [signer?: Signer]
  | ConstructorParameters<typeof ContractFactory>;

const isSuperArgs = (
  xs: TokenFeeMockConstructorParams
): xs is ConstructorParameters<typeof ContractFactory> => xs.length > 1;

export class TokenFeeMock__factory extends ContractFactory {
  constructor(...args: TokenFeeMockConstructorParams) {
    if (isSuperArgs(args)) {
      super(...args);
    } else {
      super(_abi, _bytecode, args[0]);
    }
    this.contractName = "TokenFeeMock";
  }

  override deploy(
    name_: PromiseOrValue<string>,
    symbol_: PromiseOrValue<string>,
    fee_: PromiseOrValue<BigNumberish>,
    overrides?: Overrides & { from?: PromiseOrValue<string> }
  ): Promise<TokenFeeMock> {
    return super.deploy(
      name_,
      symbol_,
      fee_,
      overrides || {}
    ) as Promise<TokenFeeMock>;
  }
  override getDeployTransaction(
    name_: PromiseOrValue<string>,
    symbol_: PromiseOrValue<string>,
    fee_: PromiseOrValue<BigNumberish>,
    overrides?: Overrides & { from?: PromiseOrValue<string> }
  ): TransactionRequest {
    return super.getDeployTransaction(name_, symbol_, fee_, overrides || {});
  }
  override attach(address: string): TokenFeeMock {
    return super.attach(address) as TokenFeeMock;
  }
  override connect(signer: Signer): TokenFeeMock__factory {
    return super.connect(signer) as TokenFeeMock__factory;
  }
  static readonly contractName: "TokenFeeMock";

  public readonly contractName: "TokenFeeMock";

  static readonly bytecode = _bytecode;
  static readonly abi = _abi;
  static createInterface(): TokenFeeMockInterface {
    return new utils.Interface(_abi) as TokenFeeMockInterface;
  }
  static connect(
    address: string,
    signerOrProvider: Signer | Provider
  ): TokenFeeMock {
    return new Contract(address, _abi, signerOrProvider) as TokenFeeMock;
  }
}
