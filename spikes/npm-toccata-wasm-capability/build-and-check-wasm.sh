#!/usr/bin/env bash
set -euo pipefail

CACHE="${KASPA_TOCCATA_SPIKE_CACHE:-/tmp/kaspa-toccata-api-spikes/rusty-kaspa-toccata}"
WASM_DIR="$CACHE/wasm"
PKG_DIR="$WASM_DIR/nodejs/kaspa"

pass() { printf '%s=PASS%s\n' "$1" "${2:+ # $2}"; }
fail() { printf '%s=FAIL%s\n' "$1" "${2:+ # $2}"; }
unknown() { printf '%s=UNKNOWN%s\n' "$1" "${2:+ # $2}"; }

if [ ! -d "$CACHE/.git" ]; then
  fail OFFICIAL_RUSTY_KASPA_TOCCATA_CLONE "run check-source-capability.py first"
  exit 2
fi

if ! command -v wasm-pack >/dev/null 2>&1; then
  fail NPM_TOCCATA_WASM_BUILD_PREREQ_WASM_PACK "install wasm-pack"
  exit 2
fi

if ! rustup target list --installed | grep -q '^wasm32-unknown-unknown$'; then
  rustup target add wasm32-unknown-unknown >/dev/null
fi
pass NPM_TOCCATA_WASM_BUILD_PREREQ_WASM_TARGET

if ! command -v clang >/dev/null 2>&1; then
  fail NPM_TOCCATA_WASM_BUILD_PREREQ_CLANG "clang required by secp256k1-sys wasm build"
  exit 2
fi
pass NPM_TOCCATA_WASM_BUILD_PREREQ_CLANG

(
  cd "$WASM_DIR"
  ./build-node >/tmp/kaspa-toccata-wasm-build.log 2>&1
)

if [ -f "$PKG_DIR/kaspa.js" ] && [ -f "$PKG_DIR/kaspa_bg.wasm" ] && [ -f "$PKG_DIR/kaspa.d.ts" ]; then
  pass NPM_TOCCATA_WASM_BUILD "$PKG_DIR"
else
  fail NPM_TOCCATA_WASM_BUILD "expected package files missing; see /tmp/kaspa-toccata-wasm-build.log"
  exit 2
fi

KASPA_WASM_PKG="$PKG_DIR" node spikes/npm-toccata-wasm-capability/check-built-package.js
