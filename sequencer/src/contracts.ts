import { createWalletClient, createPublicClient, http, parseAbi, Hex } from "viem";
import { privateKeyToAccount } from "viem/accounts";

const consensusAbi = parseAbi([
  "function submitProposal(bytes32 proposalHash) payable returns (uint256 id)",
  "function finalizeProposal(uint256 id, bytes32 decision, bytes proof)",
  "function proposals(uint256 id) view returns (bytes32 proposalHash, address proposer, uint256 stake, bool finalized, bytes32 decision)"
]);

const daSinkAbi = parseAbi([
  "function publishData(bytes data) returns (bytes32 batchHash)",
  "event DataPublished(bytes32 indexed batchHash, bytes data)"
]);

export function makeClients(rpcUrl: string, privateKey: Hex) {
  const account = privateKeyToAccount(privateKey);
  const transport = http(rpcUrl);
  const publicClient = createPublicClient({ chain: undefined, transport });
  const walletClient = createWalletClient({ chain: undefined, transport, account });
  return { publicClient, walletClient, account };
}

export const consensusInterface = consensusAbi;
export const daSinkInterface = daSinkAbi;
