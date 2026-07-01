# Handover prompt after /new

Continue in `/root/kaspa-toccata-api`. The project is a live-TN10-only Kaspa Toccata API/client. Do not add or use dry-run/mock/offline/static fixture paths. Endpoint naming must remain generic/app-agnostic: `commit`, `close`, `reveal`, and `commit/tx`, `close/tx`, `reveal/tx`; do not reintroduce no-more-bets naming.

Current status:
- Live TN10 commit/close/reveal write endpoints are implemented behind explicit gates and have been live-tested.
- Public npm package `kaspa-toccata-api@0.1.1` is published.
- Proof output includes `tn10Writes` evidence and verifier checks tx evidence when present.
- Basic web demo exists at `demo/basic-api-test.html`, served by `node src/server.cjs` at `/demo/basic-api-test.html`.
- For laptop testing on VPS, start the API on a free remote port and tunnel it, e.g. `ssh -N -L 18801:127.0.0.1:8801 root@187.124.210.10`, then open `http://127.0.0.1:18801/demo/basic-api-test.html`. Verify the remote listener is `node src/server.cjs`, not `python3 -m http.server`, with `ss -ltnp 'sport = :PORT'`.

Latest manual demo result:
- User got steps 1 through 5 working; `Broadcast commit/tx` succeeded with live TN10 txid `66be59aed69724a9ae9c86f54b82ef083fc3aea85820a335aff358e55ff8b577`.
- User then reported that after clicking `Close state`, they could start at 1 and go all the way through the end, including all yellow transaction buttons, without error. Good start.
- The previous basic-demo UX/state issue has been addressed in `demo/basic-api-test.html`: already-recorded tx phases are treated as complete, existing txids are fetched/shown, completed yellow buttons are disabled, and a reset/new-round control plus next-action banner were added.

Immediate next task:
Run one manual browser pass through `demo/basic-api-test.html` after the state-flow improvement, then decide whether to begin the roulette PoC or add a browser-compatible ESM client import path first. The page now has:
1. Explicit `New round / reset UI` button.
2. Clean current round/proof/output/status reset and fresh default seeds.
3. Phase completion display through `tn10Writes` txids and disabled completed yellow buttons.
4. `live_<phase>_already_recorded` handling that fetches/shows existing txids instead of surfacing a fatal-looking error.
5. Next-action banner and button gating so transaction buttons are unavailable before their required state step.
6. Generic/app-agnostic fetch calls to the same `/v1/*` API surface wrapped by the npm client.
7. Button-by-button behavior and roulette-stage/proof-of-fairness mapping documented in `docs/BASIC_WEB_DEMO_BUTTONS.md`.

Before code changes, load skill `kaspa-toccata-api-workflow`. After every code change, run at least:
```bash
node --check src/server.cjs
scripts/basic-web-api-test-smoke.sh
scripts/api-live-contract-smoke.sh
```
Then search/confirm no offline/mock/dry-run functionality or static proof/result fixtures were added. For full verification run the bundle listed in `docs/HANDOFF.md`.

Safety:
- Live-write servers use `/tmp/toccata-tn10-disposable-key.hex` and must be killed after testing. Do not leave a funded-key API process running.
- Default/fail-closed testing should unset `TOCCATA_ENABLE_TN10_WRITES`, `TOCCATA_TN10_PRIVATE_KEY`, and `TOCCATA_TN10_BROADCAST_ACK`.
- Only run live broadcasts with explicit user authorization and `KASPA_NETWORK_ID=testnet-10`.

Docs updated before /new: `docs/HANDOFF.md`, `docs/NEXT_STEPS.md`, `docs/API_STATUS.md`, and this file (`docs/HANDOVER_PROMPT.md`).
Generated at 2026-07-01T12:40:02Z.
