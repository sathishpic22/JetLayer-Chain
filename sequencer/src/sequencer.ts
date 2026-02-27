import { Hex, encodeAbiParameters, keccak256, decodeEventLog } from "viem";
import { loadConfig } from "./config.js";
import { makeClients, consensusInterface, daSinkInterface } from "./contracts.js";

// Stub transaction type; replace with real tx objects.
interface Tx {
  from: string;
  to: string;
  data: Hex;
}

// In-memory queue for demo purposes.
const txQueue: Tx[] = [];

function enqueueDummyTx() {
  txQueue.push({ from: "0x0000000000000000000000000000000000000001", to: "0x0000000000000000000000000000000000000002", data: "0x" });
}

function drainTxQueue(): Tx[] {
  const txs = [...txQueue];
  txQueue.length = 0;
  return txs;
}

function buildBatch(txs: Tx[]): { batchData: Hex; batchHash: Hex } {
  const encoded = encodeAbiParameters(
    [{ name: "txs", type: "tuple(address from,address to,bytes data)[]" }],
    [txs.map((t) => ({ from: t.from, to: t.to, data: t.data }))]
  );
  const batchHash = keccak256(encoded);
  return { batchData: encoded, batchHash };
}

async function publishDA(batchData: Hex, cfg: ReturnType<typeof loadConfig>, walletClient: any, publicClient: any, account: any): Promise<{ txHash: Hex; batchHash: Hex }> {
  const { request } = await publicClient.simulateContract({
    address: cfg.daSinkAddress,
    abi: daSinkInterface,
    functionName: "publishData",
    args: [batchData],
    account
  });
  const txHash = await walletClient.writeContract(request);
  const receipt = await publicClient.waitForTransactionReceipt({ hash: txHash });
  const log = receipt.logs.find((log: any) => {
    try {
      decodeEventLog({ abi: daSinkInterface, data: log.data, topics: log.topics, eventName: "DataPublished" });
      return true;
    } catch (_) { return false; }
  });
  if (!log) throw new Error("No DataPublished log");
  const decoded = decodeEventLog({ abi: daSinkInterface, data: log.data, topics: log.topics, eventName: "DataPublished" });
  return { txHash, batchHash: decoded.args["batchHash"] as Hex };
}

async function getLLMDecision(cfg: ReturnType<typeof loadConfig>, proposalHash: Hex, proposer: Hex): Promise<{ decision: Hex; signatures: Hex }> {
  const body = {
    proposalHash,
    proposer,
  };
  const headers: Record<string, string> = { "content-type": "application/json" };
  if (cfg.llmApiKey) headers["authorization"] = `Bearer ${cfg.llmApiKey}`;

  const res = await fetch(cfg.llmEndpoint, {
    method: "POST",
    headers,
    body: JSON.stringify(body),
  });
  if (!res.ok) {
    const text = await res.text();
    throw new Error(`LLM endpoint error ${res.status}: ${text}`);
  }
  const json = (await res.json()) as { decision: string; signatures: string };
  if (!json.decision || !json.signatures) throw new Error("LLM response missing fields");
  return { decision: json.decision as Hex, signatures: json.signatures as Hex };
}

async function main() {
  const cfg = loadConfig();
  const { publicClient, walletClient, account } = makeClients(cfg.rpcUrl, cfg.privateKey);

  // demo ingress
  enqueueDummyTx();

  setInterval(async () => {
    if (txQueue.length === 0) return;
    const txs = drainTxQueue();

    // Build batch from queued txs
    const { batchData } = buildBatch(txs);

    // Publish DA via DA sink contract
    const { txHash: daTxHash, batchHash: proposalHash } = await publishDA(batchData, cfg, walletClient, publicClient, account);
    console.log("DA publish tx", daTxHash);

    // Submit proposal with stake
    const { request } = await publicClient.simulateContract({
      address: cfg.consensusAddress,
      abi: consensusInterface,
      functionName: "submitProposal",
      args: [proposalHash],
      account,
      value: cfg.stakeWei
    });
    const submitHash = await walletClient.writeContract(request);
    console.log("submitted proposal tx", submitHash);
    const submitReceipt = await publicClient.waitForTransactionReceipt({ hash: submitHash });

    // Extract proposal id from event
    const submittedLog = submitReceipt.logs.find((log) => {
      try {
        decodeEventLog({ abi: consensusInterface, data: log.data, topics: log.topics, eventName: "ProposalSubmitted" });
        return true;
      } catch (_) {
        return false;
      }
    });
    if (!submittedLog) throw new Error("No ProposalSubmitted log found");
    const decoded = decodeEventLog({ abi: consensusInterface, data: submittedLog.data, topics: submittedLog.topics, eventName: "ProposalSubmitted" });
    const proposalId = decoded.args["id"] as bigint;

    // Wait for LLM decision + signatures
    const { decision, signatures } = await getLLMDecision(cfg, proposalHash, account.address as Hex);

    // Finalize
    const { request: finReq } = await publicClient.simulateContract({
      address: cfg.consensusAddress,
      abi: consensusInterface,
      functionName: "finalizeProposal",
      args: [proposalId, decision, signatures],
      account
    });
    const finHash = await walletClient.writeContract(finReq);
    console.log("finalized proposal tx", finHash);
  }, cfg.batchIntervalMs);
}

main().catch((err) => {
  console.error(err);
  process.exit(1);
});
