#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

HOST="${HOST:-127.0.0.1}"
PORT="${PORT:-$(python3 - <<'PY'
import socket
s = socket.socket(); s.bind(('127.0.0.1', 0)); print(s.getsockname()[1]); s.close()
PY
)}"
BASE_URL="http://$HOST:$PORT"
LOG_FILE="${PROOF_TX_EVIDENCE_SMOKE_LOG:-/tmp/kaspa-toccata-proof-tx-evidence-smoke.log}"
export HOST PORT KASPA_WRPC_TIMEOUT_MS="${KASPA_WRPC_TIMEOUT_MS:-90000}"

pass() { printf '%s=PASS%s\n' "$1" "${2:+ # $2}"; }
fail() { printf '%s=FAIL%s\n' "$1" "${2:+ # $2}"; }

REQUIRED_ACK='I understand this spends TN10 testnet funds'
if [ "${KASPA_NETWORK_ID:-testnet-10}" != "testnet-10" ] || \
   [ "${TOCCATA_ENABLE_TN10_WRITES:-}" != "1" ] || \
   ! printf '%s' "${TOCCATA_TN10_PRIVATE_KEY:-}" | grep -Eq '^[0-9a-fA-F]{64}$' || \
   [ "${TOCCATA_TN10_BROADCAST_ACK:-}" != "$REQUIRED_ACK" ]; then
  fail PROOF_TX_EVIDENCE_LIVE_GATES "set explicit TN10 write gates and funded key; this smoke intentionally broadcasts commit/close/reveal"
  exit 2
fi
pass PROOF_TX_EVIDENCE_LIVE_GATES

node src/server.cjs >"$LOG_FILE" 2>&1 &
server_pid=$!
cleanup() {
  if kill -0 "$server_pid" >/dev/null 2>&1; then
    kill "$server_pid" >/dev/null 2>&1 || true
    wait "$server_pid" >/dev/null 2>&1 || true
  fi
}
trap cleanup EXIT

for _ in $(seq 1 80); do
  if curl -fsS "$BASE_URL/v1/health" >/tmp/kaspa-toccata-proof-tx-health.json 2>/dev/null; then
    break
  fi
  sleep 0.2
done

BASE_URL="$BASE_URL" node <<'NODE'
const assert = require('node:assert/strict');
const { createToccataApiClient } = require('./src/client.cjs');
async function sleep(ms) { return new Promise((resolve) => setTimeout(resolve, ms)); }

function assertWriteProof(proof, phase) {
  const record = proof.tn10Writes && proof.tn10Writes[phase];
  assert(record, `${phase} write evidence present`);
  assert.equal(record.phase, phase);
  assert.equal(record.networkId, 'testnet-10');
  assert.equal(record.payloadSchema, `kaspa-toccata-api/live-${phase}/v1`);
  assert(Array.isArray(record.transactionIds) && record.transactionIds.length > 0, `${phase} txids present`);
  assert(Array.isArray(record.evidence) && record.evidence.length > 0, `${phase} evidence present`);
  const item = record.evidence.find((entry) => entry.transactionId === record.transactionIds[0]);
  assert(item && item.found === true, `${phase} tx found in evidence`);
  assert(item.decodedPayload, `${phase} decoded payload present`);
  assert.equal(item.decodedPayload.phase, phase);
  assert.equal(item.decodedPayload.roundId, proof.roundId);
  assert.equal(item.decodedPayload.networkId, 'testnet-10');
  assert.equal(item.decodedPayload.commitment, proof.commitment);
  return record.transactionIds[0];
}

async function main() {
  const client = createToccataApiClient({ baseUrl: process.env.BASE_URL });
  const serverSeed = `proof-tx-evidence-server-${Date.now()}`;
  const created = await client.createRound({ game: 'generic-contract', tableId: 'proof-tx-evidence-smoke' });
  const roundId = created.round.roundId;
  await client.commitRound(roundId, { serverSeed });
  const commitTx = await client.createCommitTx(roundId, {});
  assert.equal(commitTx.ok, true);
  console.log(`PROOF_TX_COMMIT_BROADCAST=PASS # ${commitTx.commitTx.transactionIds.join(',')}`);

  await client.updateBetLedger(roundId, { bets: [{ playerId: 'alice', selection: 'generic-selection', amount: 1 }] });
  await client.closeRound(roundId, { clientSeed: `proof-tx-evidence-client-${Date.now()}`, entropyMode: 'live_tn10_future', targetOffsetBlueScore: 1 });
  const closeTx = await client.createCloseTx(roundId, {});
  assert.equal(closeTx.ok, true);
  console.log(`PROOF_TX_CLOSE_BROADCAST=PASS # ${closeTx.closeTx.transactionIds.join(',')}`);

  let entropy;
  for (let i = 0; i < 80; i++) {
    try {
      entropy = await client.getEntropy(roundId);
      if (entropy.entropy && entropy.entropy.evidence && entropy.entropy.evidence.blockHash) break;
    } catch (error) {
      if (error.status !== 409 && error.status !== 503) throw error;
    }
    await sleep(500);
  }
  assert(entropy && entropy.entropy && entropy.entropy.evidence.blockHash, 'live TN10 entropy fetched');

  await client.revealRound(roundId, { serverSeed });
  const revealTx = await client.createRevealTx(roundId, {});
  assert.equal(revealTx.ok, true);
  console.log(`PROOF_TX_REVEAL_BROADCAST=PASS # ${revealTx.revealTx.transactionIds.join(',')}`);

  const proofResponse = await client.getProof(roundId);
  const proof = proofResponse.proof;
  const commitTxid = assertWriteProof(proof, 'commit');
  const closeTxid = assertWriteProof(proof, 'close');
  const revealTxid = assertWriteProof(proof, 'reveal');
  console.log('PROOF_INCLUDES_COMMIT_TX=PASS');
  console.log('PROOF_INCLUDES_CLOSE_TX=PASS');
  console.log('PROOF_INCLUDES_REVEAL_TX=PASS');
  console.log('PROOF_TX_PHASES_MATCH=PASS');
  console.log('PROOF_TX_ROUND_IDS_MATCH=PASS');
  assert(proof.tn10Writes.reveal.evidence[0].decodedPayload.priorTn10Writes.commit.includes(commitTxid));
  assert(proof.tn10Writes.reveal.evidence[0].decodedPayload.priorTn10Writes.close.includes(closeTxid));
  assert.equal(proof.tn10Writes.reveal.transactionIds[0], revealTxid);
  console.log('PROOF_TX_PRIOR_REFS_MATCH=PASS');

  const verified = await client.verifyProof(proof);
  assert.equal(verified.ok, true);
  assert.equal(verified.verified, true);
  assert(verified.txEvidence && verified.txEvidence.verified === true, 'tx evidence verified');
  assert(verified.txEvidence.checked.length >= 3, 'commit close reveal tx evidence checked');
  console.log('PROOF_VERIFY_TX_EVIDENCE=PASS');
}

main().catch((error) => {
  console.error(error.stack || error.message || String(error));
  process.exit(2);
});
NODE

if find . \
  -path './.git' -prune -o \
  -path './node_modules' -prune -o \
  -type f \( \
    -name 'sample-round.json' -o \
    -name 'toccata-fairness-proof.json' -o \
    -name 'proof.json' -o \
    -name 'round.json' \
  \) -print | grep -q .; then
  fail NO_STATIC_APP_FIXTURES
  exit 2
fi
pass NO_STATIC_APP_FIXTURES
