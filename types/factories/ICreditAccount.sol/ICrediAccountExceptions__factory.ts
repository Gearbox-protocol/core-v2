/* Autogenerated file. Do not edit manually. */
/* tslint:disable */
/* eslint-disable */

import { Contract, Signer, utils } from "ethers";
import type { Provider } from "@ethersproject/providers";
import type {
  ICrediAccountExceptions,
  ICrediAccountExceptionsInterface,
} from "../../ICreditAccount.sol/ICrediAccountExceptions";

const _abi = [
  {
    inputs: [],
    name: "CallerNotCreditManagerException",
    type: "error",
  },
  {
    inputs: [],
    name: "CallerNotFactoryException",
    type: "error",
  },
] as const;

export class ICrediAccountExceptions__factory {
  static readonly abi = _abi;
  static createInterface(): ICrediAccountExceptionsInterface {
    return new utils.Interface(_abi) as ICrediAccountExceptionsInterface;
  }
  static connect(
    address: string,
    signerOrProvider: Signer | Provider
  ): ICrediAccountExceptions {
    return new Contract(
      address,
      _abi,
      signerOrProvider
    ) as ICrediAccountExceptions;
  }
}
