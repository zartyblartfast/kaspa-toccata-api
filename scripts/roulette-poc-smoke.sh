#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

APP_DIR="apps/roulette-poc"
APP_URL_PATH="/apps/roulette-poc/"

fail() {
  printf '%s=FAIL\n' "$1" >&2
  exit 1
}

pass() {
  printf '%s=PASS\n' "$1"
}

[[ -f "$APP_DIR/index.html" ]] || fail ROULETTE_POC_INDEX_EXISTS
[[ -f "$APP_DIR/app.js" ]] || fail ROULETTE_POC_APP_JS_EXISTS
[[ -f "$APP_DIR/styles.css" ]] || fail ROULETTE_POC_STYLES_EXISTS
[[ -f "$APP_DIR/flowchart-spec.json" ]] || fail ROULETTE_POC_FLOWCHART_SPEC_EXISTS
[[ -f "$APP_DIR/roulette-table-renderer.js" ]] || fail ROULETTE_POC_RENDERER_EXISTS
[[ -f "$APP_DIR/roulette-table-layout.js" ]] || fail ROULETTE_POC_LAYOUT_EXISTS
[[ -f "src/client.mjs" ]] || fail ROULETTE_POC_ESM_CLIENT_EXISTS
pass ROULETTE_POC_FILES_EXIST

node --check "$APP_DIR/app.js"
node --check "$APP_DIR/roulette-table-renderer.js"
node --check "$APP_DIR/roulette-table-layout.js"
node --check src/client.mjs
node -e "JSON.parse(require('fs').readFileSync('$APP_DIR/flowchart-spec.json', 'utf8'))"
node -e "import('./src/client.mjs').then((m) => { if (typeof m.createToccataApiClient !== 'function') process.exit(2); })"
pass ROULETTE_POC_JS_SYNTAX

if grep -R -n -E 'sample-round|toccata-fairness-proof|proof\.json|round\.json|dry-run|dryRun|offline|Math\.random|localStorage|sessionStorage' "$APP_DIR" >/tmp/roulette-poc-forbidden-static.txt; then
  cat /tmp/roulette-poc-forbidden-static.txt >&2
  fail ROULETTE_POC_NO_STATIC_OR_OFFLINE_PATTERNS
fi
pass ROULETTE_POC_NO_STATIC_OR_OFFLINE_PATTERNS

if grep -R -n -i 'mock' "$APP_DIR" >/tmp/roulette-poc-forbidden-mock.txt; then
  cat /tmp/roulette-poc-forbidden-mock.txt >&2
  fail ROULETTE_POC_NO_MOCK_PATTERNS
fi
pass ROULETTE_POC_NO_MOCK_PATTERNS

if ! grep -F '"kaspa-toccata-api"' "$APP_DIR/index.html" >/dev/null; then
  fail ROULETTE_POC_IMPORT_MAP_PACKAGE_NAME
fi
if ! grep -F "from 'kaspa-toccata-api'" "$APP_DIR/app.js" >/dev/null; then
  fail ROULETTE_POC_APP_IMPORTS_NPM_API
fi
if grep -n -E '\bfetch\s*\(' "$APP_DIR/app.js" | grep -v 'flowchart-spec\.json' >/tmp/roulette-poc-app-fetch.txt; then
  cat /tmp/roulette-poc-app-fetch.txt >&2
  fail ROULETTE_POC_APP_NO_RAW_FETCH
fi
grep -F "fetch('/apps/roulette-poc/flowchart-spec.json'" "$APP_DIR/app.js" >/dev/null || fail ROULETTE_POC_FLOWCHART_SPEC_FETCH_ONLY
if ! node -e "const p=require('./package.json'); const root=p.exports && p.exports['.']; if (!root || root.import !== './src/client.mjs') process.exit(2); const client=p.exports && p.exports['./client']; if (!client || client.import !== './src/client.mjs') process.exit(3); if (!p.files.includes('src/client.mjs')) process.exit(4);"; then
  fail ROULETTE_POC_PACKAGE_ESM_EXPORT
fi
pass ROULETTE_POC_NPM_API_IMPORT_READY

node <<'NODE'
const fs = require('fs');
const spec = JSON.parse(fs.readFileSync('apps/roulette-poc/flowchart-spec.json', 'utf8'));
const nodes = new Map(spec.nodes.map((node) => [node.id, node]));
for (const edge of spec.edges) {
  const from = nodes.get(edge.from);
  const to = nodes.get(edge.to);
  if (!from || !to) process.exit(2);
  if (from.row !== to.row) process.exit(3);
}
if (spec.edges.some((edge) => edge.label === 'opens table')) process.exit(4);
if (!spec.edges.some((edge) => edge.label === 'enables chip placement')) process.exit(5);
if (!spec.compact || !Array.isArray(spec.compact.rows) || spec.compact.rows.length !== 2) process.exit(6);
if (!spec.compact.rows.every((row) => Array.isArray(row.nodeIds) && row.nodeIds.length === 8)) process.exit(7);
if (!spec.compact.rows.some((row) => row.nodeIds.includes(null))) process.exit(8);
if (nodes.get('proof_entropy')?.compactLabel !== 'Entropy') process.exit(9);
if (!nodes.get('proof_entropy')?.compactHelp?.includes('GET /entropy')) process.exit(10);
if (!nodes.get('proof_entropy')?.compactHelp?.includes('external entropy')) process.exit(11);
if (!nodes.get('round_waiting')?.compactHelp?.includes('GET /entropy')) process.exit(12);
if (!nodes.get('proof_close')?.compactHelp?.includes('future TN10 blue-score')) process.exit(13);
if (!Array.isArray(nodes.get('proof_entropy')?.compactLinks) || nodes.get('proof_entropy').compactLinks.length < 2) process.exit(14);
if (!nodes.get('proof_entropy').compactLinks.every((link) => link.href.startsWith('https://github.com/zartyblartfast/kaspa-toccata-api/'))) process.exit(15);
NODE
pass ROULETTE_POC_FLOWCHART_SPEC_ALIGNED

for required in \
  '/v1/health' \
  '/v1/capabilities' \
  '/v1/network/status' \
  '/v1/rounds' \
  '/commit' \
  '/commit/tx' \
  '/bets/ledger' \
  '/close' \
  '/close/tx' \
  '/entropy' \
  '/reveal' \
  '/reveal/tx' \
  '/proof' \
  '/v1/proofs/verify'; do
  grep -R -F "$required" "$APP_DIR" src/client.mjs >/dev/null || fail ROULETTE_POC_API_ENDPOINTS_PRESENT
done
pass ROULETTE_POC_API_ENDPOINTS_PRESENT

PORT="${PORT:-$((42000 + RANDOM % 1000))}"
LOG_FILE="$(mktemp -t roulette-poc-api.XXXXXX.log)"
cleanup() {
  if [[ -n "${SERVER_PID:-}" ]] && kill -0 "$SERVER_PID" 2>/dev/null; then
    kill "$SERVER_PID" 2>/dev/null || true
    wait "$SERVER_PID" 2>/dev/null || true
  fi
  rm -f "$LOG_FILE" /tmp/roulette-poc-forbidden-static.txt /tmp/roulette-poc-forbidden-mock.txt /tmp/roulette-poc-health.json /tmp/roulette-poc-commit-state.json /tmp/roulette-poc-commit-tx.json
}
trap cleanup EXIT

unset TOCCATA_ENABLE_TN10_WRITES TOCCATA_TN10_PRIVATE_KEY TOCCATA_TN10_BROADCAST_ACK TOCCATA_TN10_DESTINATION_ADDRESS
HOST=127.0.0.1 PORT="$PORT" node src/server.cjs >"$LOG_FILE" 2>&1 &
SERVER_PID=$!

for _ in $(seq 1 60); do
  if curl -fsS "http://127.0.0.1:$PORT/v1/health" >/tmp/roulette-poc-health.json 2>/dev/null; then
    break
  fi
  sleep 0.2
done

curl -fsS "http://127.0.0.1:$PORT/v1/health" >/tmp/roulette-poc-health.json || { cat "$LOG_FILE" >&2; fail ROULETTE_POC_API_HEALTH; }
pass ROULETTE_POC_API_HEALTH

curl -fsS "http://127.0.0.1:$PORT$APP_URL_PATH" | grep -F 'Kaspa Toccata Roulette PoC' >/dev/null || fail ROULETTE_POC_PAGE_SERVED
curl -fsS "http://127.0.0.1:$PORT$APP_URL_PATH" | grep -F 'liveProofStatusRoot' >/dev/null || fail ROULETTE_POC_COMPACT_STATUS_ROOT
curl -fsS "http://127.0.0.1:$PORT$APP_URL_PATH" | grep -F 'flowchart-details' >/dev/null || fail ROULETTE_POC_FLOWCHART_COLLAPSIBLE
pass ROULETTE_POC_PAGE_SERVED

curl -fsS "http://127.0.0.1:$PORT/apps/roulette-poc/app.js" | grep -F "from 'kaspa-toccata-api'" >/dev/null || fail ROULETTE_POC_APP_JS_SERVED
curl -fsS "http://127.0.0.1:$PORT/apps/roulette-poc/app.js" | grep -F 'renderCompactStatus' >/dev/null || fail ROULETTE_POC_COMPACT_STATUS_RENDERER_SERVED
curl -fsS "http://127.0.0.1:$PORT/apps/roulette-poc/app.js" | grep -F 'compact-help' >/dev/null || fail ROULETTE_POC_COMPACT_HELP_RENDERER_SERVED
pass ROULETTE_POC_APP_JS_SERVED

curl -fsS "http://127.0.0.1:$PORT/apps/roulette-poc/flowchart-spec.json" | grep -F 'enables chip placement' >/dev/null || fail ROULETTE_POC_FLOWCHART_SPEC_SERVED
curl -fsS "http://127.0.0.1:$PORT/apps/roulette-poc/flowchart-spec.json" | grep -F '"compact"' >/dev/null || fail ROULETTE_POC_COMPACT_SPEC_SERVED
curl -fsS "http://127.0.0.1:$PORT/apps/roulette-poc/flowchart-spec.json" | grep -F '"compactHelp"' >/dev/null || fail ROULETTE_POC_COMPACT_HELP_SPEC_SERVED
curl -fsS "http://127.0.0.1:$PORT/apps/roulette-poc/flowchart-spec.json" | grep -F '"compactLinks"' >/dev/null || fail ROULETTE_POC_COMPACT_LINK_SPEC_SERVED
pass ROULETTE_POC_FLOWCHART_SPEC_SERVED

curl -fsS "http://127.0.0.1:$PORT/apps/roulette-poc/roulette-table-renderer.js" | grep -F 'renderRouletteTable' >/dev/null || fail ROULETTE_POC_RENDERER_SERVED
pass ROULETTE_POC_RENDERER_SERVED

curl -fsS "http://127.0.0.1:$PORT/apps/roulette-poc/roulette-table-layout.js" | grep -F 'createRouletteTableLayout' >/dev/null || fail ROULETTE_POC_LAYOUT_SERVED
pass ROULETTE_POC_LAYOUT_SERVED

curl -fsS "http://127.0.0.1:$PORT/src/client.mjs" | grep -F 'createToccataApiClient' >/dev/null || fail ROULETTE_POC_ESM_CLIENT_SERVED
pass ROULETTE_POC_ESM_CLIENT_SERVED

ROUND_ID="$(curl -fsS -X POST "http://127.0.0.1:$PORT/v1/rounds" -H 'content-type: application/json' -d '{"game":"roulette","tableId":"roulette-poc-smoke"}' | node -e "let s='';process.stdin.on('data',d=>s+=d);process.stdin.on('end',()=>{const j=JSON.parse(s); if(!j.round || !j.round.roundId) process.exit(2); console.log(j.round.roundId);})")"
[[ -n "$ROUND_ID" ]] || fail ROULETTE_POC_API_CREATE_ROUND
pass ROULETTE_POC_API_CREATE_ROUND

curl -fsS -X POST "http://127.0.0.1:$PORT/v1/rounds/$ROUND_ID/commit" -H 'content-type: application/json' -d '{"serverSeed":"roulette-poc-smoke-server-seed"}' >/tmp/roulette-poc-commit-state.json || fail ROULETTE_POC_API_COMMIT_STATE
pass ROULETTE_POC_API_COMMIT_STATE

HTTP_STATUS="$(curl -sS -o /tmp/roulette-poc-commit-tx.json -w '%{http_code}' -X POST "http://127.0.0.1:$PORT/v1/rounds/$ROUND_ID/commit/tx" -H 'content-type: application/json' -d '{}')"
[[ "$HTTP_STATUS" == "403" ]] || fail ROULETTE_POC_TX_FAIL_CLOSED
if grep -F 'tn10_writes_disabled' /tmp/roulette-poc-commit-tx.json >/dev/null; then
  pass ROULETTE_POC_TX_FAIL_CLOSED
else
  cat /tmp/roulette-poc-commit-tx.json >&2
  fail ROULETTE_POC_TX_FAIL_CLOSED
fi

if find "$APP_DIR" -type f \( -name 'sample-round.json' -o -name 'toccata-fairness-proof.json' -o -name 'proof.json' -o -name 'round.json' \) -print | grep -q .; then
  fail ROULETTE_POC_NO_STATIC_PROOF_FIXTURES
fi
pass ROULETTE_POC_NO_STATIC_PROOF_FIXTURES
