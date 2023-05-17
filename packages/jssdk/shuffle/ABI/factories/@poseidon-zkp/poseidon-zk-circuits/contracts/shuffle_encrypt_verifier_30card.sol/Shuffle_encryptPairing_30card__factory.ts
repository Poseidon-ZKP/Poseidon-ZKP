/* Autogenerated file. Do not edit manually. */
/* tslint:disable */
/* eslint-disable */
import { Signer, utils, Contract, ContractFactory, Overrides } from "ethers";
import type { Provider, TransactionRequest } from "@ethersproject/providers";
import type { PromiseOrValue } from "../../../../../common";
import type {
  Shuffle_encryptPairing_30card,
  Shuffle_encryptPairing_30cardInterface,
} from "../../../../../@poseidon-zkp/poseidon-zk-circuits/contracts/shuffle_encrypt_verifier_30card.sol/Shuffle_encryptPairing_30card";

const _abi = [
  {
    inputs: [],
    name: "InvalidProof",
    type: "error",
  },
] as const;

const _bytecode =
  "0x60566050600b82828239805160001a6073146043577f4e487b7100000000000000000000000000000000000000000000000000000000600052600060045260246000fd5b30600052607381538281f3fe73000000000000000000000000000000000000000030146080604052600080fdfea2646970667358221220145b2c8efc4191b67870b946d8ef3b17014778af76f5509750fc5516e422319264736f6c63430008040033";

type Shuffle_encryptPairing_30cardConstructorParams =
  | [signer?: Signer]
  | ConstructorParameters<typeof ContractFactory>;

const isSuperArgs = (
  xs: Shuffle_encryptPairing_30cardConstructorParams
): xs is ConstructorParameters<typeof ContractFactory> => xs.length > 1;

export class Shuffle_encryptPairing_30card__factory extends ContractFactory {
  constructor(...args: Shuffle_encryptPairing_30cardConstructorParams) {
    if (isSuperArgs(args)) {
      super(...args);
    } else {
      super(_abi, _bytecode, args[0]);
    }
  }

  override deploy(
    overrides?: Overrides & { from?: PromiseOrValue<string> }
  ): Promise<Shuffle_encryptPairing_30card> {
    return super.deploy(
      overrides || {}
    ) as Promise<Shuffle_encryptPairing_30card>;
  }
  override getDeployTransaction(
    overrides?: Overrides & { from?: PromiseOrValue<string> }
  ): TransactionRequest {
    return super.getDeployTransaction(overrides || {});
  }
  override attach(address: string): Shuffle_encryptPairing_30card {
    return super.attach(address) as Shuffle_encryptPairing_30card;
  }
  override connect(signer: Signer): Shuffle_encryptPairing_30card__factory {
    return super.connect(signer) as Shuffle_encryptPairing_30card__factory;
  }

  static readonly bytecode = _bytecode;
  static readonly abi = _abi;
  static createInterface(): Shuffle_encryptPairing_30cardInterface {
    return new utils.Interface(_abi) as Shuffle_encryptPairing_30cardInterface;
  }
  static connect(
    address: string,
    signerOrProvider: Signer | Provider
  ): Shuffle_encryptPairing_30card {
    return new Contract(
      address,
      _abi,
      signerOrProvider
    ) as Shuffle_encryptPairing_30card;
  }
}
