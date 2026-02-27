# Sequencer Hardening Plan

- Ingress: add HTTP/websocket submission API; validate tx format, fee caps, size limits; rate limit per IP/key.
- Persistence: durable queue (SQLite/Badger/RocksDB); write-ahead log for batches; resume on restart.
- Retries: exponential backoff on submitProposal/finalizeProposal; reorg handling by reconciling latest finalized id/root.
- Metrics/logging: structured logs, Prometheus counters (ingress, batches, finalize success/fail, latency), alerting hooks.
- Security: signer key isolation, API auth for submit, payload size caps, sanity checks on decision/signature payloads.
- State linkage: store DA tx hash, batchHash, proposalId, decision, signatures for later verification; expose status RPC.
- Testing: integration tests against local anvil; simulate invalid signatures, DA publish failures, and replay of proposal ids.
