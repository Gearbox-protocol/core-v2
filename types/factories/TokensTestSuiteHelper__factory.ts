/* Autogenerated file. Do not edit manually. */
/* tslint:disable */
/* eslint-disable */
import { Signer, utils, Contract, ContractFactory, Overrides } from "ethers";
import type { Provider, TransactionRequest } from "@ethersproject/providers";
import type { PromiseOrValue } from "../common";
import type {
  TokensTestSuiteHelper,
  TokensTestSuiteHelperInterface,
} from "../TokensTestSuiteHelper";

const _abi = [
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
    inputs: [
      {
        internalType: "address",
        name: "token",
        type: "address",
      },
      {
        internalType: "address",
        name: "holder",
        type: "address",
      },
      {
        internalType: "address",
        name: "targetContract",
        type: "address",
      },
      {
        internalType: "uint256",
        name: "amount",
        type: "uint256",
      },
    ],
    name: "approve",
    outputs: [],
    stateMutability: "nonpayable",
    type: "function",
  },
  {
    inputs: [
      {
        internalType: "address",
        name: "token",
        type: "address",
      },
      {
        internalType: "address",
        name: "holder",
        type: "address",
      },
      {
        internalType: "address",
        name: "targetContract",
        type: "address",
      },
    ],
    name: "approve",
    outputs: [],
    stateMutability: "nonpayable",
    type: "function",
  },
  {
    inputs: [
      {
        internalType: "address",
        name: "token",
        type: "address",
      },
      {
        internalType: "address",
        name: "holder",
        type: "address",
      },
    ],
    name: "balanceOf",
    outputs: [
      {
        internalType: "uint256",
        name: "balance",
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
        name: "token",
        type: "address",
      },
      {
        internalType: "address",
        name: "from",
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
  {
    inputs: [
      {
        internalType: "address",
        name: "token",
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
    name: "mint",
    outputs: [],
    stateMutability: "nonpayable",
    type: "function",
  },
  {
    inputs: [],
    name: "topUpWETH",
    outputs: [],
    stateMutability: "payable",
    type: "function",
  },
  {
    inputs: [
      {
        internalType: "address",
        name: "onBehalfOf",
        type: "address",
      },
      {
        internalType: "uint256",
        name: "value",
        type: "uint256",
      },
    ],
    name: "topUpWETH",
    outputs: [],
    stateMutability: "nonpayable",
    type: "function",
  },
  {
    inputs: [],
    name: "wethToken",
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
    stateMutability: "payable",
    type: "receive",
  },
] as const;

const _bytecode =
  "0x60806040526000805460ff19166001179055600880546001600160a01b031916737109709ecfa91a80626ff3989d68f67f5b1dd12d17905534801561004357600080fd5b50610c12806100536000396000f3fe6080604052600436106100b55760003560e01c8063c6c3bbe611610069578063f7888aec1161004e578063f7888aec146101c7578063f8ebe1b8146101f5578063fa7626d41461021557600080fd5b8063c6c3bbe614610187578063f6b911bc146101a757600080fd5b80639b140a851161009a5780639b140a851461013a578063b36ba2081461015a578063ba414fa61461016257600080fd5b80634b57b0be146100c157806359eba4541461011857600080fd5b366100bc57005b600080fd5b3480156100cd57600080fd5b506009546100ee9073ffffffffffffffffffffffffffffffffffffffff1681565b60405173ffffffffffffffffffffffffffffffffffffffff90911681526020015b60405180910390f35b34801561012457600080fd5b506101386101333660046109f7565b61022f565b005b34801561014657600080fd5b50610138610155366004610a42565b610354565b610138610385565b34801561016e57600080fd5b50610177610403565b604051901515815260200161010f565b34801561019357600080fd5b506101386101a2366004610a85565b610563565b3480156101b357600080fd5b506101386101c2366004610a85565b6107d1565b3480156101d357600080fd5b506101e76101e2366004610ac1565b61082c565b60405190815260200161010f565b34801561020157600080fd5b50610138610210366004610af4565b6108c7565b34801561022157600080fd5b506000546101779060ff1681565b6008546040517fca669fa700000000000000000000000000000000000000000000000000000000815273ffffffffffffffffffffffffffffffffffffffff85811660048301529091169063ca669fa790602401600060405180830381600087803b15801561029c57600080fd5b505af11580156102b0573d6000803e3d6000fd5b50506040517f095ea7b300000000000000000000000000000000000000000000000000000000815273ffffffffffffffffffffffffffffffffffffffff8581166004830152602482018590528716925063095ea7b391506044016020604051808303816000875af1158015610329573d6000803e3d6000fd5b505050506040513d601f19601f8201168201806040525081019061034d9190610b1e565b5050505050565b6103808383837fffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff61022f565b505050565b600960009054906101000a900473ffffffffffffffffffffffffffffffffffffffff1673ffffffffffffffffffffffffffffffffffffffff1663d0e30db0346040518263ffffffff1660e01b81526004016000604051808303818588803b1580156103ef57600080fd5b505af115801561034d573d6000803e3d6000fd5b60008054610100900460ff16156104235750600054610100900460ff1690565b6000737109709ecfa91a80626ff3989d68f67f5b1dd12d3b1561055e5760408051737109709ecfa91a80626ff3989d68f67f5b1dd12d602082018190527f6661696c65640000000000000000000000000000000000000000000000000000828401528251808303840181526060830190935260009290916104c8917f667f9d70ca411d70ead50d8d5c22070dafc36ad75f3dcf5e7237b22ade9aecc491608001610b7b565b604080517fffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffe08184030181529082905261050091610bb7565b6000604051808303816000865af19150503d806000811461053d576040519150601f19603f3d011682016040523d82523d6000602084013e610542565b606091505b509150508080602001905181019061055a9190610b1e565b9150505b919050565b60095473ffffffffffffffffffffffffffffffffffffffff84811691161415610698576008546040517fc88a5e6d0000000000000000000000000000000000000000000000000000000081523060048201526024810183905273ffffffffffffffffffffffffffffffffffffffff9091169063c88a5e6d90604401600060405180830381600087803b1580156105f857600080fd5b505af115801561060c573d6000803e3d6000fd5b50505050600960009054906101000a900473ffffffffffffffffffffffffffffffffffffffff1673ffffffffffffffffffffffffffffffffffffffff1663d0e30db0826040518263ffffffff1660e01b81526004016000604051808303818588803b15801561067a57600080fd5b505af115801561068e573d6000803e3d6000fd5b5050505050610731565b6040517f40c10f190000000000000000000000000000000000000000000000000000000081523060048201526024810182905273ffffffffffffffffffffffffffffffffffffffff8416906340c10f19906044016020604051808303816000875af115801561070b573d6000803e3d6000fd5b505050506040513d601f19601f8201168201806040525081019061072f9190610b1e565b505b6040517fa9059cbb00000000000000000000000000000000000000000000000000000000815273ffffffffffffffffffffffffffffffffffffffff83811660048301526024820183905284169063a9059cbb906044015b6020604051808303816000875af11580156107a7573d6000803e3d6000fd5b505050506040513d601f19601f820116820180604052508101906107cb9190610b1e565b50505050565b6040517f9dc29fac00000000000000000000000000000000000000000000000000000000815273ffffffffffffffffffffffffffffffffffffffff838116600483015260248201839052841690639dc29fac90604401610788565b6040517f70a0823100000000000000000000000000000000000000000000000000000000815273ffffffffffffffffffffffffffffffffffffffff8281166004830152600091908416906370a0823190602401602060405180830381865afa15801561089c573d6000803e3d6000fd5b505050506040513d601f19601f820116820180604052508101906108c09190610bc3565b9392505050565b6008546040517fca669fa700000000000000000000000000000000000000000000000000000000815273ffffffffffffffffffffffffffffffffffffffff84811660048301529091169063ca669fa790602401600060405180830381600087803b15801561093457600080fd5b505af1158015610948573d6000803e3d6000fd5b50505050600960009054906101000a900473ffffffffffffffffffffffffffffffffffffffff1673ffffffffffffffffffffffffffffffffffffffff1663d0e30db0826040518263ffffffff1660e01b81526004016000604051808303818588803b1580156109b657600080fd5b505af11580156109ca573d6000803e3d6000fd5b50505050505050565b803573ffffffffffffffffffffffffffffffffffffffff8116811461055e57600080fd5b60008060008060808587031215610a0d57600080fd5b610a16856109d3565b9350610a24602086016109d3565b9250610a32604086016109d3565b9396929550929360600135925050565b600080600060608486031215610a5757600080fd5b610a60846109d3565b9250610a6e602085016109d3565b9150610a7c604085016109d3565b90509250925092565b600080600060608486031215610a9a57600080fd5b610aa3846109d3565b9250610ab1602085016109d3565b9150604084013590509250925092565b60008060408385031215610ad457600080fd5b610add836109d3565b9150610aeb602084016109d3565b90509250929050565b60008060408385031215610b0757600080fd5b610b10836109d3565b946020939093013593505050565b600060208284031215610b3057600080fd5b815180151581146108c057600080fd5b6000815160005b81811015610b615760208185018101518683015201610b47565b81811115610b70576000828601525b509290920192915050565b7fffffffff00000000000000000000000000000000000000000000000000000000831681526000610baf6004830184610b40565b949350505050565b60006108c08284610b40565b600060208284031215610bd557600080fd5b505191905056fea2646970667358221220fdf2483a8bf7a400d749de49c5a66e02470bb9260472bb3b45e4597b2f09536e64736f6c634300080a0033";

type TokensTestSuiteHelperConstructorParams =
  | [signer?: Signer]
  | ConstructorParameters<typeof ContractFactory>;

const isSuperArgs = (
  xs: TokensTestSuiteHelperConstructorParams
): xs is ConstructorParameters<typeof ContractFactory> => xs.length > 1;

export class TokensTestSuiteHelper__factory extends ContractFactory {
  constructor(...args: TokensTestSuiteHelperConstructorParams) {
    if (isSuperArgs(args)) {
      super(...args);
    } else {
      super(_abi, _bytecode, args[0]);
    }
    this.contractName = "TokensTestSuiteHelper";
  }

  override deploy(
    overrides?: Overrides & { from?: PromiseOrValue<string> }
  ): Promise<TokensTestSuiteHelper> {
    return super.deploy(overrides || {}) as Promise<TokensTestSuiteHelper>;
  }
  override getDeployTransaction(
    overrides?: Overrides & { from?: PromiseOrValue<string> }
  ): TransactionRequest {
    return super.getDeployTransaction(overrides || {});
  }
  override attach(address: string): TokensTestSuiteHelper {
    return super.attach(address) as TokensTestSuiteHelper;
  }
  override connect(signer: Signer): TokensTestSuiteHelper__factory {
    return super.connect(signer) as TokensTestSuiteHelper__factory;
  }
  static readonly contractName: "TokensTestSuiteHelper";

  public readonly contractName: "TokensTestSuiteHelper";

  static readonly bytecode = _bytecode;
  static readonly abi = _abi;
  static createInterface(): TokensTestSuiteHelperInterface {
    return new utils.Interface(_abi) as TokensTestSuiteHelperInterface;
  }
  static connect(
    address: string,
    signerOrProvider: Signer | Provider
  ): TokensTestSuiteHelper {
    return new Contract(
      address,
      _abi,
      signerOrProvider
    ) as TokensTestSuiteHelper;
  }
}
