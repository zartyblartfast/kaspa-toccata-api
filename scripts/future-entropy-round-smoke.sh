#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

HOST="${HOST:-127.0.0.1}"
PORT="${PORT:-$(python3 - <<'PY'
import socket
s = socket.socket()
s.bind(('127.0.0.1', 0))
print(s.getsockname()[1])
s.close()
PY
)}"
BASE_URL="http://$HOST:$PORT"
LOG_FILE="${FUTURE_ENTROPY_SMOKE_LOG:-/tmp/kaspa-toccata-future-entropy-smoke.log}"
export HOST PORT KASPA_WRPC_TIMEOUT_MS="${KASPA_WRPC_TIMEOUT_MS:-60000}"

pass() { printf '%s=PASS%s\n' "$1" "${2:+ # $2}"; }
fail() { printf '%s=FAIL%s\n' "$1" "${2:+ # $2}"; }

node src/server.cjs >"$LOG_FILE" 2>&1 &
server_pid=$!
cleanup() {
  if kill -0 "$server_pid" >/dev/null 2>&1; then
    kill "$server_pid" >/dev/null 2>&1 || true
    wait "$server_pid" >/dev/null 2>&1 || true
  fi
}
trap cleanup EXIT

for _ in $(seq 1 50); do
  if curl -fsS "$BASE_URL/v1/health" >/tmp/kaspa-toccata-future-health.json 2>/dev/null; then
    break
  fi
  sleep 0.2
done

BASE_URL="$BASE_URL" node <<'NODE'
const assert = require('node:assert/strict');
const { createToccataApiClient } = require('./src/client.cjs');

async function sleep(ms) { return new Promise((resolve) => setTimeout(resolve, ms)); }

async function main() {
  const client = createToccataApiClient({ baseUrl: process.env.BASE_URL });
  const created = await client.createRound({ game: 'roulette', tableId: 'future-entropy-smoke' });
  const roundId = created.round.roundId;
  console.log(`FUTURE_ROUND_CREATE_OK=PASS # ${roundId}`);

  await client.commitRound(roundId, { serverSeed: 'future-entropy-server-seed' });
  console.log('FUTURE_COMMIT_OK=PASS');

  await client.updateBetLedger(roundId, { bets: [{ playerId: 'alice', selection: 'odd', amount: 3 }] });
  console.log('FUTURE_BET_LEDGER_OK=PASS');

  const closed = await client.closeRound(roundId, {
    clientSeed: 'future-entropy-client-seed',
    entropyMode: 'live_tn10_future',
    targetOffsetBlueScore: 1
  });
  assert.equal(closed.round.claimLevel, 'tn10_future_entropy');
  assert.equal(closed.round.provider, 'rusty-kaspa-toccata-wasm');
  assert.equal(closed.round.futureEntropyPlan.claimLevel, 'tn10_future_entropy');
  assert.equal(closed.round.futureEntropyPlan.targetMetric, 'blueScore');
  assert(closed.round.futureEntropyPlan.targetBlueScore, 'target blue score fixed');
  console.log(`FUTURE_CLOSE_TARGET_FIXED=PASS # blueScore:${closed.round.futureEntropyPlan.targetBlueScore}`);

  let entropy;
  for (let i = 0; i < 40; i++) {
    try {
      entropy = await client.getEntropy(roundId);
      if (entropy.entropy && entropy.entropy.claimLevel === 'tn10_future_entropy') break;
    } catch (error) {
      if (error.status !== 409 && error.status !== 503) throw error;
    }
    await sleep(500);
  }
  assert(entropy, 'entropy was fetched');
  assert.equal(entropy.entropy.claimLevel, 'tn10_future_entropy');
  assert(entropy.entropy.entropyHash, 'entropy hash present');
  assert(entropy.entropy.evidence.blockHash, 'live block hash present');
  assert(BigInt(entropy.entropy.evidence.blueScore) >= BigInt(closed.round.futureEntropyPlan.targetBlueScore), 'evidence is at/after target blue score');
  console.log(`FUTURE_TN10_ENTROPY_FETCH_OK=PASS # ${entropy.entropy.evidence.blockHash}`);

  const revealed = await client.revealRound(roundId, { serverSeed: 'future-entropy-server-seed' });
  assert.equal(revealed.round.claimLevel, 'tn10_future_entropy');
  assert.equal(revealed.round.status, 'revealed');
  assert(Number.isInteger(revealed.round.result.number));
  console.log(`FUTURE_REVEAL_OK=PASS # ${revealed.round.result.number}`);

  const proof = await client.getProof(roundId);
  assert.equal(proof.proof.claimLevel, 'tn10_future_entropy');
  assert(proof.proof.entropy.evidence.blockHash, 'proof includes live TN10 evidence');
  console.log('FUTURE_PROOF_GET_OK=PASS');

  const verified = await client.verifyProof(proof.proof);
  assert.equal(verified.ok, true);
  assert.equal(verified.verified, true);
  assert.equal(verified.claimLevel, 'tn10_future_entropy');
  console.log('FUTURE_PROOF_VERIFY_OK=PASS');
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
