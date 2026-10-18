"""Package three isolated, fictional PWA previews for one static host."""

import json
import shutil
from pathlib import Path


APPS = ("cliente", "gestao", "entregador")
ROOT = Path(__file__).resolve().parents[1]


def prepare(root: Path = ROOT) -> Path:
    destination = root / "build" / "pwa"
    destination.mkdir(parents=True, exist_ok=True)
    for app in APPS:
        source = root / "apps" / app / "build" / "web"
        if not all((source / item).is_file() for item in ("index.html", "main.dart.js", "version.json")):
            raise FileNotFoundError(f"Incomplete Flutter Web build: {source}")
        target = destination / app
        shutil.copytree(source, target, dirs_exist_ok=True)
        manifest_path = target / "manifest.json"
        manifest = json.loads(manifest_path.read_text(encoding="utf-8"))
        manifest.update({"id": f"/{app}/", "start_url": f"/{app}/", "scope": f"/{app}/"})
        manifest_path.write_text(
            json.dumps(manifest, ensure_ascii=False, indent=2) + "\n", encoding="utf-8"
        )
        if f'<base href="/{app}/">' not in (target / "index.html").read_text(encoding="utf-8"):
            raise ValueError(f"Incorrect base href for {app}")

    (destination / "index.html").write_text(
        """<!doctype html><html lang="pt-BR"><head><meta charset="utf-8">
<meta name="viewport" content="width=device-width,initial-scale=1">
<meta name="robots" content="noindex,nofollow"><title>GOGDELY Homologação</title>
<style>body{font:16px system-ui;background:#101522;color:#f8fafc;max-width:34rem;margin:10vh auto;padding:1.5rem}a{display:block;color:#93c5fd;padding:.7rem 0}</style></head>
<body><h1>GOGDELY · Homologação</h1><p>Prévias com dados fictícios. Não faça pedidos reais.</p>
<a href="/cliente/">Cliente</a><a href="/gestao/">Gestão da loja</a>
<a href="/entregador/">Entregador</a>
<p><a href="/THIRD_PARTY_NOTICES.md">Créditos e licenças</a></p></body></html>\n""",
        encoding="utf-8",
    )
    shutil.copy2(root / "docs" / "THIRD_PARTY_NOTICES.md", destination / "THIRD_PARTY_NOTICES.md")
    (destination / "robots.txt").write_text("User-agent: *\nDisallow: /\n", encoding="utf-8")
    return destination


if __name__ == "__main__":
    prepare()
