# NPM / Toccata WASM Capability Spike

Goal: determine whether a TypeScript/npm-first implementation can use official Kaspa Toccata features via WASM.

Official source to evaluate:

```text
https://github.com/kaspanet/rusty-kaspa.git branch: toccata
```

## Current scope: source-level capability

The first capability test is intentionally narrow. It verifies that the official `toccata` branch contains JS/WASM-facing covenant primitives that could plausibly support our own npm package.

Run:

```bash
python3 spikes/npm-toccata-wasm-capability/check-source-capability.py
```

The script clones or refreshes the official `toccata` branch under:

```text
/tmp/kaspa-toccata-api-spikes/rusty-kaspa-toccata
```

## Questions

- Can we find official Toccata WASM source?
- Are `CovenantBinding` and `GenesisCovenantGroup` available from JS/TS-facing source?
- Can JS/TS-facing code compute covenant IDs?
- Can `TransactionOutput.covenant` be created/read at the WASM layer?
- Does the WASM SDK document `testnet-10` wRPC usage?
- Later: can we build/consume the WASM package?
- Later: can Node connect to TN10 through wRPC/resolver?
- Later: can JS/TS build/sign/broadcast a Toccata transaction, or is that Rust-only for now?

## Latest observed output

```text
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
```

## Verdict: PARTIAL

### What worked

The official `kaspanet/rusty-kaspa` `toccata` branch contains source-level WASM/TypeScript-facing covenant primitives:

- `ICovenantBinding`
- `IGenesisCovenantGroup`
- `covenantId` hashing wrapper
- `TransactionOutput.covenant`
- consensus/txscript WASM reexports
- `testnet-10` wRPC examples using Borsh encoding

### What did not get proven yet

- WASM build from source.
- npm package consumption from our project.
- live Node wRPC connection to TN10.
- Toccata transaction build/sign/broadcast from JS/TS.

### Recommendation for the real build

Continue the npm-first investigation, but do not choose TypeScript/npm as the implementation runtime yet. The next npm spike should attempt to build or package the official Toccata WASM and import the covenant symbols from Node.
