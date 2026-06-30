#!/usr/bin/env node
/*
 * Verify the built official Toccata WASM node package can be imported from Node
 * and exposes/constructs covenant primitives.
 */
const path = process.env.KASPA_WASM_PKG || "/tmp/kaspa-toccata-api-spikes/rusty-kaspa-toccata/wasm/nodejs/kaspa";

function emit(key, value, detail) {
  console.log(`${key}=${value}${detail ? ` # ${detail}` : ""}`);
}

let kaspa;
try {
  kaspa = require(path);
  emit("NPM_TOCCATA_WASM_IMPORT", "PASS", path);
} catch (error) {
  emit("NPM_TOCCATA_WASM_IMPORT", "FAIL", error.message);
  process.exit(2);
}

const required = [
  "Hash",
  "CovenantBinding",
  "GenesisCovenantGroup",
  "TransactionOutput",
  "Transaction",
  "TransactionOutpoint",
  "covenantId",
  "payToScriptHashScript",
  "RpcClient",
  "Resolver",
  "Encoding",
];

let failed = false;
for (const name of required) {
  const ok = Object.prototype.hasOwnProperty.call(kaspa, name) || kaspa[name] !== undefined;
  emit(`NPM_TOCCATA_WASM_EXPORT_${name}`, ok ? "PASS" : "FAIL");
  failed ||= !ok;
}

try {
  const h = new kaspa.Hash("00".repeat(32));
  const binding = new kaspa.CovenantBinding(0, h);
  emit("NPM_COVENANT_BINDING_CONSTRUCT", "PASS", JSON.stringify(binding.toJSON()));

  const group = new kaspa.GenesisCovenantGroup(0, [0]);
  emit("NPM_GENESIS_COVENANT_GROUP_CONSTRUCT", "PASS", JSON.stringify(group.toJSON()));

  const spk = kaspa.payToScriptHashScript(new Uint8Array([0x51]));
  const output = new kaspa.TransactionOutput(1000n, spk, binding);
  const covenant = output.covenant;
  emit("NPM_TRANSACTION_OUTPUT_COVENANT_CONSTRUCT", covenant ? "PASS" : "FAIL", covenant ? JSON.stringify(covenant.toJSON()) : "missing");
  failed ||= !covenant;
} catch (error) {
  emit("NPM_COVENANT_RUNTIME_CONSTRUCT", "FAIL", error.stack || error.message);
  failed = true;
}

emit("NPM_BUILT_PACKAGE_VERDICT", failed ? "INVALIDATED" : "VALIDATED");
process.exit(failed ? 2 : 0);
