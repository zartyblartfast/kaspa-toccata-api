# NPM Wrapper Package Capability Spike

Goal: test whether the built official `rusty-kaspa` `toccata` WASM Node package can be consumed through our own npm package boundary.

This spike intentionally creates the wrapper package under `/tmp` and does not commit generated WASM artifacts to this repo.

## Prerequisite

Run the official WASM build/import spike first if `/tmp/kaspa-toccata-api-spikes/rusty-kaspa-toccata/wasm/nodejs/kaspa` is missing:

```bash
spikes/npm-toccata-wasm-capability/build-and-check-wasm.sh
```

## Run

```bash
spikes/npm-wrapper-package-capability/check-wrapper-package.sh
```

## What it proves

- a temporary own package named `@kaspa-toccata/core` can wrap the official generated `kaspa-wasm` package;
- the wrapper can be packed with `npm pack`;
- the packed tarball includes `kaspa_bg.wasm`;
- a clean consumer project can install the tarball;
- importing `@kaspa-toccata/core` from the consumer resolves the vendored WASM correctly;
- wrapped covenant primitive construction works after install.

## What it does not prove

- publishing to the npm registry;
- a final source/build strategy for generated WASM artifacts;
- JS/TS transaction build/sign/broadcast;
- long-term package naming.

## Expected output

```text
NPM_WRAPPER_PACKAGE_PREREQ_NPM=PASS
NPM_WRAPPER_OFFICIAL_PACKAGE_JSON=PASS
NPM_WRAPPER_OFFICIAL_PACKAGE_JS=PASS
NPM_WRAPPER_OFFICIAL_PACKAGE_WASM=PASS
NPM_WRAPPER_OFFICIAL_PACKAGE_TYPES=PASS
NPM_WRAPPER_PACKAGE_DIRECT_IMPORT=PASS
NPM_WRAPPER_PACKAGE_PACK=PASS
NPM_WRAPPER_PACKAGE_TARBALL_CONTAINS_WASM=PASS
NPM_WRAPPER_PACKAGE_CONSUMER_INSTALL=PASS
NPM_WRAPPER_PACKAGE_CONSUMER_IMPORT=PASS
NPM_WRAPPER_PACKAGE_CONSUMER_COVENANT_CONSTRUCT=PASS
NPM_WRAPPER_PACKAGE_VERDICT=PASS # VALIDATED
```
