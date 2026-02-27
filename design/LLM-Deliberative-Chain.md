# LLM-Powered Deliberative Consensus (EVM-focused)

Goal: low-fee, high-throughput chain where block decisions are guided by an LLM deliberation step and enforced on-chain via verifiable attestations.

## Objectives
- High throughput: rollup-style batching, calldata blobs (EIP-4844), and gas-optimized precompiles.
- Low fees: compressed calldata, batched state diffs, pre-priced op tables, and fee rebates for common ops.
- Fast confirmation: soft-finality < 2s via sequencer attest; economic finality via challenge/validity proof.
- LLM deliberation: validator set queries an LLM; output is committed on-chain only with a verifiable proof.

## Architecture
- **Execution layer**: EVM-compatible, L2 rollup over Ethereum (or standalone with DA bridge). Supports EIP-4844 blobs for cheap data availability.
- **Consensus layer**: Hybrid
  - Proposer builds block, emits proposal hash.
  - LLM deliberation network evaluates proposal (policy, safety, MEV filters) and produces `decision` and `trace`.
  - Proof system (zk-SNARK or signature quorum) certifies that the decision came from an authorized LLM flow.
  - On-chain contract accepts blocks only if accompanied by valid proof.
- **LLM attestation**
  - Input: proposal hash, policies, previous state commitments.
  - Output: decision hash + optional guidance metadata.
  - Proof: zk circuit or threshold-signature oracle; the sample contract models this via `IProofVerifier`.
- **Data availability**: blobs for tx data; fallback to calldata if blobs unavailable.
- **Sequencer**: single or rotating; bonded; slashable on invalid proposal or withheld data.

## Flow (happy path)
1. Sequencer assembles tx batch; publishes data to blobs.
2. Sequencer posts block proposal hash on L1 (or L2 contract).
3. LLM network ingests proposal; runs deliberation; emits `decision`, `trace`, and `proof`.
4. `LLMDeliberativeConsensus.finalizeProposal` is called with decision + proof.
5. Contract verifies proof and marks block finalized; emits event for settlement.

## Safety and liveness
- Safety: block accepted only with valid proof; invalid proof triggers slash. Optional fraud proof window for optimistic mode.
- Liveness: timeout allows fallback to human/validator quorum if LLM network stalls; staking keeps proposers online.

## Gas and scalability levers
- Batch size tuning, calldata compression, blob usage.
- Precompile for signature aggregation (e.g., BLS) to keep proofs small.
- Use Merkle multiproofs for state diff verification.
- Consider EIP-3074/7702 for sponsored tx to reduce user gas exposure.

## Open engineering items
- Define the proof system: zk circuit for LLM execution trace, or threshold signatures from an attested LLM committee.
- Design the LLM policy layer (prompt templates, guardrails) and trace commitments.
- Build a relayer/oracle that feeds decisions on-chain with minimal trust (TEE, zk, or multi-sig as stopgap).
- Economics: staking amounts, slashing conditions, rewards for fast/valid attestations.

## Minimal on-chain contract shape
- `submitProposal(bytes32 proposalHash)` → records proposer and stake.
- `finalizeProposal(uint256 id, bytes32 decision, bytes proof)` → verifies via pluggable `IProofVerifier`.
- `challenge(uint256 id, bytes evidence)` → optional fraud window.

This document is a starting point; choose a proof mechanism next to move from stub to runnable chain.
