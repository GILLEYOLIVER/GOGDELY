"""A missing bundle must not publish a partial release manifest."""

from pathlib import Path
from tempfile import TemporaryDirectory
from unittest import TestCase

from scripts.stamp_pwa_version import APPS, stamp


class StampPwaVersionTest(TestCase):
    def test_stamps_all_bundles_only_when_complete(self) -> None:
        with TemporaryDirectory() as directory:
            root = Path(directory)
            for app in APPS:
                bundle = root / "apps" / app / "build" / "web"
                bundle.mkdir(parents=True)
                (bundle / "index.html").write_text("<html></html>", encoding="utf-8")
                (bundle / "main.dart.js").write_text("// build", encoding="utf-8")
            missing = root / "apps" / "entregador" / "build" / "web" / "main.dart.js"
            missing.unlink()
            with self.assertRaises(FileNotFoundError):
                stamp(root, "a" * 40)
            self.assertFalse((root / "apps" / "cliente" / "build" / "web" / "version.json").exists())

            missing.write_text("// build", encoding="utf-8")
            stamp(root, "a" * 40)
            for app in APPS:
                self.assertEqual(
                    (root / "apps" / app / "build" / "web" / "version.json").read_text(encoding="utf-8"),
                    '{"commit":"' + "a" * 40 + '"}\n',
                )
