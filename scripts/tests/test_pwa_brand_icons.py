"""Guard the iPhone shortcut and manifest against default Flutter artwork."""

import json
import struct
import unittest
from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]


def png_dimensions(path: Path) -> tuple[int, int]:
    data = path.read_bytes()[:24]
    if data[:8] != b"\x89PNG\r\n\x1a\n" or data[12:16] != b"IHDR":
        raise ValueError(f"Not a PNG: {path}")
    return struct.unpack(">II", data[16:24])


class PwaBrandIconsTest(unittest.TestCase):
    def test_delivery_and_management_icons_are_branded(self):
        for app, prefix, source in (
            ("entregador", "Entrega", "gogdely-entrega.svg"),
            ("gestao", "Lojas", "gogdely-lojas.svg"),
        ):
            with self.subTest(app=app):
                web = ROOT / "apps" / app / "web"
                manifest = json.loads((web / "manifest.json").read_text(encoding="utf-8"))
                index = (web / "index.html").read_text(encoding="utf-8")
                self.assertIn('href="apple-touch-icon.png"', index)
                self.assertIn('href="favicon-brand.png"', index)
                self.assertNotIn("icons/Icon-192.png", index)
                self.assertEqual(png_dimensions(web / "apple-touch-icon.png"), (180, 180))
                self.assertEqual(png_dimensions(web / "favicon-brand.png"), (48, 48))
                self.assertTrue((web / "icons" / source).is_file())
                expected = {
                    f"icons/{prefix}-{size}.png": size
                    for size in (192, 512)
                } | {
                    f"icons/{prefix}-maskable-{size}.png": size
                    for size in (192, 512)
                }
                self.assertEqual({entry["src"] for entry in manifest["icons"]}, set(expected))
                for relative, size in expected.items():
                    self.assertEqual(png_dimensions(web / relative), (size, size))


if __name__ == "__main__":
    unittest.main()
