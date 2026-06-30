# kaspa-toccata-api

Reusable Kaspa TN10/Toccata API and developer-facing integration layer for app-agnostic proof-of-fairness workflows.

This repository is intentionally API-first. The roulette proof-of-concept will come later as a consumer of this API/client, not as the source of proof logic.

## Current stage

Stage 3/4 scaffolding:

1. Decide the runtime/API presentation model.
2. Run small capability spikes against official Kaspa sources.
3. Only then implement the first API shell.

## Non-negotiables

- API before app.
- Curl/scripts before UI.
- No app-facing static proof/result JSON fixtures.
- Roulette consumes the public API/client only.
- Claim levels must be explicit and conservative.
- TN10 write support must be guarded and disabled by default.

## Official source priority

1. `kaspanet/kips` for KIP-17, KIP-20, KIP-21 semantics.
2. `kaspanet/rusty-kaspa` `toccata` branch for implementation APIs and WASM bindings.
3. `kaspanet/docs` for integration, wRPC, and node setup.
4. Old `kaspa-fair-foundation` only as historical workflow/evidence reference.

## Next command

```bash
scripts/spike-api-runtime-decision.sh
```

At this initial commit the script is a scaffold: it checks project guardrails and records which capability spikes still need implementation.
