"""Local-only PWA files must revalidate, and new builds must change version."""

from fastapi import FastAPI
from fastapi.testclient import TestClient

from gogdely_api.main import LocalPwaStaticFiles, local_pwa_build_version


def test_local_pwa_revalidates_and_detects_new_bundle(tmp_path):
    (tmp_path / "index.html").write_text("<h1>GOGDELY</h1>", encoding="utf-8")
    bundle = tmp_path / "main.dart.js"
    bundle.write_text("first build", encoding="utf-8")
    app = FastAPI()
    app.mount("/", LocalPwaStaticFiles(directory=tmp_path, html=True))
    response = TestClient(app).get("/")
    assert response.status_code == 200
    assert response.headers["cache-control"] == "no-cache, max-age=0, must-revalidate"

    first_version = local_pwa_build_version(tmp_path)
    bundle.write_text("a different second build", encoding="utf-8")
    assert local_pwa_build_version(tmp_path) != first_version
