# Roulette PoC UI Design Handover

Generated: 2026-07-01T16:01:56Z

## Purpose

This handover captures the corrected UI direction for the roulette PoC before starting a fresh `/new` session.

The first `apps/roulette-poc/` scaffold proved npm-client/API wiring, but its UI was too close to the API demo/test page and was rejected as the target app. The next pass should rebuild the app as a roulette-first experience, not preserve that API-checklist layout.

## Non-negotiable direction

- The roulette app must use the `kaspa-toccata-api` npm API surface directly.
- The browser app should import `createToccataApiClient` from `kaspa-toccata-api` via the local browser ESM import map.
- No app-facing static round/proof/result JSON.
- No mock/static data in place of the API for a roulette round.
- No browser-side result/proof authority.
- The API/proof lifecycle must be embedded in the game experience, not sidestepped.

## Correct high-level UI

Only two main sections:

```text
1. Roulette Game
2. Proof of Fairness
```

### 1. Roulette Game

This is the top section and should visually resemble the original roulette PoC, not the current API-demo-like scaffold.

Use the old roulette table/game UI as the starting point:

```text
/root/kaspa-fair-foundation/examples/roulette-poc/ui/
```

Important files:

```text
index.html
styles.css
app.js
roulette-table-renderer.js
roulette-table-schema.json
roulette-table-schema.js
```

Reuse/adapt:

- table-first layout
- SVG roulette table
- clickable rectangles and selection circles
- chip placement directly on selected table zones
- bet amount shown on chips
- selected-bet display/ledger UI where helpful
- result number/color display styling
- simple Start/Reset control style

Do not reuse as runtime sources:

```text
sample-round.json
toccata-fairness-proof.json
```

Those old files are static proof/result artifacts and must not power the new app.

### Roulette controls

The user should not see the eight API demo controls.

The user should be able to:

```text
- click table zones to place chips
- Spin Wheel
- Reset Round
```

No separate `Place Bet` button is needed. Placing chips on the table is the bet action.

A chip amount selector is acceptable if needed.

### Simplified round flow

For now, simplify real roulette timing:

```text
Reset Round / new round
→ API creates and commits hidden outcome/proof state
→ user places chips directly on the table
→ Spin Wheel
→ API submits ledger/closes/fetches entropy/reveals/verifies
→ result number/color displayed
```

Proof requirement:

```text
The winning number/color must be committed before the user places chips.
The Proof of Fairness section must make that understandable.
```

## 2. Proof of Fairness

This section sits below the roulette table.

It should not be a wall of JSON. It should be a flowchart.

Use the existing draft flowchart as starting point:

```text
/root/kaspa-fair-foundation/examples/roulette-poc/ui-sketches/env095-flowchart-demo.html
/root/kaspa-fair-foundation/examples/roulette-poc/ui-sketches/env095-flowchart-demo.css
/root/kaspa-fair-foundation/examples/roulette-poc/ui-sketches/env095-flowchart-demo.js
/root/kaspa-fair-foundation/examples/roulette-poc/ui-sketches/env095-flowchart-data.json
```

Reuse/adapt:

- two-column flowchart renderer
- rectangle cards
- directional arrows
- downwards primary flow
- horizontal interactions between columns
- clickable cards / `More detail` disclosure pattern
- JSON-driven node/edge model
- ability to highlight the current stage of the round

Replace old flowchart content.

Old flowchart columns:

```text
Demo UI
Current checked data sources
```

New flowchart columns:

```text
Roulette Round
Kaspa Toccata Proof of Fairness
```

### Flowchart behavior

Each rectangle should give a very simple explanation of why that step is part of the proof chain.

Users should be able to click a rectangle or `more info` to see raw JSON/API details only if they want them.

The flowchart should directly show where the current round is up to by highlighting the relevant rectangle(s).

General flow direction:

```text
Downwards through the round
Horizontal arrows for interactions between roulette round and proof/fairness API/evidence
```

Example conceptual mapping:

```text
Roulette Round column                  Kaspa Toccata Proof of Fairness column
---------------------                  -------------------------------------
New round / hidden result prepared  ->  API creates round
Chips not yet placed                ->  Commitment locks result before bet
Player places chips                 ->  Bet ledger captured by API
Spin wheel                          ->  Round closed / entropy target fixed
Wheel/result displayed              ->  API reveals result
Player sees result                  ->  Proof verifies commitment + result
```

Exact node labels can be refined, but the user-facing story must be simple:

```text
The result was committed before chips were placed.
The later reveal proves the displayed number/color matches that prior commitment.
```

## Current implementation status

Current repo:

```text
/root/kaspa-toccata-api
```

Current branch:

```text
main
```

The first app scaffold was rejected. Do not commit or preserve it as the product UI. If stale untracked files exist under `apps/roulette-poc/`, remove or replace them before rebuilding the app.

The useful work to preserve is the package/client infrastructure:

- `src/client.mjs` is the browser-compatible ESM client.
- `src/client.cjs` remains the CommonJS Node client.
- `package.json` maps package `import` consumers to `src/client.mjs` and `require` consumers to `src/client.cjs`.
- `src/server.cjs` serves `/src/client.mjs` but no longer serves `/apps/roulette-poc/*` from the rejected scaffold.

Future roulette app should still import:

```js
import { createToccataApiClient } from 'kaspa-toccata-api';
```

A future no-bundler browser PoC can map the package name to:

```text
/src/client.mjs
```

Important pitfall already fixed:

```text
globalThis.fetch must be bound before storing/calling it in the client, otherwise browser usage can throw `Illegal invocation`.
```

## Current verification evidence

Latest focused ad-hoc verification for the server/client state after rejecting the app scaffold:

```text
ADHOC_SERVER_SYNTAX=PASS
ADHOC_BAD_APP_ROUTE_REMOVED=PASS
ADHOC_CLIENT_MODULE_ROUTE_PRESENT=PASS
ADHOC_SERVER_HEALTH=PASS
ADHOC_CLIENT_MJS_SERVED=PASS
ADHOC_BAD_APP_ROUTE_NOT_SERVED=PASS
ADHOC_VERIFY_EXIT=0
```

Earlier focused ad-hoc verification for npm/browser import behavior passed:

```text
ADHOC_NPM_API_CHANGED_FILES_EXIST=PASS
ADHOC_NPM_API_JS_SYNTAX=PASS
ADHOC_NPM_API_PACKAGE_EXPORTS=PASS
ADHOC_NPM_API_ESM_IMPORT_AND_CLIENT_CALL=PASS
ADHOC_ROULETTE_IMPORT_MAP=PASS
ADHOC_ROULETTE_APP_USES_NPM_API=PASS
ADHOC_SERVER_SERVES_ESM_CLIENT=PASS
ADHOC_FETCH_BINDING=PASS
ADHOC_ROULETTE_FORBIDDEN_PATTERNS=PASS
ADHOC_ROULETTE_SMOKE_WITH_NPM_IMPORT=PASS
ADHOC_VERIFY_EXIT=0
```

No temporary server should be left running.

## Current paths to commit

Commit the useful package/client/docs changes, not the rejected untracked app scaffold:

```text
.gitignore
docs/API_STATUS.md
docs/HANDOFF.md
docs/HANDOVER_PROMPT.md
docs/NEXT_STEPS.md
docs/ROULETTE_UI_DESIGN_HANDOVER.md
package.json
src/client.cjs
src/client.mjs
src/server.cjs
```

## Suggested next-session prompt

```text
Continue in /root/kaspa-toccata-api. Load the kaspa-toccata-api-workflow skill. Read docs/ROULETTE_UI_DESIGN_HANDOVER.md, docs/API_STATUS.md, and docs/HANDOFF.md.

Do not preserve the rejected API-demo-like roulette PoC layout as the target UI. Redesign the roulette PoC as two sections:
1. Roulette Game at the top, based on /root/kaspa-fair-foundation/examples/roulette-poc/ui/ table-first UI and chip placement behavior.
2. Proof of Fairness below, based on /root/kaspa-fair-foundation/examples/roulette-poc/ui-sketches/env095-flowchart-*.

Use the kaspa-toccata-api npm API surface directly via createToccataApiClient imported from 'kaspa-toccata-api'. Do not use static round/proof/result JSON as runtime sources. The flowchart must have left column 'Roulette Round' and right column 'Kaspa Toccata Proof of Fairness', with arrows and highlight of current stage.
```

## Do not regress

- Do not turn the roulette app into an API test page.
- Do not expose the eight demo buttons as the main UI.
- Do not use `sample-round.json` or `toccata-fairness-proof.json` as runtime input.
- Do not use raw app-level `fetch()` instead of the npm API client.
- Do not generate result/proof in the browser.
- Do not leave live/funded TN10 write servers running.
