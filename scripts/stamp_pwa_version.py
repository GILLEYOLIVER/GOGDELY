"""Stamp every completed Flutter Web build with one reviewed release SHA."""

import json
import re
import sys
from pathlib import Path


APPS = ("cliente", "gestao", "entregador", "master")


def stamp(root: Path, commit: str) -> None:
    if re.fullmatch(r"[0-9a-f]{40}", commit) is None:
        raise ValueError("a full lowercase Git commit SHA is required")
    bundles = [root / "apps" / app / "build" / "web" for app in APPS]
    for bundle in bundles:
        if not (bundle / "index.html").is_file() or not (bundle / "main.dart.js").is_file():
            raise FileNotFoundError(f"Flutter Web build missing: {bundle}")
    for bundle in bundles:
        (bundle / "version.json").write_text(
            json.dumps({"commit": commit}, separators=(",", ":")) + "\n",
            encoding="utf-8",
        )


if __name__ == "__main__":
    if len(sys.argv) != 2:
        raise SystemExit("usage: python scripts/stamp_pwa_version.py <full-commit-sha>")
    stamp(Path(__file__).resolve().parents[1], sys.argv[1])
