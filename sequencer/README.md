# Sequencer/Batcher Skeleton

Goal: off-chain service that builds tx batches, posts data commitments, and finalizes proposals via the on-chain consensus + quorum verifier.

## Responsibilities
- Accept transactions (stubbed as a queue) and build batches.
- Compute batch/proposal hashes and publish data availability (stubbed here).
- Submit proposals to `LLMDeliberativeConsensus` with staking.
- Collect quorum signatures over `inputHash` (LLM decision) and call `finalizeProposal`.
- Basic retry/error logging hooks.

## Structure
- `src/config.ts` — environment and address config.
- `src/contracts.ts` — minimal ABIs and client creation.
- `src/sequencer.ts` — main loop with stubbed DA publish + LLM attestation hook.

## Running (skeleton)
1) Install deps: `npm install`
2) Set env vars (see config.ts): `RPC_URL`, `PRIVATE_KEY`, `CONSENSUS_ADDRESS`, `DA_SINK_ADDRESS`, `LLM_ENDPOINT`, `LLM_API_KEY` (optional), `STAKE_WEI`, `BATCH_INTERVAL_MS` (optional).
3) Run: `npm start`

## Next steps
- Replace stubbed DA publish with real blob/calldata posting.
- Implement a real mempool/ingress API (REST/websocket) instead of the in-memory queue.
- Hook to real LLM attestation service that returns a decision + signatures.
- Add persistence for batch metadata and retries.
- Add metrics and structured logging.
