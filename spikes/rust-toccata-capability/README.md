# Rust / Toccata Capability Spike

Goal: determine whether a Rust service can cleanly use official Kaspa Toccata features from the official `rusty-kaspa` `toccata` branch.

Official source to evaluate:

```text
https://github.com/kaspanet/rusty-kaspa.git branch: toccata
```

Questions:

- Can we depend on the official branch without local old-project paths?
- Is `TX_VERSION_TOCCATA` available?
- Are `CovenantBinding` and `GenesisCovenantGroup` available?
- Does `TransactionOutput` expose covenant binding?
- Can Rust connect to TN10 through wRPC/resolver?
- Can Rust build/sign/broadcast a Toccata transaction with explicit TN10-only safety gates?

Expected future PASS/FAIL lines:

```text
RUST_TOCCATA_BRANCH_DEPENDENCY=UNKNOWN
RUST_TX_VERSION_TOCCATA=UNKNOWN
RUST_COVENANT_BINDING=UNKNOWN
RUST_GENESIS_COVENANT_GROUP=UNKNOWN
RUST_TRANSACTION_OUTPUT_COVENANT=UNKNOWN
RUST_TN10_WRPC_CONNECT=UNKNOWN
RUST_TRANSACTION_BUILD_SIGN_BROADCAST_CAPABILITY=UNKNOWN
```
