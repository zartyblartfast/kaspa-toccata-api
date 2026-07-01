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
LOG_FILE="${BASIC_WEB_API_TEST_LOG:-/tmp/kaspa-toccata-basic-web-api-test.log}"
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

for _ in $(seq 1 80); do
  if curl -fsS "$BASE_URL/v1/health" >/tmp/kaspa-toccata-basic-web-health.json 2>/dev/null; then
    break
  fi
  sleep 0.2
done

html="$(curl -fsS "$BASE_URL/demo/basic-api-test")"
printf '%s' "$html" | grep -q 'Kaspa Toccata API Basic Live Test' && pass BASIC_WEB_PAGE_SERVED || { fail BASIC_WEB_PAGE_SERVED; exit 2; }
curl -fsS "$BASE_URL/demo/basic-api-test.html" | grep -q 'Kaspa Toccata API Basic Live Test' && pass BASIC_WEB_PAGE_HTML_ROUTE_SERVED || { fail BASIC_WEB_PAGE_HTML_ROUTE_SERVED; exit 2; }
curl -fsS "$BASE_URL/demo/" | grep -q 'Kaspa Toccata API Basic Live Test' && pass BASIC_WEB_DEMO_INDEX_SERVED || { fail BASIC_WEB_DEMO_INDEX_SERVED; exit 2; }
printf '%s' "$html" | grep -q 'Broadcast commit/tx' && pass BASIC_WEB_COMMIT_TX_BUTTON || { fail BASIC_WEB_COMMIT_TX_BUTTON; exit 2; }
printf '%s' "$html" | grep -q 'Broadcast close/tx' && pass BASIC_WEB_CLOSE_TX_BUTTON || { fail BASIC_WEB_CLOSE_TX_BUTTON; exit 2; }
printf '%s' "$html" | grep -q 'Broadcast reveal/tx' && pass BASIC_WEB_REVEAL_TX_BUTTON || { fail BASIC_WEB_REVEAL_TX_BUTTON; exit 2; }
printf '%s' "$html" | grep -q 'Verify proof' && pass BASIC_WEB_VERIFY_BUTTON || { fail BASIC_WEB_VERIFY_BUTTON; exit 2; }

BASE_URL="$BASE_URL" node <<'NODE'
const assert = require('node:assert/strict');
const { createToccataApiClient } = require('./src/client.cjs');
(async () => {
  const client = createToccataApiClient({ baseUrl: process.env.BASE_URL });
  const health = await client.health();
  assert.equal(health.ok, true);
  const created = await client.createRound({ game: 'generic-contract', tableId: 'basic-web-smoke' });
  assert.match(created.round.roundId, /^tn10_/);
  console.log('BASIC_WEB_API_HEALTH=PASS');
  console.log('BASIC_WEB_API_CREATE_ROUND=PASS # ' + created.round.roundId);
})().catch((error) => {
  console.error(error.stack || error.message || String(error));
  process.exit(2);
});
NODE

preflight_status="$(curl -s -o /tmp/kaspa-toccata-basic-web-options.txt -w '%{http_code}' \
  -X OPTIONS \
  -H 'Origin: http://127.0.0.1:8789' \
  -H 'Access-Control-Request-Method: POST' \
  "$BASE_URL/v1/rounds")"
test "$preflight_status" = "204" && pass BASIC_WEB_CORS_PREFLIGHT || { fail BASIC_WEB_CORS_PREFLIGHT "status=$preflight_status"; exit 2; }

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
