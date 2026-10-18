import json
import tempfile
import unittest
from pathlib import Path

from scripts.prepare_hosted_pwas import APPS, prepare


class PrepareHostedPwasTest(unittest.TestCase):
    def test_app_scopes_and_base_paths_are_separate(self):
        with tempfile.TemporaryDirectory() as temp:
            root = Path(temp)
            (root / "docs").mkdir()
            (root / "docs" / "THIRD_PARTY_NOTICES.md").write_text("credits")
            for app in APPS:
                source = root / "apps" / app / "build" / "web"
                source.mkdir(parents=True)
                (source / "index.html").write_text(f'<base href="/{app}/">')
                (source / "main.dart.js").write_text("bundle")
                (source / "version.json").write_text('{"commit":"' + "a" * 40 + '"}')
                (source / "manifest.json").write_text('{"name":"Demo"}')

            destination = prepare(root)
            for app in APPS:
                manifest = json.loads((destination / app / "manifest.json").read_text())
                self.assertEqual(manifest["id"], f"/{app}/")
                self.assertEqual(manifest["start_url"], f"/{app}/")
                self.assertEqual(manifest["scope"], f"/{app}/")
                self.assertTrue((destination / app / "version.json").is_file())
            self.assertIn("Não faça pedidos reais", (destination / "index.html").read_text(encoding="utf-8"))


if __name__ == "__main__":
    unittest.main()
