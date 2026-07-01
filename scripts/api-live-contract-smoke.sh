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
LOG_FILE="${API_LIVE_CONTRACT_SMOKE_LOG:-/tmp/kaspa-toccata-api-live-contract-smoke.log}"
export HOST PORT BASE_URL KASPA_WRPC_TIMEOUT_MS="${KASPA_WRPC_TIMEOUT_MS:-90000}"

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
  if curl -fsS "$BASE_URL/v1/health" >/tmp/kaspa-toccata-api-live-contract-health.json 2>/dev/null; then
    break
  fi
  sleep 0.2
done

node <<'NODE'
const assert = require('node:assert/strict');
const { createToccataApiClient, ToccataApiError } = require('./src/client.cjs');

async function expectApiError(label, fn, expectedStatus, expectedError) {
  try {
    await fn();
  } catch (error) {
    if (error instanceof ToccataApiError && error.status === expectedStatus && (!expectedError || error.body?.error === expectedError)) {
      console.log(`${label}=PASS`);
      return error.body;
    }
    throw error;
  }
  throw new Error(`${label} expected ${expectedStatus}${expectedError ? ` ${expectedError}` : ''}`);
}

async function main() {
  const client = createToccataApiClient({ baseUrl: process.env.BASE_URL });
  const health = await client.health();
  assert.equal(health.ok, true);
  console.log('API_HEALTH=PASS');

  const capabilities = await client.capabilities();
  assert.equal(capabilities.capabilities.network, 'kaspa-tn10');
  assert.equal(capabilities.capabilities.mainnetEnabled, false);
  console.log('API_CAPABILITIES=PASS');

  const status = await client.networkStatus();
  assert.equal(status.networkId, 'testnet-10');
  assert(status.blockDagInfo, 'live TN10 blockDAG info is required');
  console.log('TN10_STATUS=PASS');

  const created = await client.createRound({ game: 'generic-contract', tableId: 'api-live-contract-smoke' });
  assert.equal(created.round.claimLevel, 'live_tn10_pending');
  assert.equal(created.round.provider, 'rusty-kaspa-toccata-wasm');
  assert.match(created.round.roundId, /^tn10_/);
  const roundId = created.round.roundId;
  console.log(`ROUND_CREATE=PASS # ${roundId}`);

  const serverSeed = `api-live-contract-${Date.now()}`;
  const committed = await client.commitRound(roundId, { serverSeed });
  assert.equal(committed.round.status, 'committed');
  console.log('ROUND_COMMIT_STATE=PASS');

  await expectApiError('ROUND_COMMIT_TX_FAIL_CLOSED', () => client.createCommitTx(roundId, {}), 403, 'tn10_writes_disabled');
  await expectApiError('LOCAL_ENTROPY_DISABLED', () => client.closeRound(roundId, { clientSeed: 'contract-local-disabled' }), 400, 'bad_request');
  await expectApiError('DRY_RUN_FORBIDDEN', () => client.createCommitTx(roundId, { dryRun: true }), 400, 'dry_run_forbidden');

  const closed = await client.closeRound(roundId, { clientSeed: 'contract-live-tn10-client-seed', entropyMode: 'live_tn10_future', targetOffsetBlueScore: 1 });
  assert.equal(closed.round.status, 'closed');
  assert.equal(closed.round.claimLevel, 'tn10_future_entropy');
  console.log('ROUND_CLOSE_STATE=PASS');

  await expectApiError('ROUND_CLOSE_TX_FAIL_CLOSED', () => client.createCloseTx(roundId, {}), 403, 'tn10_writes_disabled');

  let entropy;
  for (let i = 0; i < 60; i++) {
    try {
      entropy = await client.getEntropy(roundId);
      break;
    } catch (error) {
      if (error.status !== 409 && error.status !== 503) throw error;
      await new Promise((resolve) => setTimeout(resolve, 500));
    }
  }
  assert(entropy && entropy.entropy && entropy.entropy.evidence.blockHash, 'future entropy fetched');
  const revealed = await client.revealRound(roundId, { serverSeed });
  assert.equal(revealed.round.status, 'revealed');
  console.log('ROUND_REVEAL_STATE=PASS');

  await expectApiError('ROUND_REVEAL_TX_FAIL_CLOSED', () => client.createRevealTx(roundId, {}), 403, 'tn10_writes_disabled');

  console.log('API_LIVE_CONTRACT_READY=PASS # generic commit/close/reveal endpoints exist and fail closed by default; live broadcasts require explicit TN10 gates');
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
