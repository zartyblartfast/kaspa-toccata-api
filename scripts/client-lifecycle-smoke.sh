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
LOG_FILE="${CLIENT_LIFECYCLE_SMOKE_LOG:-/tmp/kaspa-toccata-client-lifecycle-smoke.log}"
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
  if curl -fsS "$BASE_URL/v1/health" >/tmp/kaspa-toccata-client-health.json 2>/dev/null; then
    break
  fi
  sleep 0.2
done

BASE_URL="$BASE_URL" node <<'NODE'
const assert = require('node:assert/strict');
const { ToccataApiClient, createToccataApiClient } = require('./src/client.cjs');

async function main() {
  const baseUrl = process.env.BASE_URL;
  const client = createToccataApiClient({ baseUrl });
  assert(client instanceof ToccataApiClient, 'factory returns client instance');

  const health = await client.health();
  assert.equal(health.ok, true);
  assert.equal(health.service, 'kaspa-toccata-api');
  console.log('CLIENT_HEALTH_OK=PASS');

  const capabilities = await client.capabilities();
  assert.equal(capabilities.ok, true);
  assert.equal(capabilities.capabilities.canSign, false);
  assert.equal(capabilities.capabilities.canBroadcast, false);
  assert.equal(capabilities.capabilities.mainnetEnabled, false);
  assert.equal(capabilities.capabilities.broadcastEvidence.validated, true);
  console.log('CLIENT_CAPABILITIES_OK=PASS');

  const networkStatus = await client.networkStatus();
  assert.equal(networkStatus.ok, true);
  assert.equal(networkStatus.claimLevel, 'live_tn10_status');
  assert.equal(networkStatus.networkId, 'testnet-10');
  assert(networkStatus.blockDagInfo.virtualDaaScore, 'network status includes live DAA score');
  console.log('CLIENT_TN10_STATUS_OK=PASS');

  const created = await client.createRound({ game: 'roulette', tableId: 'client-smoke-table', metadata: { smoke: 'client' } });
  assert.equal(created.ok, true);
  assert.equal(created.round.claimLevel, 'live_tn10_pending');
  assert.equal(created.round.provider, 'rusty-kaspa-toccata-wasm');
  const roundId = created.round.roundId;
  console.log(`CLIENT_ROUND_CREATE_OK=PASS # ${roundId}`);

  const fetched = await client.getRound(roundId);
  assert.equal(fetched.ok, true);
  assert.equal(fetched.round.status, 'created');
  console.log('CLIENT_ROUND_GET_OK=PASS');

  const committed = await client.commitRound(roundId, { serverSeed: 'client-smoke-server-seed' });
  assert.equal(committed.round.status, 'committed');
  assert(committed.round.commitment, 'commitment present');
  assert.equal(committed.round.serverSeed, undefined, 'server seed must not leak before reveal');
  console.log(`CLIENT_ROUND_COMMIT_OK=PASS # ${committed.round.commitment}`);

  const ledger = await client.updateBetLedger(roundId, {
    bets: [
      { playerId: 'alice', selection: 'red', amount: 5 },
      { playerId: 'bob', selection: '17', amount: 1 }
    ]
  });
  assert.equal(ledger.round.status, 'betting_open');
  assert.equal(ledger.round.betLedger.count, 2);
  assert(ledger.round.betLedger.ledgerHash, 'ledger hash present');
  console.log('CLIENT_BET_LEDGER_OK=PASS');

  const closed = await client.closeRound(roundId, { clientSeed: 'client-smoke-client-seed', entropyMode: 'live_tn10_future', targetOffsetBlueScore: 1 });
  assert.equal(closed.round.status, 'closed');
  assert.equal(closed.round.futureEntropyPlan.claimLevel, 'tn10_future_entropy');
  console.log('CLIENT_CLOSE_OK=PASS');

  let entropy;
  for (let i = 0; i < 40; i++) {
    try { entropy = await client.getEntropy(roundId); break; }
    catch (error) { if (error.status !== 409 && error.status !== 503) throw error; await new Promise((resolve) => setTimeout(resolve, 500)); }
  }
  assert(entropy && entropy.ok, 'live entropy fetched');
  assert.equal(entropy.entropy.claimLevel, 'tn10_future_entropy');
  assert(entropy.entropy.evidence.blockHash, 'live block hash present');
  console.log(`CLIENT_TN10_ENTROPY_OK=PASS # ${entropy.entropy.evidence.blockHash}`);

  const revealed = await client.revealRound(roundId, { serverSeed: 'client-smoke-server-seed' });
  assert.equal(revealed.round.status, 'revealed');
  assert(Number.isInteger(revealed.round.result.number));
  assert(revealed.round.result.number >= 0 && revealed.round.result.number <= 36);
  console.log(`CLIENT_ROUND_REVEAL_OK=PASS # ${revealed.round.result.number}`);

  const proof = await client.getProof(roundId);
  assert.equal(proof.ok, true);
  assert.equal(proof.proof.claimLevel, 'tn10_future_entropy');
  assert(proof.proof.result, 'proof result present');
  console.log('CLIENT_PROOF_GET_OK=PASS');

  const verified = await client.verifyProof(proof.proof);
  assert.equal(verified.ok, true);
  assert.equal(verified.verified, true);
  assert.equal(verified.claimLevel, 'tn10_future_entropy');
  console.log('CLIENT_PROOF_VERIFY_OK=PASS');
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
