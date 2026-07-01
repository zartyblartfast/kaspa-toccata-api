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
LOG_FILE="${CLIENT_PACKAGE_BOUNDARY_LOG:-/tmp/kaspa-toccata-client-package-boundary.log}"
WORKDIR="${CLIENT_PACKAGE_BOUNDARY_WORKDIR:-$(mktemp -d /tmp/kaspa-toccata-client-package.XXXXXX)}"
export HOST PORT KASPA_WRPC_TIMEOUT_MS="${KASPA_WRPC_TIMEOUT_MS:-60000}"

pass() { printf '%s=PASS%s\n' "$1" "${2:+ # $2}"; }
fail() { printf '%s=FAIL%s\n' "$1" "${2:+ # $2}"; }

node src/server.cjs >"$LOG_FILE" 2>&1 &
server_pid=$!
TARBALL=""
cleanup() {
  if kill -0 "$server_pid" >/dev/null 2>&1; then
    kill "$server_pid" >/dev/null 2>&1 || true
    wait "$server_pid" >/dev/null 2>&1 || true
  fi
  rm -rf "$WORKDIR"
  if [ -n "$TARBALL" ] && [ -f "$ROOT/$TARBALL" ]; then
    rm -f "$ROOT/$TARBALL"
  fi
}
trap cleanup EXIT

for _ in $(seq 1 50); do
  if curl -fsS "$BASE_URL/v1/health" >/tmp/kaspa-toccata-client-package-health.json 2>/dev/null; then
    break
  fi
  sleep 0.2
done

TARBALL="$(npm pack --silent)"
case "$TARBALL" in
  *.tgz) ;;
  *) fail CLIENT_PACKAGE_PACK_OK "unexpected npm pack output: $TARBALL"; exit 2 ;;
esac
pass CLIENT_PACKAGE_PACK_OK "$TARBALL"

mkdir -p "$WORKDIR/consumer"
cp "$TARBALL" "$WORKDIR/consumer/"
(
  cd "$WORKDIR/consumer"
  npm init -y >/dev/null
  npm install --silent "./$TARBALL"
  BASE_URL="$BASE_URL" node <<'NODE'
const assert = require('node:assert/strict');
const api = require('kaspa-toccata-api');
assert.equal(typeof api.ToccataApiClient, 'function');
assert.equal(typeof api.createToccataApiClient, 'function');
assert.equal(typeof api.ToccataApiError, 'function');
const client = api.createToccataApiClient({ baseUrl: process.env.BASE_URL });
(async () => {
  const health = await client.health();
  assert.equal(health.ok, true);
  const created = await client.createRound({ game: 'roulette', tableId: 'package-boundary-smoke' });
  assert.equal(created.round.claimLevel, 'live_tn10_pending');
  const fetched = await client.getRound(created.round.roundId);
  assert.equal(fetched.round.roundId, created.round.roundId);
  console.log('CLIENT_PACKAGE_CONSUMER_IMPORT=PASS');
  console.log('CLIENT_PACKAGE_CONSUMER_API_CALL=PASS # ' + created.round.roundId);
})().catch((error) => {
  console.error(error.stack || error.message || String(error));
  process.exit(2);
});
NODE
)

CONTENTS="$(tar -tzf "$TARBALL")"
if printf '%s\n' "$CONTENTS" | grep -q '^package/src/client.cjs$' && printf '%s\n' "$CONTENTS" | grep -q '^package/src/client.d.ts$'; then
  pass CLIENT_PACKAGE_TARBALL_CONTENTS_OK
else
  fail CLIENT_PACKAGE_TARBALL_CONTENTS_OK "client.cjs/client.d.ts missing"
  printf '%s\n' "$CONTENTS"
  exit 2
fi

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
