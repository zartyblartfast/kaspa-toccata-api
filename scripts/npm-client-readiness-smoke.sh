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
LOG_FILE="${NPM_CLIENT_READINESS_LOG:-/tmp/kaspa-toccata-npm-client-readiness.log}"
WORKDIR="${NPM_CLIENT_READINESS_WORKDIR:-$(mktemp -d /tmp/kaspa-toccata-npm-readiness.XXXXXX)}"
export HOST PORT KASPA_WRPC_TIMEOUT_MS="${KASPA_WRPC_TIMEOUT_MS:-60000}"

pass() { printf '%s=PASS%s\n' "$1" "${2:+ # $2}"; }
fail() { printf '%s=FAIL%s\n' "$1" "${2:+ # $2}"; }

PACKAGE_NAME="$(node -p "require('./package.json').name")"
PACKAGE_VERSION="$(node -p "require('./package.json').version")"
PACKAGE_PRIVATE="$(node -p "Boolean(require('./package.json').private)")"
[ "$PACKAGE_NAME" = "kaspa-toccata-api" ] && pass PACKAGE_NAME_OK "$PACKAGE_NAME" || { fail PACKAGE_NAME_OK "$PACKAGE_NAME"; exit 2; }
[ "$PACKAGE_PRIVATE" = "false" ] && pass PACKAGE_PUBLIC_OK || { fail PACKAGE_PUBLIC_OK "package private flag is true"; exit 2; }
node -e "const p=require('./package.json'); if(!p.main||!p.types||!p.exports||!p.files) process.exit(2)" && pass PACKAGE_METADATA_OK "$PACKAGE_VERSION"
node -e "require('./src/client.cjs');" && pass PACKAGE_EXPORTS_OK
node -e "const fs=require('fs'); const d=fs.readFileSync('src/client.d.ts','utf8'); for (const s of ['createToccataApiClient','createCommitTx','createCloseTx','createRevealTx','CloseRoundInput']) if(!d.includes(s)) throw new Error(s);" && pass PACKAGE_TYPES_OK

if grep --line-number -E 'TOCCATA_TN10_PRIVATE_KEY|BEGIN (RSA|OPENSSH|EC|PRIVATE) KEY|npm_[A-Za-z0-9]' \
  src/client.cjs src/client.d.ts README.md docs/VERIFY_TN10_TRANSACTIONS.md docs/API_STATUS.md package.json LICENSE \
  >/tmp/kaspa-toccata-secret-scan.txt 2>/dev/null; then
  fail NO_PRIVATE_KEYS_IN_PACKAGE "potential secret marker found in package files"
  cat /tmp/kaspa-toccata-secret-scan.txt
  exit 2
fi
pass NO_PRIVATE_KEYS_IN_PACKAGE

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

for _ in $(seq 1 80); do
  if curl -fsS "$BASE_URL/v1/health" >/tmp/kaspa-toccata-npm-readiness-health.json 2>/dev/null; then
    break
  fi
  sleep 0.2
done
curl -fsS "$BASE_URL/v1/health" >/dev/null && pass PACKAGE_TEST_API_STARTED

TARBALL="$(npm pack --silent)"
case "$TARBALL" in
  *.tgz) pass PACKAGE_PACK_OK "$TARBALL" ;;
  *) fail PACKAGE_PACK_OK "unexpected npm pack output: $TARBALL"; exit 2 ;;
esac

CONTENTS="$(tar -tzf "$TARBALL")"
for required in \
  package/package.json \
  package/src/client.cjs \
  package/src/client.d.ts \
  package/README.md \
  package/LICENSE \
  package/docs/API_STATUS.md \
  package/docs/VERIFY_TN10_TRANSACTIONS.md; do
  if ! printf '%s\n' "$CONTENTS" | grep -qx "$required"; then
    fail PACKAGE_TARBALL_CONTENTS_OK "missing $required"
    printf '%s\n' "$CONTENTS"
    exit 2
  fi
done
if printf '%s\n' "$CONTENTS" | grep -Eq '^package/(src/server\.cjs|scripts/|spikes/|\.env|.*private.*key|.*wallet)'; then
  fail NO_SERVER_INTERNALS_EXPORTED
  printf '%s\n' "$CONTENTS"
  exit 2
fi
pass PACKAGE_TARBALL_CONTENTS_OK
pass NO_SERVER_INTERNALS_EXPORTED

mkdir -p "$WORKDIR/consumer"
cp "$TARBALL" "$WORKDIR/consumer/"
(
  cd "$WORKDIR/consumer"
  npm init -y >/dev/null
  npm install --silent "./$TARBALL"
  BASE_URL="$BASE_URL" PACKAGE_NAME="$PACKAGE_NAME" node <<'NODE'
const assert = require('node:assert/strict');
const api = require(process.env.PACKAGE_NAME);
assert.equal(typeof api.ToccataApiClient, 'function');
assert.equal(typeof api.createToccataApiClient, 'function');
assert.equal(typeof api.ToccataApiError, 'function');
const client = api.createToccataApiClient({ baseUrl: process.env.BASE_URL });
(async () => {
  const health = await client.health();
  assert.equal(health.ok, true);
  const created = await client.createRound({ game: 'generic-contract', tableId: 'npm-readiness-smoke' });
  assert.match(created.round.roundId, /^tn10_/);
  assert.equal(created.round.claimLevel, 'live_tn10_pending');
  console.log('PACKAGE_CONSUMER_IMPORT=PASS');
  console.log('PACKAGE_CONSUMER_API_CALL=PASS # ' + created.round.roundId);
})().catch((error) => {
  console.error(error.stack || error.message || String(error));
  process.exit(2);
});
NODE
)

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
pass NPM_CLIENT_READY
