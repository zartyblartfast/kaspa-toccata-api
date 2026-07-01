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
LOG_FILE="${TN10_WRITE_SMOKE_LOG:-/tmp/kaspa-toccata-tn10-write-smoke.log}"
export HOST PORT KASPA_WRPC_TIMEOUT_MS="${KASPA_WRPC_TIMEOUT_MS:-60000}"
unset TOCCATA_ENABLE_TN10_WRITES TOCCATA_TN10_PRIVATE_KEY TOCCATA_TN10_BROADCAST_ACK || true

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
  if curl -fsS "$BASE_URL/v1/health" >/tmp/kaspa-toccata-write-health.json 2>/dev/null; then
    break
  fi
  sleep 0.2
done

BASE_URL="$BASE_URL" node <<'NODE'
const assert = require('node:assert/strict');
const { createToccataApiClient, ToccataApiError } = require('./src/client.cjs');

async function main() {
  const client = createToccataApiClient({ baseUrl: process.env.BASE_URL });
  const capabilities = await client.capabilities();
  assert.equal(capabilities.capabilities.networkId, 'testnet-10');
  assert.equal(capabilities.capabilities.mainnetEnabled, false);
  assert.equal(capabilities.capabilities.canSign, false);
  assert.equal(capabilities.capabilities.canBroadcast, false);
  assert.equal(capabilities.capabilities.providers.write, 'disabled');
  console.log('NETWORK_GUARD=PASS');
  console.log('WRITE_DEFAULT_DISABLED=PASS');

  const created = await client.createRound({ game: 'roulette', tableId: 'tn10-write-smoke' });
  const roundId = created.round.roundId;
  await client.commitRound(roundId, { serverSeed: 'tn10-write-server-seed' });

  for (const [label, fn] of [
    ['COMMIT_TX_DRY_RUN_FORBIDDEN', () => client.createCommitTx(roundId, { dryRun: true })]
  ]) {
    let forbidden = false;
    try {
      await fn();
    } catch (error) {
      if (error instanceof ToccataApiError && error.status === 400 && error.body && error.body.error === 'dry_run_forbidden') {
        forbidden = true;
      } else {
        throw error;
      }
    }
    assert.equal(forbidden, true, `${label} should reject dry-run requests`);
    console.log(`${label}=PASS`);
  }

  await client.updateBetLedger(roundId, { bets: [{ playerId: 'alice', selection: 'black', amount: 5 }] });
  await client.closeRound(roundId, {
    clientSeed: 'tn10-write-client-seed',
    entropyMode: 'live_tn10_future',
    targetOffsetBlueScore: 1
  });
  for (const [label, fn] of [
    ['CLOSE_TX_DRY_RUN_FORBIDDEN', () => client.createCloseTx(roundId, { dryRun: true })]
  ]) {
    let forbidden = false;
    try {
      await fn();
    } catch (error) {
      if (error instanceof ToccataApiError && error.status === 400 && error.body && error.body.error === 'dry_run_forbidden') {
        forbidden = true;
      } else {
        throw error;
      }
    }
    assert.equal(forbidden, true, `${label} should reject dry-run requests`);
    console.log(`${label}=PASS`);
  }

  let entropy;
  for (let i = 0; i < 40; i++) {
    try {
      entropy = await client.getEntropy(roundId);
      break;
    } catch (error) {
      if (error.status !== 409 && error.status !== 503) throw error;
      await new Promise((resolve) => setTimeout(resolve, 500));
    }
  }
  assert(entropy && entropy.entropy && entropy.entropy.evidence.blockHash, 'future entropy fetched');
  const revealed = await client.revealRound(roundId, { serverSeed: 'tn10-write-server-seed' });
  assert.equal(revealed.round.status, 'revealed');
  for (const [label, fn] of [
    ['REVEAL_TX_DRY_RUN_FORBIDDEN', () => client.createRevealTx(roundId, { dryRun: true })]
  ]) {
    let forbidden = false;
    try {
      await fn();
    } catch (error) {
      if (error instanceof ToccataApiError && error.status === 400 && error.body && error.body.error === 'dry_run_forbidden') {
        forbidden = true;
      } else {
        throw error;
      }
    }
    assert.equal(forbidden, true, `${label} should reject dry-run requests`);
    console.log(`${label}=PASS`);
  }

  for (const [label, fn] of [
    ['COMMIT_TX_BROADCAST_FAIL_CLOSED', () => client.createCommitTx(roundId, {})],
    ['CLOSE_TX_BROADCAST_FAIL_CLOSED', () => client.createCloseTx(roundId, {})],
    ['REVEAL_TX_BROADCAST_FAIL_CLOSED', () => client.createRevealTx(roundId, {})]
  ]) {
    let failedClosed = false;
    try {
      await fn();
    } catch (error) {
      if (error instanceof ToccataApiError && error.status === 403 && error.body && error.body.error === 'tn10_writes_disabled') {
        failedClosed = true;
      } else {
        throw error;
      }
    }
    assert.equal(failedClosed, true, `${label} should fail closed`);
    console.log(`${label}=PASS`);
  }

  const proof = await client.getProof(roundId);
  const verified = await client.verifyProof(proof.proof);
  assert.equal(verified.verified, true);
  console.log('PROOF_VERIFIED=PASS');
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
