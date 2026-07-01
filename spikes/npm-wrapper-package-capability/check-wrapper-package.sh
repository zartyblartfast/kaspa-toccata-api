#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
CACHE="${KASPA_TOCCATA_SPIKE_CACHE:-/tmp/kaspa-toccata-api-spikes/rusty-kaspa-toccata}"
OFFICIAL_PKG="${KASPA_WASM_PKG:-$CACHE/wasm/nodejs/kaspa}"
WORK_ROOT="${KASPA_WRAPPER_SPIKE_WORK:-/tmp/kaspa-toccata-api-spikes/npm-wrapper-package}"
WRAPPER_DIR="$WORK_ROOT/package"
CONSUMER_DIR="$WORK_ROOT/consumer"

pass() { printf '%s=PASS%s\n' "$1" "${2:+ # $2}"; }
fail() { printf '%s=FAIL%s\n' "$1" "${2:+ # $2}"; }

required_file() {
  local path="$1"
  local key="$2"
  if [ -f "$path" ]; then
    pass "$key" "$path"
  else
    fail "$key" "$path missing"
    exit 2
  fi
}

if ! command -v npm >/dev/null 2>&1; then
  fail NPM_WRAPPER_PACKAGE_PREREQ_NPM "npm missing"
  exit 2
fi
pass NPM_WRAPPER_PACKAGE_PREREQ_NPM "$(npm --version)"

required_file "$OFFICIAL_PKG/package.json" NPM_WRAPPER_OFFICIAL_PACKAGE_JSON
required_file "$OFFICIAL_PKG/kaspa.js" NPM_WRAPPER_OFFICIAL_PACKAGE_JS
required_file "$OFFICIAL_PKG/kaspa_bg.wasm" NPM_WRAPPER_OFFICIAL_PACKAGE_WASM
required_file "$OFFICIAL_PKG/kaspa.d.ts" NPM_WRAPPER_OFFICIAL_PACKAGE_TYPES

rm -rf "$WORK_ROOT"
mkdir -p "$WRAPPER_DIR/vendor/kaspa-wasm" "$CONSUMER_DIR"
cp "$OFFICIAL_PKG/package.json" \
   "$OFFICIAL_PKG/kaspa.js" \
   "$OFFICIAL_PKG/kaspa_bg.wasm" \
   "$OFFICIAL_PKG/kaspa.d.ts" \
   "$OFFICIAL_PKG/kaspa_bg.wasm.d.ts" \
   "$WRAPPER_DIR/vendor/kaspa-wasm/"

cat > "$WRAPPER_DIR/package.json" <<'JSON'
{
  "name": "@kaspa-toccata/core",
  "version": "0.0.0-spike.0",
  "description": "Spike wrapper around official rusty-kaspa toccata WASM package",
  "private": false,
  "license": "MIT",
  "main": "index.cjs",
  "types": "index.d.ts",
  "files": [
    "index.cjs",
    "index.d.ts",
    "vendor/kaspa-wasm/package.json",
    "vendor/kaspa-wasm/kaspa.js",
    "vendor/kaspa-wasm/kaspa.d.ts",
    "vendor/kaspa-wasm/kaspa_bg.wasm",
    "vendor/kaspa-wasm/kaspa_bg.wasm.d.ts"
  ],
  "scripts": {
    "test": "node test-consume.cjs"
  }
}
JSON

cat > "$WRAPPER_DIR/index.cjs" <<'JS'
'use strict';

const kaspa = require('./vendor/kaspa-wasm/kaspa.js');

function createZeroCovenantBinding(authorizingInput = 0) {
  const zeroHash = new kaspa.Hash('00'.repeat(32));
  return new kaspa.CovenantBinding(authorizingInput, zeroHash);
}

function createGenesisCovenantGroup(authorizingInput = 0, outputs = [0]) {
  return new kaspa.GenesisCovenantGroup(authorizingInput, outputs);
}

function createCovenantOutput(value = 1000n) {
  const binding = createZeroCovenantBinding(0);
  const script = kaspa.payToScriptHashScript(new Uint8Array([0x51]));
  return new kaspa.TransactionOutput(BigInt(value), script, binding);
}

function getWrappedExports() {
  return {
    hasHash: typeof kaspa.Hash === 'function',
    hasCovenantBinding: typeof kaspa.CovenantBinding === 'function',
    hasGenesisCovenantGroup: typeof kaspa.GenesisCovenantGroup === 'function',
    hasTransactionOutput: typeof kaspa.TransactionOutput === 'function',
    hasRpcClient: typeof kaspa.RpcClient === 'function',
    hasResolver: typeof kaspa.Resolver === 'function'
  };
}

module.exports = {
  kaspa,
  getWrappedExports,
  createZeroCovenantBinding,
  createGenesisCovenantGroup,
  createCovenantOutput
};
JS

cat > "$WRAPPER_DIR/index.d.ts" <<'TS'
export const kaspa: any;
export function getWrappedExports(): {
  hasHash: boolean;
  hasCovenantBinding: boolean;
  hasGenesisCovenantGroup: boolean;
  hasTransactionOutput: boolean;
  hasRpcClient: boolean;
  hasResolver: boolean;
};
export function createZeroCovenantBinding(authorizingInput?: number): any;
export function createGenesisCovenantGroup(authorizingInput?: number, outputs?: number[]): any;
export function createCovenantOutput(value?: bigint | number): any;
TS

cat > "$WRAPPER_DIR/test-consume.cjs" <<'JS'
'use strict';
const core = require('./index.cjs');
const exportsStatus = core.getWrappedExports();
for (const [key, value] of Object.entries(exportsStatus)) {
  if (!value) throw new Error(`missing wrapped export ${key}`);
}
const binding = core.createZeroCovenantBinding();
const group = core.createGenesisCovenantGroup();
const output = core.createCovenantOutput(1000n);
if (!output.covenant) throw new Error('missing covenant on output');
console.log(JSON.stringify({
  exportsStatus,
  binding: binding.toJSON(),
  group: group.toJSON(),
  covenant: output.covenant.toJSON()
}));
JS

(
  cd "$WRAPPER_DIR"
  npm test >/tmp/kaspa-toccata-wrapper-direct-test.log 2>&1
)
pass NPM_WRAPPER_PACKAGE_DIRECT_IMPORT "$WRAPPER_DIR"

TARBALL_JSON="$(cd "$WRAPPER_DIR" && npm pack --json)"
TARBALL_NAME="$(node -e 'const fs=require("fs"); const data=JSON.parse(fs.readFileSync(0,"utf8")); console.log(data[0].filename)' <<<"$TARBALL_JSON")"
TARBALL="$WRAPPER_DIR/$TARBALL_NAME"
required_file "$TARBALL" NPM_WRAPPER_PACKAGE_PACK

TARBALL_CONTENTS="$(tar -tf "$TARBALL")"
if grep -q 'package/vendor/kaspa-wasm/kaspa_bg.wasm' <<<"$TARBALL_CONTENTS"; then
  pass NPM_WRAPPER_PACKAGE_TARBALL_CONTAINS_WASM
else
  fail NPM_WRAPPER_PACKAGE_TARBALL_CONTAINS_WASM
  printf '%s\n' "$TARBALL_CONTENTS" >&2
  exit 2
fi

cat > "$CONSUMER_DIR/package.json" <<'JSON'
{
  "name": "kaspa-toccata-wrapper-spike-consumer",
  "version": "0.0.0",
  "private": true,
  "type": "commonjs"
}
JSON

(
  cd "$CONSUMER_DIR"
  npm install --ignore-scripts "$TARBALL" >/tmp/kaspa-toccata-wrapper-install.log 2>&1
)
pass NPM_WRAPPER_PACKAGE_CONSUMER_INSTALL "$CONSUMER_DIR"

cat > "$CONSUMER_DIR/consume.cjs" <<'JS'
'use strict';
const core = require('@kaspa-toccata/core');
const status = core.getWrappedExports();
for (const [key, value] of Object.entries(status)) {
  if (!value) throw new Error(`missing wrapped export ${key}`);
}
const binding = core.createZeroCovenantBinding();
const group = core.createGenesisCovenantGroup();
const output = core.createCovenantOutput(1000n);
if (!output.covenant) throw new Error('missing covenant on installed wrapped output');
console.log(JSON.stringify({
  status,
  binding: binding.toJSON(),
  group: group.toJSON(),
  covenant: output.covenant.toJSON()
}));
JS

CONSUME_OUTPUT="$(node "$CONSUMER_DIR/consume.cjs")"
pass NPM_WRAPPER_PACKAGE_CONSUMER_IMPORT "$CONSUME_OUTPUT"
pass NPM_WRAPPER_PACKAGE_CONSUMER_COVENANT_CONSTRUCT
pass NPM_WRAPPER_PACKAGE_VERDICT "VALIDATED"
