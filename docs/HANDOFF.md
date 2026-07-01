# Handoff

## Current milestone

Guarded TN10 write endpoint surface with dry-runs forbidden, Milestone 4 live TN10 future entropy round, live-TN10-only API policy enforcement, and the reusable typed client/package boundary are implemented and verified. JSON persistence remains temporary dev/test only. Milestone 1 API shell remains implemented and verified using npm/WASM for live TN10 status. JS/TS live transaction write capability is validated. A guarded live TN10 broadcast txid was validated: `79e2aa3be09dc0847a7888aea06437a0793c72b97e76cd83205f14425b436021`.

- Stage 3: runtime/API presentation decision matrix is drafted in `docs/architecture-decision-api-runtime.md`.
- Stage 4: npm/Toccata WASM source, build, import, covenant-construction, live TN10 wRPC status, own npm wrapper-package boundary, JS/TS live transaction write, and guarded live broadcast evidence exist.
- Milestone 1: `GET /v1/health`, `GET /v1/capabilities`, `GET /v1/network/status`, and `scripts/api-smoke.sh` pass.
- Milestone 2: live-TN10-only lifecycle policy checks, reusable client calls, and clean package-consumer import pass.
- Generic API contract smoke exists at `scripts/api-live-contract-smoke.sh` and reports `API_LIVE_CONTRACT_READY=PASS`.
- Milestone 4: future entropy lifecycle fixes target DAA score, fetches live TN10 block evidence, derives/reveals result, and verifies proof replay.
- Persistence seam: `TOCCATA_ROUND_STORE_FILE` file-backed round store survives service restart and supports reveal/proof verification after restart.

## What works now

- Repository scaffold exists.
- Official `rusty-kaspa` `toccata` branch Node WASM package builds and imports.
- Node can construct covenant primitives.
- Node can connect to live TN10 wRPC and fetch server/blockDAG info.
- Temporary own npm package `@kaspa-toccata/core` can wrap the built official WASM package, pack into a tarball containing `kaspa_bg.wasm`, install into a clean consumer, import through the package boundary, and construct covenant primitives.
- JS/TS live commit write is proven through the API: live UTXO lookup, transaction construction, signing, submission, txid recording, and external TN10 REST evidence retrieval.
- A live TN10 broadcast spike transaction was validated at txid `79e2aa3be09dc0847a7888aea06437a0793c72b97e76cd83205f14425b436021`.
- The API live commit endpoint was validated with real TN10 commit txid `5576e597aa80197de50dd6dfe3f9c351ba5c8c58b5e7d9be33bc82b5d86258e8`; public TN10 API evidence returned accepting block hash `7a7177a5da86857e4e0a32ca2afbb4828d370eae42a76e4873764eaad325b60a` and payload bytes.
- The API service starts via `node src/server.cjs`.
- `/v1/network/status` returns live TN10 network evidence; the broader project also has validated broadcast txid evidence.
- Live-only policy checks work through HTTP: local/mock entropy is rejected, dry-runs are forbidden, and live TN10 future entropy/proof paths pass.
- Round setup responses now use `claimLevel: live_tn10_pending`; `local_dev_only`/`local-dev` are removed from the public API.
- Future entropy responses/proofs use `claimLevel: tn10_future_entropy` and include live TN10 block hash/blue-score evidence.
- Optional file-backed round store exists via `TOCCATA_ROUND_STORE_FILE`; commit stores only the commitment, not the unrevealed server seed. This remains a temporary dev/test seam only.

- Guarded write endpoints: `POST /v1/rounds/:roundId/commit/tx`, `/close/tx`, and `/reveal/tx` reject any `dryRun` request with `400 dry_run_forbidden` and fail closed for ordinary write requests unless TN10 write gates are satisfied. Commit, close, and reveal endpoints have live TN10 implementation paths: with explicit gates and a funded env-supplied testnet key they look up live UTXOs, build/sign/submit real TN10 transactions, record txid/evidence on the round, and never fall back to mocks.
- Reusable client boundary exists at `src/client.cjs` with declarations at `src/client.d.ts`; package export/import is verified by clean npm consumer smokes. Public npm package `kaspa-toccata-api@0.1.1` has been published and registry-install verified; it includes proof transaction-evidence docs/client package content.
- Safety flags remain false: `canSign`, `canBroadcast`, `canCreateTransactions`, `mainnetEnabled`.

## Last verified commands

```bash
scripts/api-smoke.sh
scripts/api-live-contract-smoke.sh
scripts/basic-web-api-test-smoke.sh
scripts/live-only-policy-smoke.sh
scripts/client-lifecycle-smoke.sh
scripts/client-package-boundary-smoke.sh
scripts/npm-client-readiness-smoke.sh
scripts/future-entropy-round-smoke.sh
scripts/proof-transaction-evidence-smoke.sh
scripts/persistence-smoke.sh
scripts/tn10-write-round-smoke.sh
scripts/tn10-live-close-smoke.sh
scripts/tn10-live-reveal-smoke.sh
```

Latest `scripts/api-smoke.sh` output:

```text
API_PREREQ_KASPA_WASM_PKG=PASS
HEALTH_OK=PASS
CAPABILITIES_OK=PASS
TN10_STATUS_OK=PASS
NO_STATIC_APP_FIXTURES=PASS
```

Latest `scripts/live-only-policy-smoke.sh` output:

```text
ROUND_CREATE_LIVE_PENDING_OK=PASS
ROUND_COMMIT_STATE_ONLY_OK=PASS
LOCAL_ENTROPY_DISABLED=PASS
DRY_RUN_FORBIDDEN=PASS
NO_STATIC_APP_FIXTURES=PASS
```

## Important files

```text
package.json
src/server.cjs
src/client.cjs
src/client.mjs
scripts/api-smoke.sh
scripts/api-live-contract-smoke.sh
scripts/basic-web-api-test-smoke.sh
scripts/live-only-policy-smoke.sh
scripts/client-lifecycle-smoke.sh
scripts/client-package-boundary-smoke.sh
scripts/npm-client-readiness-smoke.sh
scripts/future-entropy-round-smoke.sh
scripts/proof-transaction-evidence-smoke.sh
scripts/persistence-smoke.sh
scripts/tn10-write-round-smoke.sh
scripts/spike-api-runtime-decision.sh
docs/architecture-decision-api-runtime.md
docs/DECISIONS.md
docs/API_STATUS.md
docs/NEXT_STEPS.md
docs/REPO_STRATEGY.md
docs/BASIC_WEB_DEMO_BUTTONS.md
docs/ROULETTE_UI_DESIGN_HANDOVER.md
spikes/npm-toccata-wasm-capability/README.md
spikes/npm-wrapper-package-capability/README.md
spikes/npm-wrapper-package-capability/check-wrapper-package.sh
spikes/live-tn10-broadcast-capability/README.md
spikes/live-tn10-broadcast-capability/check-live-tn10-broadcast.js
spikes/rust-toccata-capability/README.md
```


## Latest browser demo session notes

- Basic web demo page: `GET /demo/basic-api-test.html` served by `node src/server.cjs`. Remote browser testing from laptop needs SSH tunnel to the VPS API port, not a static Python server.
- Latest manual live-write test reached all steps successfully after using `Close state` to advance/reset the UI flow. User reported that the sequence could run from 1 through the end, including yellow `commit/tx`, `close/tx`, and `reveal/tx` buttons, without error.
- The basic web page state model has been improved: it now includes `New round / reset UI`, clears current round/proof/output/status state, shows a next-action banner, disables transaction buttons until the required state step is done, disables completed `commit/tx`, `close/tx`, and `reveal/tx` buttons once txids are recorded, and treats `live_<phase>_already_recorded` as already complete by fetching/showing existing `tn10Writes[phase].transactionIds`.
- Button-by-button demo behavior and roulette-stage/proof-of-fairness mapping are documented in `docs/BASIC_WEB_DEMO_BUTTONS.md`. Use this when deciding how the roulette PoC presents commitment, close/entropy target, live entropy, reveal, transaction evidence, and proof verification.
- The page remains generic/app-agnostic and calls the same `/v1/*` HTTP API surface wrapped by the `kaspa-toccata-api` npm client; it does not load static proof/result fixtures or perform browser-side proof/result substitution.
- Rejected roulette PoC scaffold: the first `apps/roulette-poc/` implementation proved package-name browser import (`createToccataApiClient` from `kaspa-toccata-api`) and real `/v1/*` API wiring, but the user corrected that its layout was too API-demo-like and should not be preserved as target UI. The server no longer serves `/apps/roulette-poc/*`; `/src/client.mjs` remains served for future browser package imports. Target UI design is documented in `docs/ROULETTE_UI_DESIGN_HANDOVER.md`: two sections only, `Roulette Game` on top using the older `/root/kaspa-fair-foundation/examples/roulette-poc/ui/` table-first chip-placement UI as the visual/interaction starting point, and `Proof of Fairness` below using `/root/kaspa-fair-foundation/examples/roulette-poc/ui-sketches/env095-flowchart-*` as the flowchart starting point.
- A live-write-enabled server was killed before handoff; do not leave funded-key API processes running after testing.

## Current blockers / unknowns

- Live commit write is implemented and validated; live close write is implemented behind the same gates and has fail-closed smoke coverage; reveal live write is implemented behind the same gates and has fail-closed smoke coverage.
- Client package layout is finalized for first public release `kaspa-toccata-api@0.1.0`; server/runtime and generated-WASM artifact strategy remain future work.
- Rust comparison remains unrun.
- Toccata covenant lineage/state-transition proof is not implemented.

## Next 3 actions

1. In the next session, read `docs/ROULETTE_UI_DESIGN_HANDOVER.md` before changing UI code.
2. Redesign `apps/roulette-poc/` as two sections: top `Roulette Game` using `/root/kaspa-fair-foundation/examples/roulette-poc/ui/` table-first chip-placement behavior, and lower `Proof of Fairness` using `/root/kaspa-fair-foundation/examples/roulette-poc/ui-sketches/env095-flowchart-*` adapted to live API data.
3. Preserve npm-client API usage (`import { createToccataApiClient } from 'kaspa-toccata-api'`) and keep smoke/ad-hoc checks proving no static round/proof/result JSON, no mock/offline paths, no app-level raw `fetch()`, and fail-closed TN10 writes by default.

## Do not regress

- API before app.
- No static app proof/result fixtures.
- Curl/scripts prove API milestones.
- Roulette app consumes API/client only.
- Do not copy old `kaspa-fair-foundation` static JSON workflow.
- Do not commit generated WASM artifacts until package strategy is explicit.
- Do not enable signing/broadcast endpoints without explicit testnet-only safety gates and user authorization.

## Live broadcast key/funding investigation

With explicit user approval, checked historical Kaspa Fair Foundation / lab locations for a usable funded TN10 key:

- Foundation profile `.env` files contain no TN10 key material.
- Historical helper key file under `/root/kaspa-fair-lab/spikes/tn12-minimal-covenant/local-secrets/env-059-helper-key/helper-private-key.hex` exists and maps on TN10 to `kaspatest:qzn7auhpkdladk9m20f02dz46clvv7whgumgrm4pex4djesaued0g9wutcqld`, but live TN10 UTXO lookup returned zero spendable entries.
- Another old test key under `/root/kaspa-fair-lab/spikes/tn12-minimal-covenant/local-secrets/env-049-key-address/tn12-test-only-key.private` maps on TN10 to `kaspatest:qqaq5f4ju52g9r869c50n55lmtgku9nsf2pc56y76neaj7rksmewg2ytrxccg`, but live TN10 UTXO lookup returned zero spendable entries.
- Old wallet files `/root/.kaspa/env052-tn10-test-only.wallet` and `/root/.kaspa/env052-tn10-test-only.password` exist, but the password file did not decrypt the wallet in the current CLI attempt (`Unable to decrypt this wallet`). Do not claim this wallet is usable unless a later run proves it.
- A new disposable key was generated locally at `/tmp/toccata-tn10-disposable-key.hex` for possible faucet funding; its public address is `kaspatest:qp6pqywzj8pvmk6l8pl775jqvsvw59md5hqrvtwrfzy2pngcrzgcge2sx3gd2`. The private key must not be printed or committed.
- The TN10 faucet URL documented historically is currently behind Cloudflare challenge from this environment, so automated faucet funding was not completed.
