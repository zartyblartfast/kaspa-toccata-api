# Repository strategy

Decision: keep `kaspa-toccata-api` as the canonical API/client repository and include the roulette proof-of-concept in this same repository for the next phase.

Remote:

```text
https://github.com/zartyblartfast/kaspa-toccata-api.git
```

## Decision

Use a single repo for now:

```text
kaspa-toccata-api/
  package.json                 # published npm client package metadata
  src/                         # API server and reusable client source
  scripts/                     # smoke/verification scripts
  docs/                        # handoff, status, decisions, proof docs
  demo/                        # generic browser API exerciser, not roulette app
  spikes/                      # bounded research/capability probes
  apps/roulette-poc/           # future roulette PoC app, when started
```

The root package remains `kaspa-toccata-api`. Its `package.json` `files` field controls the npm package surface, so adding `demo/` or a future `apps/roulette-poc/` directory to the GitHub repo does not automatically publish the roulette app or server internals to npm.

## Why same repo for roulette PoC

1. The roulette PoC is a consumer/demo of the API, not an independent product yet.
2. Keeping it in the same repo makes API/client/UI changes easier to coordinate while the proof-of-fairness presentation is still evolving.
3. The current basic demo already documents the bridge from generic API actions to roulette-stage proof presentation in `docs/BASIC_WEB_DEMO_BUTTONS.md`.
4. The repo can enforce one anti-fixture policy across API, demo, and PoC: no static app proof/result JSON, no mock/offline/dry-run success paths, and no browser-side proof authority.
5. If the roulette PoC later becomes a real standalone application, it can be split into its own repo after the app/API boundary is stable and it consumes the published npm package cleanly.

## Boundary rules

### Root API/client package

The root package should stay app-agnostic:

- package name: `kaspa-toccata-api`
- generic API/client names: `commit`, `close`, `reveal`, `commit/tx`, `close/tx`, `reveal/tx`
- no roulette-specific endpoint names in the API or client
- no generated WASM artifacts committed or published unless a later package-artifact decision explicitly changes that
- no private keys, wallet files, npm tokens, or local secret files

### Generic browser demo

`demo/basic-api-test.html` stays in the repo because it is useful API evidence and a manual diagnostic tool. It should remain generic/app-agnostic and should not become the roulette app.

Allowed in `demo/`:

- small static browser API exercisers
- labels and status text explaining the generic lifecycle
- direct browser `fetch()` calls to the real `/v1/*` API

Forbidden in `demo/`:

- static proof/result fixtures
- browser-side proof/result generation that bypasses the API
- mock transaction success paths
- roulette-only API naming that leaks back into the API surface

### Future roulette PoC

When started, place the roulette PoC under:

```text
apps/roulette-poc/
```

The roulette app should:

- consume the API/client only
- use app-friendly wording while mapping internally to generic API phases
- display proof/result data from API responses
- show claim level and limitations honestly
- present commitment, close/entropy target, live TN10 entropy, reveal, tx evidence, and verification as a player-readable proof timeline

The roulette app must not:

- load static proof/result JSON as source of truth
- compute authoritative result/proof locally in the browser
- sign or broadcast directly from the UI
- introduce endpoint/client names such as `no-more-bets` into the shared API/client

## What to commit now

Commit source, docs, smoke scripts, and bounded spikes that represent the current API/client state:

```text
LICENSE
README.md
package.json
src/client.cjs
src/client.d.ts
src/server.cjs
demo/basic-api-test
demo/basic-api-test.html
demo/index.html
docs/API_STATUS.md
docs/BASIC_WEB_DEMO_BUTTONS.md
docs/DECISIONS.md
docs/HANDOFF.md
docs/HANDOVER_PROMPT.md
docs/NEXT_STEPS.md
docs/REPO_STRATEGY.md
docs/VERIFY_TN10_TRANSACTIONS.md
docs/architecture-decision-api-runtime.md
scripts/*.sh
scripts/print-live-proof-output.js
spikes/live-tn10-broadcast-capability/README.md
spikes/live-tn10-broadcast-capability/check-live-tn10-broadcast.js
spikes/npm-wrapper-package-capability/README.md
spikes/npm-wrapper-package-capability/check-wrapper-package.sh
spikes/npm-toccata-wasm-capability/README.md
spikes/npm-toccata-wasm-capability/check-tn10-wrpc.js
scripts/spike-api-runtime-decision.sh
```

Also commit tracked documentation/source changes already present in the working tree.

## What to leave untracked / ignored

Do not commit:

```text
node_modules/
dist/
build/
target/
.env
.env.*
*.pem
*.key
*.seed
*.wallet
*.tgz
*.log
artifacts/generated/
local-secrets/
*.round-store.json
round-store*.json
```

Also do not commit:

- `/tmp/toccata-tn10-disposable-key.hex`
- generated official `kaspa_bg.wasm` or other built WASM artifacts
- clean-consumer temp directories from package-boundary smokes
- proof JSON exports used only as generated evidence
- API round-store JSON files used only for temporary persistence testing

## GitHub/npm relationship

GitHub repo contents and npm package contents are intentionally different.

The GitHub repo may contain:

- API server
- client source
- docs
- smoke scripts
- generic demo
- future roulette PoC
- bounded spikes

The npm package should remain smaller and developer-facing. Current package boundary from `npm pack` includes only:

```text
LICENSE
README.md
docs/API_STATUS.md
docs/VERIFY_TN10_TRANSACTIONS.md
package.json
src/client.cjs
src/client.d.ts
```

This is correct for now: other apps should consume the API through the npm client while the repo can still contain local server/demo/spike material.

## Split criteria for a future separate roulette repo

Consider splitting roulette into a separate repo only if at least one of these becomes true:

1. The roulette app needs independent deployment/release cadence.
2. The app needs separate issue tracking, branding, or hosting infrastructure.
3. The app is no longer a PoC and should consume only the published `kaspa-toccata-api` package plus deployed API endpoints.
4. The repo becomes too noisy for API/client consumers.
5. The roulette app needs a different license, security posture, or access model.

Until then, same repo is simpler and safer.

## Pre-commit checks

Before committing/pushing this state, run at minimum:

```bash
node --check src/server.cjs
node --check src/client.cjs
scripts/basic-web-api-test-smoke.sh
scripts/api-live-contract-smoke.sh
scripts/live-only-policy-smoke.sh
scripts/client-package-boundary-smoke.sh
```

For a fuller confidence pass, also run:

```bash
scripts/api-smoke.sh
scripts/client-lifecycle-smoke.sh
scripts/npm-client-readiness-smoke.sh
scripts/future-entropy-round-smoke.sh
scripts/persistence-smoke.sh
```

Live-broadcast smokes should only run with explicit TN10 gates and a funded disposable testnet key.
