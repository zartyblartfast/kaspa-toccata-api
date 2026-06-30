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

## 0003 — Runtime implementation is not decided yet

Status: pending spike evidence

Options under review:

- TypeScript/npm-first using official `rusty-kaspa` Toccata WASM.
- Rust service using official `rusty-kaspa` `toccata` branch plus npm client/wrapper.
- Hybrid npm package wrapping a Rust binary.

Decision will be made after capability spikes.

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
