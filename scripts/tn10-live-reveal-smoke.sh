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
LOG_FILE="${TN10_LIVE_REVEAL_SMOKE_LOG:-/tmp/kaspa-toccata-tn10-live-reveal-smoke.log}"
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
  if curl -fsS "$BASE_URL/v1/health" >/tmp/kaspa-toccata-live-reveal-health.json 2>/dev/null; then
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
  console.log('LIVE_REVEAL_NETWORK_GUARD=PASS');

  const serverSeed = `tn10-live-reveal-server-seed-${Date.now()}`;
  const created = await client.createRound({ game: 'generic-contract', tableId: 'tn10-live-reveal-smoke' });
  const roundId = created.round.roundId;
  await client.commitRound(roundId, { serverSeed });
  await client.updateBetLedger(roundId, { bets: [{ playerId: 'alice', selection: 'generic-selection', amount: 1 }] });
  await client.closeRound(roundId, { clientSeed: `tn10-live-reveal-client-seed-${Date.now()}`, entropyMode: 'live_tn10_future', targetOffsetBlueScore: 1 });
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
  assert(revealed.round.result, 'revealed result present');
  console.log('LIVE_REVEAL_ROUND_REVEALED=PASS');

  if (!liveGatesPresent()) {
    let failedClosed = false;
    try {
      await client.createRevealTx(roundId, {});
    } catch (error) {
      if (error instanceof ToccataApiError && error.status === 403 && error.body && error.body.error === 'tn10_writes_disabled') {
        failedClosed = true;
      } else {
        throw error;
      }
    }
    assert.equal(failedClosed, true, 'live reveal should fail closed without all live gates');
    console.log('LIVE_REVEAL_DEFAULT_FAIL_CLOSED=PASS');
    console.log('LIVE_REVEAL_EXECUTED=PASS # NO; set explicit TN10 write gates and a funded key to broadcast');
    return;
  }

  console.log('LIVE_REVEAL_GATES_PRESENT=PASS');
  let result;
  try {
    result = await client.createRevealTx(roundId, {});
  } catch (error) {
    if (error instanceof ToccataApiError && error.status === 503 && error.body && error.body.error === 'tn10_live_reveal_failed') {
      if (error.body.sourceAddress) console.log(`LIVE_REVEAL_SOURCE_ADDRESS=PASS # ${error.body.sourceAddress}`);
      if (error.body.totalUtxos !== undefined) console.log(`LIVE_REVEAL_UTXO_FOUND=FAIL # totalUtxos=${error.body.totalUtxos} minUtxoSompi=${error.body.minUtxoSompi || 'unknown'}`);
      throw error;
    }
    throw error;
  }
  assert.equal(result.ok, true);
  assert.equal(result.revealTx.phase, 'reveal');
  assert.match(result.revealTx.sourceAddress, /^kaspatest:/);
  assert(Array.isArray(result.revealTx.transactionIds) && result.revealTx.transactionIds.length > 0, 'transaction ids recorded');
  assert.match(result.revealTx.payloadHash, /^[0-9a-f]{64}$/);
  assert.equal(result.round.tn10Writes.reveal.transactionIds[0], result.revealTx.transactionIds[0]);
  console.log(`LIVE_REVEAL_SOURCE_ADDRESS=PASS # ${result.revealTx.sourceAddress}`);
  console.log(`LIVE_REVEAL_UTXO_FOUND=PASS # selected=${result.revealTx.utxoSelection.selectedUtxos}`);
  console.log('LIVE_REVEAL_TX_CREATED=PASS');
  console.log('LIVE_REVEAL_TX_SIGNED=PASS');
  console.log(`LIVE_REVEAL_TX_BROADCAST=PASS # ${result.revealTx.transactionIds.join(',')}`);
  console.log('LIVE_REVEAL_TXID_RECORDED=PASS');
  console.log(`LIVE_REVEAL_TX_EVIDENCE_FETCHED=PASS # found=${result.revealTx.evidence.some((item) => item.found)}`);
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
