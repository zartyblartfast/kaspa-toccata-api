# Handoff

## Current milestone

Stage 4 capability spike in progress; npm/WASM read-only path validated.

- Stage 3: runtime/API presentation decision matrix is drafted in `docs/architecture-decision-api-runtime.md`.
- Stage 4: npm/Toccata WASM source, build, import, covenant-construction, and live TN10 read-only wRPC checks pass.

## What works now

- Repository scaffold exists.
- Handoff docs exist.
- Decision matrix exists.
- Spike directories exist.
- Guardrail script exists at `scripts/spike-api-runtime-decision.sh`.
- Official `rusty-kaspa` `toccata` branch Node WASM package builds.
- Node can import built Toccata WASM package.
- Node can construct covenant primitives.
- Node can connect to live TN10 wRPC and fetch server/blockDAG info.

No API server has been implemented yet.

## Last verified commands

```bash
scripts/spike-api-runtime-decision.sh
```

Latest output summary includes the first npm/WASM build/import test:

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
```

Additional verified command:

```bash
spikes/npm-toccata-wasm-capability/build-and-check-wasm.sh
```

Output summary:

```text
NPM_TOCCATA_WASM_BUILD_PREREQ_WASM_TARGET=PASS
NPM_TOCCATA_WASM_BUILD_PREREQ_CLANG=PASS
NPM_TOCCATA_WASM_BUILD=PASS
NPM_TOCCATA_WASM_IMPORT=PASS
NPM_TOCCATA_WASM_EXPORT_Hash=PASS
NPM_TOCCATA_WASM_EXPORT_CovenantBinding=PASS
NPM_TOCCATA_WASM_EXPORT_GenesisCovenantGroup=PASS
NPM_TOCCATA_WASM_EXPORT_TransactionOutput=PASS
NPM_TOCCATA_WASM_EXPORT_Transaction=PASS
NPM_TOCCATA_WASM_EXPORT_TransactionOutpoint=PASS
NPM_TOCCATA_WASM_EXPORT_covenantId=PASS
NPM_TOCCATA_WASM_EXPORT_payToScriptHashScript=PASS
NPM_TOCCATA_WASM_EXPORT_RpcClient=PASS
NPM_TOCCATA_WASM_EXPORT_Resolver=PASS
NPM_TOCCATA_WASM_EXPORT_Encoding=PASS
NPM_COVENANT_BINDING_CONSTRUCT=PASS
NPM_GENESIS_COVENANT_GROUP_CONSTRUCT=PASS
NPM_TRANSACTION_OUTPUT_COVENANT_CONSTRUCT=PASS
NPM_BUILT_PACKAGE_VERDICT=VALIDATED
```

Additional verified live-network command:

```bash
KASPA_WRPC_TIMEOUT_MS=60000 node spikes/npm-toccata-wasm-capability/check-tn10-wrpc.js
```

Output summary:

```text
NPM_TN10_WRPC_IMPORTS=PASS
NPM_TN10_WRPC_REQUIRED_EXPORTS=PASS
NPM_TN10_WRPC_RESOLVER_CONSTRUCT=PASS
NPM_TN10_WRPC_RESOLVER_GET_URL=PASS # wss://vector-10.kaspa.green/kaspa/testnet-10/wrpc/borsh
NPM_TN10_WRPC_CLIENT_CONSTRUCT=PASS
NPM_TN10_WRPC_CONNECT=PASS # wss://muon-10.kaspa.blue/kaspa/testnet-10/wrpc/borsh
NPM_TN10_WRPC_GET_SERVER_INFO=PASS # networkId=testnet-10 serverVersion=2.0.1 isSynced=true hasUtxoIndex=true
NPM_TN10_WRPC_GET_BLOCKDAG_INFO=PASS # live blockDAG data returned
NPM_TN10_WRPC_DISCONNECT=PASS
NPM_TN10_WRPC_VERDICT=VALIDATED
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

- Whether official `rusty-kaspa` `toccata` WASM can be wrapped/published cleanly from our own npm package.
- Whether JS/TS can build/sign/broadcast the Toccata transactions needed for later write/covenant milestones.
- Whether the API implementation should now proceed TypeScript/npm-first for Milestone 1/read-only TN10, or first compare with Rust.
- Exact dependency strategy for official `rusty-kaspa` `toccata` branch.

## Next 3 actions

1. Choose next path: package/wrap npm spike, JS/TS write capability spike, Rust comparison spike, or start Milestone 1 API shell using npm/WASM read-only TN10.
2. If handing over to `/new`, start by loading `kaspa-toccata-api-workflow`, reading this file plus `docs/API_STATUS.md`, and running `scripts/spike-api-runtime-decision.sh`.
3. If continuing implementation now, the lowest-risk API step is Milestone 1: `GET /v1/health`, `GET /v1/capabilities`, `GET /v1/network/status`, and `scripts/api-smoke.sh`.

## Do not regress

- API before app.
- No static app proof/result fixtures.
- Curl/scripts prove API milestones.
- Roulette app consumes API/client only.
- Do not copy old `kaspa-fair-foundation` static JSON workflow.
