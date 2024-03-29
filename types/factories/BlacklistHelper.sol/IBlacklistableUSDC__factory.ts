/* Autogenerated file. Do not edit manually. */
/* tslint:disable */
/* eslint-disable */

import { Contract, Signer, utils } from "ethers";
import type { Provider } from "@ethersproject/providers";
import type {
  IBlacklistableUSDC,
  IBlacklistableUSDCInterface,
} from "../../BlacklistHelper.sol/IBlacklistableUSDC";

const _abi = [
  {
    inputs: [
      {
        internalType: "address",
        name: "_account",
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
] as const;

export class IBlacklistableUSDC__factory {
  static readonly abi = _abi;
  static createInterface(): IBlacklistableUSDCInterface {
    return new utils.Interface(_abi) as IBlacklistableUSDCInterface;
  }
  static connect(
    address: string,
    signerOrProvider: Signer | Provider
  ): IBlacklistableUSDC {
    return new Contract(address, _abi, signerOrProvider) as IBlacklistableUSDC;
  }
}
