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
  PayableOverrides,
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
} from "./common";

export type PriceFeedConfigStruct = {
  token: PromiseOrValue<string>;
  priceFeed: PromiseOrValue<string>;
};

export type PriceFeedConfigStructOutput = [string, string] & {
  token: string;
  priceFeed: string;
};

export interface TokensTestSuiteInterface extends utils.Interface {
  functions: {
    "IS_TEST()": FunctionFragment;
    "addressOf(uint8)": FunctionFragment;
    "allowance(uint8,address,address)": FunctionFragment;
    "approve(address,address,address,uint256)": FunctionFragment;
    "approve(uint8,address,address,uint256)": FunctionFragment;
    "approve(uint8,address,address)": FunctionFragment;
    "approve(address,address,address)": FunctionFragment;
    "balanceOf(uint8,address)": FunctionFragment;
    "balanceOf(address,address)": FunctionFragment;
    "burn(uint8,address,uint256)": FunctionFragment;
    "burn(address,address,uint256)": FunctionFragment;
    "failed()": FunctionFragment;
    "getPriceFeeds()": FunctionFragment;
    "mint(address,address,uint256)": FunctionFragment;
    "mint(uint8,address,uint256)": FunctionFragment;
    "priceFeeds(uint256)": FunctionFragment;
    "priceFeedsMap(uint8)": FunctionFragment;
    "prices(uint8)": FunctionFragment;
    "symbols(uint8)": FunctionFragment;
    "tokenCount()": FunctionFragment;
    "tokenIndexes(address)": FunctionFragment;
    "topUpWETH()": FunctionFragment;
    "topUpWETH(address,uint256)": FunctionFragment;
    "wethToken()": FunctionFragment;
  };

  getFunction(
    nameOrSignatureOrTopic:
      | "IS_TEST"
      | "addressOf"
      | "allowance"
      | "approve(address,address,address,uint256)"
      | "approve(uint8,address,address,uint256)"
      | "approve(uint8,address,address)"
      | "approve(address,address,address)"
      | "balanceOf(uint8,address)"
      | "balanceOf(address,address)"
      | "burn(uint8,address,uint256)"
      | "burn(address,address,uint256)"
      | "failed"
      | "getPriceFeeds"
      | "mint(address,address,uint256)"
      | "mint(uint8,address,uint256)"
      | "priceFeeds"
      | "priceFeedsMap"
      | "prices"
      | "symbols"
      | "tokenCount"
      | "tokenIndexes"
      | "topUpWETH()"
      | "topUpWETH(address,uint256)"
      | "wethToken"
  ): FunctionFragment;

  encodeFunctionData(functionFragment: "IS_TEST", values?: undefined): string;
  encodeFunctionData(
    functionFragment: "addressOf",
    values: [PromiseOrValue<BigNumberish>]
  ): string;
  encodeFunctionData(
    functionFragment: "allowance",
    values: [
      PromiseOrValue<BigNumberish>,
      PromiseOrValue<string>,
      PromiseOrValue<string>
    ]
  ): string;
  encodeFunctionData(
    functionFragment: "approve(address,address,address,uint256)",
    values: [
      PromiseOrValue<string>,
      PromiseOrValue<string>,
      PromiseOrValue<string>,
      PromiseOrValue<BigNumberish>
    ]
  ): string;
  encodeFunctionData(
    functionFragment: "approve(uint8,address,address,uint256)",
    values: [
      PromiseOrValue<BigNumberish>,
      PromiseOrValue<string>,
      PromiseOrValue<string>,
      PromiseOrValue<BigNumberish>
    ]
  ): string;
  encodeFunctionData(
    functionFragment: "approve(uint8,address,address)",
    values: [
      PromiseOrValue<BigNumberish>,
      PromiseOrValue<string>,
      PromiseOrValue<string>
    ]
  ): string;
  encodeFunctionData(
    functionFragment: "approve(address,address,address)",
    values: [
      PromiseOrValue<string>,
      PromiseOrValue<string>,
      PromiseOrValue<string>
    ]
  ): string;
  encodeFunctionData(
    functionFragment: "balanceOf(uint8,address)",
    values: [PromiseOrValue<BigNumberish>, PromiseOrValue<string>]
  ): string;
  encodeFunctionData(
    functionFragment: "balanceOf(address,address)",
    values: [PromiseOrValue<string>, PromiseOrValue<string>]
  ): string;
  encodeFunctionData(
    functionFragment: "burn(uint8,address,uint256)",
    values: [
      PromiseOrValue<BigNumberish>,
      PromiseOrValue<string>,
      PromiseOrValue<BigNumberish>
    ]
  ): string;
  encodeFunctionData(
    functionFragment: "burn(address,address,uint256)",
    values: [
      PromiseOrValue<string>,
      PromiseOrValue<string>,
      PromiseOrValue<BigNumberish>
    ]
  ): string;
  encodeFunctionData(functionFragment: "failed", values?: undefined): string;
  encodeFunctionData(
    functionFragment: "getPriceFeeds",
    values?: undefined
  ): string;
  encodeFunctionData(
    functionFragment: "mint(address,address,uint256)",
    values: [
      PromiseOrValue<string>,
      PromiseOrValue<string>,
      PromiseOrValue<BigNumberish>
    ]
  ): string;
  encodeFunctionData(
    functionFragment: "mint(uint8,address,uint256)",
    values: [
      PromiseOrValue<BigNumberish>,
      PromiseOrValue<string>,
      PromiseOrValue<BigNumberish>
    ]
  ): string;
  encodeFunctionData(
    functionFragment: "priceFeeds",
    values: [PromiseOrValue<BigNumberish>]
  ): string;
  encodeFunctionData(
    functionFragment: "priceFeedsMap",
    values: [PromiseOrValue<BigNumberish>]
  ): string;
  encodeFunctionData(
    functionFragment: "prices",
    values: [PromiseOrValue<BigNumberish>]
  ): string;
  encodeFunctionData(
    functionFragment: "symbols",
    values: [PromiseOrValue<BigNumberish>]
  ): string;
  encodeFunctionData(
    functionFragment: "tokenCount",
    values?: undefined
  ): string;
  encodeFunctionData(
    functionFragment: "tokenIndexes",
    values: [PromiseOrValue<string>]
  ): string;
  encodeFunctionData(
    functionFragment: "topUpWETH()",
    values?: undefined
  ): string;
  encodeFunctionData(
    functionFragment: "topUpWETH(address,uint256)",
    values: [PromiseOrValue<string>, PromiseOrValue<BigNumberish>]
  ): string;
  encodeFunctionData(functionFragment: "wethToken", values?: undefined): string;

  decodeFunctionResult(functionFragment: "IS_TEST", data: BytesLike): Result;
  decodeFunctionResult(functionFragment: "addressOf", data: BytesLike): Result;
  decodeFunctionResult(functionFragment: "allowance", data: BytesLike): Result;
  decodeFunctionResult(
    functionFragment: "approve(address,address,address,uint256)",
    data: BytesLike
  ): Result;
  decodeFunctionResult(
    functionFragment: "approve(uint8,address,address,uint256)",
    data: BytesLike
  ): Result;
  decodeFunctionResult(
    functionFragment: "approve(uint8,address,address)",
    data: BytesLike
  ): Result;
  decodeFunctionResult(
    functionFragment: "approve(address,address,address)",
    data: BytesLike
  ): Result;
  decodeFunctionResult(
    functionFragment: "balanceOf(uint8,address)",
    data: BytesLike
  ): Result;
  decodeFunctionResult(
    functionFragment: "balanceOf(address,address)",
    data: BytesLike
  ): Result;
  decodeFunctionResult(
    functionFragment: "burn(uint8,address,uint256)",
    data: BytesLike
  ): Result;
  decodeFunctionResult(
    functionFragment: "burn(address,address,uint256)",
    data: BytesLike
  ): Result;
  decodeFunctionResult(functionFragment: "failed", data: BytesLike): Result;
  decodeFunctionResult(
    functionFragment: "getPriceFeeds",
    data: BytesLike
  ): Result;
  decodeFunctionResult(
    functionFragment: "mint(address,address,uint256)",
    data: BytesLike
  ): Result;
  decodeFunctionResult(
    functionFragment: "mint(uint8,address,uint256)",
    data: BytesLike
  ): Result;
  decodeFunctionResult(functionFragment: "priceFeeds", data: BytesLike): Result;
  decodeFunctionResult(
    functionFragment: "priceFeedsMap",
    data: BytesLike
  ): Result;
  decodeFunctionResult(functionFragment: "prices", data: BytesLike): Result;
  decodeFunctionResult(functionFragment: "symbols", data: BytesLike): Result;
  decodeFunctionResult(functionFragment: "tokenCount", data: BytesLike): Result;
  decodeFunctionResult(
    functionFragment: "tokenIndexes",
    data: BytesLike
  ): Result;
  decodeFunctionResult(
    functionFragment: "topUpWETH()",
    data: BytesLike
  ): Result;
  decodeFunctionResult(
    functionFragment: "topUpWETH(address,uint256)",
    data: BytesLike
  ): Result;
  decodeFunctionResult(functionFragment: "wethToken", data: BytesLike): Result;

  events: {
    "log(string)": EventFragment;
    "log_address(address)": EventFragment;
    "log_bytes(bytes)": EventFragment;
    "log_bytes32(bytes32)": EventFragment;
    "log_int(int256)": EventFragment;
    "log_named_address(string,address)": EventFragment;
    "log_named_bytes(string,bytes)": EventFragment;
    "log_named_bytes32(string,bytes32)": EventFragment;
    "log_named_decimal_int(string,int256,uint256)": EventFragment;
    "log_named_decimal_uint(string,uint256,uint256)": EventFragment;
    "log_named_int(string,int256)": EventFragment;
    "log_named_string(string,string)": EventFragment;
    "log_named_uint(string,uint256)": EventFragment;
    "log_string(string)": EventFragment;
    "log_uint(uint256)": EventFragment;
    "logs(bytes)": EventFragment;
  };

  getEvent(nameOrSignatureOrTopic: "log"): EventFragment;
  getEvent(nameOrSignatureOrTopic: "log_address"): EventFragment;
  getEvent(nameOrSignatureOrTopic: "log_bytes"): EventFragment;
  getEvent(nameOrSignatureOrTopic: "log_bytes32"): EventFragment;
  getEvent(nameOrSignatureOrTopic: "log_int"): EventFragment;
  getEvent(nameOrSignatureOrTopic: "log_named_address"): EventFragment;
  getEvent(nameOrSignatureOrTopic: "log_named_bytes"): EventFragment;
  getEvent(nameOrSignatureOrTopic: "log_named_bytes32"): EventFragment;
  getEvent(nameOrSignatureOrTopic: "log_named_decimal_int"): EventFragment;
  getEvent(nameOrSignatureOrTopic: "log_named_decimal_uint"): EventFragment;
  getEvent(nameOrSignatureOrTopic: "log_named_int"): EventFragment;
  getEvent(nameOrSignatureOrTopic: "log_named_string"): EventFragment;
  getEvent(nameOrSignatureOrTopic: "log_named_uint"): EventFragment;
  getEvent(nameOrSignatureOrTopic: "log_string"): EventFragment;
  getEvent(nameOrSignatureOrTopic: "log_uint"): EventFragment;
  getEvent(nameOrSignatureOrTopic: "logs"): EventFragment;
}

export interface logEventObject {
  arg0: string;
}
export type logEvent = TypedEvent<[string], logEventObject>;

export type logEventFilter = TypedEventFilter<logEvent>;

export interface log_addressEventObject {
  arg0: string;
}
export type log_addressEvent = TypedEvent<[string], log_addressEventObject>;

export type log_addressEventFilter = TypedEventFilter<log_addressEvent>;

export interface log_bytesEventObject {
  arg0: string;
}
export type log_bytesEvent = TypedEvent<[string], log_bytesEventObject>;

export type log_bytesEventFilter = TypedEventFilter<log_bytesEvent>;

export interface log_bytes32EventObject {
  arg0: string;
}
export type log_bytes32Event = TypedEvent<[string], log_bytes32EventObject>;

export type log_bytes32EventFilter = TypedEventFilter<log_bytes32Event>;

export interface log_intEventObject {
  arg0: BigNumber;
}
export type log_intEvent = TypedEvent<[BigNumber], log_intEventObject>;

export type log_intEventFilter = TypedEventFilter<log_intEvent>;

export interface log_named_addressEventObject {
  key: string;
  val: string;
}
export type log_named_addressEvent = TypedEvent<
  [string, string],
  log_named_addressEventObject
>;

export type log_named_addressEventFilter =
  TypedEventFilter<log_named_addressEvent>;

export interface log_named_bytesEventObject {
  key: string;
  val: string;
}
export type log_named_bytesEvent = TypedEvent<
  [string, string],
  log_named_bytesEventObject
>;

export type log_named_bytesEventFilter = TypedEventFilter<log_named_bytesEvent>;

export interface log_named_bytes32EventObject {
  key: string;
  val: string;
}
export type log_named_bytes32Event = TypedEvent<
  [string, string],
  log_named_bytes32EventObject
>;

export type log_named_bytes32EventFilter =
  TypedEventFilter<log_named_bytes32Event>;

export interface log_named_decimal_intEventObject {
  key: string;
  val: BigNumber;
  decimals: BigNumber;
}
export type log_named_decimal_intEvent = TypedEvent<
  [string, BigNumber, BigNumber],
  log_named_decimal_intEventObject
>;

export type log_named_decimal_intEventFilter =
  TypedEventFilter<log_named_decimal_intEvent>;

export interface log_named_decimal_uintEventObject {
  key: string;
  val: BigNumber;
  decimals: BigNumber;
}
export type log_named_decimal_uintEvent = TypedEvent<
  [string, BigNumber, BigNumber],
  log_named_decimal_uintEventObject
>;

export type log_named_decimal_uintEventFilter =
  TypedEventFilter<log_named_decimal_uintEvent>;

export interface log_named_intEventObject {
  key: string;
  val: BigNumber;
}
export type log_named_intEvent = TypedEvent<
  [string, BigNumber],
  log_named_intEventObject
>;

export type log_named_intEventFilter = TypedEventFilter<log_named_intEvent>;

export interface log_named_stringEventObject {
  key: string;
  val: string;
}
export type log_named_stringEvent = TypedEvent<
  [string, string],
  log_named_stringEventObject
>;

export type log_named_stringEventFilter =
  TypedEventFilter<log_named_stringEvent>;

export interface log_named_uintEventObject {
  key: string;
  val: BigNumber;
}
export type log_named_uintEvent = TypedEvent<
  [string, BigNumber],
  log_named_uintEventObject
>;

export type log_named_uintEventFilter = TypedEventFilter<log_named_uintEvent>;

export interface log_stringEventObject {
  arg0: string;
}
export type log_stringEvent = TypedEvent<[string], log_stringEventObject>;

export type log_stringEventFilter = TypedEventFilter<log_stringEvent>;

export interface log_uintEventObject {
  arg0: BigNumber;
}
export type log_uintEvent = TypedEvent<[BigNumber], log_uintEventObject>;

export type log_uintEventFilter = TypedEventFilter<log_uintEvent>;

export interface logsEventObject {
  arg0: string;
}
export type logsEvent = TypedEvent<[string], logsEventObject>;

export type logsEventFilter = TypedEventFilter<logsEvent>;

export interface TokensTestSuite extends BaseContract {
  contractName: "TokensTestSuite";

  connect(signerOrProvider: Signer | Provider | string): this;
  attach(addressOrName: string): this;
  deployed(): Promise<this>;

  interface: TokensTestSuiteInterface;

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
    IS_TEST(overrides?: CallOverrides): Promise<[boolean]>;

    addressOf(
      arg0: PromiseOrValue<BigNumberish>,
      overrides?: CallOverrides
    ): Promise<[string]>;

    allowance(
      t: PromiseOrValue<BigNumberish>,
      holder: PromiseOrValue<string>,
      targetContract: PromiseOrValue<string>,
      overrides?: CallOverrides
    ): Promise<[BigNumber]>;

    "approve(address,address,address,uint256)"(
      token: PromiseOrValue<string>,
      holder: PromiseOrValue<string>,
      targetContract: PromiseOrValue<string>,
      amount: PromiseOrValue<BigNumberish>,
      overrides?: Overrides & { from?: PromiseOrValue<string> }
    ): Promise<ContractTransaction>;

    "approve(uint8,address,address,uint256)"(
      t: PromiseOrValue<BigNumberish>,
      holder: PromiseOrValue<string>,
      targetContract: PromiseOrValue<string>,
      amount: PromiseOrValue<BigNumberish>,
      overrides?: Overrides & { from?: PromiseOrValue<string> }
    ): Promise<ContractTransaction>;

    "approve(uint8,address,address)"(
      t: PromiseOrValue<BigNumberish>,
      holder: PromiseOrValue<string>,
      targetContract: PromiseOrValue<string>,
      overrides?: Overrides & { from?: PromiseOrValue<string> }
    ): Promise<ContractTransaction>;

    "approve(address,address,address)"(
      token: PromiseOrValue<string>,
      holder: PromiseOrValue<string>,
      targetContract: PromiseOrValue<string>,
      overrides?: Overrides & { from?: PromiseOrValue<string> }
    ): Promise<ContractTransaction>;

    "balanceOf(uint8,address)"(
      t: PromiseOrValue<BigNumberish>,
      holder: PromiseOrValue<string>,
      overrides?: CallOverrides
    ): Promise<[BigNumber]>;

    "balanceOf(address,address)"(
      token: PromiseOrValue<string>,
      holder: PromiseOrValue<string>,
      overrides?: CallOverrides
    ): Promise<[BigNumber] & { balance: BigNumber }>;

    "burn(uint8,address,uint256)"(
      t: PromiseOrValue<BigNumberish>,
      from: PromiseOrValue<string>,
      amount: PromiseOrValue<BigNumberish>,
      overrides?: Overrides & { from?: PromiseOrValue<string> }
    ): Promise<ContractTransaction>;

    "burn(address,address,uint256)"(
      token: PromiseOrValue<string>,
      from: PromiseOrValue<string>,
      amount: PromiseOrValue<BigNumberish>,
      overrides?: Overrides & { from?: PromiseOrValue<string> }
    ): Promise<ContractTransaction>;

    failed(
      overrides?: Overrides & { from?: PromiseOrValue<string> }
    ): Promise<ContractTransaction>;

    getPriceFeeds(
      overrides?: CallOverrides
    ): Promise<[PriceFeedConfigStructOutput[]]>;

    "mint(address,address,uint256)"(
      token: PromiseOrValue<string>,
      to: PromiseOrValue<string>,
      amount: PromiseOrValue<BigNumberish>,
      overrides?: Overrides & { from?: PromiseOrValue<string> }
    ): Promise<ContractTransaction>;

    "mint(uint8,address,uint256)"(
      t: PromiseOrValue<BigNumberish>,
      to: PromiseOrValue<string>,
      amount: PromiseOrValue<BigNumberish>,
      overrides?: Overrides & { from?: PromiseOrValue<string> }
    ): Promise<ContractTransaction>;

    priceFeeds(
      arg0: PromiseOrValue<BigNumberish>,
      overrides?: CallOverrides
    ): Promise<[string, string] & { token: string; priceFeed: string }>;

    priceFeedsMap(
      arg0: PromiseOrValue<BigNumberish>,
      overrides?: CallOverrides
    ): Promise<[string]>;

    prices(
      arg0: PromiseOrValue<BigNumberish>,
      overrides?: CallOverrides
    ): Promise<[BigNumber]>;

    symbols(
      arg0: PromiseOrValue<BigNumberish>,
      overrides?: CallOverrides
    ): Promise<[string]>;

    tokenCount(overrides?: CallOverrides): Promise<[BigNumber]>;

    tokenIndexes(
      arg0: PromiseOrValue<string>,
      overrides?: CallOverrides
    ): Promise<[number]>;

    "topUpWETH()"(
      overrides?: PayableOverrides & { from?: PromiseOrValue<string> }
    ): Promise<ContractTransaction>;

    "topUpWETH(address,uint256)"(
      onBehalfOf: PromiseOrValue<string>,
      value: PromiseOrValue<BigNumberish>,
      overrides?: Overrides & { from?: PromiseOrValue<string> }
    ): Promise<ContractTransaction>;

    wethToken(overrides?: CallOverrides): Promise<[string]>;
  };

  IS_TEST(overrides?: CallOverrides): Promise<boolean>;

  addressOf(
    arg0: PromiseOrValue<BigNumberish>,
    overrides?: CallOverrides
  ): Promise<string>;

  allowance(
    t: PromiseOrValue<BigNumberish>,
    holder: PromiseOrValue<string>,
    targetContract: PromiseOrValue<string>,
    overrides?: CallOverrides
  ): Promise<BigNumber>;

  "approve(address,address,address,uint256)"(
    token: PromiseOrValue<string>,
    holder: PromiseOrValue<string>,
    targetContract: PromiseOrValue<string>,
    amount: PromiseOrValue<BigNumberish>,
    overrides?: Overrides & { from?: PromiseOrValue<string> }
  ): Promise<ContractTransaction>;

  "approve(uint8,address,address,uint256)"(
    t: PromiseOrValue<BigNumberish>,
    holder: PromiseOrValue<string>,
    targetContract: PromiseOrValue<string>,
    amount: PromiseOrValue<BigNumberish>,
    overrides?: Overrides & { from?: PromiseOrValue<string> }
  ): Promise<ContractTransaction>;

  "approve(uint8,address,address)"(
    t: PromiseOrValue<BigNumberish>,
    holder: PromiseOrValue<string>,
    targetContract: PromiseOrValue<string>,
    overrides?: Overrides & { from?: PromiseOrValue<string> }
  ): Promise<ContractTransaction>;

  "approve(address,address,address)"(
    token: PromiseOrValue<string>,
    holder: PromiseOrValue<string>,
    targetContract: PromiseOrValue<string>,
    overrides?: Overrides & { from?: PromiseOrValue<string> }
  ): Promise<ContractTransaction>;

  "balanceOf(uint8,address)"(
    t: PromiseOrValue<BigNumberish>,
    holder: PromiseOrValue<string>,
    overrides?: CallOverrides
  ): Promise<BigNumber>;

  "balanceOf(address,address)"(
    token: PromiseOrValue<string>,
    holder: PromiseOrValue<string>,
    overrides?: CallOverrides
  ): Promise<BigNumber>;

  "burn(uint8,address,uint256)"(
    t: PromiseOrValue<BigNumberish>,
    from: PromiseOrValue<string>,
    amount: PromiseOrValue<BigNumberish>,
    overrides?: Overrides & { from?: PromiseOrValue<string> }
  ): Promise<ContractTransaction>;

  "burn(address,address,uint256)"(
    token: PromiseOrValue<string>,
    from: PromiseOrValue<string>,
    amount: PromiseOrValue<BigNumberish>,
    overrides?: Overrides & { from?: PromiseOrValue<string> }
  ): Promise<ContractTransaction>;

  failed(
    overrides?: Overrides & { from?: PromiseOrValue<string> }
  ): Promise<ContractTransaction>;

  getPriceFeeds(
    overrides?: CallOverrides
  ): Promise<PriceFeedConfigStructOutput[]>;

  "mint(address,address,uint256)"(
    token: PromiseOrValue<string>,
    to: PromiseOrValue<string>,
    amount: PromiseOrValue<BigNumberish>,
    overrides?: Overrides & { from?: PromiseOrValue<string> }
  ): Promise<ContractTransaction>;

  "mint(uint8,address,uint256)"(
    t: PromiseOrValue<BigNumberish>,
    to: PromiseOrValue<string>,
    amount: PromiseOrValue<BigNumberish>,
    overrides?: Overrides & { from?: PromiseOrValue<string> }
  ): Promise<ContractTransaction>;

  priceFeeds(
    arg0: PromiseOrValue<BigNumberish>,
    overrides?: CallOverrides
  ): Promise<[string, string] & { token: string; priceFeed: string }>;

  priceFeedsMap(
    arg0: PromiseOrValue<BigNumberish>,
    overrides?: CallOverrides
  ): Promise<string>;

  prices(
    arg0: PromiseOrValue<BigNumberish>,
    overrides?: CallOverrides
  ): Promise<BigNumber>;

  symbols(
    arg0: PromiseOrValue<BigNumberish>,
    overrides?: CallOverrides
  ): Promise<string>;

  tokenCount(overrides?: CallOverrides): Promise<BigNumber>;

  tokenIndexes(
    arg0: PromiseOrValue<string>,
    overrides?: CallOverrides
  ): Promise<number>;

  "topUpWETH()"(
    overrides?: PayableOverrides & { from?: PromiseOrValue<string> }
  ): Promise<ContractTransaction>;

  "topUpWETH(address,uint256)"(
    onBehalfOf: PromiseOrValue<string>,
    value: PromiseOrValue<BigNumberish>,
    overrides?: Overrides & { from?: PromiseOrValue<string> }
  ): Promise<ContractTransaction>;

  wethToken(overrides?: CallOverrides): Promise<string>;

  callStatic: {
    IS_TEST(overrides?: CallOverrides): Promise<boolean>;

    addressOf(
      arg0: PromiseOrValue<BigNumberish>,
      overrides?: CallOverrides
    ): Promise<string>;

    allowance(
      t: PromiseOrValue<BigNumberish>,
      holder: PromiseOrValue<string>,
      targetContract: PromiseOrValue<string>,
      overrides?: CallOverrides
    ): Promise<BigNumber>;

    "approve(address,address,address,uint256)"(
      token: PromiseOrValue<string>,
      holder: PromiseOrValue<string>,
      targetContract: PromiseOrValue<string>,
      amount: PromiseOrValue<BigNumberish>,
      overrides?: CallOverrides
    ): Promise<void>;

    "approve(uint8,address,address,uint256)"(
      t: PromiseOrValue<BigNumberish>,
      holder: PromiseOrValue<string>,
      targetContract: PromiseOrValue<string>,
      amount: PromiseOrValue<BigNumberish>,
      overrides?: CallOverrides
    ): Promise<void>;

    "approve(uint8,address,address)"(
      t: PromiseOrValue<BigNumberish>,
      holder: PromiseOrValue<string>,
      targetContract: PromiseOrValue<string>,
      overrides?: CallOverrides
    ): Promise<void>;

    "approve(address,address,address)"(
      token: PromiseOrValue<string>,
      holder: PromiseOrValue<string>,
      targetContract: PromiseOrValue<string>,
      overrides?: CallOverrides
    ): Promise<void>;

    "balanceOf(uint8,address)"(
      t: PromiseOrValue<BigNumberish>,
      holder: PromiseOrValue<string>,
      overrides?: CallOverrides
    ): Promise<BigNumber>;

    "balanceOf(address,address)"(
      token: PromiseOrValue<string>,
      holder: PromiseOrValue<string>,
      overrides?: CallOverrides
    ): Promise<BigNumber>;

    "burn(uint8,address,uint256)"(
      t: PromiseOrValue<BigNumberish>,
      from: PromiseOrValue<string>,
      amount: PromiseOrValue<BigNumberish>,
      overrides?: CallOverrides
    ): Promise<void>;

    "burn(address,address,uint256)"(
      token: PromiseOrValue<string>,
      from: PromiseOrValue<string>,
      amount: PromiseOrValue<BigNumberish>,
      overrides?: CallOverrides
    ): Promise<void>;

    failed(overrides?: CallOverrides): Promise<boolean>;

    getPriceFeeds(
      overrides?: CallOverrides
    ): Promise<PriceFeedConfigStructOutput[]>;

    "mint(address,address,uint256)"(
      token: PromiseOrValue<string>,
      to: PromiseOrValue<string>,
      amount: PromiseOrValue<BigNumberish>,
      overrides?: CallOverrides
    ): Promise<void>;

    "mint(uint8,address,uint256)"(
      t: PromiseOrValue<BigNumberish>,
      to: PromiseOrValue<string>,
      amount: PromiseOrValue<BigNumberish>,
      overrides?: CallOverrides
    ): Promise<void>;

    priceFeeds(
      arg0: PromiseOrValue<BigNumberish>,
      overrides?: CallOverrides
    ): Promise<[string, string] & { token: string; priceFeed: string }>;

    priceFeedsMap(
      arg0: PromiseOrValue<BigNumberish>,
      overrides?: CallOverrides
    ): Promise<string>;

    prices(
      arg0: PromiseOrValue<BigNumberish>,
      overrides?: CallOverrides
    ): Promise<BigNumber>;

    symbols(
      arg0: PromiseOrValue<BigNumberish>,
      overrides?: CallOverrides
    ): Promise<string>;

    tokenCount(overrides?: CallOverrides): Promise<BigNumber>;

    tokenIndexes(
      arg0: PromiseOrValue<string>,
      overrides?: CallOverrides
    ): Promise<number>;

    "topUpWETH()"(overrides?: CallOverrides): Promise<void>;

    "topUpWETH(address,uint256)"(
      onBehalfOf: PromiseOrValue<string>,
      value: PromiseOrValue<BigNumberish>,
      overrides?: CallOverrides
    ): Promise<void>;

    wethToken(overrides?: CallOverrides): Promise<string>;
  };

  filters: {
    "log(string)"(arg0?: null): logEventFilter;
    log(arg0?: null): logEventFilter;

    "log_address(address)"(arg0?: null): log_addressEventFilter;
    log_address(arg0?: null): log_addressEventFilter;

    "log_bytes(bytes)"(arg0?: null): log_bytesEventFilter;
    log_bytes(arg0?: null): log_bytesEventFilter;

    "log_bytes32(bytes32)"(arg0?: null): log_bytes32EventFilter;
    log_bytes32(arg0?: null): log_bytes32EventFilter;

    "log_int(int256)"(arg0?: null): log_intEventFilter;
    log_int(arg0?: null): log_intEventFilter;

    "log_named_address(string,address)"(
      key?: null,
      val?: null
    ): log_named_addressEventFilter;
    log_named_address(key?: null, val?: null): log_named_addressEventFilter;

    "log_named_bytes(string,bytes)"(
      key?: null,
      val?: null
    ): log_named_bytesEventFilter;
    log_named_bytes(key?: null, val?: null): log_named_bytesEventFilter;

    "log_named_bytes32(string,bytes32)"(
      key?: null,
      val?: null
    ): log_named_bytes32EventFilter;
    log_named_bytes32(key?: null, val?: null): log_named_bytes32EventFilter;

    "log_named_decimal_int(string,int256,uint256)"(
      key?: null,
      val?: null,
      decimals?: null
    ): log_named_decimal_intEventFilter;
    log_named_decimal_int(
      key?: null,
      val?: null,
      decimals?: null
    ): log_named_decimal_intEventFilter;

    "log_named_decimal_uint(string,uint256,uint256)"(
      key?: null,
      val?: null,
      decimals?: null
    ): log_named_decimal_uintEventFilter;
    log_named_decimal_uint(
      key?: null,
      val?: null,
      decimals?: null
    ): log_named_decimal_uintEventFilter;

    "log_named_int(string,int256)"(
      key?: null,
      val?: null
    ): log_named_intEventFilter;
    log_named_int(key?: null, val?: null): log_named_intEventFilter;

    "log_named_string(string,string)"(
      key?: null,
      val?: null
    ): log_named_stringEventFilter;
    log_named_string(key?: null, val?: null): log_named_stringEventFilter;

    "log_named_uint(string,uint256)"(
      key?: null,
      val?: null
    ): log_named_uintEventFilter;
    log_named_uint(key?: null, val?: null): log_named_uintEventFilter;

    "log_string(string)"(arg0?: null): log_stringEventFilter;
    log_string(arg0?: null): log_stringEventFilter;

    "log_uint(uint256)"(arg0?: null): log_uintEventFilter;
    log_uint(arg0?: null): log_uintEventFilter;

    "logs(bytes)"(arg0?: null): logsEventFilter;
    logs(arg0?: null): logsEventFilter;
  };

  estimateGas: {
    IS_TEST(overrides?: CallOverrides): Promise<BigNumber>;

    addressOf(
      arg0: PromiseOrValue<BigNumberish>,
      overrides?: CallOverrides
    ): Promise<BigNumber>;

    allowance(
      t: PromiseOrValue<BigNumberish>,
      holder: PromiseOrValue<string>,
      targetContract: PromiseOrValue<string>,
      overrides?: CallOverrides
    ): Promise<BigNumber>;

    "approve(address,address,address,uint256)"(
      token: PromiseOrValue<string>,
      holder: PromiseOrValue<string>,
      targetContract: PromiseOrValue<string>,
      amount: PromiseOrValue<BigNumberish>,
      overrides?: Overrides & { from?: PromiseOrValue<string> }
    ): Promise<BigNumber>;

    "approve(uint8,address,address,uint256)"(
      t: PromiseOrValue<BigNumberish>,
      holder: PromiseOrValue<string>,
      targetContract: PromiseOrValue<string>,
      amount: PromiseOrValue<BigNumberish>,
      overrides?: Overrides & { from?: PromiseOrValue<string> }
    ): Promise<BigNumber>;

    "approve(uint8,address,address)"(
      t: PromiseOrValue<BigNumberish>,
      holder: PromiseOrValue<string>,
      targetContract: PromiseOrValue<string>,
      overrides?: Overrides & { from?: PromiseOrValue<string> }
    ): Promise<BigNumber>;

    "approve(address,address,address)"(
      token: PromiseOrValue<string>,
      holder: PromiseOrValue<string>,
      targetContract: PromiseOrValue<string>,
      overrides?: Overrides & { from?: PromiseOrValue<string> }
    ): Promise<BigNumber>;

    "balanceOf(uint8,address)"(
      t: PromiseOrValue<BigNumberish>,
      holder: PromiseOrValue<string>,
      overrides?: CallOverrides
    ): Promise<BigNumber>;

    "balanceOf(address,address)"(
      token: PromiseOrValue<string>,
      holder: PromiseOrValue<string>,
      overrides?: CallOverrides
    ): Promise<BigNumber>;

    "burn(uint8,address,uint256)"(
      t: PromiseOrValue<BigNumberish>,
      from: PromiseOrValue<string>,
      amount: PromiseOrValue<BigNumberish>,
      overrides?: Overrides & { from?: PromiseOrValue<string> }
    ): Promise<BigNumber>;

    "burn(address,address,uint256)"(
      token: PromiseOrValue<string>,
      from: PromiseOrValue<string>,
      amount: PromiseOrValue<BigNumberish>,
      overrides?: Overrides & { from?: PromiseOrValue<string> }
    ): Promise<BigNumber>;

    failed(
      overrides?: Overrides & { from?: PromiseOrValue<string> }
    ): Promise<BigNumber>;

    getPriceFeeds(overrides?: CallOverrides): Promise<BigNumber>;

    "mint(address,address,uint256)"(
      token: PromiseOrValue<string>,
      to: PromiseOrValue<string>,
      amount: PromiseOrValue<BigNumberish>,
      overrides?: Overrides & { from?: PromiseOrValue<string> }
    ): Promise<BigNumber>;

    "mint(uint8,address,uint256)"(
      t: PromiseOrValue<BigNumberish>,
      to: PromiseOrValue<string>,
      amount: PromiseOrValue<BigNumberish>,
      overrides?: Overrides & { from?: PromiseOrValue<string> }
    ): Promise<BigNumber>;

    priceFeeds(
      arg0: PromiseOrValue<BigNumberish>,
      overrides?: CallOverrides
    ): Promise<BigNumber>;

    priceFeedsMap(
      arg0: PromiseOrValue<BigNumberish>,
      overrides?: CallOverrides
    ): Promise<BigNumber>;

    prices(
      arg0: PromiseOrValue<BigNumberish>,
      overrides?: CallOverrides
    ): Promise<BigNumber>;

    symbols(
      arg0: PromiseOrValue<BigNumberish>,
      overrides?: CallOverrides
    ): Promise<BigNumber>;

    tokenCount(overrides?: CallOverrides): Promise<BigNumber>;

    tokenIndexes(
      arg0: PromiseOrValue<string>,
      overrides?: CallOverrides
    ): Promise<BigNumber>;

    "topUpWETH()"(
      overrides?: PayableOverrides & { from?: PromiseOrValue<string> }
    ): Promise<BigNumber>;

    "topUpWETH(address,uint256)"(
      onBehalfOf: PromiseOrValue<string>,
      value: PromiseOrValue<BigNumberish>,
      overrides?: Overrides & { from?: PromiseOrValue<string> }
    ): Promise<BigNumber>;

    wethToken(overrides?: CallOverrides): Promise<BigNumber>;
  };

  populateTransaction: {
    IS_TEST(overrides?: CallOverrides): Promise<PopulatedTransaction>;

    addressOf(
      arg0: PromiseOrValue<BigNumberish>,
      overrides?: CallOverrides
    ): Promise<PopulatedTransaction>;

    allowance(
      t: PromiseOrValue<BigNumberish>,
      holder: PromiseOrValue<string>,
      targetContract: PromiseOrValue<string>,
      overrides?: CallOverrides
    ): Promise<PopulatedTransaction>;

    "approve(address,address,address,uint256)"(
      token: PromiseOrValue<string>,
      holder: PromiseOrValue<string>,
      targetContract: PromiseOrValue<string>,
      amount: PromiseOrValue<BigNumberish>,
      overrides?: Overrides & { from?: PromiseOrValue<string> }
    ): Promise<PopulatedTransaction>;

    "approve(uint8,address,address,uint256)"(
      t: PromiseOrValue<BigNumberish>,
      holder: PromiseOrValue<string>,
      targetContract: PromiseOrValue<string>,
      amount: PromiseOrValue<BigNumberish>,
      overrides?: Overrides & { from?: PromiseOrValue<string> }
    ): Promise<PopulatedTransaction>;

    "approve(uint8,address,address)"(
      t: PromiseOrValue<BigNumberish>,
      holder: PromiseOrValue<string>,
      targetContract: PromiseOrValue<string>,
      overrides?: Overrides & { from?: PromiseOrValue<string> }
    ): Promise<PopulatedTransaction>;

    "approve(address,address,address)"(
      token: PromiseOrValue<string>,
      holder: PromiseOrValue<string>,
      targetContract: PromiseOrValue<string>,
      overrides?: Overrides & { from?: PromiseOrValue<string> }
    ): Promise<PopulatedTransaction>;

    "balanceOf(uint8,address)"(
      t: PromiseOrValue<BigNumberish>,
      holder: PromiseOrValue<string>,
      overrides?: CallOverrides
    ): Promise<PopulatedTransaction>;

    "balanceOf(address,address)"(
      token: PromiseOrValue<string>,
      holder: PromiseOrValue<string>,
      overrides?: CallOverrides
    ): Promise<PopulatedTransaction>;

    "burn(uint8,address,uint256)"(
      t: PromiseOrValue<BigNumberish>,
      from: PromiseOrValue<string>,
      amount: PromiseOrValue<BigNumberish>,
      overrides?: Overrides & { from?: PromiseOrValue<string> }
    ): Promise<PopulatedTransaction>;

    "burn(address,address,uint256)"(
      token: PromiseOrValue<string>,
      from: PromiseOrValue<string>,
      amount: PromiseOrValue<BigNumberish>,
      overrides?: Overrides & { from?: PromiseOrValue<string> }
    ): Promise<PopulatedTransaction>;

    failed(
      overrides?: Overrides & { from?: PromiseOrValue<string> }
    ): Promise<PopulatedTransaction>;

    getPriceFeeds(overrides?: CallOverrides): Promise<PopulatedTransaction>;

    "mint(address,address,uint256)"(
      token: PromiseOrValue<string>,
      to: PromiseOrValue<string>,
      amount: PromiseOrValue<BigNumberish>,
      overrides?: Overrides & { from?: PromiseOrValue<string> }
    ): Promise<PopulatedTransaction>;

    "mint(uint8,address,uint256)"(
      t: PromiseOrValue<BigNumberish>,
      to: PromiseOrValue<string>,
      amount: PromiseOrValue<BigNumberish>,
      overrides?: Overrides & { from?: PromiseOrValue<string> }
    ): Promise<PopulatedTransaction>;

    priceFeeds(
      arg0: PromiseOrValue<BigNumberish>,
      overrides?: CallOverrides
    ): Promise<PopulatedTransaction>;

    priceFeedsMap(
      arg0: PromiseOrValue<BigNumberish>,
      overrides?: CallOverrides
    ): Promise<PopulatedTransaction>;

    prices(
      arg0: PromiseOrValue<BigNumberish>,
      overrides?: CallOverrides
    ): Promise<PopulatedTransaction>;

    symbols(
      arg0: PromiseOrValue<BigNumberish>,
      overrides?: CallOverrides
    ): Promise<PopulatedTransaction>;

    tokenCount(overrides?: CallOverrides): Promise<PopulatedTransaction>;

    tokenIndexes(
      arg0: PromiseOrValue<string>,
      overrides?: CallOverrides
    ): Promise<PopulatedTransaction>;

    "topUpWETH()"(
      overrides?: PayableOverrides & { from?: PromiseOrValue<string> }
    ): Promise<PopulatedTransaction>;

    "topUpWETH(address,uint256)"(
      onBehalfOf: PromiseOrValue<string>,
      value: PromiseOrValue<BigNumberish>,
      overrides?: Overrides & { from?: PromiseOrValue<string> }
    ): Promise<PopulatedTransaction>;

    wethToken(overrides?: CallOverrides): Promise<PopulatedTransaction>;
  };
}
