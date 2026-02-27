import { createServer } from "http";
import { Hex, keccak256, hexToBytes, bytesToHex } from "viem";
import { secp256k1 } from "@noble/secp256k1";

interface DecisionRequest {
  proposalHash: string;
  proposer: string;
}

const PORT = Number(process.env.PORT || 8787);
const SIGNER_KEYS = (process.env.SIGNER_KEYS || "").split(",").map((k) => k.trim()).filter((k) => k.length > 0);

if (SIGNER_KEYS.length === 0) {
  console.error("SIGNER_KEYS required (comma-separated hex privkeys)");
  process.exit(1);
}

function deriveAddress(priv: string): string {
  const pub = secp256k1.getPublicKey(priv, false).slice(1); // uncompressed no prefix byte
  const hash = keccak256(pub as Uint8Array);
  return "0x" + hash.slice(-40);
}

const signerPrivKeys = SIGNER_KEYS.map((k) => (k.startsWith("0x") ? k.slice(2) : k));
const signerAddresses = signerPrivKeys.map(deriveAddress);
console.log("LLM signer service loaded signers:", signerAddresses);

function signDigest(privHex: string, digest: Hex): Hex {
  const digestBytes = hexToBytes(digest);
  const sig = secp256k1.sign(digestBytes, privHex, { der: false, recovered: true });
  const [sigBytes, recId] = sig;
  const r = sigBytes.slice(0, 32);
  const s = sigBytes.slice(32, 64);
  const v = recId + 27;
  return bytesToHex(new Uint8Array([...r, ...s, v]));
}

function handleDecision(req: DecisionRequest) {
  const proposalHash = req.proposalHash as Hex;
  const proposer = req.proposer as Hex;
  // Demo decision = keccak(proposalHash || proposer)
  const decision = keccak256(proposalHash + proposer.slice(2)) as Hex;
  const inputHash = keccak256(`0x${proposalHash.slice(2)}${decision.slice(2)}${proposer.slice(2)}` as Hex);

  const signatures = signerPrivKeys.map((k) => signDigest(k, inputHash)).join("");
  return { decision, signatures: (`0x${signatures}`) as Hex };
}

createServer(async (req, res) => {
  if (req.method !== "POST") {
    res.writeHead(405); res.end(); return;
  }
  let body = "";
  req.on("data", (chunk) => { body += chunk; });
  req.on("end", () => {
    try {
      const parsed = JSON.parse(body) as DecisionRequest;
      if (!parsed.proposalHash || !parsed.proposer) throw new Error("missing fields");
      const result = handleDecision(parsed);
      res.writeHead(200, { "content-type": "application/json" });
      res.end(JSON.stringify({ decision: result.decision, signatures: result.signatures, signers: signerAddresses }));
    } catch (e: any) {
      res.writeHead(400, { "content-type": "text/plain" });
      res.end(e.message || "bad request");
    }
  });
}).listen(PORT, () => {
  console.log(`LLM signer service listening on ${PORT}`);
});
