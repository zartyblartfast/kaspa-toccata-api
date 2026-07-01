#!/usr/bin/env node
'use strict';

const path = process.env.KASPA_WASM_PKG || '/tmp/kaspa-toccata-api-spikes/rusty-kaspa-toccata/wasm/nodejs/kaspa';
const NETWORK_ID = process.env.KASPA_NETWORK_ID || 'testnet-10';
const ENABLE_WRITES = process.env.TOCCATA_ENABLE_TN10_WRITES === '1';
const PRIVATE_KEY_HEX = process.env.TOCCATA_TN10_PRIVATE_KEY || '';
const BROADCAST_ACK = process.env.TOCCATA_TN10_BROADCAST_ACK || '';
const REQUIRED_ACK = 'I understand this spends TN10 testnet funds';
const AMOUNT_SOMPI = BigInt(process.env.TOCCATA_TN10_SEND_AMOUNT_SOMPI || '10000000');
const PRIORITY_FEE_SOMPI = BigInt(process.env.TOCCATA_TN10_PRIORITY_FEE_SOMPI || '0');
const TIMEOUT_MS = Number(process.env.KASPA_WRPC_TIMEOUT_MS || 60000);
const MIN_UTXO_SOMPI = AMOUNT_SOMPI + 1_000_000n;

function emit(key, value, detail) {
  console.log(`${key}=${value}${detail ? ` # ${detail}` : ''}`);
}

function json(value) {
  return JSON.stringify(value, (_k, v) => typeof v === 'bigint' ? v.toString() : v);
}

function withTimeout(label, promise, timeoutMs = TIMEOUT_MS) {
  let timer;
  const timeout = new Promise((_, reject) => {
    timer = setTimeout(() => reject(new Error(`${label} timed out after ${timeoutMs}ms`)), timeoutMs);
  });
  return Promise.race([promise, timeout]).finally(() => clearTimeout(timer));
}

function guard() {
  let ok = true;
  if (NETWORK_ID !== 'testnet-10') {
    emit('LIVE_TN10_NETWORK_GUARD', 'FAIL', `KASPA_NETWORK_ID must be testnet-10, got ${NETWORK_ID}`);
    ok = false;
  } else {
    emit('LIVE_TN10_NETWORK_GUARD', 'PASS', NETWORK_ID);
  }

  if (!ENABLE_WRITES) {
    emit('LIVE_TN10_WRITE_ENABLE_GUARD', 'PASS', 'TOCCATA_ENABLE_TN10_WRITES is not 1; broadcast disabled');
    ok = false;
  } else {
    emit('LIVE_TN10_WRITE_ENABLE_GUARD', 'PASS', 'explicit write env enabled');
  }

  if (BROADCAST_ACK !== REQUIRED_ACK) {
    emit('LIVE_TN10_BROADCAST_ACK_GUARD', 'PASS', 'ack phrase missing/mismatched; broadcast disabled');
    ok = false;
  } else {
    emit('LIVE_TN10_BROADCAST_ACK_GUARD', 'PASS', 'explicit broadcast acknowledgement present');
  }

  if (!/^[0-9a-fA-F]{64}$/.test(PRIVATE_KEY_HEX)) {
    emit('LIVE_TN10_PRIVATE_KEY_GUARD', 'PASS', 'TOCCATA_TN10_PRIVATE_KEY missing or not 64 hex chars; broadcast disabled');
    ok = false;
  } else {
    emit('LIVE_TN10_PRIVATE_KEY_GUARD', 'PASS', 'private key supplied via env; value not printed');
  }

  if (AMOUNT_SOMPI <= 0n) {
    emit('LIVE_TN10_AMOUNT_GUARD', 'FAIL', 'TOCCATA_TN10_SEND_AMOUNT_SOMPI must be positive');
    ok = false;
  } else {
    emit('LIVE_TN10_AMOUNT_GUARD', 'PASS', `amountSompi=${AMOUNT_SOMPI.toString()}`);
  }

  return ok;
}

async function main() {
  let kaspa;
  try {
    kaspa = require(path);
    emit('LIVE_TN10_WASM_IMPORT', 'PASS', path);
  } catch (error) {
    emit('LIVE_TN10_WASM_IMPORT', 'FAIL', error.message);
    process.exitCode = 2;
    return;
  }

  const required = ['PrivateKey', 'createTransactions', 'RpcClient', 'Resolver', 'Encoding'];
  let missing = false;
  for (const name of required) {
    const ok = kaspa[name] !== undefined;
    emit(`LIVE_TN10_EXPORT_${name}`, ok ? 'PASS' : 'FAIL');
    missing ||= !ok;
  }
  if (missing) {
    emit('LIVE_TN10_BROADCAST_VERDICT', 'INVALIDATED', 'required exports missing');
    process.exitCode = 2;
    return;
  }

  const guardsOk = guard();
  if (!guardsOk) {
    emit('LIVE_TN10_BROADCAST_EXECUTED', 'PASS', 'NO; fail-closed guards prevented live broadcast');
    emit('LIVE_TN10_BROADCAST_VERDICT', 'GUARDED', 'set all required env vars to execute live TN10 broadcast');
    return;
  }

  const { PrivateKey, createTransactions, RpcClient, Resolver, Encoding } = kaspa;
  const privateKey = new PrivateKey(PRIVATE_KEY_HEX);
  const sourceAddress = privateKey.toKeypair().toAddress(NETWORK_ID);
  const destinationAddress = process.env.TOCCATA_TN10_DESTINATION_ADDRESS || sourceAddress.toString();
  emit('LIVE_TN10_SOURCE_ADDRESS', 'PASS', sourceAddress.toString());
  emit('LIVE_TN10_DESTINATION_ADDRESS', 'PASS', destinationAddress);

  const resolver = new Resolver();
  const resolvedUrl = await withTimeout('resolver.getUrl', resolver.getUrl(Encoding.Borsh, NETWORK_ID), 20000);
  emit('LIVE_TN10_RESOLVER_GET_URL', 'PASS', resolvedUrl);

  const rpc = new RpcClient({ resolver, networkId: NETWORK_ID, encoding: Encoding.Borsh });
  let connected = false;
  try {
    await withTimeout('rpc.connect', rpc.connect(), TIMEOUT_MS);
    connected = true;
    emit('LIVE_TN10_RPC_CONNECT', 'PASS', rpc.url || resolvedUrl);

    const info = await withTimeout('rpc.getServerInfo', rpc.getServerInfo(), 20000);
    if (info.networkId !== NETWORK_ID || !info.isSynced) {
      emit('LIVE_TN10_SERVER_INFO', 'FAIL', json({ networkId: info.networkId, isSynced: info.isSynced }));
      process.exitCode = 2;
      return;
    }
    emit('LIVE_TN10_SERVER_INFO', 'PASS', json({ networkId: info.networkId, isSynced: info.isSynced, hasUtxoIndex: info.hasUtxoIndex }));

    const utxoResponse = await withTimeout('rpc.getUtxosByAddresses', rpc.getUtxosByAddresses([sourceAddress]), 30000);
    const entries = (utxoResponse.entries || []).filter((entry) => !entry.isCoinbase && BigInt(entry.amount) >= MIN_UTXO_SOMPI);
    emit('LIVE_TN10_UTXO_LOOKUP', entries.length ? 'PASS' : 'FAIL', json({ totalEntries: utxoResponse.entries?.length || 0, spendableForSpike: entries.length, minUtxoSompi: MIN_UTXO_SOMPI }));
    if (!entries.length) {
      emit('LIVE_TN10_BROADCAST_EXECUTED', 'PASS', 'NO; no sufficiently funded non-coinbase UTXO found');
      emit('LIVE_TN10_BROADCAST_VERDICT', 'BLOCKED', 'fund the source address on testnet-10 and retry');
      process.exitCode = 2;
      return;
    }

    entries.sort((a, b) => BigInt(a.amount) > BigInt(b.amount) ? 1 : -1);
    const { transactions, summary } = await createTransactions({
      entries,
      outputs: [{ address: destinationAddress, amount: AMOUNT_SOMPI }],
      priorityFee: PRIORITY_FEE_SOMPI,
      changeAddress: sourceAddress,
      networkId: NETWORK_ID
    });
    emit('LIVE_TN10_CREATE_TRANSACTIONS', transactions.length ? 'PASS' : 'FAIL', json({ transactions: transactions.length, summary: summary.toJSON ? summary.toJSON() : summary }));
    if (!transactions.length) {
      process.exitCode = 2;
      return;
    }

    const submitted = [];
    for (const pending of transactions) {
      pending.sign([privateKey], true);
      emit('LIVE_TN10_SIGN_PENDING_TRANSACTION', 'PASS', pending.transaction.id);
      const txid = await withTimeout('pending.submit', pending.submit(rpc), TIMEOUT_MS);
      submitted.push(txid);
      emit('LIVE_TN10_SUBMIT_TRANSACTION', 'PASS', String(txid));
    }

    emit('LIVE_TN10_BROADCAST_EXECUTED', 'PASS', 'YES');
    emit('LIVE_TN10_BROADCAST_VERDICT', 'VALIDATED', json({ transactionIds: submitted }));
  } catch (error) {
    emit('LIVE_TN10_BROADCAST_ERROR', 'FAIL', error.stack || error.message || String(error));
    emit('LIVE_TN10_BROADCAST_VERDICT', 'FAILED');
    process.exitCode = 2;
  } finally {
    if (connected) {
      await withTimeout('rpc.disconnect', rpc.disconnect(), 10000).then(
        () => emit('LIVE_TN10_RPC_DISCONNECT', 'PASS'),
        (error) => emit('LIVE_TN10_RPC_DISCONNECT', 'FAIL', error.message || String(error))
      );
    }
  }
}

main().catch((error) => {
  emit('LIVE_TN10_UNCAUGHT', 'FAIL', error.stack || error.message || String(error));
  process.exitCode = 2;
});
