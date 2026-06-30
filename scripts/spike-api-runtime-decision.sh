#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

pass() { printf '%s=PASS
' "$1"; }
fail() { printf '%s=FAIL
' "$1"; }
unknown() { printf '%s=UNKNOWN
' "$1"; }

[ -f docs/architecture-decision-api-runtime.md ] && pass ARCH_DECISION_DOC || fail ARCH_DECISION_DOC
[ -d spikes/npm-toccata-wasm-capability ] && pass NPM_SPIKE_DIR || fail NPM_SPIKE_DIR
[ -d spikes/rust-toccata-capability ] && pass RUST_SPIKE_DIR || fail RUST_SPIKE_DIR

if find .   -path './.git' -prune -o   -path './node_modules' -prune -o   -type f \(     -name 'sample-round.json' -o     -name 'toccata-fairness-proof.json' -o     -name 'proof.json' -o     -name 'round.json'   \) -print | grep -q .; then
  fail NO_STATIC_APP_FIXTURES
else
  pass NO_STATIC_APP_FIXTURES
fi

# First real capability check: source-level npm/Toccata WASM evidence.
if [ -x spikes/npm-toccata-wasm-capability/check-source-capability.py ] || [ -f spikes/npm-toccata-wasm-capability/check-source-capability.py ]; then
  python3 spikes/npm-toccata-wasm-capability/check-source-capability.py
else
  unknown NPM_TOCCATA_WASM_SOURCE_COVENANT_BINDING
  unknown NPM_TOCCATA_WASM_SOURCE_GENESIS_COVENANT_GROUP
  unknown NPM_TOCCATA_WASM_SOURCE_COVENANT_ID_HASH
  unknown NPM_TOCCATA_WASM_SOURCE_TRANSACTION_OUTPUT_COVENANT
  unknown NPM_TOCCATA_WASM_BUILD
  unknown NPM_TN10_WRPC_CONNECT
fi

if [ "${RUN_WASM_BUILD:-0}" = "1" ]; then
  spikes/npm-toccata-wasm-capability/build-and-check-wasm.sh
else
  if [ -f /tmp/kaspa-toccata-api-spikes/rusty-kaspa-toccata/wasm/nodejs/kaspa/kaspa.js ]; then
    KASPA_WASM_PKG=/tmp/kaspa-toccata-api-spikes/rusty-kaspa-toccata/wasm/nodejs/kaspa node spikes/npm-toccata-wasm-capability/check-built-package.js || true
  else
    unknown NPM_TOCCATA_WASM_BUILD "set RUN_WASM_BUILD=1 to run build"
  fi
fi

# Rust capability checks remain pending.
unknown RUST_TOCCATA_TX_VERSION
unknown RUST_COVENANT_OUTPUT
unknown RUST_TN10_WRPC_CONNECT
printf 'RECOMMENDED_RUNTIME=undecided\n'
