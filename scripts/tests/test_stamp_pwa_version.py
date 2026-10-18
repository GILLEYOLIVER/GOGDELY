"""A missing bundle must not publish a partial release manifest."""

from pathlib import Path

import pytest

from scripts.stamp_pwa_version import APPS, stamp


def test_stamps_all_bundles_only_when_complete(tmp_path: Path) -> None:
    for app in APPS:
        bundle = tmp_path / "apps" / app / "build" / "web"
        bundle.mkdir(parents=True)
        (bundle / "index.html").write_text("<html></html>", encoding="utf-8")
        (bundle / "main.dart.js").write_text("// build", encoding="utf-8")
    missing = tmp_path / "apps" / "entregador" / "build" / "web" / "main.dart.js"
    missing.unlink()
    with pytest.raises(FileNotFoundError):
        stamp(tmp_path, "a" * 40)
    assert not (tmp_path / "apps" / "cliente" / "build" / "web" / "version.json").exists()

    missing.write_text("// build", encoding="utf-8")
    stamp(tmp_path, "a" * 40)
    for app in APPS:
        assert (tmp_path / "apps" / app / "build" / "web" / "version.json").read_text(
            encoding="utf-8"
        ) == '{"commit":"' + "a" * 40 + '"}\n'
