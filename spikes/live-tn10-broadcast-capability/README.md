# Guarded Live TN10 Broadcast Capability Spike

Goal: prove live TN10 broadcast from the TypeScript/npm/WASM path, but only behind explicit fail-closed safety gates.

This script never reads secrets from files and never writes private keys to disk. Do not commit keys, wallet files, or generated secret material.

## Fail-closed default

Run without secrets:

```bash
node spikes/live-tn10-broadcast-capability/check-live-tn10-broadcast.js
```

Expected result: import/export checks pass, guards pass as disabled, and no broadcast is executed.

## Required env vars for actual live broadcast

Only use a small funded `testnet-10` key. Never use mainnet funds.

```bash
export TOCCATA_ENABLE_TN10_WRITES=1
export TOCCATA_TN10_PRIVATE_KEY='<64 hex char testnet-only private key>'
export TOCCATA_TN10_BROADCAST_ACK='I understand this spends TN10 testnet funds'
# optional; defaults to sending back to source address
export TOCCATA_TN10_DESTINATION_ADDRESS='<kaspatest:...>'
# optional; defaults to 10000000 sompi
export TOCCATA_TN10_SEND_AMOUNT_SOMPI=10000000
# optional; defaults to 0
export TOCCATA_TN10_PRIORITY_FEE_SOMPI=0
node spikes/live-tn10-broadcast-capability/check-live-tn10-broadcast.js
```

## Guards

The script requires all of these before submitting a transaction:

- `KASPA_NETWORK_ID` must be unset or exactly `testnet-10`.
- `TOCCATA_ENABLE_TN10_WRITES=1`.
- `TOCCATA_TN10_PRIVATE_KEY` must be a 64-hex-character private key supplied via environment variable.
- `TOCCATA_TN10_BROADCAST_ACK` must exactly equal `I understand this spends TN10 testnet funds`.
- amount must be positive.
- node server info must report `networkId=testnet-10` and synced.
- source address must have at least one sufficiently funded non-coinbase UTXO.

## What it proves if fully executed

- JS/WASM can connect to live TN10.
- JS/WASM can look up UTXOs for a funded testnet address.
- JS/WASM can create a live spend transaction.
- JS/WASM can sign it.
- JS/WASM can submit it via `PendingTransaction.submit(rpc)`.
- TN10 node returns a transaction id.

## What it still does not prove

- production API write endpoint safety design;
- Toccata commit/reveal covenant lineage semantics;
- confirmation/finality tracking;
- npm package publish flow.
