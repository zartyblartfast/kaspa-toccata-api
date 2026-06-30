#!/usr/bin/env node
/*
 * Verify the built official Toccata WASM Node package can connect to live TN10
 * wRPC and retrieve read-only node/blockDAG evidence.
 */
const path = process.env.KASPA_WASM_PKG || "/tmp/kaspa-toccata-api-spikes/rusty-kaspa-toccata/wasm/nodejs/kaspa";
const NETWORK_ID = process.env.KASPA_NETWORK_ID || "testnet-10";
const TIMEOUT_MS = Number(process.env.KASPA_WRPC_TIMEOUT_MS || 45000);

function emit(key, value, detail) {
  console.log(`${key}=${value}${detail ? ` # ${detail}` : ""}`);
}

function summarize(value, max = 300) {
  try {
    const text = JSON.stringify(value, (_k, v) => typeof v === "bigint" ? v.toString() : v);
    return text.length > max ? text.slice(0, max) + "..." : text;
  } catch (_err) {
    return String(value).slice(0, max);
  }
}

async function withTimeout(label, promise, timeoutMs = TIMEOUT_MS) {
  let timer;
  const timeout = new Promise((_, reject) => {
    timer = setTimeout(() => reject(new Error(`${label} timed out after ${timeoutMs}ms`)), timeoutMs);
  });
  try {
    return await Promise.race([promise, timeout]);
  } finally {
    clearTimeout(timer);
  }
}

async function main() {
  let kaspa;
  try {
    kaspa = require(path);
    emit("NPM_TN10_WRPC_IMPORTS", "PASS", path);
  } catch (error) {
    emit("NPM_TN10_WRPC_IMPORTS", "FAIL", error.message);
    process.exitCode = 2;
    return;
  }

  const { RpcClient, Resolver, Encoding } = kaspa;
  if (!RpcClient || !Resolver || !Encoding) {
    emit("NPM_TN10_WRPC_REQUIRED_EXPORTS", "FAIL", "RpcClient/Resolver/Encoding missing");
    process.exitCode = 2;
    return;
  }
  emit("NPM_TN10_WRPC_REQUIRED_EXPORTS", "PASS");

  let resolver;
  let url;
  try {
    resolver = new Resolver();
    emit("NPM_TN10_WRPC_RESOLVER_CONSTRUCT", "PASS");
    url = await withTimeout("resolver.getUrl", resolver.getUrl(Encoding.Borsh, NETWORK_ID), 20000);
    emit("NPM_TN10_WRPC_RESOLVER_GET_URL", "PASS", url);
  } catch (error) {
    emit("NPM_TN10_WRPC_RESOLVER_GET_URL", "FAIL", error.message || String(error));
    process.exitCode = 2;
    return;
  }

  let rpc;
  let connected = false;
  try {
    rpc = new RpcClient({ resolver, networkId: NETWORK_ID, encoding: Encoding.Borsh });
    emit("NPM_TN10_WRPC_CLIENT_CONSTRUCT", "PASS");
  } catch (error) {
    emit("NPM_TN10_WRPC_CLIENT_CONSTRUCT", "FAIL", error.message || String(error));
    process.exitCode = 2;
    return;
  }

  try {
    await withTimeout("rpc.connect", rpc.connect(), TIMEOUT_MS);
    connected = true;
    emit("NPM_TN10_WRPC_CONNECT", "PASS", rpc.url || url || NETWORK_ID);
  } catch (error) {
    emit("NPM_TN10_WRPC_CONNECT", "FAIL", error.message || String(error));
    process.exitCode = 2;
    return;
  }

  let failed = false;
  try {
    const serverInfo = await withTimeout("rpc.getServerInfo", rpc.getServerInfo(), 20000);
    emit("NPM_TN10_WRPC_GET_SERVER_INFO", "PASS", summarize({ networkId: serverInfo.networkId, serverVersion: serverInfo.serverVersion, isSynced: serverInfo.isSynced, hasUtxoIndex: serverInfo.hasUtxoIndex }));
  } catch (error) {
    emit("NPM_TN10_WRPC_GET_SERVER_INFO", "FAIL", error.message || String(error));
    failed = true;
  }

  try {
    const dag = await withTimeout("rpc.getBlockDagInfo", rpc.getBlockDagInfo(), 20000);
    emit("NPM_TN10_WRPC_GET_BLOCKDAG_INFO", "PASS", summarize({ networkName: dag.networkName, blockCount: dag.blockCount, tipHashes: dag.tipHashes?.slice?.(0, 2), virtualParentHashes: dag.virtualParentHashes?.slice?.(0, 2), virtualDaaScore: dag.virtualDaaScore, virtualBlueScore: dag.virtualBlueScore }));
  } catch (error) {
    emit("NPM_TN10_WRPC_GET_BLOCKDAG_INFO", "FAIL", error.message || String(error));
    failed = true;
  }

  if (connected) {
    try {
      await withTimeout("rpc.disconnect", rpc.disconnect(), 10000);
      emit("NPM_TN10_WRPC_DISCONNECT", "PASS");
    } catch (error) {
      emit("NPM_TN10_WRPC_DISCONNECT", "FAIL", error.message || String(error));
      failed = true;
    }
  }

  emit("NPM_TN10_WRPC_VERDICT", failed ? "PARTIAL" : "VALIDATED");
  process.exitCode = failed ? 2 : 0;
}

main().catch((error) => {
  emit("NPM_TN10_WRPC_UNCAUGHT", "FAIL", error.stack || error.message || String(error));
  process.exitCode = 2;
});
