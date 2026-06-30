# Handoff

## Current milestone

Stage 3 / Stage 4 transition.

- Stage 3: runtime/API presentation decision matrix is drafted in `docs/architecture-decision-api-runtime.md`.
- Stage 4: spike scaffold exists; actual capability code still needs implementation.

## What works now

- Repository scaffold exists.
- Handoff docs exist.
- Decision matrix exists.
- Spike directories exist.
- Guardrail script exists at `scripts/spike-api-runtime-decision.sh`.

No API server has been implemented yet.

## Last verified commands

```bash
scripts/spike-api-runtime-decision.sh
```

Latest output summary:

```text
ARCH_DECISION_DOC=PASS
NPM_SPIKE_DIR=PASS
RUST_SPIKE_DIR=PASS
NO_STATIC_APP_FIXTURES=PASS
OFFICIAL_RUSTY_KASPA_TOCCATA_CLONE=PASS
NPM_TOCCATA_WASM_SOURCE_COVENANT_BINDING=PASS
NPM_TOCCATA_WASM_SOURCE_GENESIS_COVENANT_GROUP=PASS
NPM_TOCCATA_WASM_SOURCE_COVENANT_ID_HASH=PASS
NPM_TOCCATA_WASM_SOURCE_TRANSACTION_OUTPUT_COVENANT=PASS
NPM_TOCCATA_WASM_SOURCE_REEXPORTS_CONSENSUS=PASS
NPM_TOCCATA_WASM_SOURCE_TN10_RPC_EXAMPLE=PASS
NPM_TOCCATA_WASM_BUILD=UNKNOWN
NPM_TN10_WRPC_CONNECT=UNKNOWN
NPM_TRANSACTION_BUILD_SIGN_BROADCAST_CAPABILITY=UNKNOWN
NPM_SPIKE_VERDICT=PARTIAL
RUST_TOCCATA_TX_VERSION=UNKNOWN
RUST_COVENANT_OUTPUT=UNKNOWN
RUST_TN10_WRPC_CONNECT=UNKNOWN
RECOMMENDED_RUNTIME=undecided
```

## Important files

```text
docs/architecture-decision-api-runtime.md
docs/DECISIONS.md
docs/API_STATUS.md
docs/NEXT_STEPS.md
scripts/spike-api-runtime-decision.sh
spikes/npm-toccata-wasm-capability/README.md
spikes/rust-toccata-capability/README.md
```

## Current blockers / unknowns

- Whether official `rusty-kaspa` `toccata` WASM can be built/consumed cleanly from a custom npm package.
- Whether the API implementation should be TypeScript/npm-first, Rust service + npm wrapper/client, or hybrid.
- Whether public TN10 wRPC/REST endpoints expose enough fields for all early read-path needs.
- Exact dependency strategy for official `rusty-kaspa` `toccata` branch.

## Next 3 actions

1. Implement `spikes/npm-toccata-wasm-capability/` to prove TypeScript/WASM covenant primitives and TN10 connectivity.
2. Implement `spikes/rust-toccata-capability/` to prove Rust Toccata transaction/covenant primitives and TN10 connectivity.
3. Update `docs/architecture-decision-api-runtime.md` with PASS/FAIL outputs and choose the runtime for Milestone 1.

## Do not regress

- API before app.
- No static app proof/result fixtures.
- Curl/scripts prove API milestones.
- Roulette app consumes API/client only.
- Do not copy old `kaspa-fair-foundation` static JSON workflow.
