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

# Real capability checks will be implemented inside the spike directories.
unknown NPM_TOCCATA_WASM_BUILD
unknown NPM_COVENANT_BINDING
unknown NPM_GENESIS_COVENANT_GROUP
unknown NPM_TN10_WRPC_CONNECT
unknown RUST_TOCCATA_TX_VERSION
unknown RUST_COVENANT_OUTPUT
unknown RUST_TN10_WRPC_CONNECT
printf 'RECOMMENDED_RUNTIME=undecided
'
