# kaspa-toccata-api

Developer-facing JavaScript client for the Kaspa TN10/Toccata fairness API.

This package is intentionally app-agnostic. A roulette proof-of-concept can consume it later, but the API/client naming is generic: rounds are committed, closed, revealed, proven, and verified.

## Install

```bash
npm install kaspa-toccata-api
```

## Use the client

```js
const { createToccataApiClient } = require('kaspa-toccata-api');

const client = createToccataApiClient({
  baseUrl: 'http://127.0.0.1:8787'
});

const created = await client.createRound({
  game: 'roulette-poc',
  tableId: 'example-table'
});

const roundId = created.round.roundId;

await client.commitRound(roundId, { serverSeed: 'server-seed-kept-secret-until-reveal' });
await client.updateBetLedger(roundId, {
  bets: [{ playerId: 'alice', selection: '17', amount: 1 }]
});
await client.closeRound(roundId, {
  clientSeed: 'client-seed',
  entropyMode: 'live_tn10_future',
  targetOffsetBlueScore: 1
});

const entropy = await client.getEntropy(roundId);
const reveal = await client.revealRound(roundId, { serverSeed: 'server-seed-kept-secret-until-reveal' });
const proof = await client.getProof(roundId);
const verified = await client.verifyProof(proof.proof);
```

Proof responses include first-class TN10 write evidence when live transactions have been broadcast:

```js
proof.proof.tn10Writes.commit.transactionIds
proof.proof.tn10Writes.close.transactionIds
proof.proof.tn10Writes.reveal.transactionIds
proof.proof.tn10Writes.reveal.evidence[0].decodedPayload
```

`verifyProof()` also returns `txEvidence` when transaction evidence is present and internally consistent.

## Generic live-write methods

The API also exposes explicit TN10 transaction write endpoints. They are live TN10 only and fail closed unless the API server has explicit testnet write gates configured.

```js
await client.createCommitTx(roundId);
await client.createCloseTx(roundId);
await client.createRevealTx(roundId);
```

These methods do not perform local transaction dry-runs. Dry-run/mock/offline transaction paths are intentionally unsupported.

## Independent TN10 transaction confirmation

After a live write, the API/proof can include transaction IDs for:

```text
commit/tx
close/tx
reveal/tx
```

Users can independently confirm those transactions through the public TN10 API, without trusting the roulette app or this package.

See:

```text
docs/VERIFY_TN10_TRANSACTIONS.md
```

## Safety and claim level

Current guarantees are deliberately conservative:

- network: Kaspa TN10 / `testnet-10`
- API/client names are app-agnostic
- dry-runs, mocks, offline transaction paths, and static app proof fixtures are forbidden
- live writes require explicit server-side testnet-only gates
- browser apps should consume the API/client and display proof; they should not sign or broadcast

Toccata covenant lineage/state-transition enforcement is a future claim level and is not claimed by this package yet.
