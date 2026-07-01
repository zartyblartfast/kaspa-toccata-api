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
LOG_FILE="${LIVE_ONLY_POLICY_SMOKE_LOG:-/tmp/kaspa-toccata-live-only-policy-smoke.log}"
export HOST PORT KASPA_WRPC_TIMEOUT_MS="${KASPA_WRPC_TIMEOUT_MS:-60000}"

pass() { printf '%s=PASS%s\n' "$1" "${2:+ # $2}"; }
fail() { printf '%s=FAIL%s\n' "$1" "${2:+ # $2}"; }

node src/server.cjs >"$LOG_FILE" 2>&1 &
server_pid=$!
cleanup() { if kill -0 "$server_pid" >/dev/null 2>&1; then kill "$server_pid" >/dev/null 2>&1 || true; wait "$server_pid" >/dev/null 2>&1 || true; fi; }
trap cleanup EXIT

for _ in $(seq 1 50); do
  curl -fsS "$BASE_URL/v1/health" >/tmp/kaspa-toccata-live-only-health.json 2>/dev/null && break
  sleep 0.2
done

BASE_URL="$BASE_URL" node <<'NODE'
const assert = require('node:assert/strict');
const { createToccataApiClient, ToccataApiError } = require('./src/client.cjs');

async function expectError(label, fn, status, code) {
  let ok = false;
  try { await fn(); } catch (error) {
    if (error instanceof ToccataApiError && error.status === status && error.body && error.body.error === code) ok = true;
    else throw error;
  }
  assert.equal(ok, true, `${label} should fail with ${status} ${code}`);
  console.log(`${label}=PASS`);
}

(async () => {
  const client = createToccataApiClient({ baseUrl: process.env.BASE_URL });
  const created = await client.createRound({ game: 'roulette', tableId: 'live-only-policy' });
  assert.equal(created.round.claimLevel, 'live_tn10_pending');
  assert.equal(created.round.provider, 'rusty-kaspa-toccata-wasm');
  console.log('ROUND_CREATE_LIVE_PENDING_OK=PASS');
  const roundId = created.round.roundId;
  await client.commitRound(roundId, { serverSeed: 'live-only-policy-server-seed' });
  console.log('ROUND_COMMIT_STATE_ONLY_OK=PASS');
  await client.updateBetLedger(roundId, { bets: [{ playerId: 'alice', selection: 'red', amount: 1 }] });
  await expectError('LOCAL_ENTROPY_DISABLED', () => client.closeRound(roundId, { clientSeed: 'local-disabled' }), 400, 'bad_request');
  await expectError('DRY_RUN_FORBIDDEN', () => client.createCommitTx(roundId, { dryRun: true }), 400, 'dry_run_forbidden');
})();
NODE

if find . -path './.git' -prune -o -path './node_modules' -prune -o -type f \( -name 'sample-round.json' -o -name 'toccata-fairness-proof.json' -o -name 'proof.json' -o -name 'round.json' \) -print | grep -q .; then
  fail NO_STATIC_APP_FIXTURES
  exit 2
fi
pass NO_STATIC_APP_FIXTURES
