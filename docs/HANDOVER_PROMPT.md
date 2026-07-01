# Handover Prompt

Generated: 2026-07-01T21:05:56Z

Continue in `/root/kaspa-toccata-api`.

First load the `kaspa-toccata-api-workflow` skill, then read:

```text
docs/HANDOFF.md
docs/API_STATUS.md
docs/NEXT_STEPS.md
docs/ROULETTE_POC_STATUS.md
docs/ROULETTE_UI_DESIGN_HANDOVER.md
```

## Current state

The rejected first roulette scaffold has been replaced by the corrected live-API-backed roulette PoC under:

```text
apps/roulette-poc/
```

The app is served by `node src/server.cjs` at:

```text
/apps/roulette-poc/
```

The current local viewing server during handoff was:

```text
http://127.0.0.1:8797/apps/roulette-poc/
node pid=710117
```

Verify the live process before using that port:

```bash
ss -ltnp 'sport = :8797'
curl -fsS http://127.0.0.1:8797/v1/health
```

If viewing from a laptop through the VPS, use an SSH tunnel to the Node API port. Do not use `python3 -m http.server`; a static server cannot serve `/v1/*`.

## UI shape

The app has only two main user-facing sections:

```text
1. Roulette Game
2. Proof of Fairness
```

`Roulette Game` is table-first and reuses/adapts the original clickable SVG roulette table/chip placement lineage from:

```text
/root/kaspa-fair-foundation/examples/roulette-poc/ui/
```

Visible game controls remain minimal:

```text
Spin Wheel
Reset Round
Chip amount
```

No separate Place Bet button is used; clicking table rectangles/selection circles places chips.

`Proof of Fairness` uses the env095-style flowchart direction from:

```text
/root/kaspa-fair-foundation/examples/roulette-poc/ui-sketches/env095-flowchart-*
```

The full flowchart is now data-driven from:

```text
apps/roulette-poc/flowchart-spec.json
```

This JSON is a static design/layout/help spec only. It must not contain round results, proof payloads, verifier outputs, TN10 evidence, or fixture data.

## Current flowchart/status design

The proof UX now has two levels:

1. A compact two-row live proof status strip near the roulette table so users can see state changes without scrolling.
2. A collapsible full vertical Proof of Fairness flowchart below.

Compact status rows:

```text
Roulette: Ready | Gate | Chips | Spin | Closed | Waiting | Result | Verified
Toccata:  Create | Commit | —     | Ledger | Close | Entropy | Reveal | Verify
```

Each compact tile has:

- short label from `compactLabel`
- explanatory popup text from `compactHelp`
- small `i` marker
- hover/focus tooltip
- keyboard focus support via `tabindex="0"`
- optional allow-listed `compactLinks` to project docs

Important copy corrections already made:

- Use `Entropy`, not bare `TN10`, as the compact tile label.
- Use `Waiting`, not `Pending`, for the player-facing pause.
- Avoid vague wording like `fixed target` without explanation.
- `Waiting` explicitly mentions `GET /entropy` and that the API watches TN10 until the chosen future blue-score has live block evidence.
- `Entropy` explains that `GET /entropy` fetches the live TN10 block at/after the future blue-score and derives an entropy hash.
- `Close` explains that the future blue-score is chosen before the block hash entropy is known.

Example current Entropy help:

```text
GET /entropy fetches the live TN10 block at or after the chosen future blue-score and derives an entropy hash. This external entropy helps prevent either side from picking the result after bets close.
```

The full flowchart uses a shared three-column grid:

```text
roulette node | connector label | proof node
```

Arrow-connected nodes share the same JSON row. Gaps elsewhere are expected.

## API/package requirement

The roulette app must keep importing the npm/client API surface:

```js
import { createToccataApiClient } from 'kaspa-toccata-api';
```

The browser import map points the package name to:

```text
/src/client.mjs
```

Raw app-level `fetch()` is allowed only for the static design asset:

```text
/apps/roulette-poc/flowchart-spec.json
```

All `/v1/*` API operations must stay inside the reusable client implementation.

## Forbidden regressions

Do not add or preserve:

```text
apps/**/sample-round.json
apps/**/toccata-fairness-proof.json
apps/**/proof.json
apps/**/round.json
mock result/proof paths
offline/local entropy paths
dry-run transaction success paths
browser-side proof authority
browser-side result authority
raw app-level fetch('/v1/*')
```

Write endpoints remain fail-closed by default unless explicit TN10 write gates are set and authorized.

## Latest verification

Focused roulette smoke:

```bash
scripts/roulette-poc-smoke.sh
```

Latest output:

```text
ROULETTE_POC_FILES_EXIST=PASS
ROULETTE_POC_JS_SYNTAX=PASS
ROULETTE_POC_NO_STATIC_OR_OFFLINE_PATTERNS=PASS
ROULETTE_POC_NO_MOCK_PATTERNS=PASS
ROULETTE_POC_NPM_API_IMPORT_READY=PASS
ROULETTE_POC_FLOWCHART_SPEC_ALIGNED=PASS
ROULETTE_POC_API_ENDPOINTS_PRESENT=PASS
ROULETTE_POC_API_HEALTH=PASS
ROULETTE_POC_PAGE_SERVED=PASS
ROULETTE_POC_APP_JS_SERVED=PASS
ROULETTE_POC_FLOWCHART_SPEC_SERVED=PASS
ROULETTE_POC_RENDERER_SERVED=PASS
ROULETTE_POC_LAYOUT_SERVED=PASS
ROULETTE_POC_ESM_CLIENT_SERVED=PASS
ROULETTE_POC_API_CREATE_ROUND=PASS
ROULETTE_POC_API_COMMIT_STATE=PASS
ROULETTE_POC_TX_FAIL_CLOSED=PASS
ROULETTE_POC_NO_STATIC_PROOF_FIXTURES=PASS
```

Latest focused ad-hoc verifier for help-copy/link changes:

```text
ADHOC_HELP_COPY_SYNTAX_AND_JSON_PARSE=PASS
ADHOC_HELP_COPY_SPEC_CONTENT=PASS
ADHOC_HELP_COPY_RENDERER=PASS
ADHOC_HELP_COPY_NPM_FETCH_BOUNDARY=PASS
ADHOC_HELP_COPY_NO_STATIC_OFFLINE_PATHS=PASS
ADHOC_HELP_COPY_NO_MOCK_PATHS=PASS
ADHOC_HELP_COPY_API_HEALTH=PASS
ADHOC_HELP_COPY_UPDATED_ASSETS_SERVED=PASS
ADHOC_HELP_COPY_FOCUSED_SMOKE=PASS
EXIT_CODE=0
```

Latest browser spot-check confirmed:

```text
compact labels include Entropy, not TN10
Waiting help mentions GET /entropy and future blue-score evidence
Entropy help explains external entropy and why it matters
Entropy tile includes links: entropy step; future entropy design
full Proof of Fairness flowchart is collapsed below
```

## Known issue / next UX work

A weak network exposed noticeable waits around reset/spin because live TN10/API calls can be slow. This is expected for real TN10 paths and should be surfaced with better status messages rather than solved with mock/offline fallbacks.

Next reasonable work:

1. Review the pushed diff from this handoff.
2. Do a browser UX pass on smaller screens and tooltip placement/clipping.
3. Improve status messaging around slow `network/status`, `close`, and `entropy` API waits.
4. If explicitly authorized, run a live-write-gated browser/API pass; otherwise keep write endpoints fail-closed.
