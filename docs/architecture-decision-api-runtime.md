# Architecture Decision: API Runtime and Presentation

Status: draft, pending spike evidence

## Context

This project is a reusable Kaspa TN10/Toccata feature layer for app-agnostic proof-of-fairness workflows. Roulette is a later proof-of-concept consumer.

The runtime must support:

- official Kaspa TN10/Toccata features;
- KIP-17 covenant scripting concepts;
- KIP-20 covenant IDs / lineage;
- TN10 read capability;
- later guarded TN10 write/sign/broadcast capability;
- script/curl verification before UI;
- npm-friendly developer adoption if possible.

Official source priority:

1. `kaspanet/kips` for KIP-17, KIP-20, KIP-21 semantics.
2. `kaspanet/rusty-kaspa` `toccata` branch for implementation APIs and WASM bindings.
3. `kaspanet/docs` for wRPC and node setup.
4. Old `kaspa-fair-foundation` only as historical reference.

## Options

### Option A — TypeScript/npm-first using official Toccata WASM

Shape:

```text
packages/toccata-core-ts
packages/toccata-client
services/toccata-api-ts
```

Potential advantages:

- Best npm developer experience.
- Can publish package(s) directly.
- Same language for API/client/roulette.
- Official `rusty-kaspa` `toccata` branch appears to contain WASM/TypeScript covenant bindings.

Risks:

- Toccata WASM build and package consumption must be proven.
- TN10 wRPC connectivity from Node must be proven.
- Transaction signing/broadcast/covenant support from JS/WASM must be proven.
- May inherit WASM packaging complexity.

Spike must prove:

```text
NPM_TOCCATA_WASM_BUILD
NPM_COVENANT_BINDING
NPM_GENESIS_COVENANT_GROUP
NPM_COVENANT_ID_HASH
NPM_TRANSACTION_OUTPUT_COVENANT
NPM_TN10_WRPC_CONNECT
NPM_TRANSACTION_BUILD_SIGN_BROADCAST_CAPABILITY
```

### Option B — Rust service using official Toccata branch + npm client/wrapper

Shape:

```text
crates/toccata-core
services/toccata-api
packages/toccata-client
optional packages/toccata-api-launcher
```

Potential advantages:

- Closest to rusty-kaspa implementation surface.
- Stronger fit for low-level transaction/covenant work.
- HTTP API hides implementation details from app developers.
- npm client still gives friendly app integration.

Risks:

- Rust dependency strategy for `toccata` branch must be clean.
- Publishing an easy `npx` launcher may require platform binaries or install scripts.
- More moving parts than a pure TypeScript package.

Spike must prove:

```text
RUST_TOCCATA_BRANCH_DEPENDENCY
RUST_TX_VERSION_TOCCATA
RUST_COVENANT_BINDING
RUST_GENESIS_COVENANT_GROUP
RUST_TRANSACTION_OUTPUT_COVENANT
RUST_TN10_WRPC_CONNECT
RUST_TRANSACTION_BUILD_SIGN_BROADCAST_CAPABILITY
```

### Option C — Hybrid npm package wrapping Rust binary

Shape:

```text
bin/toccata-api-rs
packages/toccata-api
packages/toccata-client
```

Potential advantages:

- App developers can use `npx` while core remains Rust.
- Matches common npm native-binary distribution patterns.
- Good later distribution story if Option B is selected.

Risks:

- Cross-platform binary packaging and releases add complexity.
- Not needed for Milestone 1 if local source build is acceptable.
- Could distract from proving API semantics.

Spike must prove later:

```text
NPM_BINARY_WRAPPER
PLATFORM_BINARY_SELECTION
NPX_SERVE_HEALTHCHECK
```

## Decision matrix

| Criterion | Option A: TS/npm + WASM | Option B: Rust API + npm client | Option C: npm wraps Rust binary |
|---|---:|---:|---:|
| npm developer experience | High | Medium/High | High |
| source-level Toccata WASM primitives | PASS | n/a | n/a |
| Toccata WASM Node build/import | PASS | n/a | n/a |
| Node live TN10 wRPC read | PASS | n/a | n/a |
| direct Toccata primitive access | Covenant primitives PASS; API live commit write/broadcast PASS; no offline/mock write path retained | Likely High | Likely High |
| TN10 wRPC from runtime | PASS for Node live status | Likely | Likely |
| covenant/KIP-20 support | Covenant primitives PASS, full workflow UNKNOWN | Likely | Likely |
| curl/API smoke tests | High | High | High |
| package publish complexity | Own wrapper tarball PASS; registry publish not tested | Medium | High |
| low-level correctness confidence | Promising, write path unknown | High if official branch works | High if official branch works |
| fastest Milestone 1 | Medium | Medium | Low/Medium |
| long-term app adoption | High | High | High |

## First spike result

The npm/Toccata WASM spike has now passed source, build, import, and basic covenant-construction checks:

```text
OFFICIAL_RUSTY_KASPA_TOCCATA_CLONE=PASS
NPM_TOCCATA_WASM_SOURCE_COVENANT_BINDING=PASS
NPM_TOCCATA_WASM_SOURCE_GENESIS_COVENANT_GROUP=PASS
NPM_TOCCATA_WASM_SOURCE_COVENANT_ID_HASH=PASS
NPM_TOCCATA_WASM_SOURCE_TRANSACTION_OUTPUT_COVENANT=PASS
NPM_TOCCATA_WASM_SOURCE_REEXPORTS_CONSENSUS=PASS
NPM_TOCCATA_WASM_SOURCE_TN10_RPC_EXAMPLE=PASS
NPM_TOCCATA_WASM_BUILD=PASS
NPM_TOCCATA_WASM_IMPORT=PASS
NPM_TOCCATA_WASM_EXPORT_CovenantBinding=PASS
NPM_TOCCATA_WASM_EXPORT_GenesisCovenantGroup=PASS
NPM_TOCCATA_WASM_EXPORT_TransactionOutput=PASS
NPM_TOCCATA_WASM_EXPORT_RpcClient=PASS
NPM_COVENANT_BINDING_CONSTRUCT=PASS
NPM_GENESIS_COVENANT_GROUP_CONSTRUCT=PASS
NPM_TRANSACTION_OUTPUT_COVENANT_CONSTRUCT=PASS
NPM_TN10_WRPC_IMPORTS=PASS
NPM_TN10_WRPC_REQUIRED_EXPORTS=PASS
NPM_TN10_WRPC_RESOLVER_CONSTRUCT=PASS
NPM_TN10_WRPC_RESOLVER_GET_URL=PASS
NPM_TN10_WRPC_CLIENT_CONSTRUCT=PASS
NPM_TN10_WRPC_CONNECT=PASS
NPM_TN10_WRPC_GET_SERVER_INFO=PASS
NPM_TN10_WRPC_GET_BLOCKDAG_INFO=PASS
NPM_TN10_WRPC_DISCONNECT=PASS
NPM_TN10_WRPC_VERDICT=VALIDATED
```

This makes Option A strongly plausible for Milestone 1 and live TN10 status work. A follow-up wrapper-package spike also proved that the built official WASM package can be vendored into a temporary `@kaspa-toccata/core` tarball, installed by a clean consumer, imported through our package boundary, and used to construct covenant primitives. It does **not** yet prove Option A is sufficient for the full API, because transaction build/sign/broadcast and real npm registry publishing remain untested.

## Current recommendation

Proceed with Milestone 1 API shell using the TypeScript/npm-first path for live TN10 status.

Reason: source/build/import/covenant-construction/live-TN10-read checks passed, and the own-package wrapper tarball/clean-consumer check passed. Keep runtime choice provisional for write/covenant-enforced milestones until JS/TS transaction build/sign/broadcast is tested.

Option C is likely a distribution strategy after a Rust-backed decision, not the first implementation strategy.

## Required spike output

`scripts/spike-api-runtime-decision.sh` should eventually print:

```text
OFFICIAL_KIPS_FOUND=PASS
RUSTY_KASPA_TOCCATA_BRANCH=PASS
NPM_TOCCATA_WASM_BUILD=PASS|FAIL|UNKNOWN
NPM_COVENANT_BINDING=PASS|FAIL|UNKNOWN
NPM_GENESIS_COVENANT_GROUP=PASS|FAIL|UNKNOWN
NPM_TN10_WRPC_CONNECT=PASS|FAIL|UNKNOWN
NPM_WRAPPER_PACKAGE_VERDICT=PASS|FAIL|UNKNOWN
RUST_TOCCATA_TX_VERSION=PASS|FAIL|UNKNOWN
RUST_COVENANT_OUTPUT=PASS|FAIL|UNKNOWN
RUST_TN10_WRPC_CONNECT=PASS|FAIL|UNKNOWN
RECOMMENDED_RUNTIME=typescript|rust|hybrid|undecided
```

## Anti-decision

Do not choose a runtime because the old app used it. Old work is evidence, not authority.

## Wrapper package spike result

The npm wrapper/package-boundary spike passed:

```text
NPM_WRAPPER_PACKAGE_PREREQ_NPM=PASS
NPM_WRAPPER_OFFICIAL_PACKAGE_JSON=PASS
NPM_WRAPPER_OFFICIAL_PACKAGE_JS=PASS
NPM_WRAPPER_OFFICIAL_PACKAGE_WASM=PASS
NPM_WRAPPER_OFFICIAL_PACKAGE_TYPES=PASS
NPM_WRAPPER_PACKAGE_DIRECT_IMPORT=PASS
NPM_WRAPPER_PACKAGE_PACK=PASS
NPM_WRAPPER_PACKAGE_TARBALL_CONTAINS_WASM=PASS
NPM_WRAPPER_PACKAGE_CONSUMER_INSTALL=PASS
NPM_WRAPPER_PACKAGE_CONSUMER_IMPORT=PASS
NPM_WRAPPER_PACKAGE_CONSUMER_COVENANT_CONSTRUCT=PASS
NPM_WRAPPER_PACKAGE_VERDICT=PASS # VALIDATED
```

Important limitation: the spike copies generated official WASM artifacts only into `/tmp` to test package consumption. It does not commit generated WASM to this repository and does not publish to npm.

## Historical JS/TS transaction capability note

The old offline/synthetic transaction spike code has been removed from the repo. Current implementation direction is live TN10 only. The relevant current evidence is the API live commit endpoint, validated with txid `5576e597aa80197de50dd6dfe3f9c351ba5c8c58b5e7d9be33bc82b5d86258e8`.

Interpretation: TypeScript/npm-first remains viable for Milestone 1, live TN10 status, live TN10 commit write work and guarded live TN10 broadcast. Production TN10 reveal write endpoint still require explicit safety design before being enabled.

## Guarded live TN10 broadcast spike status

A guarded live TN10 broadcast spike script now exists at `spikes/live-tn10-broadcast-capability/check-live-tn10-broadcast.js`. Its fail-closed path is verified:

```text
LIVE_TN10_WASM_IMPORT=PASS
LIVE_TN10_EXPORT_PrivateKey=PASS
LIVE_TN10_EXPORT_createTransactions=PASS
LIVE_TN10_EXPORT_RpcClient=PASS
LIVE_TN10_EXPORT_Resolver=PASS
LIVE_TN10_EXPORT_Encoding=PASS
LIVE_TN10_NETWORK_GUARD=PASS # testnet-10
LIVE_TN10_WRITE_ENABLE_GUARD=PASS # TOCCATA_ENABLE_TN10_WRITES is not 1; broadcast disabled
LIVE_TN10_BROADCAST_ACK_GUARD=PASS # ack phrase missing/mismatched; broadcast disabled
LIVE_TN10_PRIVATE_KEY_GUARD=PASS # TOCCATA_TN10_PRIVATE_KEY missing or not 64 hex chars; broadcast disabled
LIVE_TN10_AMOUNT_GUARD=PASS # amountSompi=10000000
LIVE_TN10_BROADCAST_EXECUTED=PASS # NO; fail-closed guards prevented live broadcast
LIVE_TN10_BROADCAST_VERDICT=GUARDED # set all required env vars to execute live TN10 broadcast
```

Interpretation: the live-broadcast path is now safely scaffolded, but actual broadcast acceptance remains UNKNOWN until a funded disposable `testnet-10` key is supplied through the required environment gates.
