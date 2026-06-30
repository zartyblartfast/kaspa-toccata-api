# Next Steps

## Immediate

1. Decide whether to do one more npm spike before Milestone 1:

```text
A. package/wrap the built Toccata WASM as our own npm package
B. test JS/TS transaction construction/signing/broadcast capability
C. start Milestone 1 API shell using npm/WASM for read-only TN10 status
```

2. If choosing package/wrap next, investigate whether the built `kaspa-wasm` output can be consumed through our own package boundary without copying large generated artifacts into the wrong place.

3. If choosing API shell next, implement:

```text
GET /v1/health
GET /v1/capabilities
GET /v1/network/status
scripts/api-smoke.sh
```

4. If choosing Rust comparison next, implement:

```text
spikes/rust-toccata-capability/
```

5. Update:

```text
docs/architecture-decision-api-runtime.md
```

with real PASS/FAIL evidence.

## After runtime decision

Implement Milestone 1 API shell:

```text
GET /v1/health
GET /v1/capabilities
GET /v1/network/status
scripts/api-smoke.sh
```

## Not yet

- Do not build roulette app yet.
- Do not add static proof JSON fixtures.
- Do not implement TN10 write/broadcast before explicit safety gates and user authorization.
