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


def test_hosted_environment_cannot_reach_local_demo_routes(monkeypatch) -> None:
    monkeypatch.setenv("GOGDELY_ENV", "homolog")
    monkeypatch.setenv("GOGDELY_LOCAL_DEMO", "1")
    response = client.get("/api/v1/local/stores")
    assert response.status_code == 404
    assert response.json() == {"detail": "Local demo disabled"}


def test_ready_requires_database_and_does_not_expose_secret(monkeypatch) -> None:
    monkeypatch.delenv("GOGDELY_DATABASE_URL", raising=False)
    response = client.get("/ready")
    assert response.status_code == 503
    assert "database" in response.json()["detail"]

    monkeypatch.setenv("GOGDELY_DATABASE_URL", "postgresql://user:secret@db.test/postgres")
    monkeypatch.setattr("gogdely_api.main.foundation_ready", lambda _: False)
    response = client.get("/ready")
    assert response.status_code == 503
    assert "secret" not in response.text


def test_ready_logs_missing_variable_names_without_values(monkeypatch, caplog) -> None:
    monkeypatch.delenv("GOGDELY_DATABASE_URL", raising=False)
    monkeypatch.setenv("GOGDELY_DATABASE_HOST", "private-host")
    monkeypatch.setenv("GOGDELY_DATABASE_USER", "private-user")
    monkeypatch.delenv("GOGDELY_DATABASE_PASSWORD", raising=False)
    response = client.get("/ready")
    assert response.status_code == 503
    assert "GOGDELY_DATABASE_PASSWORD" in caplog.text
    assert "private-host" not in caplog.text
    assert "private-user" not in caplog.text


def test_ready_with_foundation(monkeypatch) -> None:
    monkeypatch.setenv("GOGDELY_DATABASE_URL", "postgresql://user:secret@db.test/postgres")
    monkeypatch.setattr("gogdely_api.main.foundation_ready", lambda _: True)
    response = client.get("/ready")
    assert response.status_code == 200
    assert response.json()["status"] == "ready"


def test_ready_accepts_separate_password_secret(monkeypatch) -> None:
    monkeypatch.delenv("GOGDELY_DATABASE_URL", raising=False)
    monkeypatch.setenv("GOGDELY_DATABASE_HOST", "pooler.test")
    monkeypatch.setenv("GOGDELY_DATABASE_USER", "postgres.project")
    monkeypatch.setenv("GOGDELY_DATABASE_PASSWORD", "p@ss:/?#")
    monkeypatch.setenv("GOGDELY_DATABASE_PORT", "5432")
    captured = []
    monkeypatch.setattr(
        "gogdely_api.main.foundation_ready",
        lambda url: captured.append(url) or True,
    )
    response = client.get("/ready")
    assert response.status_code == 200
    assert captured == [
        "postgresql://postgres.project:p%40ss%3A%2F%3F%23@pooler.test:5432/postgres"
    ]
    assert "p@ss" not in response.text


def test_version_exposes_only_commit(monkeypatch) -> None:
    monkeypatch.setenv("RENDER_GIT_COMMIT", "abc123")
    response = client.get("/version.json")
    assert response.status_code == 200
    assert response.json() == {"commit": "abc123"}
    assert response.headers["cache-control"] == "no-store"
