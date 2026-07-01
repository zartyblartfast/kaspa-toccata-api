# Basic web demo button map

This document treats `demo/basic-api-test.html` as the completed generic Toccata API demo page. It maps every visible action in the eight demo sections to the API behavior and to the likely roulette proof-of-fairness stage that a future roulette PoC will need to present clearly.

The page is intentionally generic/app-agnostic. It uses browser `fetch()` calls to the same `/v1/*` HTTP API surface wrapped by the `kaspa-toccata-api` npm client. It does not generate proof authority in the browser, does not load static proof/result files, and does not mock transaction results.

## Page-level controls

| Area | Button / label | API behavior | Roulette-stage meaning | Proof-of-fairness presentation note |
| --- | --- | --- | --- | --- |
| Current round | API base URL | Selects same-origin API by default or an explicitly entered API origin when the page is served separately. | App configuration / service connection. | In roulette, hide or preconfigure this for normal users; keep visible in diagnostic/dev mode. |
| Current round | New round / reset UI | Browser-only reset of current page state: clears current round id, cached proof, statuses/output, and generates fresh default seed inputs. It does not delete server-side rounds. | Start a fresh roulette hand/spin/session display. | Useful as a dealer/operator reset control; label clearly that it starts a new UI flow, not an on-chain deletion. |
| Current round | Next-action banner | Browser-only guidance derived from the current round state and recorded `tn10Writes`. | Guides the player/operator through commit, close, entropy, reveal, and proof stages. | This pattern should become the roulette app's proof timeline/status rail. |

## Section 1: API health and TN10 status

| Button / label | Endpoint | What it does | Roulette-stage mapping | Proof-of-fairness presentation note |
| --- | --- | --- | --- | --- |
| Health | `GET /v1/health` | Confirms the local API service is reachable and identifies service/network basics. | Pre-round system readiness. | In roulette, surface as a simple service-connected indicator, not as fairness proof. |
| Capabilities | `GET /v1/capabilities` | Shows live-TN10-only policy, supported claim levels, safety flags, provider mode, and limitations. | Table/system rules and safety disclosure before a round. | Important for honest claims: show whether signing/broadcast is enabled and what claim level is actually available. |
| TN10 network status | `GET /v1/network/status` | Connects to live TN10 through the configured Kaspa/Toccata WASM/RPC path and fetches server/blockDAG status. | Chain-readiness check before accepting/settling a round. | In roulette, this can be summarized as “TN10 reachable/synced” with expandable raw network evidence. |

## Section 2: Create generic round

| Button / label | Endpoint | What it does | Roulette-stage mapping | Proof-of-fairness presentation note |
| --- | --- | --- | --- | --- |
| Create round | `POST /v1/rounds` | Creates a new generic round with `game`, `tableId`, `roundId`, `status: created`, `claimLevel: live_tn10_pending`, and no result. | New roulette round/spin is opened before commitment. | Show a round id early so all later commitment, tx, entropy, reveal, and proof evidence has a stable identifier. |

## Section 3: Commit hidden server seed

| Button / label | Endpoint | What it does | Roulette-stage mapping | Proof-of-fairness presentation note |
| --- | --- | --- | --- | --- |
| Commit state | `POST /v1/rounds/:roundId/commit` | Hashes and records the hidden server seed commitment through the API, then advances the round to `committed`. The browser supplies the seed but does not become proof authority. | Dealer/server commits before bets or final player input are closed. | This is the first fairness anchor: the result-driving server secret is committed before later entropy/result material is known. In roulette UI, show the commitment hash before close/reveal. |
| Broadcast commit/tx | `POST /v1/rounds/:roundId/commit/tx` | Calls the guarded live TN10 write endpoint. With explicit testnet-only gates and a funded key, it broadcasts a real TN10 transaction anchoring the commit payload and records txid/evidence in `round.tn10Writes.commit`. Without gates it fails closed. If already recorded, the page fetches the existing txid and treats the phase as complete. | Optional/stronger on-chain anchor for the pre-bet commitment. | In roulette, present as “commitment anchored on TN10” with txid, explorer/API link, payload summary, and status. This is stronger than an API-only commitment. |

## Section 4: Bet/input ledger

| Button / label | Endpoint | What it does | Roulette-stage mapping | Proof-of-fairness presentation note |
| --- | --- | --- | --- | --- |
| Update ledger | `POST /v1/rounds/:roundId/bets/ledger` | Sends the current generic input/bet list to the API. The API sanitizes it, computes a ledger hash, and advances the round to `betting_open`. | Captures current roulette bets/inputs before close. | In roulette, the bet ledger hash should be shown as the immutable summary of accepted bets/input state. The UI should not be proof authority for this hash. |

## Section 5: Close round and fix future TN10 entropy target

| Button / label | Endpoint | What it does | Roulette-stage mapping | Proof-of-fairness presentation note |
| --- | --- | --- | --- | --- |
| Close state | `POST /v1/rounds/:roundId/close` | Closes the round with a client seed and `entropyMode: live_tn10_future`. The API fetches current TN10 score, fixes a future target, records `futureEntropyPlan`, and advances to `closed`. | “No more bets” equivalent, but generic API naming is `close`. This fixes the future entropy target after bets/inputs are known. | In roulette, present as “bets closed; future TN10 entropy target fixed” with target metric/score, offset, and fixed-at timestamp. Avoid betting-specific API names even if the roulette UI uses friendly language. |
| Broadcast close/tx | `POST /v1/rounds/:roundId/close/tx` | Calls the guarded live TN10 write endpoint. With explicit testnet gates, it broadcasts a real TN10 transaction anchoring close payload: ledger hash, client seed hash, and future entropy plan. Records txid/evidence in `round.tn10Writes.close`. Already-recorded responses are treated as complete. | Optional/stronger on-chain anchor for close/no-more-bets and entropy-target selection. | In roulette, this is a major fairness milestone: after close tx, the chosen future entropy target and bet ledger are externally anchored. Display txid and decoded payload fields. |

## Section 6: Fetch live TN10 entropy

| Button / label | Endpoint | What it does | Roulette-stage mapping | Proof-of-fairness presentation note |
| --- | --- | --- | --- | --- |
| Fetch entropy | `GET /v1/rounds/:roundId/entropy` | The API waits/checks for the fixed future TN10 target to be reached, fetches live block evidence, and derives `entropyHash` from round id, commitment, client seed, ledger hash, block hash, DAA score, and blue score. | Obtain independent future randomness after betting/input close. | In roulette, this is the core external entropy proof. Show block hash, score evidence, target reached check, and that entropy was fetched after close. |

## Section 7: Reveal and calculate result

| Button / label | Endpoint | What it does | Roulette-stage mapping | Proof-of-fairness presentation note |
| --- | --- | --- | --- | --- |
| Reveal state | `POST /v1/rounds/:roundId/reveal` | Reveals the server seed, verifies it matches the pre-commitment, ensures live entropy is available, computes the result from the entropy hash, and advances to `revealed`. | Reveal the dealer/server secret and calculate roulette outcome. | In roulette, show commitment match, entropy hash, result derivation, and final number/color. Explain that the UI displays API-calculated result, not browser-generated result. |
| Broadcast reveal/tx | `POST /v1/rounds/:roundId/reveal/tx` | Calls the guarded live TN10 write endpoint. With explicit testnet gates, it broadcasts a real TN10 transaction anchoring revealed seed hash, entropy evidence, result, and prior commit/close tx references. Records txid/evidence in `round.tn10Writes.reveal`. Already-recorded responses are treated as complete. | Optional/stronger on-chain anchor for reveal and final result. | In roulette, this can be the final on-chain proof marker: the revealed seed, result, and prior tx chain are all bound in one payload. |

## Section 8: Proof, verification, and TN10 tx evidence

| Button / label | Endpoint | What it does | Roulette-stage mapping | Proof-of-fairness presentation note |
| --- | --- | --- | --- | --- |
| Get proof | `GET /v1/rounds/:roundId/proof` | Fetches the API-produced proof object after reveal. It includes round id, commitment, server/client seeds, bet ledger, entropy evidence, result, limitations, and optional `tn10Writes` tx evidence. | Player-visible proof package for the completed roulette round. | In roulette, this should back an expandable “proof details” panel and/or export/share option. Keep the proof object as API output, not app fixture input. |
| Verify proof | `POST /v1/proofs/verify` | Sends the fetched proof back to the API verifier. The API replays commitment, ledger hash, entropy derivation, result derivation, and tx evidence checks when tx evidence is present. | Independent verification pass for the completed roulette result. | In roulette, show a clear pass/fail badge with replay details. Consider explaining which claim level was verified. |
| Clear output | Browser-only | Clears the diagnostic output pane. Does not change server-side round state, proof, or transactions. | Diagnostic cleanup only. | In roulette, this may not be needed for end users; use a cleaner proof panel instead of a raw log. |

## Suggested roulette proof timeline

The future roulette PoC should likely present the fairness story as a timeline rather than as raw buttons:

1. Round created: stable round id assigned.
2. Server seed committed: commitment hash shown before close/reveal.
3. Bets/input ledger captured: ledger hash shown.
4. Round closed: future TN10 target fixed after bets/input are known.
5. Optional close tx: target and ledger anchored on TN10.
6. Live TN10 entropy fetched: block/score evidence shown.
7. Server seed revealed: commitment match shown.
8. Result derived: number/color and derivation shown.
9. Optional reveal tx: final result and prior references anchored on TN10.
10. Proof verified: replay result and tx evidence checks pass.

## Design implications for the roulette PoC

- Keep API and client names generic: `commit`, `close`, `reveal`, `commit/tx`, `close/tx`, `reveal/tx`.
- Roulette UI may use player-friendly labels such as “bets closed”, but it should map internally to the generic `close` phase.
- The UI should never generate proof/result authority locally. It should display API/client responses and verifier results.
- Show claim level honestly, especially the distinction between future entropy proof and full Toccata covenant enforcement.
- Treat yellow transaction steps as stronger TN10 anchoring milestones. If write gates are not enabled, the app should explain that the API is fail-closed rather than showing a mock success.
- For player trust, favor progressive proof disclosure: simple status badges first, expandable raw txids/payloads/proof JSON second.
