/* Autogenerated file. Do not edit manually. */
/* tslint:disable */
/* eslint-disable */

import { Contract, Signer, utils } from "ethers";
import type { Provider } from "@ethersproject/providers";
import type {
  IPriceOracleV2Ext,
  IPriceOracleV2ExtInterface,
} from "../../IPriceOracle.sol/IPriceOracleV2Ext";

const _abi = [
  {
    inputs: [],
    name: "ChainPriceStaleException",
    type: "error",
  },
  {
    inputs: [],
    name: "PriceOracleNotExistsException",
    type: "error",
  },
  {
    inputs: [],
    name: "ZeroPriceException",
    type: "error",
  },
  {
    anonymous: false,
    inputs: [
      {
        indexed: true,
        internalType: "address",
        name: "token",
        type: "address",
      },
      {
        indexed: true,
        internalType: "address",
        name: "priceFeed",
        type: "address",
      },
    ],
    name: "NewPriceFeed",
    type: "event",
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
        name: "priceFeed",
        type: "address",
      },
    ],
    name: "addPriceFeed",
    outputs: [],
    stateMutability: "nonpayable",
    type: "function",
  },
  {
    inputs: [
      {
        internalType: "uint256",
        name: "amount",
        type: "uint256",
      },
      {
        internalType: "address",
        name: "tokenFrom",
        type: "address",
      },
      {
        internalType: "address",
        name: "tokenTo",
        type: "address",
      },
    ],
    name: "convert",
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
        internalType: "uint256",
        name: "amount",
        type: "uint256",
      },
      {
        internalType: "address",
        name: "token",
        type: "address",
      },
    ],
    name: "convertFromUSD",
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
        internalType: "uint256",
        name: "amount",
        type: "uint256",
      },
      {
        internalType: "address",
        name: "token",
        type: "address",
      },
    ],
    name: "convertToUSD",
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
        internalType: "uint256",
        name: "amountFrom",
        type: "uint256",
      },
      {
        internalType: "address",
        name: "tokenFrom",
        type: "address",
      },
      {
        internalType: "uint256",
        name: "amountTo",
        type: "uint256",
      },
      {
        internalType: "address",
        name: "tokenTo",
        type: "address",
      },
    ],
    name: "fastCheck",
    outputs: [
      {
        internalType: "uint256",
        name: "collateralFrom",
        type: "uint256",
      },
      {
        internalType: "uint256",
        name: "collateralTo",
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
    ],
    name: "getPrice",
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
        name: "token",
        type: "address",
      },
    ],
    name: "priceFeeds",
    outputs: [
      {
        internalType: "address",
        name: "priceFeed",
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
    ],
    name: "priceFeedsWithFlags",
    outputs: [
      {
        internalType: "address",
        name: "priceFeed",
        type: "address",
      },
      {
        internalType: "bool",
        name: "skipCheck",
        type: "bool",
      },
      {
        internalType: "uint256",
        name: "decimals",
        type: "uint256",
      },
    ],
    stateMutability: "view",
    type: "function",
  },
  {
    inputs: [],
    name: "version",
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
] as const;

export class IPriceOracleV2Ext__factory {
  static readonly abi = _abi;
  static createInterface(): IPriceOracleV2ExtInterface {
    return new utils.Interface(_abi) as IPriceOracleV2ExtInterface;
  }
  static connect(
    address: string,
    signerOrProvider: Signer | Provider
  ): IPriceOracleV2Ext {
    return new Contract(address, _abi, signerOrProvider) as IPriceOracleV2Ext;
  }
}
