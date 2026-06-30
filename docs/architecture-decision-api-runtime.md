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
| direct Toccata primitive access | Unknown | Likely High | Likely High |
| TN10 wRPC from runtime | Unknown | Likely | Likely |
| covenant/KIP-20 support | Unknown but promising | Likely | Likely |
| curl/API smoke tests | High | High | High |
| package publish complexity | Medium | Medium | High |
| low-level correctness confidence | Unknown | High if official branch works | High if official branch works |
| fastest Milestone 1 | Medium | Medium | Low/Medium |
| long-term app adoption | High | High | High |

## Current recommendation

Do not choose yet.

Run both capability spikes first. If Option A proves the necessary Toccata/WASM features cleanly, prefer TypeScript/npm-first. If not, choose Option B for implementation and keep npm as the developer-facing client/wrapper layer.

Option C is likely a distribution strategy after Option B, not the first implementation strategy.

## Required spike output

`scripts/spike-api-runtime-decision.sh` should eventually print:

```text
OFFICIAL_KIPS_FOUND=PASS
RUSTY_KASPA_TOCCATA_BRANCH=PASS
NPM_TOCCATA_WASM_BUILD=PASS|FAIL|UNKNOWN
NPM_COVENANT_BINDING=PASS|FAIL|UNKNOWN
NPM_GENESIS_COVENANT_GROUP=PASS|FAIL|UNKNOWN
NPM_TN10_WRPC_CONNECT=PASS|FAIL|UNKNOWN
RUST_TOCCATA_TX_VERSION=PASS|FAIL|UNKNOWN
RUST_COVENANT_OUTPUT=PASS|FAIL|UNKNOWN
RUST_TN10_WRPC_CONNECT=PASS|FAIL|UNKNOWN
RECOMMENDED_RUNTIME=typescript|rust|hybrid|undecided
```

## Anti-decision

Do not choose a runtime because the old app used it. Old work is evidence, not authority.
