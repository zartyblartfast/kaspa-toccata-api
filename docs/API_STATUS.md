# API Status

No API has been implemented yet.

## Current stage

Runtime/API presentation spike scaffold plus first npm/Toccata WASM source/build/import capability checks.

The npm/WASM spike now validates that official `kaspanet/rusty-kaspa` branch `toccata`:

- contains JS/WASM-facing covenant primitives;
- builds a Node WASM package via `wasm-pack`;
- imports from Node;
- exposes covenant-related exports;
- can construct `CovenantBinding`, `GenesisCovenantGroup`, and `TransactionOutput` with a covenant binding.

It does not yet prove live TN10 wRPC from Node, JS transaction broadcast, or wrapping/publishing the built package as our own npm package.

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
