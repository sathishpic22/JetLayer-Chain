# Node Stack Blueprint

This document sketches the minimal components for a JetLayer node: execution client, consensus/settlement contracts, mempool, RPC, and state sync/snapshots. It is written for an EVM rollup with the LLM-gated consensus contract.

## Components
- Execution client
  - EVM interpreter and state transition function.
  - Applies batches from the sequencer; exposes JSON-RPC (eth_*), tracing, and websockets.
- Consensus/settlement contracts (on L1)
  - Data availability posting (blobs/calldata commitments).
  - LLMDeliberativeConsensus for proposal/decision gating.
  - Bridge/rollup contract for state root updates and withdrawals.
  - Optional fraud-proof or zk-proof verifier.
- Sequencer + mempool
  - Ingests user tx via RPC, orders them, builds batches, posts DA commitments, and submits proposal hashes to the consensus contract.
  - Enforces fee rules and spam limits; supports priority fee markets.
- RPC layer
  - Public/full RPC (read-only) and private/tx-submission RPC.
  - Websocket subscriptions for new heads, logs, and batch status.
- State sync / snapshots
  - Periodic state snapshots (e.g., every N blocks) stored in object storage.
  - State sync protocol to fast-sync new nodes using recent snapshots + batch replay.
  - Light client mode that verifies state roots via settlement contract events.

## Minimal flows
- Tx ingress → mempool → sequencer batches → DA post → proposalHash to L1 → LLM attestation + quorum signatures → finalizeProposal → state root update.
- State sync: download latest snapshot, verify its root against the last finalized root from L1, then replay subsequent batches.

## Engineering checklist
- Execution client: fork a lightweight EVM (e.g., reth, geth fork, or custom) with batch import and rollup-specific RPC methods.
- Contracts: finalize bridge/rollup contract, DA commitment scheme, and root update path; integrate LLMDeliberativeConsensus.
- Mempool: implement fee market, DoS limits, and MEV policy; expose txpool RPC.
- Sequencer: build batcher, blob/calldata publisher, and proposer to call finalizeProposal with attested decisions.
- RPC/infra: gateway with rate limits, metrics, and logs; separate submission and archive endpoints.
- Sync: implement snapshot creation and distribution, light client verification, and batch replay tooling.

## Next steps
- Pick an execution client base and define batch format.
- Draft rollup/bridge contract that anchors state roots and DA commitments.
- Specify snapshot format and light client verification rules.
- Implement sequencer service with LLM attestor integration.
