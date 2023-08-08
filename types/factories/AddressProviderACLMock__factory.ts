/* Autogenerated file. Do not edit manually. */
/* tslint:disable */
/* eslint-disable */
import { Signer, utils, Contract, ContractFactory, Overrides } from "ethers";
import type { Provider, TransactionRequest } from "@ethersproject/providers";
import type { PromiseOrValue } from "../common";
import type {
  AddressProviderACLMock,
  AddressProviderACLMockInterface,
} from "../AddressProviderACLMock";

const _abi = [
  {
    inputs: [],
    stateMutability: "nonpayable",
    type: "constructor",
  },
  {
    inputs: [],
    name: "getACL",
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
    name: "getPriceOracle",
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
    name: "priceFeeds",
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
        name: "token",
        type: "address",
      },
      {
        internalType: "address",
        name: "feed",
        type: "address",
      },
    ],
    name: "setPriceFeed",
    outputs: [],
    stateMutability: "nonpayable",
    type: "function",
  },
] as const;

const _bytecode =
  "0x608060405234801561001057600080fd5b50600080546001600160a01b03199081163390811783556001805483163090811782556003805490941617909255825260026020526040909120805460ff19169091179055610281806100646000396000f3fe608060405234801561001057600080fd5b50600436106100725760003560e01c80638da5cb5b116100505780638da5cb5b146101575780639dcb511a14610177578063fca513a8146101ad57600080fd5b806308737695146100775780635f259aba146100c157806376e11286146100f4575b600080fd5b6001546100979073ffffffffffffffffffffffffffffffffffffffff1681565b60405173ffffffffffffffffffffffffffffffffffffffff90911681526020015b60405180910390f35b6100e46100cf3660046101f6565b60026020526000908152604090205460ff1681565b60405190151581526020016100b8565b610155610102366004610218565b73ffffffffffffffffffffffffffffffffffffffff918216600090815260046020526040902080547fffffffffffffffffffffffff00000000000000000000000000000000000000001691909216179055565b005b6000546100979073ffffffffffffffffffffffffffffffffffffffff1681565b6100976101853660046101f6565b60046020526000908152604090205473ffffffffffffffffffffffffffffffffffffffff1681565b6003546100979073ffffffffffffffffffffffffffffffffffffffff1681565b803573ffffffffffffffffffffffffffffffffffffffff811681146101f157600080fd5b919050565b60006020828403121561020857600080fd5b610211826101cd565b9392505050565b6000806040838503121561022b57600080fd5b610234836101cd565b9150610242602084016101cd565b9050925092905056fea2646970667358221220526ca85f703b2f92ecc54e93b875fe1967eb4000780cf9dc2f92ac0ac3bd917564736f6c634300080a0033";

type AddressProviderACLMockConstructorParams =
  | [signer?: Signer]
  | ConstructorParameters<typeof ContractFactory>;

const isSuperArgs = (
  xs: AddressProviderACLMockConstructorParams
): xs is ConstructorParameters<typeof ContractFactory> => xs.length > 1;

export class AddressProviderACLMock__factory extends ContractFactory {
  constructor(...args: AddressProviderACLMockConstructorParams) {
    if (isSuperArgs(args)) {
      super(...args);
    } else {
      super(_abi, _bytecode, args[0]);
    }
    this.contractName = "AddressProviderACLMock";
  }

  override deploy(
    overrides?: Overrides & { from?: PromiseOrValue<string> }
  ): Promise<AddressProviderACLMock> {
    return super.deploy(overrides || {}) as Promise<AddressProviderACLMock>;
  }
  override getDeployTransaction(
    overrides?: Overrides & { from?: PromiseOrValue<string> }
  ): TransactionRequest {
    return super.getDeployTransaction(overrides || {});
  }
  override attach(address: string): AddressProviderACLMock {
    return super.attach(address) as AddressProviderACLMock;
  }
  override connect(signer: Signer): AddressProviderACLMock__factory {
    return super.connect(signer) as AddressProviderACLMock__factory;
  }
  static readonly contractName: "AddressProviderACLMock";

  public readonly contractName: "AddressProviderACLMock";

  static readonly bytecode = _bytecode;
  static readonly abi = _abi;
  static createInterface(): AddressProviderACLMockInterface {
    return new utils.Interface(_abi) as AddressProviderACLMockInterface;
  }
  static connect(
    address: string,
    signerOrProvider: Signer | Provider
  ): AddressProviderACLMock {
    return new Contract(
      address,
      _abi,
      signerOrProvider
    ) as AddressProviderACLMock;
  }
}
