#!/usr/bin/env node
'use strict';

const fs = require('node:fs');
const assert = require('node:assert/strict');
const { createToccataApiClient } = require('../src/client.cjs');

const baseUrl = process.env.BASE_URL || 'http://127.0.0.1:8797';
const outPath = process.env.PROOF_OUTPUT_FILE || '/tmp/kaspa-toccata-live-proof-output.json';

async function sleep(ms) { return new Promise((resolve) => setTimeout(resolve, ms)); }

function compactWrite(record) {
  return {
    phase: record.phase,
    payloadSchema: record.payloadSchema,
    payloadHash: record.payloadHash,
    transactionIds: record.transactionIds,
    evidence: record.evidence.map((item) => ({
      transactionId: item.transactionId,
      source: item.source,
      found: item.found,
      acceptingBlockHash: item.acceptingBlockHash,
      decodedPayload: item.decodedPayload
    }))
  };
}

async function main() {
  const client = createToccataApiClient({ baseUrl });
  const serverSeed = `actual-live-proof-server-${Date.now()}`;
  const clientSeed = `actual-live-proof-client-${Date.now()}`;

  const created = await client.createRound({ game: 'generic-contract', tableId: 'actual-live-proof-output' });
  const roundId = created.round.roundId;

  await client.commitRound(roundId, { serverSeed });
  const commitTx = await client.createCommitTx(roundId, {});

  await client.updateBetLedger(roundId, { bets: [
    { playerId: 'alice', selection: 'generic-selection', amount: 1 },
    { playerId: 'bob', selection: 'generic-selection-2', amount: 2 }
  ] });
  await client.closeRound(roundId, { clientSeed, entropyMode: 'live_tn10_future', targetOffsetBlueScore: 1 });
  const closeTx = await client.createCloseTx(roundId, {});

  let entropy;
  for (let i = 0; i < 100; i += 1) {
    try {
      entropy = await client.getEntropy(roundId);
      if (entropy.entropy && entropy.entropy.evidence && entropy.entropy.evidence.blockHash) break;
    } catch (error) {
      if (error.status !== 409 && error.status !== 503) throw error;
    }
    await sleep(500);
  }
  assert(entropy && entropy.entropy && entropy.entropy.evidence && entropy.entropy.evidence.blockHash, 'entropy fetched');

  await client.revealRound(roundId, { serverSeed });
  const revealTx = await client.createRevealTx(roundId, {});
  const proofResponse = await client.getProof(roundId);
  const verified = await client.verifyProof(proofResponse.proof);
  assert.equal(verified.verified, true);

  const proof = proofResponse.proof;
  const visible = {
    roundId,
    txids: {
      commit: commitTx.commitTx.transactionIds,
      close: closeTx.closeTx.transactionIds,
      reveal: revealTx.revealTx.transactionIds
    },
    proofSummary: {
      proofVersion: proof.proofVersion,
      claimLevel: proof.claimLevel,
      network: proof.network,
      networkId: proof.networkId,
      commitment: proof.commitment,
      clientSeed: proof.clientSeed,
      entropyHash: proof.entropy.entropyHash,
      entropyEvidence: proof.entropy.evidence,
      result: proof.result,
      tn10Writes: {
        commit: compactWrite(proof.tn10Writes.commit),
        close: compactWrite(proof.tn10Writes.close),
        reveal: compactWrite(proof.tn10Writes.reveal)
      }
    },
    verifyResponse: {
      ok: verified.ok,
      verified: verified.verified,
      reason: verified.reason,
      txEvidence: verified.txEvidence
    }
  };

  fs.writeFileSync(outPath, JSON.stringify({ fullProof: proof, visible }, null, 2));
  console.log(JSON.stringify(visible, null, 2));
  console.error(`FULL_PROOF_FILE=${outPath}`);
}

main().catch((error) => {
  console.error(error.stack || error.message || String(error));
  process.exit(2);
});
