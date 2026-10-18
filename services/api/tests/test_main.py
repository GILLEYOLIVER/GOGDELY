from fastapi.testclient import TestClient
from gogdely_api.main import app

client = TestClient(app)


def test_health() -> None:
    response = client.get("/health")
    assert response.status_code == 200
    assert response.json() == {"status": "ok", "service": "gogdely-api", "version": "0.1.0"}


def test_info(monkeypatch) -> None:
    monkeypatch.setenv("GOGDELY_ENV", "testes")
    response = client.get("/api/v1/info")
    assert response.status_code == 200
    assert response.json()["api_version"] == "v1"
    assert response.json()["environment"] == "testes"


def test_no_business_endpoints_yet() -> None:
    assert client.get("/api/v1/orders").status_code == 404
