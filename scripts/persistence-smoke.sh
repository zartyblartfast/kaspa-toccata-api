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
STORE_FILE="${TOCCATA_ROUND_STORE_FILE:-$(mktemp /tmp/kaspa-toccata-round-store.XXXXXX.json)}"
LOG_FILE="${PERSISTENCE_SMOKE_LOG:-/tmp/kaspa-toccata-persistence-smoke.log}"
export HOST PORT TOCCATA_ROUND_STORE_FILE="$STORE_FILE" KASPA_WRPC_TIMEOUT_MS="${KASPA_WRPC_TIMEOUT_MS:-60000}"

server_pid=""
pass() { printf '%s=PASS%s\n' "$1" "${2:+ # $2}"; }
fail() { printf '%s=FAIL%s\n' "$1" "${2:+ # $2}"; }

start_server() {
  node src/server.cjs >"$LOG_FILE" 2>&1 &
  server_pid=$!
  for _ in $(seq 1 50); do
    if curl -fsS "$BASE_URL/v1/health" >/tmp/kaspa-toccata-persistence-health.json 2>/dev/null; then
      return 0
    fi
    sleep 0.2
  done
  fail PERSISTENCE_SERVER_START "server did not become ready; see $LOG_FILE"
  exit 2
}

stop_server() {
  if [ -n "$server_pid" ] && kill -0 "$server_pid" >/dev/null 2>&1; then
    kill "$server_pid" >/dev/null 2>&1 || true
    wait "$server_pid" >/dev/null 2>&1 || true
  fi
  server_pid=""
}

cleanup() {
  stop_server
  rm -f "$STORE_FILE"
}
trap cleanup EXIT

start_server
ROUND_ID="$(BASE_URL="$BASE_URL" node <<'NODE'
const assert = require('node:assert/strict');
const { createToccataApiClient } = require('./src/client.cjs');
(async () => {
  const client = createToccataApiClient({ baseUrl: process.env.BASE_URL });
  const created = await client.createRound({ game: 'roulette', tableId: 'persistence-smoke' });
  const roundId = created.round.roundId;
  await client.commitRound(roundId, { serverSeed: 'persist-server-seed' });
  await client.updateBetLedger(roundId, { bets: [{ playerId: 'alice', selection: 'red', amount: 2 }] });
  const closed = await client.closeRound(roundId, { clientSeed: 'persist-client-seed', entropyMode: 'live_tn10_future', targetOffsetBlueScore: 1 });
  assert.equal(closed.round.status, 'closed');
  assert.equal(closed.round.claimLevel, 'tn10_future_entropy');
  process.stdout.write(roundId);
})().catch((error) => { console.error(error.stack || error.message || String(error)); process.exit(2); });
NODE
)"
pass PERSISTENCE_ROUND_CREATED "$ROUND_ID"

if [ ! -s "$STORE_FILE" ]; then
  fail PERSISTENCE_STORE_WRITTEN "$STORE_FILE missing or empty"
  exit 2
fi
pass PERSISTENCE_STORE_WRITTEN "$STORE_FILE"

stop_server
pass PERSISTENCE_RESTART_STOPPED
start_server
pass PERSISTENCE_RESTART_STARTED

BASE_URL="$BASE_URL" ROUND_ID="$ROUND_ID" node <<'NODE'
const assert = require('node:assert/strict');
const { createToccataApiClient } = require('./src/client.cjs');
(async () => {
  const client = createToccataApiClient({ baseUrl: process.env.BASE_URL });
  const round = await client.getRound(process.env.ROUND_ID);
  assert.equal(round.round.roundId, process.env.ROUND_ID);
  assert.equal(round.round.status, 'closed');
  assert.equal(round.round.claimLevel, 'tn10_future_entropy');
  assert(round.round.futureEntropyPlan, 'persisted live TN10 entropy plan present');
  assert(!round.round.localEntropyPlan, 'local entropy plan must not be present');
  console.log('PERSISTENCE_ROUND_RELOADED=PASS');
  console.log('PERSISTENCE_LIVE_TN10_PLAN_ONLY=PASS');
})().catch((error) => { console.error(error.stack || error.message || String(error)); process.exit(2); });
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
