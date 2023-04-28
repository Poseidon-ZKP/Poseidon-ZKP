/* Autogenerated file. Do not edit manually. */
/* tslint:disable */
/* eslint-disable */

import { Contract, Signer, utils } from "ethers";
import type { Provider } from "@ethersproject/providers";
import type { IGroup, IGroupInterface } from "../../../contracts/group/IGroup";

const _abi = [
  {
    inputs: [
      {
        internalType: "uint256",
        name: "groupId",
        type: "uint256",
      },
      {
        internalType: "uint256",
        name: "identityCommitment",
        type: "uint256",
      },
    ],
    name: "addMember",
    outputs: [],
    stateMutability: "nonpayable",
    type: "function",
  },
  {
    inputs: [
      {
        internalType: "uint256",
        name: "groupId",
        type: "uint256",
      },
      {
        internalType: "uint256",
        name: "merkleTreeDepth",
        type: "uint256",
      },
      {
        internalType: "address",
        name: "admin",
        type: "address",
      },
    ],
    name: "createGroup",
    outputs: [],
    stateMutability: "nonpayable",
    type: "function",
  },
  {
    inputs: [
      {
        internalType: "uint256",
        name: "groupId",
        type: "uint256",
      },
      {
        internalType: "uint256",
        name: "identityCommitment",
        type: "uint256",
      },
      {
        internalType: "uint256[]",
        name: "proofSiblings",
        type: "uint256[]",
      },
      {
        internalType: "uint8[]",
        name: "proofPathIndices",
        type: "uint8[]",
      },
    ],
    name: "removeMember",
    outputs: [],
    stateMutability: "nonpayable",
    type: "function",
  },
  {
    inputs: [
      {
        internalType: "uint256",
        name: "groupId",
        type: "uint256",
      },
      {
        internalType: "address",
        name: "newAdmin",
        type: "address",
      },
    ],
    name: "updateGroupAdmin",
    outputs: [],
    stateMutability: "nonpayable",
    type: "function",
  },
  {
    inputs: [
      {
        internalType: "uint256",
        name: "groupId",
        type: "uint256",
      },
      {
        internalType: "uint256",
        name: "identityCommitment",
        type: "uint256",
      },
      {
        internalType: "uint256",
        name: "newIdentityCommitment",
        type: "uint256",
      },
      {
        internalType: "uint256[]",
        name: "proofSiblings",
        type: "uint256[]",
      },
      {
        internalType: "uint8[]",
        name: "proofPathIndices",
        type: "uint8[]",
      },
    ],
    name: "updateMember",
    outputs: [],
    stateMutability: "nonpayable",
    type: "function",
  },
  {
    inputs: [
      {
        internalType: "uint256",
        name: "rc",
        type: "uint256",
      },
      {
        internalType: "uint256",
        name: "groupId",
        type: "uint256",
      },
      {
        internalType: "uint256[8]",
        name: "proof",
        type: "uint256[8]",
      },
    ],
    name: "verifyProof",
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

export class IGroup__factory {
  static readonly abi = _abi;
  static createInterface(): IGroupInterface {
    return new utils.Interface(_abi) as IGroupInterface;
  }
  static connect(address: string, signerOrProvider: Signer | Provider): IGroup {
    return new Contract(address, _abi, signerOrProvider) as IGroup;
  }
}