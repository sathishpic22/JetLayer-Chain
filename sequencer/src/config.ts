export interface Config {
  rpcUrl: string;
  privateKey: `0x${string}`;
  consensusAddress: `0x${string}`;
  daSinkAddress: `0x${string}`;
  llmEndpoint: string;
  llmApiKey?: string;
  stakeWei: bigint;
  batchIntervalMs: number;
}

export function loadConfig(): Config {
  const rpcUrl = process.env.RPC_URL || "";
  const privateKey = process.env.PRIVATE_KEY as `0x${string}`;
  const consensusAddress = process.env.CONSENSUS_ADDRESS as `0x${string}`;
  const daSinkAddress = process.env.DA_SINK_ADDRESS as `0x${string}`;
  const llmEndpoint = process.env.LLM_ENDPOINT || "";
  const llmApiKey = process.env.LLM_API_KEY;
  const stakeWei = BigInt(process.env.STAKE_WEI || "0");
  const batchIntervalMs = Number(process.env.BATCH_INTERVAL_MS || "5000");

  if (!rpcUrl) throw new Error("RPC_URL required");
  if (!privateKey) throw new Error("PRIVATE_KEY required");
  if (!consensusAddress) throw new Error("CONSENSUS_ADDRESS required");
  if (!daSinkAddress) throw new Error("DA_SINK_ADDRESS required");
  if (!llmEndpoint) throw new Error("LLM_ENDPOINT required");
  if (stakeWei === 0n) throw new Error("STAKE_WEI required");

  return { rpcUrl, privateKey, consensusAddress, daSinkAddress, llmEndpoint, llmApiKey, stakeWei, batchIntervalMs };
}
