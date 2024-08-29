import { Interface } from "ethers";
import { ConfidentialTransactionResponse } from "ethers-suave";
import { HardhatRuntimeEnvironment as HRE } from "hardhat/types";

import { createDecipheriv } from "crypto";

export async function getContract(
  hre: HRE,
  contractName: string,
  contractAddress?: string | undefined,
) {
  if (!contractAddress) {
    contractAddress = await hre.deployments.get(contractName).then((c) => c.address);
  }
  return hre.ethers.getContractAt(contractName, contractAddress);
}

export type Result<T> = [T, null] | [null, string];

export async function prettyPromise(
  promise: Promise<ConfidentialTransactionResponse>,
  contract: Interface,
  label_?: string,
): Promise<Result<Promise<string>>> {
  const label: string = label_ ? `'${label_}'` : "";
  return promise
    .then(async (r) => {
      const success = handleNewSubmission(r, contract, label);
      return [success, null] as Result<Promise<string>>;
    })
    .catch((err) => {
      const error = handleSubmissionErr(contract, err, label);
      return [null, error] as Result<Promise<string>>;
    });
}

async function handleNewSubmission(
  response: ConfidentialTransactionResponse,
  iface: Interface,
  label: string,
): Promise<string> {
  const receipt = await response.wait();
  let output = `\t${label} Tx ${response.hash} confirmed:`;
  if (receipt.status === 0) {
    output += "\t❌ Tx execution failed";
    output += `\n\t${JSON.stringify(receipt)}`;
  } else {
    const tab = (n) => "\t  ".repeat(n);
    output += "\n\t✅ Tx execution succeeded\n";
    receipt.logs.forEach((log) => {
      try {
        const parsedLog = iface.parseLog({
          data: log.data,
          topics: log.topics as string[],
        });
        output += `${tab(1)}${parsedLog.name}\n`;
        parsedLog.fragment.inputs.forEach((input, i) => {
          output += `${tab(2)}${input.name}: ${parsedLog.args[i]}\n`;
        });
      } catch {
        output += `${tab(1)}${log.topics[0]}\n`;
        output += `${tab(2)}${log.data}\n`;
      }
    });
  }

  return output + "\n";
}

function handleSubmissionErr(iface: Interface, err: any, label: string): string {
  if (err.body) {
    const rpcErr = JSON.parse(err.body)?.error?.message;
    if (rpcErr && rpcErr.startsWith("execution reverted: ")) {
      const revertMsg = rpcErr.slice("execution reverted: ".length);
      if (revertMsg != "0x") {
        try {
          const err = iface.parseError(revertMsg);
          if (err.signature == "PeekerReverted(address,bytes)") {
            const errStr = Buffer.from(err.args[1].slice(2), "hex").toString();
            return `\t❗️ ${label} PeekerReverted(${err.args[0]}, '${errStr})'`;
          }
          return `\t❗️ ${label} ${err.signature}(${err.args.map((a) => `'${a}'`).join(",")})`;
        } catch {
          return `\t❗️ ${label} ${rpcErr}`;
        }
      }
    }
  }
  return `\t❗️ ${label} ` + err;
}

export async function handleResult<T>(result: Result<Promise<T>>): Promise<boolean> {
  const [s, e] = result;
  if (s) {
    console.log("✅");
    await s.then(console.log);
    return true;
  } else {
    console.log("❌");
    console.log(e);
    return false;
  }
}

export function aesDecryptStr(key: string, ciphertext: string): string {
  const keyBuffer = Buffer.from(key.replace(/^0x/, ""), "hex");
  const ciphertextBuffer = Buffer.from(ciphertext.replace(/^0x/, ""), "hex");
  const plaintextBuffer = aesDecrypt(keyBuffer, ciphertextBuffer);
  return plaintextBuffer.toString("utf8");
}

export function aesDecrypt(key: Buffer, ciphertext: Buffer): Buffer {
  try {
    const keyBytes = Buffer.alloc(32);
    key.copy(keyBytes, 0, 0, Math.min(key.length, 32));

    const nonceSize = 12; // GCM nonce size is typically 12 bytes
    const tagSize = 16; // GCM authentication tag is 16 bytes
    const minSize = nonceSize + tagSize;

    if (ciphertext.length < minSize) {
      throw new Error(
        `Ciphertext too short. Expected at least ${minSize} bytes, but got ${ciphertext.length} bytes.`,
      );
    }

    const nonce = ciphertext.subarray(0, nonceSize);
    const tag = ciphertext.subarray(ciphertext.length - tagSize);
    const encryptedData = ciphertext.subarray(nonceSize, ciphertext.length - tagSize);

    const decipher = createDecipheriv("aes-256-gcm", keyBytes, nonce);
    decipher.setAuthTag(tag);

    const plaintextBuffer = Buffer.concat([decipher.update(encryptedData), decipher.final()]);

    return plaintextBuffer;
  } catch (error) {
    console.error("Decryption error:", error);
    throw error;
  }
}
