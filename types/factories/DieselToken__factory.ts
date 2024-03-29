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
import type { PromiseOrValue } from "../common";
import type { DieselToken, DieselTokenInterface } from "../DieselToken";

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
    inputs: [],
    name: "PoolServiceOnlyException",
    type: "error",
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
    name: "burn",
    outputs: [],
    stateMutability: "nonpayable",
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
    name: "poolService",
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
        name: "to",
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
] as const;

const _bytecode =
  "0x60c06040523480156200001157600080fd5b506040516200131d3803806200131d8339810160408190526200003491620001eb565b8251839083906200004d90600390602085019062000078565b5080516200006390600490602084019062000078565b50505060ff1660805250503360a052620002ad565b828054620000869062000270565b90600052602060002090601f016020900481019282620000aa5760008555620000f5565b82601f10620000c557805160ff1916838001178555620000f5565b82800160010185558215620000f5579182015b82811115620000f5578251825591602001919060010190620000d8565b506200010392915062000107565b5090565b5b8082111562000103576000815560010162000108565b634e487b7160e01b600052604160045260246000fd5b600082601f8301126200014657600080fd5b81516001600160401b03808211156200016357620001636200011e565b604051601f8301601f19908116603f011681019082821181831017156200018e576200018e6200011e565b81604052838152602092508683858801011115620001ab57600080fd5b600091505b83821015620001cf5785820183015181830184015290820190620001b0565b83821115620001e15760008385830101525b9695505050505050565b6000806000606084860312156200020157600080fd5b83516001600160401b03808211156200021957600080fd5b620002278783880162000134565b945060208601519150808211156200023e57600080fd5b506200024d8682870162000134565b925050604084015160ff811681146200026557600080fd5b809150509250925092565b600181811c908216806200028557607f821691505b60208210811415620002a757634e487b7160e01b600052602260045260246000fd5b50919050565b60805160a05161103c620002e1600039600081816101b3015281816103e901526104750152600061015c015261103c6000f3fe608060405234801561001057600080fd5b50600436106100ea5760003560e01c8063570a7af21161008c5780639dc29fac116100665780639dc29fac14610238578063a457c2d71461024b578063a9059cbb1461025e578063dd62ed3e1461027157600080fd5b8063570a7af2146101ae57806370a08231146101fa57806395d89b411461023057600080fd5b806323b872dd116100c857806323b872dd14610142578063313ce56714610155578063395093511461018657806340c10f191461019957600080fd5b806306fdde03146100ef578063095ea7b31461010d57806318160ddd14610130575b600080fd5b6100f76102b7565b6040516101049190610dfd565b60405180910390f35b61012061011b366004610e99565b610349565b6040519015158152602001610104565b6002545b604051908152602001610104565b610120610150366004610ec3565b610361565b60405160ff7f0000000000000000000000000000000000000000000000000000000000000000168152602001610104565b610120610194366004610e99565b610385565b6101ac6101a7366004610e99565b6103d1565b005b6101d57f000000000000000000000000000000000000000000000000000000000000000081565b60405173ffffffffffffffffffffffffffffffffffffffff9091168152602001610104565b610134610208366004610eff565b73ffffffffffffffffffffffffffffffffffffffff1660009081526020819052604090205490565b6100f761044e565b6101ac610246366004610e99565b61045d565b610120610259366004610e99565b6104d6565b61012061026c366004610e99565b6105ac565b61013461027f366004610f21565b73ffffffffffffffffffffffffffffffffffffffff918216600090815260016020908152604080832093909416825291909152205490565b6060600380546102c690610f54565b80601f01602080910402602001604051908101604052809291908181526020018280546102f290610f54565b801561033f5780601f106103145761010080835404028352916020019161033f565b820191906000526020600020905b81548152906001019060200180831161032257829003601f168201915b5050505050905090565b6000336103578185856105ba565b5060019392505050565b60003361036f85828561076e565b61037a858585610845565b506001949350505050565b33600081815260016020908152604080832073ffffffffffffffffffffffffffffffffffffffff8716845290915281205490919061035790829086906103cc908790610fd7565b6105ba565b3373ffffffffffffffffffffffffffffffffffffffff7f00000000000000000000000000000000000000000000000000000000000000001614610440576040517f95c3dbc500000000000000000000000000000000000000000000000000000000815260040160405180910390fd5b61044a8282610af8565b5050565b6060600480546102c690610f54565b3373ffffffffffffffffffffffffffffffffffffffff7f000000000000000000000000000000000000000000000000000000000000000016146104cc576040517f95c3dbc500000000000000000000000000000000000000000000000000000000815260040160405180910390fd5b61044a8282610c18565b33600081815260016020908152604080832073ffffffffffffffffffffffffffffffffffffffff871684529091528120549091908381101561059f576040517f08c379a000000000000000000000000000000000000000000000000000000000815260206004820152602560248201527f45524332303a2064656372656173656420616c6c6f77616e63652062656c6f7760448201527f207a65726f00000000000000000000000000000000000000000000000000000060648201526084015b60405180910390fd5b61037a82868684036105ba565b600033610357818585610845565b73ffffffffffffffffffffffffffffffffffffffff831661065c576040517f08c379a0000000000000000000000000000000000000000000000000000000008152602060048201526024808201527f45524332303a20617070726f76652066726f6d20746865207a65726f2061646460448201527f72657373000000000000000000000000000000000000000000000000000000006064820152608401610596565b73ffffffffffffffffffffffffffffffffffffffff82166106ff576040517f08c379a000000000000000000000000000000000000000000000000000000000815260206004820152602260248201527f45524332303a20617070726f766520746f20746865207a65726f20616464726560448201527f73730000000000000000000000000000000000000000000000000000000000006064820152608401610596565b73ffffffffffffffffffffffffffffffffffffffff83811660008181526001602090815260408083209487168084529482529182902085905590518481527f8c5be1e5ebec7d5bd14f71427d1e84f3dd0314c0f7b2291e5b200ac8c7c3b92591015b60405180910390a3505050565b73ffffffffffffffffffffffffffffffffffffffff8381166000908152600160209081526040808320938616835292905220547fffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff811461083f5781811015610832576040517f08c379a000000000000000000000000000000000000000000000000000000000815260206004820152601d60248201527f45524332303a20696e73756666696369656e7420616c6c6f77616e63650000006044820152606401610596565b61083f84848484036105ba565b50505050565b73ffffffffffffffffffffffffffffffffffffffff83166108e8576040517f08c379a000000000000000000000000000000000000000000000000000000000815260206004820152602560248201527f45524332303a207472616e736665722066726f6d20746865207a65726f20616460448201527f64726573730000000000000000000000000000000000000000000000000000006064820152608401610596565b73ffffffffffffffffffffffffffffffffffffffff821661098b576040517f08c379a000000000000000000000000000000000000000000000000000000000815260206004820152602360248201527f45524332303a207472616e7366657220746f20746865207a65726f206164647260448201527f65737300000000000000000000000000000000000000000000000000000000006064820152608401610596565b73ffffffffffffffffffffffffffffffffffffffff831660009081526020819052604090205481811015610a41576040517f08c379a000000000000000000000000000000000000000000000000000000000815260206004820152602660248201527f45524332303a207472616e7366657220616d6f756e742065786365656473206260448201527f616c616e636500000000000000000000000000000000000000000000000000006064820152608401610596565b73ffffffffffffffffffffffffffffffffffffffff808516600090815260208190526040808220858503905591851681529081208054849290610a85908490610fd7565b925050819055508273ffffffffffffffffffffffffffffffffffffffff168473ffffffffffffffffffffffffffffffffffffffff167fddf252ad1be2c89b69c2b068fc378daa952ba7f163c4a11628f55a4df523b3ef84604051610aeb91815260200190565b60405180910390a361083f565b73ffffffffffffffffffffffffffffffffffffffff8216610b75576040517f08c379a000000000000000000000000000000000000000000000000000000000815260206004820152601f60248201527f45524332303a206d696e7420746f20746865207a65726f2061646472657373006044820152606401610596565b8060026000828254610b879190610fd7565b909155505073ffffffffffffffffffffffffffffffffffffffff821660009081526020819052604081208054839290610bc1908490610fd7565b909155505060405181815273ffffffffffffffffffffffffffffffffffffffff8316906000907fddf252ad1be2c89b69c2b068fc378daa952ba7f163c4a11628f55a4df523b3ef9060200160405180910390a35050565b73ffffffffffffffffffffffffffffffffffffffff8216610cbb576040517f08c379a000000000000000000000000000000000000000000000000000000000815260206004820152602160248201527f45524332303a206275726e2066726f6d20746865207a65726f2061646472657360448201527f73000000000000000000000000000000000000000000000000000000000000006064820152608401610596565b73ffffffffffffffffffffffffffffffffffffffff821660009081526020819052604090205481811015610d71576040517f08c379a000000000000000000000000000000000000000000000000000000000815260206004820152602260248201527f45524332303a206275726e20616d6f756e7420657863656564732062616c616e60448201527f63650000000000000000000000000000000000000000000000000000000000006064820152608401610596565b73ffffffffffffffffffffffffffffffffffffffff83166000908152602081905260408120838303905560028054849290610dad908490610fef565b909155505060405182815260009073ffffffffffffffffffffffffffffffffffffffff8516907fddf252ad1be2c89b69c2b068fc378daa952ba7f163c4a11628f55a4df523b3ef90602001610761565b600060208083528351808285015260005b81811015610e2a57858101830151858201604001528201610e0e565b81811115610e3c576000604083870101525b50601f017fffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffe016929092016040019392505050565b803573ffffffffffffffffffffffffffffffffffffffff81168114610e9457600080fd5b919050565b60008060408385031215610eac57600080fd5b610eb583610e70565b946020939093013593505050565b600080600060608486031215610ed857600080fd5b610ee184610e70565b9250610eef60208501610e70565b9150604084013590509250925092565b600060208284031215610f1157600080fd5b610f1a82610e70565b9392505050565b60008060408385031215610f3457600080fd5b610f3d83610e70565b9150610f4b60208401610e70565b90509250929050565b600181811c90821680610f6857607f821691505b60208210811415610fa2577f4e487b7100000000000000000000000000000000000000000000000000000000600052602260045260246000fd5b50919050565b7f4e487b7100000000000000000000000000000000000000000000000000000000600052601160045260246000fd5b60008219821115610fea57610fea610fa8565b500190565b60008282101561100157611001610fa8565b50039056fea26469706673582212205208ce88f2cc098e52ee634868bc47ba589665eb2973e7b76d1aa539617cdc1564736f6c634300080a0033";

type DieselTokenConstructorParams =
  | [signer?: Signer]
  | ConstructorParameters<typeof ContractFactory>;

const isSuperArgs = (
  xs: DieselTokenConstructorParams
): xs is ConstructorParameters<typeof ContractFactory> => xs.length > 1;

export class DieselToken__factory extends ContractFactory {
  constructor(...args: DieselTokenConstructorParams) {
    if (isSuperArgs(args)) {
      super(...args);
    } else {
      super(_abi, _bytecode, args[0]);
    }
    this.contractName = "DieselToken";
  }

  override deploy(
    name_: PromiseOrValue<string>,
    symbol_: PromiseOrValue<string>,
    decimals_: PromiseOrValue<BigNumberish>,
    overrides?: Overrides & { from?: PromiseOrValue<string> }
  ): Promise<DieselToken> {
    return super.deploy(
      name_,
      symbol_,
      decimals_,
      overrides || {}
    ) as Promise<DieselToken>;
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
  override attach(address: string): DieselToken {
    return super.attach(address) as DieselToken;
  }
  override connect(signer: Signer): DieselToken__factory {
    return super.connect(signer) as DieselToken__factory;
  }
  static readonly contractName: "DieselToken";

  public readonly contractName: "DieselToken";

  static readonly bytecode = _bytecode;
  static readonly abi = _abi;
  static createInterface(): DieselTokenInterface {
    return new utils.Interface(_abi) as DieselTokenInterface;
  }
  static connect(
    address: string,
    signerOrProvider: Signer | Provider
  ): DieselToken {
    return new Contract(address, _abi, signerOrProvider) as DieselToken;
  }
}
