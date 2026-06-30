# Next Steps

## Immediate

1. Test live Node TN10 wRPC connectivity using the built official Toccata WASM package.

```text
spikes/npm-toccata-wasm-capability/
```

2. Investigate whether the built Toccata WASM package can be wrapped/published as our own npm package cleanly.

3. Implement Rust spike:

```text
spikes/rust-toccata-capability/
```

4. Update:

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
