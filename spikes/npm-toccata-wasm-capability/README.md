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

## Commands

Source-level check:

```bash
python3 spikes/npm-toccata-wasm-capability/check-source-capability.py
```

Build/import/runtime check:

```bash
spikes/npm-toccata-wasm-capability/build-and-check-wasm.sh
```

Live TN10 wRPC check:

```bash
KASPA_WRPC_TIMEOUT_MS=60000 node spikes/npm-toccata-wasm-capability/check-tn10-wrpc.js
```

Combined scaffold/runtime check without live network:

```bash
scripts/spike-api-runtime-decision.sh
```

Combined check with live TN10 network:

```bash
RUN_TN10_WRPC=1 scripts/spike-api-runtime-decision.sh
```

Build prerequisites discovered:

```text
rustup target add wasm32-unknown-unknown
cargo install wasm-pack --locked
apt-get install -y clang
```

`clang` is needed because `secp256k1-sys` needs a C compiler during the wasm build.

## Latest observed output

Source-level check:

```text
OFFICIAL_RUSTY_KASPA_TOCCATA_CLONE=PASS
NPM_TOCCATA_WASM_SOURCE_COVENANT_BINDING=PASS
NPM_TOCCATA_WASM_SOURCE_GENESIS_COVENANT_GROUP=PASS
NPM_TOCCATA_WASM_SOURCE_COVENANT_ID_HASH=PASS
NPM_TOCCATA_WASM_SOURCE_TRANSACTION_OUTPUT_COVENANT=PASS
NPM_TOCCATA_WASM_SOURCE_REEXPORTS_CONSENSUS=PASS
NPM_TOCCATA_WASM_SOURCE_TN10_RPC_EXAMPLE=PASS
```

Build/import/runtime check:

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

Live TN10 wRPC check:

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

## Verdict: VALIDATED for source/build/import/covenant primitives and live TN10 read-only wRPC

### What worked

The official `kaspanet/rusty-kaspa` `toccata` branch can build a Node WASM package at:

```text
/tmp/kaspa-toccata-api-spikes/rusty-kaspa-toccata/wasm/nodejs/kaspa
```

The built package imports successfully from Node and exposes/constructs:

- `Hash`
- `CovenantBinding`
- `GenesisCovenantGroup`
- `TransactionOutput`
- `Transaction`
- `TransactionOutpoint`
- `covenantId`
- `payToScriptHashScript`
- `RpcClient`
- `Resolver`
- `Encoding`

Runtime construction of `CovenantBinding`, `GenesisCovenantGroup`, and `TransactionOutput` with covenant binding passed.

Live read-only TN10 wRPC also passed using public resolver/Borsh transport. The script resolved a public TN10 endpoint, connected, fetched server info, fetched live blockDAG info, and disconnected cleanly.

### What did not get proven yet

- Toccata transaction build/sign/broadcast from JS/TS.
- packaging this built WASM as our own npm package.
- full API service shape.

### Recommendation for the real build

The npm-first path is now strongly plausible for Milestone 1 and Milestone 3 read-only TN10 API work. Before choosing it for TN10 writes/covenant-enforced rounds, test JS/TS transaction construction/signing/broadcast and package wrapping/publishing.
