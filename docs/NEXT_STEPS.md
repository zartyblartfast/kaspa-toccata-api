# Next Steps

## Immediate

Round persistence/state-provider seam, Milestone 4 live TN10 future entropy round, live-TN10-only API policy enforcement, reusable typed client/package boundary, and first public npm client publish, and proof-level TN10 transaction evidence are implemented and verified. Milestone 1 live TN10 status API shell remains verified. The commit and close write endpoints now have real live TN10 implementation paths behind explicit testnet-only gates; dry-run/mock transaction paths are forbidden. Live broadcast validation was recorded for txid `79e2aa3be09dc0847a7888aea06437a0793c72b97e76cd83205f14425b436021`, but production write endpoints remain gated.

Recommended next action: commit and push the current API/client/demo/docs state to `https://github.com/zartyblartfast/kaspa-toccata-api.git`, using the repo strategy in `docs/REPO_STRATEGY.md`. After that, use the improved basic web API test page for one more manual browser pass before starting the roulette PoC or adding a browser-compatible ESM client import path. The API is live-proven, and the demo page now has a reset/new-round control, next-action guidance, phase-completion button disabling, and already-recorded tx handling.

The generic API contract smoke now exists at `scripts/api-live-contract-smoke.sh`. It is intentionally app-agnostic and currently reports `API_LIVE_CONTRACT_READY=PASS` and now reports `API_LIVE_CONTRACT_READY=PASS` for the fail-closed contract; actual broadcasts still require explicit TN10 gates.

## Keep runnable

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
scripts/tn10-live-commit-smoke.sh
scripts/tn10-live-close-smoke.sh
scripts/tn10-live-reveal-smoke.sh
node spikes/live-tn10-broadcast-capability/check-live-tn10-broadcast.js
scripts/spike-api-runtime-decision.sh
RUN_LIVE_TN10_BROADCAST_SPIKE=1 scripts/spike-api-runtime-decision.sh
RUN_NPM_WRAPPER_PACKAGE=1 scripts/spike-api-runtime-decision.sh
spikes/npm-wrapper-package-capability/check-wrapper-package.sh
```

## Current API commands

Run the service manually:

```bash
PORT=8787 node src/server.cjs
```

Smoke it from another shell:

```bash
curl -fsS http://127.0.0.1:8787/v1/health
curl -fsS http://127.0.0.1:8787/v1/capabilities
curl -fsS http://127.0.0.1:8787/v1/network/status
curl -fsS -X POST http://127.0.0.1:8787/v1/rounds -H 'content-type: application/json' --data '{"game":"roulette"}'
```

## Not yet

- Do not build roulette app yet.
- Do not add static proof JSON fixtures.
- Do not enable TN10 signing/broadcast before explicit safety gates and user authorization; current write endpoints reject dry-run requests and fail closed by default unless all live TN10 gates are present.
- Do not publish server/runtime or generated-WASM packages until their package naming, generated artifact strategy, and auth flow are explicit. The client package `kaspa-toccata-api@0.1.1` is already published.

## Live broadcast env gates

```bash
export TOCCATA_ENABLE_TN10_WRITES=1
export TOCCATA_TN10_PRIVATE_KEY='<64 hex char testnet-only private key>'
export TOCCATA_TN10_BROADCAST_ACK='I understand this spends TN10 testnet funds'
# optional
export TOCCATA_TN10_DESTINATION_ADDRESS='<kaspatest:...>'
export TOCCATA_TN10_SEND_AMOUNT_SOMPI=10000000
node spikes/live-tn10-broadcast-capability/check-live-tn10-broadcast.js
```

## Validated live broadcast evidence

```text
LIVE_TN10_BROADCAST_TXID=79e2aa3be09dc0847a7888aea06437a0793c72b97e76cd83205f14425b436021
```

## Live broadcast key/funding investigation

With explicit user approval, checked historical Kaspa Fair Foundation / lab locations for a usable funded TN10 key:

- Foundation profile `.env` files contain no TN10 key material.
- Historical helper key file under `/root/kaspa-fair-lab/spikes/tn12-minimal-covenant/local-secrets/env-059-helper-key/helper-private-key.hex` exists and maps on TN10 to `kaspatest:qzn7auhpkdladk9m20f02dz46clvv7whgumgrm4pex4djesaued0g9wutcqld`, but live TN10 UTXO lookup returned zero spendable entries.
- Another old test key under `/root/kaspa-fair-lab/spikes/tn12-minimal-covenant/local-secrets/env-049-key-address/tn12-test-only-key.private` maps on TN10 to `kaspatest:qqaq5f4ju52g9r869c50n55lmtgku9nsf2pc56y76neaj7rksmewg2ytrxccg`, but live TN10 UTXO lookup returned zero spendable entries.
- Old wallet files `/root/.kaspa/env052-tn10-test-only.wallet` and `/root/.kaspa/env052-tn10-test-only.password` exist, but the password file did not decrypt the wallet in the current CLI attempt (`Unable to decrypt this wallet`). Do not claim this wallet is usable unless a later run proves it.
- A new disposable key was generated locally at `/tmp/toccata-tn10-disposable-key.hex` for possible faucet funding; its public address is `kaspatest:qp6pqywzj8pvmk6l8pl775jqvsvw59md5hqrvtwrfzy2pngcrzgcge2sx3gd2`. The private key must not be printed or committed.
- The TN10 faucet URL documented historically is currently behind Cloudflare challenge from this environment, so automated faucet funding was not completed.


## Basic web API test page

Use `GET /demo/basic-api-test` while the API is running to manually verify the minimal app-facing lifecycle before building the roulette PoC UI.

Static-server note: if the page is opened from a separate static server such as port 8789, `/v1/*` calls will hit that static server unless the page's `API base URL` field is set to the actual API process, for example `http://127.0.0.1:8787`. The API supports CORS preflight for this basic test page.

Current demo state-flow behavior is documented in detail in `docs/BASIC_WEB_DEMO_BUTTONS.md`, including a section/button map, API endpoint behavior, roulette-stage mapping, and proof-of-fairness presentation notes. Summary:

1. `New round / reset UI` clears current round state, output/status text, proof cache, and generates fresh default seeds.
2. Successful `commit/tx`, `close/tx`, or `reveal/tx` responses update the round summary, surface txids through `tn10Writes`, and disable the completed yellow transaction button for that round.
3. `live_<phase>_already_recorded` API errors are treated as already-complete states: the page fetches the current round, displays existing `round.tn10Writes[phase].transactionIds`, and disables that phase button.
4. A next-action banner and button disabling prevent transaction buttons before the required state step has advanced the round.
5. The page remains generic/app-agnostic and uses browser `fetch()` against the same `/v1/*` API surface wrapped by the npm client.
