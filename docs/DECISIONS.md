# Decisions

## 0001 — API-first project structure

Status: accepted

The project will build a reusable Kaspa TN10/Toccata API/developer layer before any roulette UI.

Reason:

- The previous project drifted toward static JSON proof artifacts.
- A reusable API boundary gives other apps a path to adopt the work.
- Roulette should prove the public integration path, not bypass it.

## 0002 — No app-facing static proof fixtures

Status: accepted

The project must not commit app-facing static proof/result round JSON such as `sample-round.json`, `proof.json`, `round.json`, or `toccata-fairness-proof.json`.

Generated proof exports are allowed only as output evidence under temporary/generated artifact locations. They must not be consumed by the app as source-of-truth.

## 0003 — Runtime implementation is provisionally TypeScript/npm-first for early API milestones

Status: provisional for Milestone 1/status endpoints and local lifecycle; write endpoints still pending safety design

Options under review:

- TypeScript/npm-first using official `rusty-kaspa` Toccata WASM.
- Rust service using official `rusty-kaspa` `toccata` branch plus npm client/wrapper.
- Hybrid npm package wrapping a Rust binary.

Milestone 1 should proceed TypeScript/npm-first using official Toccata WASM for live TN10 status. The write/covenant-enforced runtime decision remains pending production write-endpoint safety design and/or Rust comparison evidence.

## 0004 — npm-friendly distribution is a first-class goal

Status: accepted

Even if the core implementation is Rust-backed, the developer-facing surface should support npm installation/use where practical.

Possible packages:

```text
@<scope>/toccata-client
@<scope>/toccata-api
@<scope>/toccata-cli
@<scope>/toccata-mcp
```

## 0005 — Generated WASM artifacts are not committed yet

Status: accepted for current spike stage

The npm wrapper-package spike may copy generated official `kaspa-wasm` output into `/tmp` to test package boundaries and tarball consumption. Generated WASM artifacts should not be committed to this repo until the real package layout, source/build provenance, and publish strategy are explicit.

## 0006 — Historical offline write spike is superseded by live-TN10-only policy

Status: accepted as current evidence

An earlier offline/synthetic transaction spike validated mechanics, but that code has been removed from the repo because offline/mock paths are no longer allowed. Current write work must use live TN10 only through explicit testnet-only gates.

## 0007 — Live TN10 broadcast must be fail-closed and env-gated

Status: accepted

Any live TN10 broadcast spike must require `KASPA_NETWORK_ID=testnet-10` or default testnet-10, `TOCCATA_ENABLE_TN10_WRITES=1`, a private key supplied only via environment variable, and exact acknowledgement phrase `I understand this spends TN10 testnet funds`. Without all gates present, the script must exit without broadcasting.


## 0008 — Live TN10 broadcast acceptance validated by txid

Status: accepted as spike evidence

A guarded live TN10 broadcast transaction was validated at txid `79e2aa3be09dc0847a7888aea06437a0793c72b97e76cd83205f14425b436021`. This upgrades the evidence from offline submit-surface only to at least one accepted live testnet broadcast. It does not by itself approve production write endpoints; write endpoints still require explicit testnet-only safety gates, env-only secrets, no mainnet path, and user authorization.

## 0009 — Local lifecycle path superseded by live-TN10-only policy

Status: accepted for API-shape proof

The previous in-memory local-dev lifecycle is no longer acceptable as a public implementation path. API behavior must use live TN10 evidence or fail closed; local/mock entropy/proof paths are disabled.


## 0010 — Root package exports reusable API client first

Status: accepted for current package boundary

The root `kaspa-toccata-api` package exports the reusable HTTP client (`src/client.cjs`) with TypeScript declarations (`src/client.d.ts`) before exposing server internals or generated WASM artifacts. `scripts/client-package-boundary-smoke.sh` must keep proving that a clean consumer can install the packed package, import `kaspa-toccata-api`, and call the API through the client. Generated WASM artifacts remain outside the committed package until package provenance and publish strategy are explicit.


## 0011 — Future entropy uses live TN10 blue-score target evidence

Status: accepted for first live entropy implementation

The future-entropy milestone fixes `targetBlueScore = current sinkBlueScore at close + targetOffsetBlueScore`, then fetches a live TN10 block whose header blue score is at or after that target and derives result material from `roundId`, commitment, client seed, bet ledger hash, block hash, blue score, and DAA score. This earns `claimLevel: tn10_future_entropy` but does not claim TN10 write commit/reveal or Toccata covenant enforcement. DAA-score target semantics remain supported only as a compatibility fallback for older requests.


## 0012 — Round persistence starts as explicit JSON state-provider seam

Status: accepted for dev/test lifecycle continuity

The first persistence implementation is an opt-in file-backed JSON store enabled by `TOCCATA_ROUND_STORE_FILE`. The server loads it at startup and atomically rewrites it after round mutations, allowing local and future-entropy lifecycle state to survive service restarts. This is a state-provider seam for demos/tests, not yet a production database. The commit step stores only the commitment; the unrevealed server seed is not persisted before reveal.


## 0013 — TN10 write endpoints reject dry-runs and fail closed by default

Status: accepted

The write API surface exposes `POST /v1/rounds/:roundId/commit/tx`, `/close/tx`, and `/reveal/tx` only as live-write endpoints. Requests containing `dryRun` are rejected with `400 dry_run_forbidden` because mock/preflight transaction paths can become permanent fixtures. Ordinary write requests fail closed with `403 tn10_writes_disabled` unless exact TN10-only env gates are satisfied. With gates satisfied, `commit/tx` now attempts the real live TN10 path: live UTXO lookup, transaction assembly with commitment payload, signing, broadcast, txid recording, and evidence lookup. Reveal still return `501 tn10_write_not_implemented` until their real live implementations are added.

## 0014 — Dry-run transaction assembly was removed before it became a project seam

Status: accepted

A short-lived commit transaction dry-run draft path was removed by policy. The project direction is now explicit: no API transaction dry-runs, no synthetic funding drafts, and no dry-run/preflight write mode. Write endpoints should either execute a real TN10 testnet transaction through explicit safety gates or fail closed.

## 0015 — Live commit write path is implemented before reveal write

Status: accepted for first live API write implementation

`POST /v1/rounds/:roundId/commit/tx` is the first endpoint with a live TN10 implementation path. When exact testnet-only gates are present, it derives the source address from `TOCCATA_TN10_PRIVATE_KEY`, connects to live TN10, requires a funded non-coinbase UTXO, builds a transaction with a commitment payload, signs, submits, records transaction IDs/evidence under `round.tn10Writes.commit`, and returns the updated round. If gates or funds are absent, it fails closed and does not mock. Close and reveal live write implementations were added later behind the same gates.

## 0016 — Keep roulette PoC in the API repo until app boundary stabilizes

Status: accepted for next phase

The canonical repo remains `kaspa-toccata-api`, and the future roulette proof-of-concept should initially live in this same repo under `apps/roulette-poc/`. The API/client package remains app-agnostic at the root, while the roulette app consumes the API/client as a demo/consumer. The root `package.json` `files` field keeps npm package contents limited to the developer-facing client/docs, so repo contents and npm package contents can differ safely.

Split roulette into a separate repo only if it needs independent deployment/release cadence, separate branding/issue tracking, or a stable app boundary where it consumes only the published `kaspa-toccata-api` npm package plus deployed API endpoints. See `docs/REPO_STRATEGY.md`.
