"""SEO readiness checks for the public web surfaces (GOG-020/026/077)."""
import re

from fastapi.testclient import TestClient

from gogdely_api.config import config
from gogdely_api.main import app


def _lab_client(tmp_path, monkeypatch) -> TestClient:
    monkeypatch.setenv("GOGDELY_ENV", "local")
    monkeypatch.setenv("GOGDELY_LOCAL_DEMO", "1")
    monkeypatch.setenv("GOGDELY_LOCAL_DB", str(tmp_path / "seo.sqlite3"))
    monkeypatch.setattr(config, "public_base_url", "")
    monkeypatch.setattr(config, "require_https", False)
    monkeypatch.setattr(config, "gsc_verification", "")
    return TestClient(app)


def test_lab_robots_sitemap_and_image_are_protected(tmp_path, monkeypatch):
    client = _lab_client(tmp_path, monkeypatch)
    robots = client.get("/robots.txt")
    assert robots.status_code == 200
    assert "Disallow: /" in robots.text
    sitemap = client.get("/sitemap.xml")
    assert sitemap.status_code == 200
    assert "<urlset" in sitemap.text and "<url>" not in sitemap.text
    image = client.get("/og-image.png")
    assert image.status_code == 200
    assert image.headers["content-type"] == "image/png"
    assert image.content[:8] == b"\x89PNG\r\n\x1a\n"
    assert client.get("/googleanything.html").status_code == 404


def test_menu_page_is_seo_ready_but_stays_noindex_in_lab(tmp_path, monkeypatch):
    client = _lab_client(tmp_path, monkeypatch)
    slug = client.get("/api/v1/local/m/burger-house/M03")
    assert slug.status_code == 200
    page = slug.text
    assert 'name="robots" content="noindex, nofollow"' in page
    assert 'name="description"' in page
    assert 'alt="X-Tudo"' in page
    assert 'loading="lazy"' in page
    assert 'rel="canonical"' not in page
    assert "og:title" not in page
    assert "ld+json" not in page
    assert "<html lang=" in page and "pt-BR" in page
    assert page.count("<h1>") == 1
    # The legacy long URL keeps working for compatibility.
    legacy = client.get("/api/v1/local/mesa/burger-house/M03")
    assert legacy.status_code == 200 and "Mesa M03" in legacy.text


def test_receipt_and_print_pages_stay_private(tmp_path, monkeypatch):
    client = _lab_client(tmp_path, monkeypatch)
    created = client.post("/api/v1/local/mesa/burger-house/M04/pedidos",
                          data={"request_key": "00000000-0000-4000-8000-000000000001",
                                "qty_x-tudo": "1"}, follow_redirects=False)
    receipt_url = created.headers["location"]
    receipt = client.get(receipt_url)
    assert receipt.status_code == 200
    assert 'name="robots" content="noindex, nofollow"' in receipt.text
    assert 'href="/m/burger-house/M04"' in receipt.text
    print_page = client.get("/api/v1/local/tables/burger-house/M04/print")
    assert print_page.status_code == 200
    assert 'name="robots" content="noindex, nofollow"' in print_page.text
    assert 'href="/m/burger-house/M04"' in print_page.text


def test_public_mode_enables_indexing_canonical_og_and_schema(tmp_path, monkeypatch):
    client = _lab_client(tmp_path, monkeypatch)
    monkeypatch.setattr(config, "public_base_url", "https://piloto.gogdely.example")
    page = client.get("/api/v1/local/m/burger-house/M03").text
    assert 'name="robots" content="index, follow"' in page
    assert 'rel="canonical" href="https://piloto.gogdely.example/m/burger-house/M03"' in page
    assert 'property="og:title"' in page
    assert 'property="og:image" content="https://piloto.gogdely.example/og-image.png"' in page
    assert "ld+json" in page and '"@type": "MenuSection"' in page
    robots = client.get("/robots.txt").text
    assert "Allow: /" in robots
    assert "Disallow: /api/" in robots
    assert "Sitemap: https://piloto.gogdely.example/sitemap.xml" in robots
    sitemap = client.get("/sitemap.xml").text
    assert sitemap.count("<url>") == 10
    assert "https://piloto.gogdely.example/m/burger-house/M01" in sitemap


def test_google_search_console_verification_is_gated_by_owner_token(
        tmp_path, monkeypatch):
    client = _lab_client(tmp_path, monkeypatch)
    monkeypatch.setattr(config, "gsc_verification", "abc123token")
    ok = client.get("/googleabc123token.html")
    assert ok.status_code == 200
    assert ok.text == "google-site-verification: googleabc123token.html"
    assert client.get("/googlewrongtoken.html").status_code == 404


def test_https_is_enforced_only_when_required(tmp_path, monkeypatch):
    client = _lab_client(tmp_path, monkeypatch)
    plain = client.get("/health", follow_redirects=False)
    assert plain.status_code == 200
    assert plain.headers.get("x-content-type-options") == "nosniff"
    assert "strict-transport-security" not in plain.headers
    monkeypatch.setattr(config, "require_https", True)
    redirect = client.get("/health", follow_redirects=False)
    assert redirect.status_code == 308
    assert redirect.headers["location"].startswith("https://")
    assert "max-age=31536000" in redirect.headers["strict-transport-security"]


def test_qr_points_to_the_clean_public_slug(tmp_path, monkeypatch):
    client = _lab_client(tmp_path, monkeypatch)
    qr = client.get("/api/v1/local/tables/burger-house/M03/qr.svg")
    assert qr.status_code == 200
    assert b"<svg" in qr.content
    # The QR encodes the clean slug route, not the long API path.
    assert b"/m/burger-house/M03" in qr.content
