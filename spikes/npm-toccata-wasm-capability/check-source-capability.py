#!/usr/bin/env python3
"""
Source-level npm/Toccata WASM capability check.

This is intentionally a narrow first spike: it verifies that the official
kaspanet/rusty-kaspa `toccata` branch contains JS/WASM-facing covenant
primitives that could plausibly support our own npm package.

It does not yet build the WASM package or connect to TN10 from Node.
"""
from __future__ import annotations

import os
import shutil
import subprocess
import sys
from pathlib import Path

REPO_URL = "https://github.com/kaspanet/rusty-kaspa.git"
BRANCH = "toccata"
DEFAULT_WORKDIR = Path(os.environ.get("KASPA_TOCCATA_SPIKE_CACHE", "/tmp/kaspa-toccata-api-spikes/rusty-kaspa-toccata"))


def emit(key: str, value: str, detail: str | None = None) -> None:
    if detail:
        print(f"{key}={value} # {detail}")
    else:
        print(f"{key}={value}")


def run(cmd: list[str], cwd: Path | None = None) -> subprocess.CompletedProcess[str]:
    return subprocess.run(cmd, cwd=cwd, text=True, stdout=subprocess.PIPE, stderr=subprocess.PIPE, check=False)


def ensure_repo(path: Path) -> bool:
    if (path / ".git").exists():
        fetch = run(["git", "fetch", "--depth", "1", "origin", BRANCH], cwd=path)
        checkout = run(["git", "checkout", BRANCH], cwd=path)
        reset = run(["git", "reset", "--hard", f"origin/{BRANCH}"], cwd=path)
        return fetch.returncode == 0 and checkout.returncode == 0 and reset.returncode == 0

    path.parent.mkdir(parents=True, exist_ok=True)
    tmp = path.with_suffix(".tmp")
    if tmp.exists():
        shutil.rmtree(tmp)
    clone = run(["git", "clone", "--depth", "1", "--branch", BRANCH, REPO_URL, str(tmp)])
    if clone.returncode != 0:
        print(clone.stderr.strip(), file=sys.stderr)
        return False
    if path.exists():
        shutil.rmtree(path)
    tmp.rename(path)
    return True


def read(path: Path) -> str:
    try:
        return path.read_text(encoding="utf-8", errors="replace")
    except FileNotFoundError:
        return ""


def contains(path: Path, *needles: str) -> bool:
    text = read(path)
    return all(needle in text for needle in needles)


def main() -> int:
    repo = DEFAULT_WORKDIR
    if not ensure_repo(repo):
        emit("OFFICIAL_RUSTY_KASPA_TOCCATA_CLONE", "FAIL")
        return 1

    head = run(["git", "rev-parse", "HEAD"], cwd=repo).stdout.strip()
    branch = run(["git", "rev-parse", "--abbrev-ref", "HEAD"], cwd=repo).stdout.strip()
    emit("OFFICIAL_RUSTY_KASPA_TOCCATA_CLONE", "PASS", f"{branch} {head[:12]}")

    covenant_rs = repo / "consensus/client/src/covenant.rs"
    hash_rs = repo / "consensus/client/src/hash.rs"
    output_rs = repo / "consensus/client/src/output.rs"
    wasm_lib = repo / "wasm/src/lib.rs"
    wasm_readme = repo / "wasm/README.md"

    checks = [
        ("NPM_TOCCATA_WASM_SOURCE_COVENANT_BINDING", covenant_rs, "ICovenantBinding", "CovenantBinding", "covenantId"),
        ("NPM_TOCCATA_WASM_SOURCE_GENESIS_COVENANT_GROUP", covenant_rs, "IGenesisCovenantGroup", "GenesisCovenantGroup", "authorizingInput"),
        ("NPM_TOCCATA_WASM_SOURCE_COVENANT_ID_HASH", hash_rs, "js_covenant_id", "covenantId", "CovenantAuthorizedOutput"),
        ("NPM_TOCCATA_WASM_SOURCE_TRANSACTION_OUTPUT_COVENANT", output_rs, "covenant", "TransactionOutput", "CovenantBinding"),
        ("NPM_TOCCATA_WASM_SOURCE_REEXPORTS_CONSENSUS", wasm_lib, "pub use kaspa_consensus_wasm::*", "pub use kaspa_txscript::wasm::*"),
        ("NPM_TOCCATA_WASM_SOURCE_TN10_RPC_EXAMPLE", wasm_readme, "testnet-10", "RpcClient", "Encoding.Borsh"),
    ]

    failed = False
    for key, path, *needles in checks:
        ok = path.exists() and contains(path, *needles)
        emit(key, "PASS" if ok else "FAIL", str(path.relative_to(repo)))
        failed = failed or not ok

    emit("NPM_SOURCE_SPIKE_VERDICT", "VALIDATED" if not failed else "INVALIDATED")
    return 0 if not failed else 2


if __name__ == "__main__":
    raise SystemExit(main())
