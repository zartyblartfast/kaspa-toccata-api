# NPM / Toccata WASM Capability Spike

Goal: determine whether a TypeScript/npm-first implementation can use official Kaspa Toccata features via WASM.

Official source to evaluate:

```text
https://github.com/kaspanet/rusty-kaspa.git branch: toccata
```

Questions:

- Can we build or consume the Toccata WASM package?
- Are `CovenantBinding` and `GenesisCovenantGroup` available from JS/TS?
- Can JS/TS compute covenant IDs?
- Can `TransactionOutput.covenant` be created/read?
- Can Node connect to TN10 through wRPC/resolver?
- Can JS/TS build/sign/broadcast a Toccata transaction, or is that Rust-only for now?

Expected future PASS/FAIL lines:

```text
NPM_TOCCATA_WASM_BUILD=UNKNOWN
NPM_COVENANT_BINDING=UNKNOWN
NPM_GENESIS_COVENANT_GROUP=UNKNOWN
NPM_COVENANT_ID_HASH=UNKNOWN
NPM_TRANSACTION_OUTPUT_COVENANT=UNKNOWN
NPM_TN10_WRPC_CONNECT=UNKNOWN
NPM_TRANSACTION_BUILD_SIGN_BROADCAST_CAPABILITY=UNKNOWN
```
