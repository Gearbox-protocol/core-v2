/* Autogenerated file. Do not edit manually. */
/* tslint:disable */
/* eslint-disable */
import { Signer, utils, Contract, ContractFactory, Overrides } from "ethers";
import type { Provider, TransactionRequest } from "@ethersproject/providers";
import type { PromiseOrValue } from "../../common";
import type { Roles, RolesInterface } from "../../Constants.sol/Roles";

const _abi = [
  {
    inputs: [],
    stateMutability: "nonpayable",
    type: "constructor",
  },
  {
    anonymous: false,
    inputs: [
      {
        indexed: false,
        internalType: "string",
        name: "",
        type: "string",
      },
    ],
    name: "log",
    type: "event",
  },
  {
    anonymous: false,
    inputs: [
      {
        indexed: false,
        internalType: "address",
        name: "",
        type: "address",
      },
    ],
    name: "log_address",
    type: "event",
  },
  {
    anonymous: false,
    inputs: [
      {
        indexed: false,
        internalType: "bytes",
        name: "",
        type: "bytes",
      },
    ],
    name: "log_bytes",
    type: "event",
  },
  {
    anonymous: false,
    inputs: [
      {
        indexed: false,
        internalType: "bytes32",
        name: "",
        type: "bytes32",
      },
    ],
    name: "log_bytes32",
    type: "event",
  },
  {
    anonymous: false,
    inputs: [
      {
        indexed: false,
        internalType: "int256",
        name: "",
        type: "int256",
      },
    ],
    name: "log_int",
    type: "event",
  },
  {
    anonymous: false,
    inputs: [
      {
        indexed: false,
        internalType: "string",
        name: "key",
        type: "string",
      },
      {
        indexed: false,
        internalType: "address",
        name: "val",
        type: "address",
      },
    ],
    name: "log_named_address",
    type: "event",
  },
  {
    anonymous: false,
    inputs: [
      {
        indexed: false,
        internalType: "string",
        name: "key",
        type: "string",
      },
      {
        indexed: false,
        internalType: "bytes",
        name: "val",
        type: "bytes",
      },
    ],
    name: "log_named_bytes",
    type: "event",
  },
  {
    anonymous: false,
    inputs: [
      {
        indexed: false,
        internalType: "string",
        name: "key",
        type: "string",
      },
      {
        indexed: false,
        internalType: "bytes32",
        name: "val",
        type: "bytes32",
      },
    ],
    name: "log_named_bytes32",
    type: "event",
  },
  {
    anonymous: false,
    inputs: [
      {
        indexed: false,
        internalType: "string",
        name: "key",
        type: "string",
      },
      {
        indexed: false,
        internalType: "int256",
        name: "val",
        type: "int256",
      },
      {
        indexed: false,
        internalType: "uint256",
        name: "decimals",
        type: "uint256",
      },
    ],
    name: "log_named_decimal_int",
    type: "event",
  },
  {
    anonymous: false,
    inputs: [
      {
        indexed: false,
        internalType: "string",
        name: "key",
        type: "string",
      },
      {
        indexed: false,
        internalType: "uint256",
        name: "val",
        type: "uint256",
      },
      {
        indexed: false,
        internalType: "uint256",
        name: "decimals",
        type: "uint256",
      },
    ],
    name: "log_named_decimal_uint",
    type: "event",
  },
  {
    anonymous: false,
    inputs: [
      {
        indexed: false,
        internalType: "string",
        name: "key",
        type: "string",
      },
      {
        indexed: false,
        internalType: "int256",
        name: "val",
        type: "int256",
      },
    ],
    name: "log_named_int",
    type: "event",
  },
  {
    anonymous: false,
    inputs: [
      {
        indexed: false,
        internalType: "string",
        name: "key",
        type: "string",
      },
      {
        indexed: false,
        internalType: "string",
        name: "val",
        type: "string",
      },
    ],
    name: "log_named_string",
    type: "event",
  },
  {
    anonymous: false,
    inputs: [
      {
        indexed: false,
        internalType: "string",
        name: "key",
        type: "string",
      },
      {
        indexed: false,
        internalType: "uint256",
        name: "val",
        type: "uint256",
      },
    ],
    name: "log_named_uint",
    type: "event",
  },
  {
    anonymous: false,
    inputs: [
      {
        indexed: false,
        internalType: "string",
        name: "",
        type: "string",
      },
    ],
    name: "log_string",
    type: "event",
  },
  {
    anonymous: false,
    inputs: [
      {
        indexed: false,
        internalType: "uint256",
        name: "",
        type: "uint256",
      },
    ],
    name: "log_uint",
    type: "event",
  },
  {
    anonymous: false,
    inputs: [
      {
        indexed: false,
        internalType: "bytes",
        name: "",
        type: "bytes",
      },
    ],
    name: "logs",
    type: "event",
  },
  {
    inputs: [],
    name: "IS_TEST",
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
    name: "failed",
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
  "0x60806040526000805460ff19166001179055600880546001600160a01b031916737109709ecfa91a80626ff3989d68f67f5b1dd12d17905534801561004357600080fd5b50600854604080516318caf8e360e31b815273f39fd6e51aad88f6f4ce6ab8827279cfffb9226660048083019190915260248201929092526044810191909152632aa9a2a960e11b60648201526001600160a01b039091169063c657c71890608401600060405180830381600087803b1580156100bf57600080fd5b505af11580156100d3573d6000803e3d6000fd5b5050600854604080516318caf8e360e31b81527390f79bf6eb2c4f870365e785982e1f101e93b90660048201526024810191909152600660448201526511949251539160d21b60648201526001600160a01b03909116925063c657c7189150608401600060405180830381600087803b15801561014f57600080fd5b505af1158015610163573d6000803e3d6000fd5b5050600854604080516318caf8e360e31b8152733c44cdddb6a900fa2b585dd299e03d12fa4293bc60048201526024810191909152600a6044820152692624a8aaa4a220aa27a960b11b60648201526001600160a01b03909116925063c657c7189150608401600060405180830381600087803b1580156101e357600080fd5b505af11580156101f7573d6000803e3d6000fd5b5050600854604080516318caf8e360e31b815273c4375b7de8af5a38a93548eb8453a498222c4ff260048201526024810191909152600c60448201526b44554d425f4144445245535360a01b60648201526001600160a01b03909116925063c657c7189150608401600060405180830381600087803b15801561027957600080fd5b505af115801561028d573d6000803e3d6000fd5b5050600854604080516318caf8e360e31b8152739965507d1a55bcc2695c58ba16fb37d819b0a4dc60048201526024810191909152600760448201526620a220a82a22a960c91b60648201526001600160a01b03909116925063c657c7189150608401600060405180830381600087803b15801561030a57600080fd5b505af115801561031e573d6000803e3d6000fd5b505050506102a6806103316000396000f3fe608060405234801561001057600080fd5b50600436106100365760003560e01c8063ba414fa61461003b578063fa7626d414610057575b600080fd5b610043610064565b604051901515815260200160405180910390f35b6000546100439060ff1681565b60008054610100900460ff16156100845750600054610100900460ff1690565b6000737109709ecfa91a80626ff3989d68f67f5b1dd12d3b156101bf5760408051737109709ecfa91a80626ff3989d68f67f5b1dd12d602082018190527f6661696c6564000000000000000000000000000000000000000000000000000082840152825180830384018152606083019093526000929091610129917f667f9d70ca411d70ead50d8d5c22070dafc36ad75f3dcf5e7237b22ade9aecc4916080016101ff565b604080517fffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffe0818403018152908290526101619161023b565b6000604051808303816000865af19150503d806000811461019e576040519150601f19603f3d011682016040523d82523d6000602084013e6101a3565b606091505b50915050808060200190518101906101bb919061024e565b9150505b919050565b6000815160005b818110156101e557602081850181015186830152016101cb565b818111156101f4576000828601525b509290920192915050565b7fffffffff0000000000000000000000000000000000000000000000000000000083168152600061023360048301846101c4565b949350505050565b600061024782846101c4565b9392505050565b60006020828403121561026057600080fd5b8151801515811461024757600080fdfea264697066735822122027052c6aacf2950ae1abbf7987282f6caa01f3e952416f15ae86789cf1c5a5e364736f6c634300080a0033";

type RolesConstructorParams =
  | [signer?: Signer]
  | ConstructorParameters<typeof ContractFactory>;

const isSuperArgs = (
  xs: RolesConstructorParams
): xs is ConstructorParameters<typeof ContractFactory> => xs.length > 1;

export class Roles__factory extends ContractFactory {
  constructor(...args: RolesConstructorParams) {
    if (isSuperArgs(args)) {
      super(...args);
    } else {
      super(_abi, _bytecode, args[0]);
    }
    this.contractName = "Roles";
  }

  override deploy(
    overrides?: Overrides & { from?: PromiseOrValue<string> }
  ): Promise<Roles> {
    return super.deploy(overrides || {}) as Promise<Roles>;
  }
  override getDeployTransaction(
    overrides?: Overrides & { from?: PromiseOrValue<string> }
  ): TransactionRequest {
    return super.getDeployTransaction(overrides || {});
  }
  override attach(address: string): Roles {
    return super.attach(address) as Roles;
  }
  override connect(signer: Signer): Roles__factory {
    return super.connect(signer) as Roles__factory;
  }
  static readonly contractName: "Roles";

  public readonly contractName: "Roles";

  static readonly bytecode = _bytecode;
  static readonly abi = _abi;
  static createInterface(): RolesInterface {
    return new utils.Interface(_abi) as RolesInterface;
  }
  static connect(address: string, signerOrProvider: Signer | Provider): Roles {
    return new Contract(address, _abi, signerOrProvider) as Roles;
  }
}
