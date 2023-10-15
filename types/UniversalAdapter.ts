/* Autogenerated file. Do not edit manually. */
/* tslint:disable */
/* eslint-disable */
import type {
  BaseContract,
  BigNumber,
  BytesLike,
  CallOverrides,
  ContractTransaction,
  Overrides,
  PopulatedTransaction,
  Signer,
  utils,
} from "ethers";
import type { FunctionFragment, Result } from "@ethersproject/abi";
import type { Listener, Provider } from "@ethersproject/providers";
import type {
  TypedEventFilter,
  TypedEvent,
  TypedListener,
  OnEvent,
  PromiseOrValue,
} from "./common";

export type RevocationPairStruct = {
  spender: PromiseOrValue<string>;
  token: PromiseOrValue<string>;
};

export type RevocationPairStructOutput = [string, string] & {
  spender: string;
  token: string;
};

export interface UniversalAdapterInterface extends utils.Interface {
  functions: {
    "_acl()": FunctionFragment;
    "_gearboxAdapterType()": FunctionFragment;
    "_gearboxAdapterVersion()": FunctionFragment;
    "addressProvider()": FunctionFragment;
    "creditManager()": FunctionFragment;
    "revokeAdapterAllowances((address,address)[])": FunctionFragment;
    "targetContract()": FunctionFragment;
  };

  getFunction(
    nameOrSignatureOrTopic:
      | "_acl"
      | "_gearboxAdapterType"
      | "_gearboxAdapterVersion"
      | "addressProvider"
      | "creditManager"
      | "revokeAdapterAllowances"
      | "targetContract"
  ): FunctionFragment;

  encodeFunctionData(functionFragment: "_acl", values?: undefined): string;
  encodeFunctionData(
    functionFragment: "_gearboxAdapterType",
    values?: undefined
  ): string;
  encodeFunctionData(
    functionFragment: "_gearboxAdapterVersion",
    values?: undefined
  ): string;
  encodeFunctionData(
    functionFragment: "addressProvider",
    values?: undefined
  ): string;
  encodeFunctionData(
    functionFragment: "creditManager",
    values?: undefined
  ): string;
  encodeFunctionData(
    functionFragment: "revokeAdapterAllowances",
    values: [RevocationPairStruct[]]
  ): string;
  encodeFunctionData(
    functionFragment: "targetContract",
    values?: undefined
  ): string;

  decodeFunctionResult(functionFragment: "_acl", data: BytesLike): Result;
  decodeFunctionResult(
    functionFragment: "_gearboxAdapterType",
    data: BytesLike
  ): Result;
  decodeFunctionResult(
    functionFragment: "_gearboxAdapterVersion",
    data: BytesLike
  ): Result;
  decodeFunctionResult(
    functionFragment: "addressProvider",
    data: BytesLike
  ): Result;
  decodeFunctionResult(
    functionFragment: "creditManager",
    data: BytesLike
  ): Result;
  decodeFunctionResult(
    functionFragment: "revokeAdapterAllowances",
    data: BytesLike
  ): Result;
  decodeFunctionResult(
    functionFragment: "targetContract",
    data: BytesLike
  ): Result;

  events: {};
}

export interface UniversalAdapter extends BaseContract {
  contractName: "UniversalAdapter";

  connect(signerOrProvider: Signer | Provider | string): this;
  attach(addressOrName: string): this;
  deployed(): Promise<this>;

  interface: UniversalAdapterInterface;

  queryFilter<TEvent extends TypedEvent>(
    event: TypedEventFilter<TEvent>,
    fromBlockOrBlockhash?: string | number | undefined,
    toBlock?: string | number | undefined
  ): Promise<Array<TEvent>>;

  listeners<TEvent extends TypedEvent>(
    eventFilter?: TypedEventFilter<TEvent>
  ): Array<TypedListener<TEvent>>;
  listeners(eventName?: string): Array<Listener>;
  removeAllListeners<TEvent extends TypedEvent>(
    eventFilter: TypedEventFilter<TEvent>
  ): this;
  removeAllListeners(eventName?: string): this;
  off: OnEvent<this>;
  on: OnEvent<this>;
  once: OnEvent<this>;
  removeListener: OnEvent<this>;

  functions: {
    _acl(overrides?: CallOverrides): Promise<[string]>;

    _gearboxAdapterType(overrides?: CallOverrides): Promise<[number]>;

    _gearboxAdapterVersion(overrides?: CallOverrides): Promise<[number]>;

    addressProvider(overrides?: CallOverrides): Promise<[string]>;

    creditManager(overrides?: CallOverrides): Promise<[string]>;

    revokeAdapterAllowances(
      revocations: RevocationPairStruct[],
      overrides?: Overrides & { from?: PromiseOrValue<string> }
    ): Promise<ContractTransaction>;

    targetContract(overrides?: CallOverrides): Promise<[string]>;
  };

  _acl(overrides?: CallOverrides): Promise<string>;

  _gearboxAdapterType(overrides?: CallOverrides): Promise<number>;

  _gearboxAdapterVersion(overrides?: CallOverrides): Promise<number>;

  addressProvider(overrides?: CallOverrides): Promise<string>;

  creditManager(overrides?: CallOverrides): Promise<string>;

  revokeAdapterAllowances(
    revocations: RevocationPairStruct[],
    overrides?: Overrides & { from?: PromiseOrValue<string> }
  ): Promise<ContractTransaction>;

  targetContract(overrides?: CallOverrides): Promise<string>;

  callStatic: {
    _acl(overrides?: CallOverrides): Promise<string>;

    _gearboxAdapterType(overrides?: CallOverrides): Promise<number>;

    _gearboxAdapterVersion(overrides?: CallOverrides): Promise<number>;

    addressProvider(overrides?: CallOverrides): Promise<string>;

    creditManager(overrides?: CallOverrides): Promise<string>;

    revokeAdapterAllowances(
      revocations: RevocationPairStruct[],
      overrides?: CallOverrides
    ): Promise<void>;

    targetContract(overrides?: CallOverrides): Promise<string>;
  };

  filters: {};

  estimateGas: {
    _acl(overrides?: CallOverrides): Promise<BigNumber>;

    _gearboxAdapterType(overrides?: CallOverrides): Promise<BigNumber>;

    _gearboxAdapterVersion(overrides?: CallOverrides): Promise<BigNumber>;

    addressProvider(overrides?: CallOverrides): Promise<BigNumber>;

    creditManager(overrides?: CallOverrides): Promise<BigNumber>;

    revokeAdapterAllowances(
      revocations: RevocationPairStruct[],
      overrides?: Overrides & { from?: PromiseOrValue<string> }
    ): Promise<BigNumber>;

    targetContract(overrides?: CallOverrides): Promise<BigNumber>;
  };

  populateTransaction: {
    _acl(overrides?: CallOverrides): Promise<PopulatedTransaction>;

    _gearboxAdapterType(
      overrides?: CallOverrides
    ): Promise<PopulatedTransaction>;

    _gearboxAdapterVersion(
      overrides?: CallOverrides
    ): Promise<PopulatedTransaction>;

    addressProvider(overrides?: CallOverrides): Promise<PopulatedTransaction>;

    creditManager(overrides?: CallOverrides): Promise<PopulatedTransaction>;

    revokeAdapterAllowances(
      revocations: RevocationPairStruct[],
      overrides?: Overrides & { from?: PromiseOrValue<string> }
    ): Promise<PopulatedTransaction>;

    targetContract(overrides?: CallOverrides): Promise<PopulatedTransaction>;
  };
}