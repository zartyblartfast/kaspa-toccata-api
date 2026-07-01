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
LOG_FILE="${API_SMOKE_LOG:-/tmp/kaspa-toccata-api-smoke.log}"
KASPA_WASM_PKG="${KASPA_WASM_PKG:-/tmp/kaspa-toccata-api-spikes/rusty-kaspa-toccata/wasm/nodejs/kaspa}"
export HOST PORT KASPA_WASM_PKG KASPA_WRPC_TIMEOUT_MS="${KASPA_WRPC_TIMEOUT_MS:-60000}"

pass() { printf '%s=PASS%s\n' "$1" "${2:+ # $2}"; }
fail() { printf '%s=FAIL%s\n' "$1" "${2:+ # $2}"; }

if [ ! -f "$KASPA_WASM_PKG/kaspa.js" ] || [ ! -f "$KASPA_WASM_PKG/kaspa_bg.wasm" ]; then
  fail API_PREREQ_KASPA_WASM_PKG "$KASPA_WASM_PKG missing; run spikes/npm-toccata-wasm-capability/build-and-check-wasm.sh"
  exit 2
fi
pass API_PREREQ_KASPA_WASM_PKG "$KASPA_WASM_PKG"

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
  if curl -fsS "$BASE_URL/v1/health" >/tmp/kaspa-toccata-health.json 2>/dev/null; then
    break
  fi
  sleep 0.2
done

if ! curl -fsS "$BASE_URL/v1/health" -o /tmp/kaspa-toccata-health.json; then
  fail HEALTH_OK "server did not become ready; see $LOG_FILE"
  exit 2
fi
node -e 'const fs=require("fs"); const j=JSON.parse(fs.readFileSync("/tmp/kaspa-toccata-health.json","utf8")); if(!j.ok || j.service!=="kaspa-toccata-api") process.exit(1);'
pass HEALTH_OK

if ! curl -fsS "$BASE_URL/v1/capabilities" -o /tmp/kaspa-toccata-capabilities.json; then
  fail CAPABILITIES_OK
  exit 2
fi
node <<'NODE'
const fs = require('fs');
const j = JSON.parse(fs.readFileSync('/tmp/kaspa-toccata-capabilities.json', 'utf8'));
if (!j.ok) throw new Error('capabilities ok=false');
const c = j.capabilities || {};
if (c.canSign !== false) throw new Error('canSign must be false');
if (c.canBroadcast !== false) throw new Error('canBroadcast must be false');
if (c.canCreateTransactions !== false) throw new Error('canCreateTransactions must be false');
if (c.mainnetEnabled !== false) throw new Error('mainnetEnabled must be false');
if (c.networkId !== 'testnet-10') throw new Error(`unexpected networkId ${c.networkId}`);
NODE
pass CAPABILITIES_OK

if ! curl -fsS "$BASE_URL/v1/network/status" -o /tmp/kaspa-toccata-network-status.json; then
  fail TN10_STATUS_OK "GET /v1/network/status failed; see $LOG_FILE"
  if [ -f /tmp/kaspa-toccata-network-status.json ]; then cat /tmp/kaspa-toccata-network-status.json >&2; fi
  exit 2
fi
node <<'NODE'
const fs = require('fs');
const j = JSON.parse(fs.readFileSync('/tmp/kaspa-toccata-network-status.json', 'utf8'));
if (!j.ok) throw new Error('network status ok=false');
if (j.claimLevel !== 'live_tn10_status') throw new Error(`unexpected claimLevel ${j.claimLevel}`);
if (j.networkId !== 'testnet-10') throw new Error(`unexpected networkId ${j.networkId}`);
if (!j.serverInfo || j.serverInfo.networkId !== 'testnet-10') throw new Error('missing testnet-10 serverInfo');
if (!j.blockDagInfo || !j.blockDagInfo.virtualDaaScore || !Array.isArray(j.blockDagInfo.tipHashes)) throw new Error('missing live blockDagInfo evidence');
if (j.capabilities.canSign !== false || j.capabilities.canBroadcast !== false || j.capabilities.canCreateTransactions !== false || j.capabilities.mainnetEnabled !== false) {
  throw new Error('unsafe capability flag');
}
NODE
pass TN10_STATUS_OK

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
