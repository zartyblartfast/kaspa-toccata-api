# API Status

No API has been implemented yet.

## Current stage

Runtime/API presentation spike scaffold plus first npm/Toccata WASM source-level capability check.

The first capability check validates that official `kaspanet/rusty-kaspa` branch `toccata` contains JS/WASM-facing covenant primitives. It does not yet prove WASM build, npm package consumption, live TN10 wRPC from Node, or JS transaction broadcast.

## Planned Milestone 1 API shell

```text
GET /v1/health
GET /v1/capabilities
GET /v1/network/status
```

## Planned smoke script

```text
scripts/api-smoke.sh
```

Expected future output:

```text
HEALTH_OK=PASS
CAPABILITIES_OK=PASS
TN10_STATUS_OK=PASS
NO_STATIC_APP_FIXTURES=PASS
```

## Claim levels

Initial claim-level ladder:

```text
local_dev_only
live_tn10_readonly
tn10_future_entropy
tn10_write_commit_reveal
toccata_covenant_enforced
```

No implemented endpoint currently claims any level.
