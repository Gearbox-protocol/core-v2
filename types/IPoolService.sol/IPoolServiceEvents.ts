/* Autogenerated file. Do not edit manually. */
/* tslint:disable */
/* eslint-disable */
import type { BaseContract, BigNumber, Signer, utils } from "ethers";
import type { EventFragment } from "@ethersproject/abi";
import type { Listener, Provider } from "@ethersproject/providers";
import type {
  TypedEventFilter,
  TypedEvent,
  TypedListener,
  OnEvent,
  PromiseOrValue,
} from "../common";

export interface IPoolServiceEventsInterface extends utils.Interface {
  functions: {};

  events: {
    "AddLiquidity(address,address,uint256,uint256)": EventFragment;
    "Borrow(address,address,uint256)": EventFragment;
    "BorrowForbidden(address)": EventFragment;
    "NewCreditManagerConnected(address)": EventFragment;
    "NewExpectedLiquidityLimit(uint256)": EventFragment;
    "NewInterestRateModel(address)": EventFragment;
    "NewWithdrawFee(uint256)": EventFragment;
    "RemoveLiquidity(address,address,uint256)": EventFragment;
    "Repay(address,uint256,uint256,uint256)": EventFragment;
    "UncoveredLoss(address,uint256)": EventFragment;
  };

  getEvent(nameOrSignatureOrTopic: "AddLiquidity"): EventFragment;
  getEvent(nameOrSignatureOrTopic: "Borrow"): EventFragment;
  getEvent(nameOrSignatureOrTopic: "BorrowForbidden"): EventFragment;
  getEvent(nameOrSignatureOrTopic: "NewCreditManagerConnected"): EventFragment;
  getEvent(nameOrSignatureOrTopic: "NewExpectedLiquidityLimit"): EventFragment;
  getEvent(nameOrSignatureOrTopic: "NewInterestRateModel"): EventFragment;
  getEvent(nameOrSignatureOrTopic: "NewWithdrawFee"): EventFragment;
  getEvent(nameOrSignatureOrTopic: "RemoveLiquidity"): EventFragment;
  getEvent(nameOrSignatureOrTopic: "Repay"): EventFragment;
  getEvent(nameOrSignatureOrTopic: "UncoveredLoss"): EventFragment;
}

export interface AddLiquidityEventObject {
  sender: string;
  onBehalfOf: string;
  amount: BigNumber;
  referralCode: BigNumber;
}
export type AddLiquidityEvent = TypedEvent<
  [string, string, BigNumber, BigNumber],
  AddLiquidityEventObject
>;

export type AddLiquidityEventFilter = TypedEventFilter<AddLiquidityEvent>;

export interface BorrowEventObject {
  creditManager: string;
  creditAccount: string;
  amount: BigNumber;
}
export type BorrowEvent = TypedEvent<
  [string, string, BigNumber],
  BorrowEventObject
>;

export type BorrowEventFilter = TypedEventFilter<BorrowEvent>;

export interface BorrowForbiddenEventObject {
  creditManager: string;
}
export type BorrowForbiddenEvent = TypedEvent<
  [string],
  BorrowForbiddenEventObject
>;

export type BorrowForbiddenEventFilter = TypedEventFilter<BorrowForbiddenEvent>;

export interface NewCreditManagerConnectedEventObject {
  creditManager: string;
}
export type NewCreditManagerConnectedEvent = TypedEvent<
  [string],
  NewCreditManagerConnectedEventObject
>;

export type NewCreditManagerConnectedEventFilter =
  TypedEventFilter<NewCreditManagerConnectedEvent>;

export interface NewExpectedLiquidityLimitEventObject {
  newLimit: BigNumber;
}
export type NewExpectedLiquidityLimitEvent = TypedEvent<
  [BigNumber],
  NewExpectedLiquidityLimitEventObject
>;

export type NewExpectedLiquidityLimitEventFilter =
  TypedEventFilter<NewExpectedLiquidityLimitEvent>;

export interface NewInterestRateModelEventObject {
  newInterestRateModel: string;
}
export type NewInterestRateModelEvent = TypedEvent<
  [string],
  NewInterestRateModelEventObject
>;

export type NewInterestRateModelEventFilter =
  TypedEventFilter<NewInterestRateModelEvent>;

export interface NewWithdrawFeeEventObject {
  fee: BigNumber;
}
export type NewWithdrawFeeEvent = TypedEvent<
  [BigNumber],
  NewWithdrawFeeEventObject
>;

export type NewWithdrawFeeEventFilter = TypedEventFilter<NewWithdrawFeeEvent>;

export interface RemoveLiquidityEventObject {
  sender: string;
  to: string;
  amount: BigNumber;
}
export type RemoveLiquidityEvent = TypedEvent<
  [string, string, BigNumber],
  RemoveLiquidityEventObject
>;

export type RemoveLiquidityEventFilter = TypedEventFilter<RemoveLiquidityEvent>;

export interface RepayEventObject {
  creditManager: string;
  borrowedAmount: BigNumber;
  profit: BigNumber;
  loss: BigNumber;
}
export type RepayEvent = TypedEvent<
  [string, BigNumber, BigNumber, BigNumber],
  RepayEventObject
>;

export type RepayEventFilter = TypedEventFilter<RepayEvent>;

export interface UncoveredLossEventObject {
  creditManager: string;
  loss: BigNumber;
}
export type UncoveredLossEvent = TypedEvent<
  [string, BigNumber],
  UncoveredLossEventObject
>;

export type UncoveredLossEventFilter = TypedEventFilter<UncoveredLossEvent>;

export interface IPoolServiceEvents extends BaseContract {
  contractName: "IPoolServiceEvents";

  connect(signerOrProvider: Signer | Provider | string): this;
  attach(addressOrName: string): this;
  deployed(): Promise<this>;

  interface: IPoolServiceEventsInterface;

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

  functions: {};

  callStatic: {};

  filters: {
    "AddLiquidity(address,address,uint256,uint256)"(
      sender?: PromiseOrValue<string> | null,
      onBehalfOf?: PromiseOrValue<string> | null,
      amount?: null,
      referralCode?: null
    ): AddLiquidityEventFilter;
    AddLiquidity(
      sender?: PromiseOrValue<string> | null,
      onBehalfOf?: PromiseOrValue<string> | null,
      amount?: null,
      referralCode?: null
    ): AddLiquidityEventFilter;

    "Borrow(address,address,uint256)"(
      creditManager?: PromiseOrValue<string> | null,
      creditAccount?: PromiseOrValue<string> | null,
      amount?: null
    ): BorrowEventFilter;
    Borrow(
      creditManager?: PromiseOrValue<string> | null,
      creditAccount?: PromiseOrValue<string> | null,
      amount?: null
    ): BorrowEventFilter;

    "BorrowForbidden(address)"(
      creditManager?: PromiseOrValue<string> | null
    ): BorrowForbiddenEventFilter;
    BorrowForbidden(
      creditManager?: PromiseOrValue<string> | null
    ): BorrowForbiddenEventFilter;

    "NewCreditManagerConnected(address)"(
      creditManager?: PromiseOrValue<string> | null
    ): NewCreditManagerConnectedEventFilter;
    NewCreditManagerConnected(
      creditManager?: PromiseOrValue<string> | null
    ): NewCreditManagerConnectedEventFilter;

    "NewExpectedLiquidityLimit(uint256)"(
      newLimit?: null
    ): NewExpectedLiquidityLimitEventFilter;
    NewExpectedLiquidityLimit(
      newLimit?: null
    ): NewExpectedLiquidityLimitEventFilter;

    "NewInterestRateModel(address)"(
      newInterestRateModel?: PromiseOrValue<string> | null
    ): NewInterestRateModelEventFilter;
    NewInterestRateModel(
      newInterestRateModel?: PromiseOrValue<string> | null
    ): NewInterestRateModelEventFilter;

    "NewWithdrawFee(uint256)"(fee?: null): NewWithdrawFeeEventFilter;
    NewWithdrawFee(fee?: null): NewWithdrawFeeEventFilter;

    "RemoveLiquidity(address,address,uint256)"(
      sender?: PromiseOrValue<string> | null,
      to?: PromiseOrValue<string> | null,
      amount?: null
    ): RemoveLiquidityEventFilter;
    RemoveLiquidity(
      sender?: PromiseOrValue<string> | null,
      to?: PromiseOrValue<string> | null,
      amount?: null
    ): RemoveLiquidityEventFilter;

    "Repay(address,uint256,uint256,uint256)"(
      creditManager?: PromiseOrValue<string> | null,
      borrowedAmount?: null,
      profit?: null,
      loss?: null
    ): RepayEventFilter;
    Repay(
      creditManager?: PromiseOrValue<string> | null,
      borrowedAmount?: null,
      profit?: null,
      loss?: null
    ): RepayEventFilter;

    "UncoveredLoss(address,uint256)"(
      creditManager?: PromiseOrValue<string> | null,
      loss?: null
    ): UncoveredLossEventFilter;
    UncoveredLoss(
      creditManager?: PromiseOrValue<string> | null,
      loss?: null
    ): UncoveredLossEventFilter;
  };

  estimateGas: {};

  populateTransaction: {};
}
