# LLM Signer Service (stub)

Purpose: generate a deterministic decision hash and quorum signatures over the consensus inputHash for testing `QuorumVerifier`.

- Endpoint: `POST /` with JSON `{ "proposalHash": "0x...", "proposer": "0x..." }`
- Response: `{ "decision": "0x...", "signatures": "0x...", "signers": ["0x..."] }`
- Decision: `keccak256(proposalHash || proposer)`
- Signatures: concatenated ECDSA signatures over `inputHash = keccak256(proposalHash, decision, proposer)` using the provided SIGNER_KEYS.

Run:
```
cd llm-service
npm install
SIGNER_KEYS=0xabc...,0xdef... PORT=8787 npm start
```

Wire to sequencer via `LLM_ENDPOINT=http://localhost:8787/` and optional `LLM_API_KEY` if you front it with auth.
