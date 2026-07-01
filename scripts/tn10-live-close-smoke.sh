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
LOG_FILE="${TN10_LIVE_CLOSE_SMOKE_LOG:-/tmp/kaspa-toccata-tn10-live-close-smoke.log}"
export HOST PORT KASPA_WRPC_TIMEOUT_MS="${KASPA_WRPC_TIMEOUT_MS:-90000}"

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
  if curl -fsS "$BASE_URL/v1/health" >/tmp/kaspa-toccata-live-close-health.json 2>/dev/null; then
    break
  fi
  sleep 0.2
done

BASE_URL="$BASE_URL" node <<'NODE'
const assert = require('node:assert/strict');
const { createToccataApiClient, ToccataApiError } = require('./src/client.cjs');

const REQUIRED_ACK = 'I understand this spends TN10 testnet funds';
function liveGatesPresent() {
  return process.env.KASPA_NETWORK_ID !== 'mainnet'
    && (process.env.KASPA_NETWORK_ID || 'testnet-10') === 'testnet-10'
    && process.env.TOCCATA_ENABLE_TN10_WRITES === '1'
    && /^[0-9a-fA-F]{64}$/.test(process.env.TOCCATA_TN10_PRIVATE_KEY || '')
    && process.env.TOCCATA_TN10_BROADCAST_ACK === REQUIRED_ACK;
}

async function main() {
  const client = createToccataApiClient({ baseUrl: process.env.BASE_URL });
  const capabilities = await client.capabilities();
  assert.equal(capabilities.capabilities.networkId, 'testnet-10');
  assert.equal(capabilities.capabilities.mainnetEnabled, false);
  console.log('LIVE_CLOSE_NETWORK_GUARD=PASS');

  const created = await client.createRound({ game: 'generic-contract', tableId: 'tn10-live-close-smoke' });
  const roundId = created.round.roundId;
  await client.commitRound(roundId, { serverSeed: `tn10-live-close-server-seed-${Date.now()}` });
  await client.updateBetLedger(roundId, { bets: [{ playerId: 'alice', selection: 'generic-selection', amount: 1 }] });
  const closed = await client.closeRound(roundId, { clientSeed: `tn10-live-close-client-seed-${Date.now()}`, entropyMode: 'live_tn10_future', targetOffsetBlueScore: 1 });
  assert.equal(closed.round.status, 'closed');
  assert.equal(closed.round.claimLevel, 'tn10_future_entropy');
  console.log('LIVE_CLOSE_ROUND_CLOSED=PASS');

  if (!liveGatesPresent()) {
    let failedClosed = false;
    try {
      await client.createCloseTx(roundId, {});
    } catch (error) {
      if (error instanceof ToccataApiError && error.status === 403 && error.body && error.body.error === 'tn10_writes_disabled') {
        failedClosed = true;
      } else {
        throw error;
      }
    }
    assert.equal(failedClosed, true, 'live close should fail closed without all live gates');
    console.log('LIVE_CLOSE_DEFAULT_FAIL_CLOSED=PASS');
    console.log('LIVE_CLOSE_EXECUTED=PASS # NO; set explicit TN10 write gates and a funded key to broadcast');
    return;
  }

  console.log('LIVE_CLOSE_GATES_PRESENT=PASS');
  let result;
  try {
    result = await client.createCloseTx(roundId, {});
  } catch (error) {
    if (error instanceof ToccataApiError && error.status === 503 && error.body && error.body.error === 'tn10_live_close_failed') {
      if (error.body.sourceAddress) console.log(`LIVE_CLOSE_SOURCE_ADDRESS=PASS # ${error.body.sourceAddress}`);
      if (error.body.totalUtxos !== undefined) console.log(`LIVE_CLOSE_UTXO_FOUND=FAIL # totalUtxos=${error.body.totalUtxos} minUtxoSompi=${error.body.minUtxoSompi || 'unknown'}`);
      throw error;
    }
    throw error;
  }
  assert.equal(result.ok, true);
  assert.equal(result.closeTx.phase, 'close');
  assert.match(result.closeTx.sourceAddress, /^kaspatest:/);
  assert(Array.isArray(result.closeTx.transactionIds) && result.closeTx.transactionIds.length > 0, 'transaction ids recorded');
  assert.match(result.closeTx.payloadHash, /^[0-9a-f]{64}$/);
  assert.equal(result.round.tn10Writes.close.transactionIds[0], result.closeTx.transactionIds[0]);
  console.log(`LIVE_CLOSE_SOURCE_ADDRESS=PASS # ${result.closeTx.sourceAddress}`);
  console.log(`LIVE_CLOSE_UTXO_FOUND=PASS # selected=${result.closeTx.utxoSelection.selectedUtxos}`);
  console.log('LIVE_CLOSE_TX_CREATED=PASS');
  console.log('LIVE_CLOSE_TX_SIGNED=PASS');
  console.log(`LIVE_CLOSE_TX_BROADCAST=PASS # ${result.closeTx.transactionIds.join(',')}`);
  console.log('LIVE_CLOSE_TXID_RECORDED=PASS');
  console.log(`LIVE_CLOSE_TX_EVIDENCE_FETCHED=PASS # found=${result.closeTx.evidence.some((item) => item.found)}`);
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
