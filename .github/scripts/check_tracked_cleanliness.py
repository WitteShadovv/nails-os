#!/usr/bin/env python3
"""Fail if forbidden junk is tracked by git.

This intentionally checks tracked paths from the git index only, so ignored local
developer state does not cause failures. The policy is intentionally small and is
kept close to this repository's ignored local state and generated junk.
"""

from __future__ import annotations

import subprocess
import sys
from pathlib import PurePosixPath

FORBIDDEN_COMPONENTS = {
    ".claude": "tracked Claude local state",
    ".codex": "tracked Codex local state",
    ".direnv": "tracked direnv state",
    ".idea": "tracked IDE workspace state",
    ".pytest_cache": "tracked pytest cache",
    ".ruff_cache": "tracked Ruff cache",
    ".venv": "tracked local virtualenv",
    ".vscode": "tracked editor workspace state",
    "__pycache__": "tracked __pycache__/ directory",
    "dist": "tracked build artifact directory",
}

FORBIDDEN_BASENAMES = {
    ".DS_Store": "tracked macOS Finder metadata",
    ".envrc": "tracked direnv environment file",
    "Thumbs.db": "tracked Windows Explorer metadata",
}

FORBIDDEN_SUFFIXES = {
    ".pyc": "tracked Python bytecode (*.pyc)",
    ".pyd": "tracked Python extension artifact (*.pyd)",
    ".pyo": "tracked Python bytecode (*.pyo)",
    ".swp": "tracked editor swap file (*.swp)",
}


def tracked_paths() -> list[str]:
    result = subprocess.run(
        ["git", "ls-files", "-z"],
        check=True,
        capture_output=True,
    )
    return [path.decode("utf-8") for path in result.stdout.split(b"\0") if path]


def violation_reasons(path: str) -> list[str]:
    reasons: list[str] = []
    pure_path = PurePosixPath(path)
    parts = pure_path.parts
    top_level = parts[0]

    if pure_path.suffix in FORBIDDEN_SUFFIXES:
        reasons.append(FORBIDDEN_SUFFIXES[pure_path.suffix])

    if pure_path.name in FORBIDDEN_BASENAMES:
        reasons.append(FORBIDDEN_BASENAMES[pure_path.name])

    if top_level == "result":
        reasons.append("tracked Nix build result symlink/path")

    if top_level.startswith("result-"):
        reasons.append("tracked Nix build result-* symlink/path")

    for component, reason in FORBIDDEN_COMPONENTS.items():
        if component in parts:
            reasons.append(reason)

    return reasons


def main() -> int:
    violations = []

    for path in tracked_paths():
        reasons = violation_reasons(path)
        if reasons:
            violations.append((path, reasons))

    if not violations:
        print("✓ No forbidden tracked junk found in git index")
        return 0

    print("Forbidden tracked paths/artifacts found:", file=sys.stderr)
    for path, reasons in violations:
        print(f" - {path} ({'; '.join(reasons)})", file=sys.stderr)

    print(
        "\nThis guard checks tracked git paths only, so ignored local files are allowed.",
        file=sys.stderr,
    )
    return 1


if __name__ == "__main__":
    raise SystemExit(main())
