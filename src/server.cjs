#!/usr/bin/env node
'use strict';

const crypto = require('node:crypto');
const fs = require('node:fs');
const path = require('node:path');
const http = require('node:http');
const { URL } = require('node:url');

const SERVICE_NAME = 'kaspa-toccata-api';
const NETWORK_ID = process.env.KASPA_NETWORK_ID || 'testnet-10';
const KASPA_WASM_PKG = process.env.KASPA_WASM_PKG || '/tmp/kaspa-toccata-api-spikes/rusty-kaspa-toccata/wasm/nodejs/kaspa';
const WRPC_TIMEOUT_MS = Number(process.env.KASPA_WRPC_TIMEOUT_MS || 45000);
const PORT = Number(process.env.PORT || 8787);
const HOST = process.env.HOST || '127.0.0.1';
const ROUND_STORE_FILE = process.env.TOCCATA_ROUND_STORE_FILE || '';

const ROUND_PENDING_CLAIM_LEVEL = 'live_tn10_pending';
const TN10_PROVIDER = 'rusty-kaspa-toccata-wasm';
const LIVE_TN10_STATUS_CLAIM_LEVEL = 'live_tn10_status';
const FUTURE_ENTROPY_CLAIM_LEVEL = 'tn10_future_entropy';
const TN10_WRITE_CLAIM_LEVEL = 'tn10_write_commit_reveal';
const TN10_WRITE_ACK_PHRASE = 'I understand this spends TN10 testnet funds';
const VALIDATED_BROADCAST_TXID = '79e2aa3be09dc0847a7888aea06437a0793c72b97e76cd83205f14425b436021';

const CAPABILITIES = Object.freeze({
  network: 'kaspa-tn10',
  networkId: NETWORK_ID,
  claimLevels: [ROUND_PENDING_CLAIM_LEVEL, LIVE_TN10_STATUS_CLAIM_LEVEL, FUTURE_ENTROPY_CLAIM_LEVEL],
  plannedClaimLevels: [TN10_WRITE_CLAIM_LEVEL],
  canSign: false,
  canBroadcast: false,
  canCreateTransactions: false,
  mainnetEnabled: false,
  providers: {
    tn10Status: TN10_PROVIDER,
    write: 'disabled',
    writeEndpointMode: 'guarded-live-only-no-dry-runs'
  },
  broadcastEvidence: {
    validated: true,
    txid: VALIDATED_BROADCAST_TXID
  },
  limitations: [
    'Live TN10 is the only supported implementation path',
    'No local/dev/mock/dry-run transaction or proof paths',
    'Live TN10 commit, close, and reveal writes require explicit testnet-only gates',
    'No Toccata covenant lineage verification endpoint yet',
    'Roulette app is not implemented yet'
  ]
});

const rounds = new Map();

function loadRoundStore() {
  if (!ROUND_STORE_FILE) return;
  if (!fs.existsSync(ROUND_STORE_FILE) || fs.statSync(ROUND_STORE_FILE).size === 0) return;
  const raw = fs.readFileSync(ROUND_STORE_FILE, 'utf8');
  const parsed = JSON.parse(raw);
  if (!parsed || !Array.isArray(parsed.rounds)) throw new Error('invalid round store format');
  rounds.clear();
  for (const round of parsed.rounds) {
    if (round && round.roundId) rounds.set(round.roundId, round);
  }
}

function saveRoundStore() {
  if (!ROUND_STORE_FILE) return;
  fs.mkdirSync(path.dirname(ROUND_STORE_FILE), { recursive: true });
  const payload = JSON.stringify({
    version: 1,
    service: SERVICE_NAME,
    savedAt: new Date().toISOString(),
    rounds: Array.from(rounds.values())
  }, jsonReplacer, 2);
  const tmp = `${ROUND_STORE_FILE}.${process.pid}.tmp`;
  fs.writeFileSync(tmp, `${payload}\n`);
  fs.renameSync(tmp, ROUND_STORE_FILE);
}

function saveRound(round) {
  if (round && round.roundId) rounds.set(round.roundId, round);
  saveRoundStore();
}

loadRoundStore();

function jsonReplacer(_key, value) {
  return typeof value === 'bigint' ? value.toString() : value;
}

function stableJson(value) {
  if (Array.isArray(value)) return `[${value.map(stableJson).join(',')}]`;
  if (value && typeof value === 'object') {
    return `{${Object.keys(value).sort().map((key) => `${JSON.stringify(key)}:${stableJson(value[key])}`).join(',')}}`;
  }
  return JSON.stringify(value);
}

function sha256Hex(value) {
  return crypto.createHash('sha256').update(String(value)).digest('hex');
}

function sendJson(res, statusCode, body) {
  const payload = JSON.stringify(body, jsonReplacer, 2);
  res.writeHead(statusCode, {
    'content-type': 'application/json; charset=utf-8',
    'cache-control': 'no-store',
    'access-control-allow-origin': '*',
    'access-control-allow-methods': 'GET,POST,OPTIONS',
    'access-control-allow-headers': 'content-type'
  });
  res.end(`${payload}\n`);
}

function sendHtml(res, statusCode, html) {
  res.writeHead(statusCode, {
    'content-type': 'text/html; charset=utf-8',
    'cache-control': 'no-store',
    'access-control-allow-origin': '*',
    'access-control-allow-methods': 'GET,POST,OPTIONS',
    'access-control-allow-headers': 'content-type'
  });
  res.end(html);
}

function sendBasicApiTestPage(res) {
  const pagePath = path.join(__dirname, '..', 'demo', 'basic-api-test.html');
  sendHtml(res, 200, fs.readFileSync(pagePath, 'utf8'));
}

function sendOptions(res) {
  res.writeHead(204, {
    'access-control-allow-origin': '*',
    'access-control-allow-methods': 'GET,POST,OPTIONS',
    'access-control-allow-headers': 'content-type',
    'cache-control': 'no-store'
  });
  res.end();
}

function sendNotFound(res) {
  sendJson(res, 404, {
    ok: false,
    error: 'not_found',
    service: SERVICE_NAME
  });
}

function sendMethodNotAllowed(res) {
  sendJson(res, 405, { ok: false, error: 'method_not_allowed', service: SERVICE_NAME });
}

function sendBadRequest(res, message) {
  sendJson(res, 400, { ok: false, error: 'bad_request', service: SERVICE_NAME, message });
}

function sendConflict(res, message) {
  sendJson(res, 409, { ok: false, error: 'invalid_round_state', service: SERVICE_NAME, message });
}

function withTimeout(label, promise, timeoutMs = WRPC_TIMEOUT_MS) {
  let timer;
  const timeout = new Promise((_, reject) => {
    timer = setTimeout(() => reject(new Error(`${label} timed out after ${timeoutMs}ms`)), timeoutMs);
  });
  return Promise.race([promise, timeout]).finally(() => clearTimeout(timer));
}

function readJsonBody(req) {
  return new Promise((resolve, reject) => {
    const chunks = [];
    req.on('data', (chunk) => {
      chunks.push(chunk);
      if (Buffer.concat(chunks).length > 1024 * 1024) {
        reject(new Error('request body too large'));
        req.destroy();
      }
    });
    req.on('end', () => {
      const raw = Buffer.concat(chunks).toString('utf8').trim();
      if (!raw) {
        resolve({});
        return;
      }
      try {
        resolve(JSON.parse(raw));
      } catch (error) {
        reject(new Error(`invalid JSON body: ${error.message}`));
      }
    });
    req.on('error', reject);
  });
}

function loadKaspaWasm() {
  try {
    return { kaspa: require(KASPA_WASM_PKG), error: null };
  } catch (error) {
    return { kaspa: null, error };
  }
}

function summarizeServerInfo(serverInfo) {
  return {
    networkId: serverInfo.networkId,
    serverVersion: serverInfo.serverVersion,
    isSynced: serverInfo.isSynced,
    hasUtxoIndex: serverInfo.hasUtxoIndex
  };
}

function summarizeBlockDagInfo(dag) {
  return {
    networkName: dag.networkName,
    blockCount: dag.blockCount,
    headerCount: dag.headerCount,
    tipHashes: dag.tipHashes,
    virtualParentHashes: dag.virtualParentHashes,
    virtualDaaScore: dag.virtualDaaScore,
    virtualBlueScore: dag.virtualBlueScore
  };
}

function requireKaspaRpc() {
  const loaded = loadKaspaWasm();
  if (loaded.error) {
    const error = new Error(`Unable to load KASPA_WASM_PKG at ${KASPA_WASM_PKG}: ${loaded.error.message}`);
    error.cause = loaded.error;
    throw error;
  }
  const { RpcClient, Resolver, Encoding } = loaded.kaspa;
  if (!RpcClient || !Resolver || !Encoding) {
    throw new Error('KASPA_WASM_PKG missing RpcClient/Resolver/Encoding exports');
  }
  return { RpcClient, Resolver, Encoding };
}

async function withKaspaRpc(fn) {
  const { RpcClient, Resolver, Encoding } = requireKaspaRpc();
  const resolver = new Resolver();
  const resolvedUrl = await withTimeout('resolver.getUrl', resolver.getUrl(Encoding.Borsh, NETWORK_ID), WRPC_TIMEOUT_MS);
  const rpc = new RpcClient({ resolver, networkId: NETWORK_ID, encoding: Encoding.Borsh });
  let connected = false;
  try {
    await withTimeout('rpc.connect', rpc.connect(), WRPC_TIMEOUT_MS);
    connected = true;
    return await fn(rpc, resolvedUrl);
  } finally {
    if (connected) {
      await withTimeout('rpc.disconnect', rpc.disconnect(), 10000).catch(() => undefined);
    }
  }
}

async function getTn10Status() {
  return withKaspaRpc(async (rpc, resolvedUrl) => {
    const [serverInfo, blockDagInfo] = await Promise.all([
      withTimeout('rpc.getServerInfo', rpc.getServerInfo(), 20000),
      withTimeout('rpc.getBlockDagInfo', rpc.getBlockDagInfo(), 20000)
    ]);
    return {
      ok: true,
      service: SERVICE_NAME,
      network: 'kaspa-tn10',
      networkId: NETWORK_ID,
      claimLevel: LIVE_TN10_STATUS_CLAIM_LEVEL,
      provider: TN10_PROVIDER,
      wasmPackage: KASPA_WASM_PKG,
      resolvedUrl,
      connectedUrl: rpc.url || resolvedUrl,
      serverInfo: summarizeServerInfo(serverInfo),
      blockDagInfo: summarizeBlockDagInfo(blockDagInfo),
      capabilities: CAPABILITIES
    };
  });
}

async function getCurrentTn10BlueScore() {
  return withKaspaRpc(async (rpc) => {
    const response = await withTimeout('rpc.getSinkBlueScore', rpc.getSinkBlueScore(), 20000);
    return BigInt(response.blueScore);
  });
}

async function getCurrentTn10DaaScore() {
  return withKaspaRpc(async (rpc) => {
    const dag = await withTimeout('rpc.getBlockDagInfo', rpc.getBlockDagInfo(), 20000);
    return BigInt(dag.virtualDaaScore);
  });
}

async function fetchLiveTn10Entropy(round) {
  if (!round.futureEntropyPlan) throw new Error('round has no future entropy plan');
  const targetMetric = round.futureEntropyPlan.targetMetric || 'daaScore';
  const targetScore = BigInt(targetMetric === 'blueScore' ? round.futureEntropyPlan.targetBlueScore : round.futureEntropyPlan.targetDaaScore);
  return withKaspaRpc(async (rpc, resolvedUrl) => {
    let dag;
    let sinkBlueScore;
    for (let attempt = 0; attempt < 30; attempt++) {
      const [nextDag, nextSinkBlueScore] = await Promise.all([
        withTimeout('rpc.getBlockDagInfo', rpc.getBlockDagInfo(), 20000),
        withTimeout('rpc.getSinkBlueScore', rpc.getSinkBlueScore(), 20000)
      ]);
      dag = nextDag;
      sinkBlueScore = BigInt(nextSinkBlueScore.blueScore);
      const currentScore = targetMetric === 'blueScore' ? sinkBlueScore : BigInt(dag.virtualDaaScore);
      if (currentScore >= targetScore) break;
      await new Promise((resolve) => setTimeout(resolve, 500));
    }
    const currentScore = targetMetric === 'blueScore' ? sinkBlueScore : (dag ? BigInt(dag.virtualDaaScore) : undefined);
    if (!dag || currentScore === undefined || currentScore < targetScore) {
      const error = new Error(`TN10 target ${targetMetric} not reached: target=${targetScore.toString()} current=${currentScore === undefined ? 'unknown' : currentScore.toString()}`);
      error.code = 'TN10_TARGET_NOT_REACHED';
      throw error;
    }

    const candidateHashes = [...(dag.virtualParentHashes || []), ...(dag.tipHashes || [])];
    for (const blockHash of candidateHashes) {
      const blockResponse = await withTimeout('rpc.getBlock', rpc.getBlock({ hash: blockHash, includeTransactions: false }), 20000);
      const header = blockResponse.block && blockResponse.block.header;
      const headerScore = header && BigInt(targetMetric === 'blueScore' ? header.blueScore : header.daaScore);
      if (header && headerScore >= targetScore) {
        const ledgerHash = round.betLedger ? round.betLedger.ledgerHash : sha256Hex('[]');
        const entropyHash = sha256Hex(`${round.roundId}|${round.commitment}|${round.clientSeed}|${ledgerHash}|${header.hash}|${header.daaScore}|${header.blueScore}`);
        return {
          claimLevel: FUTURE_ENTROPY_CLAIM_LEVEL,
          provider: TN10_PROVIDER,
          network: 'kaspa-tn10',
          networkId: NETWORK_ID,
          entropyHash,
          source: 'sha256(roundId|commitment|clientSeed|ledgerHash|blockHash|daaScore|blueScore)',
          target: round.futureEntropyPlan,
          evidence: {
            blockHash: header.hash,
            daaScore: String(header.daaScore),
            blueScore: String(header.blueScore),
            timestamp: String(header.timestamp),
            targetMetric,
            targetScore: targetScore.toString(),
            sinkBlueScoreAtFetch: sinkBlueScore ? sinkBlueScore.toString() : undefined,
            virtualDaaScoreAtFetch: String(dag.virtualDaaScore),
            virtualParentHashes: dag.virtualParentHashes,
            tipHashes: dag.tipHashes,
            resolvedUrl,
            fetchedAt: new Date().toISOString()
          },
          inputs: {
            roundId: round.roundId,
            commitment: round.commitment,
            clientSeedHash: sha256Hex(round.clientSeed),
            ledgerHash
          }
        };
      }
    }
    throw new Error(`No candidate block at or after target ${targetMetric} ${targetScore.toString()}`);
  });
}

async function ensureEntropy(round) {
  if (round.entropy) return round.entropy;
  if (round.futureEntropyPlan) {
    round.entropy = await fetchLiveTn10Entropy(round);
    return round.entropy;
  }
  throw new Error('round entropy is available after close');
}

function baseRoundFields(round) {
  return {
    roundId: round.roundId,
    game: round.game,
    tableId: round.tableId,
    status: round.status,
    network: 'kaspa-tn10',
    networkId: NETWORK_ID,
    claimLevel: round.claimLevel || ROUND_PENDING_CLAIM_LEVEL,
    provider: round.provider || TN10_PROVIDER,
    capabilities: CAPABILITIES,
    limitations: round.claimLevel === FUTURE_ENTROPY_CLAIM_LEVEL ? [
      'Future entropy uses live TN10 block evidence; no local/mock entropy path exists',
      'No Toccata covenant lineage enforcement yet'
    ] : [
      'Round is pending live TN10 evidence',
      'Local/dev/mock proof paths are disabled'
    ],
    createdAt: round.createdAt,
    updatedAt: round.updatedAt,
    metadata: round.metadata || {}
  };
}

function publicRound(round) {
  const out = baseRoundFields(round);
  if (round.commitment) out.commitment = round.commitment;
  if (round.betLedger) out.betLedger = round.betLedger;
  if (round.futureEntropyPlan) out.futureEntropyPlan = round.futureEntropyPlan;
  if (round.entropy) out.entropy = round.entropy;
  if (round.result) out.result = round.result;
  if (round.tn10Writes) out.tn10Writes = round.tn10Writes;
  if (round.revealedServerSeed) out.revealedServerSeed = round.revealedServerSeed;
  return out;
}

function sanitizeBet(bet, index) {
  if (!bet || typeof bet !== 'object') throw new Error(`bet ${index} must be an object`);
  const playerId = String(bet.playerId || '').trim();
  const selection = String(bet.selection || '').trim();
  const amount = Number(bet.amount);
  if (!playerId) throw new Error(`bet ${index} missing playerId`);
  if (!selection) throw new Error(`bet ${index} missing selection`);
  if (!Number.isFinite(amount) || amount <= 0) throw new Error(`bet ${index} amount must be positive`);
  return { playerId, selection, amount };
}

function buildBetLedger(bets) {
  if (!Array.isArray(bets)) throw new Error('bets must be an array');
  const sanitized = bets.map(sanitizeBet);
  const ledgerHash = sha256Hex(stableJson(sanitized));
  return {
    count: sanitized.length,
    bets: sanitized,
    ledgerHash
  };
}

function rouletteColor(number) {
  if (number === 0) return 'green';
  const red = new Set([1, 3, 5, 7, 9, 12, 14, 16, 18, 19, 21, 23, 25, 27, 30, 32, 34, 36]);
  return red.has(number) ? 'red' : 'black';
}

function computeResult(entropyHash) {
  const n = Number(BigInt(`0x${entropyHash.slice(0, 16)}`) % 37n);
  return {
    game: 'roulette',
    number: n,
    color: rouletteColor(n),
    derivation: 'uint64_be(first8bytes(sha256(roundId|commitment|clientSeed|ledgerHash))) mod 37'
  };
}

function getRoundOrSend(res, roundId) {
  const round = rounds.get(roundId);
  if (!round) {
    sendJson(res, 404, { ok: false, error: 'round_not_found', service: SERVICE_NAME, roundId });
    return null;
  }
  return round;
}

function createRound(body) {
  const roundId = body.roundId ? String(body.roundId) : `tn10_${crypto.randomUUID()}`;
  if (rounds.has(roundId)) throw new Error(`roundId already exists: ${roundId}`);
  const now = new Date().toISOString();
  const round = {
    roundId,
    game: body.game || 'roulette',
    tableId: body.tableId || 'tn10-table',
    status: 'created',
    claimLevel: ROUND_PENDING_CLAIM_LEVEL,
    provider: TN10_PROVIDER,
    metadata: body.metadata || {},
    createdAt: now,
    updatedAt: now
  };
  saveRound(round);
  return round;
}

function touch(round) {
  round.updatedAt = new Date().toISOString();
}

function getTn10WriteGuard() {
  const enabled = process.env.TOCCATA_ENABLE_TN10_WRITES === '1';
  const networkAllowed = NETWORK_ID === 'testnet-10';
  const mainnetDisabled = NETWORK_ID !== 'mainnet';
  const hasPrivateKey = Boolean(String(process.env.TOCCATA_TN10_PRIVATE_KEY || '').trim());
  const ackAccepted = process.env.TOCCATA_TN10_BROADCAST_ACK === TN10_WRITE_ACK_PHRASE;
  return {
    enabled,
    networkId: NETWORK_ID,
    networkAllowed,
    mainnetDisabled,
    hasPrivateKey,
    ackAccepted,
    ackPhraseRequired: TN10_WRITE_ACK_PHRASE,
    canCreateTransactions: enabled && networkAllowed && mainnetDisabled,
    canSign: enabled && networkAllowed && mainnetDisabled && hasPrivateKey && ackAccepted,
    canBroadcast: enabled && networkAllowed && mainnetDisabled && hasPrivateKey && ackAccepted,
    ready: enabled && networkAllowed && mainnetDisabled && hasPrivateKey && ackAccepted
  };
}

function validateTxPhase(round, phase) {
  if (phase === 'commit' && !['committed', 'betting_open', 'closed', 'revealed'].includes(round.status)) {
    throw new Error('round must be committed before commit tx intent is available');
  }
  if (phase === 'close' && !['closed', 'revealed'].includes(round.status)) {
    throw new Error('round must be closed before close tx intent is available');
  }
  if (phase === 'reveal' && round.status !== 'revealed') {
    throw new Error('round must be revealed before reveal tx intent is available');
  }
}

function capabilitiesForGuard(guard) {
  if (!guard || !guard.ready) return CAPABILITIES;
  return {
    ...CAPABILITIES,
    canCreateTransactions: true,
    canSign: true,
    canBroadcast: true,
    providers: {
      ...CAPABILITIES.providers,
      write: 'enabled',
      writeEndpointMode: 'guarded-live-commit-close'
    },
    limitations: [
      'Live TN10 commit and close writes are enabled by explicit testnet-only gates',
      'Live TN10 commit, close, and reveal writes are enabled by explicit testnet-only gates',
      'No Toccata covenant lineage verification endpoint yet',
      'Roulette app is not implemented yet'
    ]
  };
}

function buildTxIntent(round, phase, guard) {
  return {
    phase,
    roundId: round.roundId,
    network: 'kaspa-tn10',
    networkId: NETWORK_ID,
    claimLevel: TN10_WRITE_CLAIM_LEVEL,
    provider: 'rusty-kaspa-toccata-wasm',
    willBroadcast: false,
    broadcastDisabledReason: guard.ready ? 'broadcast is still intentionally not implemented in API endpoint yet' : 'tn10 writes are disabled or guard requirements are unmet',
    evidencePlanned: {
      validatedBroadcastTxid: VALIDATED_BROADCAST_TXID,
      commit: 'live endpoint should anchor commitment hash in a real TN10 transaction payload',
      close: 'future endpoint should anchor input ledger hash and fixed entropy target in a TN10 transaction payload',
      reveal: 'future endpoint should anchor revealed seed, entropy evidence, and result in a TN10 transaction payload'
    },
    roundSnapshot: {
      status: round.status,
      commitment: round.commitment,
      ledgerHash: round.betLedger && round.betLedger.ledgerHash,
      entropyHash: round.entropy && round.entropy.entropyHash,
      result: round.result
    }
  };
}

function requireKaspaWriteKit() {
  const loaded = loadKaspaWasm();
  if (loaded.error) {
    const error = new Error(`Unable to load KASPA_WASM_PKG at ${KASPA_WASM_PKG}: ${loaded.error.message}`);
    error.cause = loaded.error;
    throw error;
  }
  const { PrivateKey, createTransactions, RpcClient, Resolver, Encoding } = loaded.kaspa;
  if (!PrivateKey || !createTransactions || !RpcClient || !Resolver || !Encoding) {
    throw new Error('KASPA_WASM_PKG missing PrivateKey/createTransactions/RpcClient/Resolver/Encoding exports required for live TN10 write');
  }
  return { PrivateKey, createTransactions, RpcClient, Resolver, Encoding };
}

function buildLiveWritePayload(round, phase) {
  const base = {
    schema: `kaspa-toccata-api/live-${phase}/v1`,
    service: SERVICE_NAME,
    phase,
    network: 'kaspa-tn10',
    networkId: NETWORK_ID,
    claimLevel: TN10_WRITE_CLAIM_LEVEL,
    roundId: round.roundId,
    commitment: round.commitment,
    roundStatus: round.status
  };
  if (phase === 'commit') {
    return {
      ...base,
      committedAt: round.committedAt
    };
  }
  if (phase === 'close') {
    const betLedger = round.betLedger || buildBetLedger([]);
    return {
      ...base,
      closedAt: round.closedAt,
      clientSeedHash: round.clientSeed ? sha256Hex(round.clientSeed) : undefined,
      betLedgerHash: betLedger.ledgerHash,
      betCount: betLedger.bets.length,
      futureEntropyPlan: round.futureEntropyPlan
    };
  }
  if (phase === 'reveal') {
    const betLedger = round.betLedger || buildBetLedger([]);
    return {
      ...base,
      revealedAt: round.revealedAt,
      serverSeed: round.revealedServerSeed,
      serverSeedHash: round.revealedServerSeed ? sha256Hex(round.revealedServerSeed) : undefined,
      clientSeedHash: round.clientSeed ? sha256Hex(round.clientSeed) : undefined,
      betLedgerHash: betLedger.ledgerHash,
      betCount: betLedger.bets.length,
      entropyHash: round.entropy && round.entropy.entropyHash,
      entropyEvidence: round.entropy && round.entropy.evidence,
      result: round.result,
      priorTn10Writes: {
        commit: round.tn10Writes && round.tn10Writes.commit && round.tn10Writes.commit.transactionIds,
        close: round.tn10Writes && round.tn10Writes.close && round.tn10Writes.close.transactionIds
      }
    };
  }
  throw new Error(`unsupported live write payload phase: ${phase}`);
}

async function tryGetTransactionEvidence(rpc, transactionId) {
  const mempoolRequests = [
    { transactionId, includeOrphanPool: true, filterTransactionPool: true },
    { transactionId, includeOrphanPool: true, filterTransactionPool: false }
  ];
  const errors = [];
  for (const request of mempoolRequests) {
    try {
      const entry = await withTimeout('rpc.getMempoolEntry', rpc.getMempoolEntry(request), 15000);
      return { source: 'mempool', found: true, entry };
    } catch (error) {
      errors.push(error.message || String(error));
    }
  }
  if (typeof fetch === 'function') {
    const url = `https://api-tn10.kaspa.org/transactions/${transactionId}?inputs=true&outputs=true`;
    try {
      const response = await withTimeout('tn10 explorer transaction lookup', fetch(url, { headers: { accept: 'application/json' } }), 20000);
      if (response.ok) {
        const transaction = await response.json();
        return { source: 'api-tn10.kaspa.org', found: true, url, transaction };
      }
      errors.push(`api-tn10.kaspa.org HTTP ${response.status}`);
    } catch (error) {
      errors.push(error.message || String(error));
    }
  }
  return { source: 'mempool/api-tn10', found: false, errors: errors.slice(0, 3) };
}

async function createLiveWriteTx(round, phase) {
  if (!['commit', 'close', 'reveal'].includes(phase)) throw new Error(`unsupported live TN10 write phase: ${phase}`);
  if (NETWORK_ID !== 'testnet-10') throw new Error(`live TN10 writes require KASPA_NETWORK_ID=testnet-10, got ${NETWORK_ID}`);
  if (!round.commitment) throw new Error(`round must have a commitment before live ${phase} tx`);
  if (phase === 'close') {
    if (round.status !== 'closed') throw new Error('round must be closed before live close tx');
    if (!round.closedAt || !round.futureEntropyPlan) throw new Error('round must have a live TN10 close/future entropy plan before live close tx');
  }
  if (phase === 'reveal') {
    if (round.status !== 'revealed') throw new Error('round must be revealed before live reveal tx');
    if (!round.revealedAt || !round.revealedServerSeed || !round.entropy || !round.result) throw new Error('round must have live entropy and revealed result before live reveal tx');
  }
  if (round.tn10Writes && round.tn10Writes[phase] && round.tn10Writes[phase].transactionIds && round.tn10Writes[phase].transactionIds.length) {
    const error = new Error(`round already has a live ${phase} transaction recorded`);
    error.code = `LIVE_${phase.toUpperCase()}_ALREADY_RECORDED`;
    throw error;
  }

  const { PrivateKey, createTransactions, RpcClient, Resolver, Encoding } = requireKaspaWriteKit();
  const privateKeyHex = String(process.env.TOCCATA_TN10_PRIVATE_KEY || '').trim();
  if (!/^[0-9a-fA-F]{64}$/.test(privateKeyHex)) throw new Error('TOCCATA_TN10_PRIVATE_KEY must be a 64 hex char testnet-only private key');
  const privateKey = new PrivateKey(privateKeyHex);
  const sourceAddress = privateKey.toKeypair().toAddress(NETWORK_ID);
  const destinationAddress = process.env.TOCCATA_TN10_DESTINATION_ADDRESS || sourceAddress.toString();
  const phaseAmountEnv = phase === 'commit'
    ? process.env.TOCCATA_TN10_COMMIT_AMOUNT_SOMPI
    : phase === 'close'
      ? process.env.TOCCATA_TN10_CLOSE_AMOUNT_SOMPI
      : process.env.TOCCATA_TN10_REVEAL_AMOUNT_SOMPI;
  const amountSompi = BigInt(phaseAmountEnv || process.env.TOCCATA_TN10_SEND_AMOUNT_SOMPI || '10000000');
  const priorityFeeSompi = BigInt(process.env.TOCCATA_TN10_PRIORITY_FEE_SOMPI || '0');
  if (amountSompi <= 0n) throw new Error(`TOCCATA_TN10_${phase.toUpperCase()}_AMOUNT_SOMPI must be positive`);

  const payloadObject = buildLiveWritePayload(round, phase);
  const payloadJson = stableJson(payloadObject);
  const payloadHex = Buffer.from(payloadJson, 'utf8').toString('hex');
  const payloadHash = sha256Hex(payloadJson);
  const minUtxoSompi = amountSompi + priorityFeeSompi + 1_000_000n;

  const resolver = new Resolver();
  const resolvedUrl = await withTimeout('resolver.getUrl', resolver.getUrl(Encoding.Borsh, NETWORK_ID), WRPC_TIMEOUT_MS);
  const rpc = new RpcClient({ resolver, networkId: NETWORK_ID, encoding: Encoding.Borsh });
  let connected = false;
  try {
    await withTimeout('rpc.connect', rpc.connect(), WRPC_TIMEOUT_MS);
    connected = true;
    const serverInfo = await withTimeout('rpc.getServerInfo', rpc.getServerInfo(), 20000);
    if (serverInfo.networkId !== NETWORK_ID) throw new Error(`connected RPC network mismatch: ${serverInfo.networkId}`);
    if (!serverInfo.isSynced) throw new Error('connected TN10 RPC is not synced');

    const utxoResponse = await withTimeout('rpc.getUtxosByAddresses', rpc.getUtxosByAddresses([sourceAddress]), 30000);
    const entries = (utxoResponse.entries || [])
      .filter((entry) => !entry.isCoinbase && BigInt(entry.amount) >= minUtxoSompi)
      .sort((a, b) => BigInt(a.amount) > BigInt(b.amount) ? 1 : -1);
    if (!entries.length) {
      const error = new Error(`no funded non-coinbase TN10 UTXO found for source address with at least ${minUtxoSompi.toString()} sompi`);
      error.code = `TN10_${phase.toUpperCase()}_NO_FUNDED_UTXO`;
      error.sourceAddress = sourceAddress.toString();
      error.totalUtxos = utxoResponse.entries ? utxoResponse.entries.length : 0;
      error.minUtxoSompi = minUtxoSompi.toString();
      throw error;
    }

    const { transactions, summary } = await createTransactions({
      entries,
      outputs: [{ address: destinationAddress, amount: amountSompi }],
      priorityFee: priorityFeeSompi,
      changeAddress: sourceAddress,
      networkId: NETWORK_ID,
      payload: payloadHex
    });
    if (!transactions.length) throw new Error(`createTransactions returned no ${phase} transactions`);

    const transactionIds = [];
    const submitted = [];
    for (const pending of transactions) {
      pending.sign([privateKey], true);
      const transactionId = String(pending.transaction.id);
      const safeJson = pending.serializeToSafeJSON();
      if (!safeJson.includes(payloadHex)) throw new Error(`signed transaction does not contain expected ${phase} payload`);
      const submittedTxid = String(await withTimeout('pending.submit', pending.submit(rpc), WRPC_TIMEOUT_MS));
      transactionIds.push(submittedTxid || transactionId);
      submitted.push({ transactionId: submittedTxid || transactionId, localTransactionId: transactionId });
    }

    const evidence = [];
    for (const transactionId of transactionIds) {
      evidence.push({ transactionId, ...(await tryGetTransactionEvidence(rpc, transactionId)) });
    }

    const record = {
      phase,
      claimLevel: TN10_WRITE_CLAIM_LEVEL,
      provider: TN10_PROVIDER,
      network: 'kaspa-tn10',
      networkId: NETWORK_ID,
      sourceAddress: sourceAddress.toString(),
      destinationAddress: String(destinationAddress),
      amountSompi: amountSompi.toString(),
      priorityFeeSompi: priorityFeeSompi.toString(),
      payloadHash,
      payload: payloadHex,
      payloadObject,
      payloadBytes: Buffer.byteLength(payloadJson),
      payloadSchema: payloadObject.schema,
      transactionIds,
      submitted,
      evidence,
      rpc: {
        resolvedUrl,
        connectedUrl: rpc.url || resolvedUrl,
        serverInfo: summarizeServerInfo(serverInfo)
      },
      utxoSelection: {
        totalUtxos: utxoResponse.entries ? utxoResponse.entries.length : 0,
        selectedUtxos: entries.length,
        minUtxoSompi: minUtxoSompi.toString()
      },
      summary: summary && summary.toJSON ? summary.toJSON() : summary,
      submittedAt: new Date().toISOString()
    };
    round.tn10Writes = { ...(round.tn10Writes || {}), [phase]: record };
    touch(round);
    saveRound(round);
    return record;
  } finally {
    if (connected) await withTimeout('rpc.disconnect', rpc.disconnect(), 10000).catch(() => undefined);
  }
}


function decodePayloadJson(payloadHex) {
  if (!payloadHex || typeof payloadHex !== 'string' || !/^[0-9a-fA-F]*$/.test(payloadHex)) return null;
  try {
    const text = Buffer.from(payloadHex, 'hex').toString('utf8');
    return JSON.parse(text);
  } catch (_error) {
    return null;
  }
}

function transactionPayloadFromEvidenceItem(item) {
  const tx = item && item.transaction;
  if (tx && typeof tx.payload === 'string') return tx.payload;
  if (tx && tx.verboseData && typeof tx.verboseData.payload === 'string') return tx.verboseData.payload;
  if (item && item.entry && item.entry.transaction && typeof item.entry.transaction.payload === 'string') return item.entry.transaction.payload;
  return undefined;
}

function acceptedBlockHashFromEvidenceItem(item) {
  const tx = item && item.transaction;
  return (tx && (tx.accepting_block_hash || tx.acceptingBlockHash))
    || (item && item.entry && (item.entry.accepting_block_hash || item.entry.acceptingBlockHash))
    || undefined;
}

function summarizeWriteEvidenceItem(item, record) {
  const payloadHex = transactionPayloadFromEvidenceItem(item);
  const decodedPayload = decodePayloadJson(payloadHex) || (record && record.payloadObject) || undefined;
  return {
    transactionId: item.transactionId,
    source: item.source,
    found: Boolean(item.found),
    acceptingBlockHash: acceptedBlockHashFromEvidenceItem(item),
    payload: payloadHex || (record && record.payload),
    decodedPayload,
    errors: item.errors
  };
}

function summarizeTn10WriteForProof(record) {
  if (!record) return undefined;
  return {
    phase: record.phase,
    claimLevel: record.claimLevel,
    provider: record.provider,
    network: record.network,
    networkId: record.networkId,
    sourceAddress: record.sourceAddress,
    destinationAddress: record.destinationAddress,
    amountSompi: record.amountSompi,
    payloadHash: record.payloadHash,
    payloadBytes: record.payloadBytes,
    payloadSchema: record.payloadSchema,
    transactionIds: record.transactionIds || [],
    payloadObject: record.payloadObject,
    evidence: (record.evidence || []).map((item) => summarizeWriteEvidenceItem(item, record)),
    submittedAt: record.submittedAt
  };
}

function buildProof(round) {
  if (round.status !== 'revealed' || !round.revealedServerSeed || !round.entropy || !round.result) {
    throw new Error('round must be revealed before proof is available');
  }
  const tn10Writes = {
    commit: summarizeTn10WriteForProof(round.tn10Writes && round.tn10Writes.commit),
    close: summarizeTn10WriteForProof(round.tn10Writes && round.tn10Writes.close),
    reveal: summarizeTn10WriteForProof(round.tn10Writes && round.tn10Writes.reveal)
  };
  return {
    proofVersion: 1,
    service: SERVICE_NAME,
    roundId: round.roundId,
    network: 'kaspa-tn10',
    networkId: NETWORK_ID,
    claimLevel: round.claimLevel || ROUND_PENDING_CLAIM_LEVEL,
    provider: round.provider || TN10_PROVIDER,
    limitations: [
      'Proof uses live TN10 entropy/write evidence only; local/mock proof paths are disabled',
      'This proof does not claim Toccata covenant enforcement yet'
    ],
    commitment: round.commitment,
    serverSeed: round.revealedServerSeed,
    clientSeed: round.clientSeed,
    betLedger: round.betLedger || buildBetLedger([]),
    entropy: round.entropy,
    result: round.result,
    tn10Writes,
    independentConfirmation: {
      tn10TransactionApi: 'https://api-tn10.kaspa.org/transactions/<txid>?inputs=true&outputs=true',
      requiredChecks: [
        'transaction exists on public TN10 API',
        'accepting_block_hash is present after acceptance',
        'decoded payload networkId is testnet-10',
        'decoded payload phase and roundId match this proof',
        'commit/close/reveal payload hashes and prior tx references match this proof'
      ]
    },
    capabilities: CAPABILITIES
  };
}

function verifyLiveProof(proof) {
  if (!proof || typeof proof !== 'object') return { verified: false, reason: 'missing proof' };
  if (proof.claimLevel === FUTURE_ENTROPY_CLAIM_LEVEL) return verifyFutureEntropyProof(proof);
  return { verified: false, reason: 'unsupported live TN10 proof claim level' };
}
function verifyFutureEntropyProof(proof) {
  if (proof.provider !== 'rusty-kaspa-toccata-wasm') return { verified: false, reason: 'unsupported future entropy provider' };
  if (!proof.roundId || !proof.serverSeed || !proof.clientSeed || !proof.commitment) return { verified: false, reason: 'missing required proof fields' };
  if (!proof.entropy || !proof.entropy.evidence || !proof.entropy.evidence.blockHash) return { verified: false, reason: 'missing live TN10 entropy evidence' };
  if (sha256Hex(proof.serverSeed) !== proof.commitment) return { verified: false, reason: 'commitment mismatch' };
  const betLedger = proof.betLedger || buildBetLedger([]);
  const recalculatedLedger = buildBetLedger(betLedger.bets || []);
  if (recalculatedLedger.ledgerHash !== betLedger.ledgerHash) return { verified: false, reason: 'bet ledger hash mismatch' };
  const target = proof.entropy.target || {};
  const targetMetric = target.targetMetric || (target.targetBlueScore ? 'blueScore' : 'daaScore');
  const targetScore = targetMetric === 'blueScore' ? target.targetBlueScore : target.targetDaaScore;
  const evidenceScore = targetMetric === 'blueScore' ? proof.entropy.evidence.blueScore : proof.entropy.evidence.daaScore;
  if (!targetScore || BigInt(evidenceScore) < BigInt(targetScore)) return { verified: false, reason: `TN10 evidence is before target ${targetMetric}` };
  const entropyHash = sha256Hex(`${proof.roundId}|${proof.commitment}|${proof.clientSeed}|${betLedger.ledgerHash}|${proof.entropy.evidence.blockHash}|${proof.entropy.evidence.daaScore}|${proof.entropy.evidence.blueScore}`);
  if (entropyHash !== proof.entropy.entropyHash) return { verified: false, reason: 'entropy mismatch' };
  const result = computeResult(entropyHash);
  if (!proof.result || result.number !== proof.result.number || result.color !== proof.result.color) return { verified: false, reason: 'result mismatch' };
  const txEvidence = verifyProofTn10Writes(proof);
  if (!txEvidence.verified) return { verified: false, reason: txEvidence.reason };
  return { verified: true, reason: 'future TN10 entropy proof replay matched', entropy: proof.entropy, result, claimLevel: FUTURE_ENTROPY_CLAIM_LEVEL, txEvidence };
}

function verifyProofTn10Writes(proof) {
  const writes = proof.tn10Writes || {};
  const checked = [];
  for (const phase of ['commit', 'close', 'reveal']) {
    const record = writes[phase];
    if (!record) continue;
    if (record.phase !== phase) return { verified: false, reason: `${phase} tx phase mismatch` };
    if (record.network !== 'kaspa-tn10' || record.networkId !== 'testnet-10') return { verified: false, reason: `${phase} tx network mismatch` };
    if (record.payloadSchema !== `kaspa-toccata-api/live-${phase}/v1`) return { verified: false, reason: `${phase} tx payload schema mismatch` };
    if (!Array.isArray(record.transactionIds) || record.transactionIds.length === 0) return { verified: false, reason: `${phase} tx missing transaction id` };
    if (!Array.isArray(record.evidence) || record.evidence.length === 0) return { verified: false, reason: `${phase} tx missing evidence` };
    for (const transactionId of record.transactionIds) {
      const item = record.evidence.find((entry) => entry && entry.transactionId === transactionId);
      if (!item) return { verified: false, reason: `${phase} tx evidence missing transaction ${transactionId}` };
      if (item.found !== true) return { verified: false, reason: `${phase} tx evidence not found for ${transactionId}` };
      if (item.decodedPayload) {
        const payload = item.decodedPayload;
        if (payload.phase !== phase) return { verified: false, reason: `${phase} tx decoded payload phase mismatch` };
        if (payload.roundId !== proof.roundId) return { verified: false, reason: `${phase} tx decoded payload roundId mismatch` };
        if (payload.networkId !== 'testnet-10') return { verified: false, reason: `${phase} tx decoded payload network mismatch` };
        if (payload.commitment !== proof.commitment) return { verified: false, reason: `${phase} tx decoded payload commitment mismatch` };
        if (phase === 'close') {
          const betLedger = proof.betLedger || buildBetLedger([]);
          if (payload.betLedgerHash !== betLedger.ledgerHash) return { verified: false, reason: 'close tx bet ledger hash mismatch' };
          if (!payload.futureEntropyPlan) return { verified: false, reason: 'close tx missing future entropy plan' };
        }
        if (phase === 'reveal') {
          if (payload.serverSeedHash !== sha256Hex(proof.serverSeed)) return { verified: false, reason: 'reveal tx server seed hash mismatch' };
          if (payload.entropyHash !== proof.entropy.entropyHash) return { verified: false, reason: 'reveal tx entropy hash mismatch' };
          if (!payload.result || payload.result.number !== proof.result.number || payload.result.color !== proof.result.color) return { verified: false, reason: 'reveal tx result mismatch' };
          const prior = payload.priorTn10Writes || {};
          if (writes.commit && Array.isArray(prior.commit) && !writes.commit.transactionIds.every((txid) => prior.commit.includes(txid))) return { verified: false, reason: 'reveal tx prior commit reference mismatch' };
          if (writes.close && Array.isArray(prior.close) && !writes.close.transactionIds.every((txid) => prior.close.includes(txid))) return { verified: false, reason: 'reveal tx prior close reference mismatch' };
        }
      }
      checked.push({ phase, transactionId, source: item.source, found: true, acceptingBlockHash: item.acceptingBlockHash });
    }
  }
  return { verified: true, checked };
}

async function handleRoundRoutes(req, res, url) {
  if (url.pathname === '/v1/rounds') {
    if (req.method !== 'POST') return sendMethodNotAllowed(res);
    let body;
    try { body = await readJsonBody(req); } catch (error) { return sendBadRequest(res, error.message); }
    try {
      const round = createRound(body);
      sendJson(res, 201, { ok: true, service: SERVICE_NAME, round: publicRound(round) });
    } catch (error) {
      sendBadRequest(res, error.message);
    }
    return true;
  }

  const roundMatch = url.pathname.match(/^\/v1\/rounds\/([^/]+)(?:\/(commit\/tx|close\/tx|reveal\/tx|commit|bets\/ledger|close|entropy|reveal|proof))?$/);
  if (!roundMatch) return false;
  const roundId = decodeURIComponent(roundMatch[1]);
  const action = roundMatch[2] || '';
  const round = getRoundOrSend(res, roundId);
  if (!round) return true;

  if (!action) {
    if (req.method !== 'GET') return sendMethodNotAllowed(res);
    sendJson(res, 200, { ok: true, service: SERVICE_NAME, round: publicRound(round) });
    return true;
  }

  if (['commit/tx', 'close/tx', 'reveal/tx'].includes(action)) {
    if (req.method !== 'POST') return sendMethodNotAllowed(res);
    let body;
    try { body = await readJsonBody(req); } catch (error) { return sendBadRequest(res, error.message); }
    const phase = action.replace('/tx', '');
    try {
      validateTxPhase(round, phase);
    } catch (error) {
      return sendConflict(res, error.message);
    }
    const guard = getTn10WriteGuard();
    const txIntent = buildTxIntent(round, phase, guard);
    if (Object.prototype.hasOwnProperty.call(body, 'dryRun')) {
      sendJson(res, 400, {
        ok: false,
        error: 'dry_run_forbidden',
        service: SERVICE_NAME,
        message: 'Dry-run transaction paths are intentionally unsupported; TN10 write endpoints must either execute through live testnet-only gates or fail closed.',
        guard,
        txIntent,
        capabilities: capabilitiesForGuard(guard)
      });
      return true;
    }
    if (!guard.ready) {
      sendJson(res, 403, {
        ok: false,
        error: 'tn10_writes_disabled',
        service: SERVICE_NAME,
        message: 'TN10 write endpoints are fail-closed unless explicit testnet-only write gates are satisfied. Dry runs are forbidden.',
        guard,
        txIntent,
        capabilities: capabilitiesForGuard(guard)
      });
      return true;
    }
    try {
      const liveTx = await createLiveWriteTx(round, phase);
      sendJson(res, 200, {
        ok: true,
        service: SERVICE_NAME,
        claimLevel: TN10_WRITE_CLAIM_LEVEL,
        guard,
        txIntent: { ...txIntent, willBroadcast: true, broadcastDisabledReason: undefined },
        [`${phase}Tx`]: liveTx,
        round: publicRound(round),
        capabilities: capabilitiesForGuard(guard)
      });
    } catch (error) {
      const alreadyRecorded = error.code === `LIVE_${phase.toUpperCase()}_ALREADY_RECORDED`;
      const status = alreadyRecorded ? 409 : 503;
      sendJson(res, status, {
        ok: false,
        error: alreadyRecorded ? `live_${phase}_already_recorded` : `tn10_live_${phase}_failed`,
        service: SERVICE_NAME,
        message: error.message || String(error),
        sourceAddress: error.sourceAddress,
        totalUtxos: error.totalUtxos,
        minUtxoSompi: error.minUtxoSompi,
        guard,
        txIntent,
        capabilities: capabilitiesForGuard(guard)
      });
    }
    return true;
  }

  if (action === 'commit') {
    if (req.method !== 'POST') return sendMethodNotAllowed(res);
    if (round.status !== 'created') return sendConflict(res, 'round must be created to commit');
    let body;
    try { body = await readJsonBody(req); } catch (error) { return sendBadRequest(res, error.message); }
    const serverSeed = String(body.serverSeed || '').trim();
    if (!serverSeed) return sendBadRequest(res, 'serverSeed is required');
    round.commitment = sha256Hex(serverSeed);
    round.status = 'committed';
    round.committedAt = new Date().toISOString();
    touch(round);
    saveRound(round);
    sendJson(res, 200, { ok: true, service: SERVICE_NAME, round: publicRound(round) });
    return true;
  }

  if (action === 'bets/ledger') {
    if (req.method !== 'POST') return sendMethodNotAllowed(res);
    if (!['committed', 'betting_open'].includes(round.status)) return sendConflict(res, 'round must be committed or betting_open to update bet ledger');
    let body;
    try { body = await readJsonBody(req); } catch (error) { return sendBadRequest(res, error.message); }
    try {
      round.betLedger = buildBetLedger(body.bets || []);
      round.status = 'betting_open';
      touch(round);
      saveRound(round);
      sendJson(res, 200, { ok: true, service: SERVICE_NAME, round: publicRound(round) });
    } catch (error) {
      sendBadRequest(res, error.message);
    }
    return true;
  }

  if (action === 'close') {
    if (req.method !== 'POST') return sendMethodNotAllowed(res);
    if (!['committed', 'betting_open'].includes(round.status)) return sendConflict(res, 'round must be committed or betting_open to close');
    let body;
    try { body = await readJsonBody(req); } catch (error) { return sendBadRequest(res, error.message); }
    const clientSeed = String(body.clientSeed || '').trim();
    if (!clientSeed) return sendBadRequest(res, 'clientSeed is required');
    if (body.entropyMode !== 'live_tn10_future') {
      sendBadRequest(res, 'live_tn10_future entropyMode is required; local/mock entropy is disabled');
      return true;
    }
    if (!round.betLedger) round.betLedger = buildBetLedger([]);
    const targetMetric = body.targetMetric || (body.targetOffsetDaaScore ? 'daaScore' : 'blueScore');
    if (!['blueScore', 'daaScore'].includes(targetMetric)) { sendBadRequest(res, 'targetMetric must be blueScore or daaScore'); return true; }
    const offset = Number(targetMetric === 'blueScore' ? (body.targetOffsetBlueScore || 1) : (body.targetOffsetDaaScore || 2));
    if (!Number.isInteger(offset) || offset < 1 || offset > 1000) { sendBadRequest(res, 'target offset must be an integer between 1 and 1000'); return true; }
    try {
      const currentScore = targetMetric === 'blueScore' ? await getCurrentTn10BlueScore() : await getCurrentTn10DaaScore();
      const closedAt = new Date().toISOString();
      round.clientSeed = clientSeed;
      round.closedAt = closedAt;
      round.status = 'closed';
      round.claimLevel = FUTURE_ENTROPY_CLAIM_LEVEL;
      round.provider = TN10_PROVIDER;
      round.futureEntropyPlan = {
        claimLevel: FUTURE_ENTROPY_CLAIM_LEVEL,
        provider: TN10_PROVIDER,
        network: 'kaspa-tn10',
        networkId: NETWORK_ID,
        targetMetric,
        currentBlueScore: targetMetric === 'blueScore' ? currentScore.toString() : undefined,
        currentDaaScore: targetMetric === 'daaScore' ? currentScore.toString() : undefined,
        targetOffsetBlueScore: targetMetric === 'blueScore' ? offset : undefined,
        targetOffsetDaaScore: targetMetric === 'daaScore' ? offset : undefined,
        targetBlueScore: targetMetric === 'blueScore' ? (currentScore + BigInt(offset)).toString() : undefined,
        targetDaaScore: targetMetric === 'daaScore' ? (currentScore + BigInt(offset)).toString() : undefined,
        fixedAt: closedAt,
        formula: targetMetric === 'blueScore' ? 'targetBlueScore = current sinkBlueScore at close + targetOffsetBlueScore' : 'targetDaaScore = current virtualDaaScore at close + targetOffsetDaaScore'
      };
      round.entropy = undefined;
    } catch (error) {
      sendJson(res, 503, { ok: false, error: 'tn10_future_target_unavailable', service: SERVICE_NAME, message: error.message });
      return true;
    }
    touch(round);
    saveRound(round);
    sendJson(res, 200, { ok: true, service: SERVICE_NAME, round: publicRound(round) });
    return true;
  }

  if (action === 'entropy') {
    if (req.method !== 'GET') return sendMethodNotAllowed(res);
    try {
      const entropy = await ensureEntropy(round);
      touch(round);
      saveRound(round);
      sendJson(res, 200, { ok: true, service: SERVICE_NAME, entropy, round: publicRound(round) });
    } catch (error) {
      if (error.code === 'TN10_TARGET_NOT_REACHED') return sendConflict(res, error.message);
      sendJson(res, 503, { ok: false, error: 'entropy_unavailable', service: SERVICE_NAME, message: error.message });
    }
    return true;
  }

  if (action === 'reveal') {
    if (req.method !== 'POST') return sendMethodNotAllowed(res);
    if (round.status !== 'closed') return sendConflict(res, 'round must be closed to reveal');
    let body;
    try { body = await readJsonBody(req); } catch (error) { return sendBadRequest(res, error.message); }
    const serverSeed = String(body.serverSeed || '').trim();
    if (!serverSeed) return sendBadRequest(res, 'serverSeed is required');
    if (sha256Hex(serverSeed) !== round.commitment) return sendBadRequest(res, 'serverSeed does not match commitment');
    try {
      await ensureEntropy(round);
    } catch (error) {
      if (error.code === 'TN10_TARGET_NOT_REACHED') return sendConflict(res, error.message);
      sendJson(res, 503, { ok: false, error: 'entropy_unavailable', service: SERVICE_NAME, message: error.message });
      return true;
    }
    round.revealedServerSeed = serverSeed;
    round.result = computeResult(round.entropy.entropyHash);
    round.status = 'revealed';
    round.revealedAt = new Date().toISOString();
    touch(round);
    saveRound(round);
    sendJson(res, 200, { ok: true, service: SERVICE_NAME, round: publicRound(round) });
    return true;
  }

  if (action === 'proof') {
    if (req.method !== 'GET') return sendMethodNotAllowed(res);
    try {
      sendJson(res, 200, { ok: true, service: SERVICE_NAME, proof: buildProof(round) });
    } catch (error) {
      sendConflict(res, error.message);
    }
    return true;
  }

  return false;
}

async function handleProofVerify(req, res, url) {
  if (url.pathname !== '/v1/proofs/verify') return false;
  if (req.method !== 'POST') return sendMethodNotAllowed(res);
  let body;
  try { body = await readJsonBody(req); } catch (error) { return sendBadRequest(res, error.message); }
  const result = verifyLiveProof(body.proof);
  sendJson(res, result.verified ? 200 : 422, {
    ok: result.verified,
    service: SERVICE_NAME,
    verified: result.verified,
    claimLevel: result.claimLevel || ROUND_PENDING_CLAIM_LEVEL,
    provider: body.proof && body.proof.provider || TN10_PROVIDER,
    reason: result.reason,
    replay: result.verified ? { entropy: result.entropy, result: result.result } : undefined,
    txEvidence: result.txEvidence
  });
  return true;
}

async function handle(req, res) {
  const url = new URL(req.url, `http://${req.headers.host || `${HOST}:${PORT}`}`);

  if (req.method === 'OPTIONS') {
    sendOptions(res);
    return;
  }

  if (['/', '/demo', '/demo/', '/demo/basic-api-test', '/demo/basic-api-test.html'].includes(url.pathname)) {
    if (req.method !== 'GET') return sendMethodNotAllowed(res);
    sendBasicApiTestPage(res);
    return;
  }

  if (url.pathname === '/v1/health') {
    if (req.method !== 'GET') return sendMethodNotAllowed(res);
    sendJson(res, 200, {
      ok: true,
      service: SERVICE_NAME,
      milestone: 'live_tn10_only_api',
      network: 'kaspa-tn10',
      networkId: NETWORK_ID
    });
    return;
  }

  if (url.pathname === '/v1/capabilities') {
    if (req.method !== 'GET') return sendMethodNotAllowed(res);
    sendJson(res, 200, {
      ok: true,
      service: SERVICE_NAME,
      capabilities: CAPABILITIES
    });
    return;
  }

  if (url.pathname === '/v1/network/status') {
    if (req.method !== 'GET') return sendMethodNotAllowed(res);
    try {
      sendJson(res, 200, await getTn10Status());
    } catch (error) {
      sendJson(res, 503, {
        ok: false,
        service: SERVICE_NAME,
        network: 'kaspa-tn10',
        networkId: NETWORK_ID,
        claimLevel: LIVE_TN10_STATUS_CLAIM_LEVEL,
        provider: TN10_PROVIDER,
        capabilities: CAPABILITIES,
        error: 'tn10_status_unavailable',
        message: error.message
      });
    }
    return;
  }

  if (await handleRoundRoutes(req, res, url)) return;
  if (await handleProofVerify(req, res, url)) return;

  sendNotFound(res);
}

function createServer() {
  return http.createServer((req, res) => {
    handle(req, res).catch((error) => {
      console.error('request handler failed', error && (error.stack || error.message || String(error)));
      if (res.headersSent) {
        res.end();
        return;
      }
      sendJson(res, 500, {
        ok: false,
        service: SERVICE_NAME,
        error: 'internal_error',
        message: error.message
      });
    });
  });
}

if (require.main === module) {
  const server = createServer();
  server.listen(PORT, HOST, () => {
    console.log(`${SERVICE_NAME} listening on http://${HOST}:${PORT}`);
  });
}

module.exports = {
  createServer,
  getTn10Status,
  CAPABILITIES,
  verifyLiveProof
};
