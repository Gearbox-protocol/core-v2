/* Autogenerated file. Do not edit manually. */
/* tslint:disable */
/* eslint-disable */
import type {
  BaseContract,
  BigNumber,
  BigNumberish,
  BytesLike,
  CallOverrides,
  ContractTransaction,
  Overrides,
  PopulatedTransaction,
  Signer,
  utils,
} from "ethers";
import type {
  FunctionFragment,
  Result,
  EventFragment,
} from "@ethersproject/abi";
import type { Listener, Provider } from "@ethersproject/providers";
import type {
  TypedEventFilter,
  TypedEvent,
  TypedListener,
  OnEvent,
  PromiseOrValue,
} from "../common";

export interface IBlacklistHelperInterface extends utils.Interface {
  functions: {
    "addClaimable(address,address,uint256)": FunctionFragment;
    "claim(address,address)": FunctionFragment;
    "claimable(address,address)": FunctionFragment;
    "isBlacklisted(address,address)": FunctionFragment;
    "version()": FunctionFragment;
  };

  getFunction(
    nameOrSignatureOrTopic:
      | "addClaimable"
      | "claim"
      | "claimable"
      | "isBlacklisted"
      | "version"
  ): FunctionFragment;

  encodeFunctionData(
    functionFragment: "addClaimable",
    values: [
      PromiseOrValue<string>,
      PromiseOrValue<string>,
      PromiseOrValue<BigNumberish>
    ]
  ): string;
  encodeFunctionData(
    functionFragment: "claim",
    values: [PromiseOrValue<string>, PromiseOrValue<string>]
  ): string;
  encodeFunctionData(
    functionFragment: "claimable",
    values: [PromiseOrValue<string>, PromiseOrValue<string>]
  ): string;
  encodeFunctionData(
    functionFragment: "isBlacklisted",
    values: [PromiseOrValue<string>, PromiseOrValue<string>]
  ): string;
  encodeFunctionData(functionFragment: "version", values?: undefined): string;

  decodeFunctionResult(
    functionFragment: "addClaimable",
    data: BytesLike
  ): Result;
  decodeFunctionResult(functionFragment: "claim", data: BytesLike): Result;
  decodeFunctionResult(functionFragment: "claimable", data: BytesLike): Result;
  decodeFunctionResult(
    functionFragment: "isBlacklisted",
    data: BytesLike
  ): Result;
  decodeFunctionResult(functionFragment: "version", data: BytesLike): Result;

  events: {
    "ClaimableAdded(address,address,uint256)": EventFragment;
    "Claimed(address,address,address,uint256)": EventFragment;
    "CreditFacadeAdded(address)": EventFragment;
    "CreditFacadeRemoved(address)": EventFragment;
  };

  getEvent(nameOrSignatureOrTopic: "ClaimableAdded"): EventFragment;
  getEvent(nameOrSignatureOrTopic: "Claimed"): EventFragment;
  getEvent(nameOrSignatureOrTopic: "CreditFacadeAdded"): EventFragment;
  getEvent(nameOrSignatureOrTopic: "CreditFacadeRemoved"): EventFragment;
}

export interface ClaimableAddedEventObject {
  underlying: string;
  holder: string;
  amount: BigNumber;
}
export type ClaimableAddedEvent = TypedEvent<
  [string, string, BigNumber],
  ClaimableAddedEventObject
>;

export type ClaimableAddedEventFilter = TypedEventFilter<ClaimableAddedEvent>;

export interface ClaimedEventObject {
  underlying: string;
  holder: string;
  to: string;
  amount: BigNumber;
}
export type ClaimedEvent = TypedEvent<
  [string, string, string, BigNumber],
  ClaimedEventObject
>;

export type ClaimedEventFilter = TypedEventFilter<ClaimedEvent>;

export interface CreditFacadeAddedEventObject {
  creditFacade: string;
}
export type CreditFacadeAddedEvent = TypedEvent<
  [string],
  CreditFacadeAddedEventObject
>;

export type CreditFacadeAddedEventFilter =
  TypedEventFilter<CreditFacadeAddedEvent>;

export interface CreditFacadeRemovedEventObject {
  creditFacade: string;
}
export type CreditFacadeRemovedEvent = TypedEvent<
  [string],
  CreditFacadeRemovedEventObject
>;

export type CreditFacadeRemovedEventFilter =
  TypedEventFilter<CreditFacadeRemovedEvent>;

export interface IBlacklistHelper extends BaseContract {
  contractName: "IBlacklistHelper";

  connect(signerOrProvider: Signer | Provider | string): this;
  attach(addressOrName: string): this;
  deployed(): Promise<this>;

  interface: IBlacklistHelperInterface;

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
    addClaimable(
      underlying: PromiseOrValue<string>,
      holder: PromiseOrValue<string>,
      amount: PromiseOrValue<BigNumberish>,
      overrides?: Overrides & { from?: PromiseOrValue<string> }
    ): Promise<ContractTransaction>;

    claim(
      underlying: PromiseOrValue<string>,
      to: PromiseOrValue<string>,
      overrides?: Overrides & { from?: PromiseOrValue<string> }
    ): Promise<ContractTransaction>;

    claimable(
      underlying: PromiseOrValue<string>,
      holder: PromiseOrValue<string>,
      overrides?: CallOverrides
    ): Promise<[BigNumber]>;

    isBlacklisted(
      underlying: PromiseOrValue<string>,
      account: PromiseOrValue<string>,
      overrides?: CallOverrides
    ): Promise<[boolean]>;

    version(overrides?: CallOverrides): Promise<[BigNumber]>;
  };

  addClaimable(
    underlying: PromiseOrValue<string>,
    holder: PromiseOrValue<string>,
    amount: PromiseOrValue<BigNumberish>,
    overrides?: Overrides & { from?: PromiseOrValue<string> }
  ): Promise<ContractTransaction>;

  claim(
    underlying: PromiseOrValue<string>,
    to: PromiseOrValue<string>,
    overrides?: Overrides & { from?: PromiseOrValue<string> }
  ): Promise<ContractTransaction>;

  claimable(
    underlying: PromiseOrValue<string>,
    holder: PromiseOrValue<string>,
    overrides?: CallOverrides
  ): Promise<BigNumber>;

  isBlacklisted(
    underlying: PromiseOrValue<string>,
    account: PromiseOrValue<string>,
    overrides?: CallOverrides
  ): Promise<boolean>;

  version(overrides?: CallOverrides): Promise<BigNumber>;

  callStatic: {
    addClaimable(
      underlying: PromiseOrValue<string>,
      holder: PromiseOrValue<string>,
      amount: PromiseOrValue<BigNumberish>,
      overrides?: CallOverrides
    ): Promise<void>;

    claim(
      underlying: PromiseOrValue<string>,
      to: PromiseOrValue<string>,
      overrides?: CallOverrides
    ): Promise<void>;

    claimable(
      underlying: PromiseOrValue<string>,
      holder: PromiseOrValue<string>,
      overrides?: CallOverrides
    ): Promise<BigNumber>;

    isBlacklisted(
      underlying: PromiseOrValue<string>,
      account: PromiseOrValue<string>,
      overrides?: CallOverrides
    ): Promise<boolean>;

    version(overrides?: CallOverrides): Promise<BigNumber>;
  };

  filters: {
    "ClaimableAdded(address,address,uint256)"(
      underlying?: PromiseOrValue<string> | null,
      holder?: PromiseOrValue<string> | null,
      amount?: null
    ): ClaimableAddedEventFilter;
    ClaimableAdded(
      underlying?: PromiseOrValue<string> | null,
      holder?: PromiseOrValue<string> | null,
      amount?: null
    ): ClaimableAddedEventFilter;

    "Claimed(address,address,address,uint256)"(
      underlying?: PromiseOrValue<string> | null,
      holder?: PromiseOrValue<string> | null,
      to?: null,
      amount?: null
    ): ClaimedEventFilter;
    Claimed(
      underlying?: PromiseOrValue<string> | null,
      holder?: PromiseOrValue<string> | null,
      to?: null,
      amount?: null
    ): ClaimedEventFilter;

    "CreditFacadeAdded(address)"(
      creditFacade?: PromiseOrValue<string> | null
    ): CreditFacadeAddedEventFilter;
    CreditFacadeAdded(
      creditFacade?: PromiseOrValue<string> | null
    ): CreditFacadeAddedEventFilter;

    "CreditFacadeRemoved(address)"(
      creditFacade?: PromiseOrValue<string> | null
    ): CreditFacadeRemovedEventFilter;
    CreditFacadeRemoved(
      creditFacade?: PromiseOrValue<string> | null
    ): CreditFacadeRemovedEventFilter;
  };

  estimateGas: {
    addClaimable(
      underlying: PromiseOrValue<string>,
      holder: PromiseOrValue<string>,
      amount: PromiseOrValue<BigNumberish>,
      overrides?: Overrides & { from?: PromiseOrValue<string> }
    ): Promise<BigNumber>;

    claim(
      underlying: PromiseOrValue<string>,
      to: PromiseOrValue<string>,
      overrides?: Overrides & { from?: PromiseOrValue<string> }
    ): Promise<BigNumber>;

    claimable(
      underlying: PromiseOrValue<string>,
      holder: PromiseOrValue<string>,
      overrides?: CallOverrides
    ): Promise<BigNumber>;

    isBlacklisted(
      underlying: PromiseOrValue<string>,
      account: PromiseOrValue<string>,
      overrides?: CallOverrides
    ): Promise<BigNumber>;

    version(overrides?: CallOverrides): Promise<BigNumber>;
  };

  populateTransaction: {
    addClaimable(
      underlying: PromiseOrValue<string>,
      holder: PromiseOrValue<string>,
      amount: PromiseOrValue<BigNumberish>,
      overrides?: Overrides & { from?: PromiseOrValue<string> }
    ): Promise<PopulatedTransaction>;

    claim(
      underlying: PromiseOrValue<string>,
      to: PromiseOrValue<string>,
      overrides?: Overrides & { from?: PromiseOrValue<string> }
    ): Promise<PopulatedTransaction>;

    claimable(
      underlying: PromiseOrValue<string>,
      holder: PromiseOrValue<string>,
      overrides?: CallOverrides
    ): Promise<PopulatedTransaction>;

    isBlacklisted(
      underlying: PromiseOrValue<string>,
      account: PromiseOrValue<string>,
      overrides?: CallOverrides
    ): Promise<PopulatedTransaction>;

    version(overrides?: CallOverrides): Promise<PopulatedTransaction>;
  };
}
