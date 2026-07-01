# Handover Prompt

Generated: 2026-07-01T16:01:56Z

Continue in `/root/kaspa-toccata-api`.

First load the `kaspa-toccata-api-workflow` skill, then read:

```text
docs/ROULETTE_UI_DESIGN_HANDOVER.md
docs/API_STATUS.md
docs/HANDOFF.md
docs/NEXT_STEPS.md
```

Important: the first `apps/roulette-poc/` scaffold was rejected and should not be preserved as the target UI. It proved browser/npm API wiring, but it resembled the API demo/test page too closely. If stale untracked files under `apps/roulette-poc/` are present in the working tree, remove or replace them before rebuilding the real roulette UI.

Target roulette UI:

```text
1. Roulette Game
2. Proof of Fairness
```

`Roulette Game` must be table-first and should use the original roulette UI as the visual/interaction starting point:

```text
/root/kaspa-fair-foundation/examples/roulette-poc/ui/
```

Reuse/adapt the clickable SVG table, rectangle/selection-circle interactions, and chip placement with bet amount shown on chips. Do not use the old static `sample-round.json` or `toccata-fairness-proof.json` as runtime data.

Visible user controls should be minimal:

```text
Spin Wheel
Reset Round
```

No separate Place Bet button is needed; clicking the table places chips.

`Proof of Fairness` must be a flowchart, not a JSON wall. Use this draft as starting point:

```text
/root/kaspa-fair-foundation/examples/roulette-poc/ui-sketches/env095-flowchart-demo.html
/root/kaspa-fair-foundation/examples/roulette-poc/ui-sketches/env095-flowchart-demo.css
/root/kaspa-fair-foundation/examples/roulette-poc/ui-sketches/env095-flowchart-demo.js
/root/kaspa-fair-foundation/examples/roulette-poc/ui-sketches/env095-flowchart-data.json
```

Replace its content with two columns:

```text
Roulette Round
Kaspa Toccata Proof of Fairness
```

The flowchart should show downward round flow, horizontal proof/API interactions, current-stage highlighting, and clickable/more-info details for the raw JSON/API evidence.

Keep the npm API requirement:

```js
import { createToccataApiClient } from 'kaspa-toccata-api';
```

via the local import map to `/src/client.mjs`. Do not reintroduce raw app-level `fetch()`, static proof/result JSON, browser-side result authority, mock/offline paths, or dry-run transaction paths.

Current uncommitted work should include the browser ESM client, package ESM export changes, server `/src/client.mjs` serving, and docs. Do not commit a stale `apps/roulette-poc/` scaffold; rebuild it from the corrected design.
