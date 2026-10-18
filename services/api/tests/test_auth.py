"""No external Auth calls or credentials are used by these tests."""

import json
import ssl
from uuid import UUID

import pytest
from fastapi.testclient import TestClient

from gogdely_api import auth
from gogdely_api.main import app

client = TestClient(app)
USER_ID = "9f4b4987-59de-4e69-9f12-b8b5d7d254e5"
TOKEN = "signed.payload.signature"


@pytest.fixture(autouse=True)
def auth_settings(monkeypatch):
    monkeypatch.setenv("GOGDELY_SUPABASE_URL", "https://project.supabase.co")
    monkeypatch.setenv("GOGDELY_SUPABASE_PUBLISHABLE_KEY", "publishable-test-key")


def fake_auth(monkeypatch, *, status_code=200, payload=None, error=None):
    captured = {}
    body = json.dumps(payload if payload is not None else {"id": USER_ID}).encode()

    class Response:
        status = status_code

        def read(self, limit):
            return body[:limit]

    class Connection:
        def __init__(self, host, *, timeout, context):
            captured.update(host=host, timeout=timeout, context=context)

        def request(self, method, path, *, headers):
            captured.update(method=method, path=path, headers=headers)
            if error:
                raise error

        def getresponse(self):
            return Response()

        def close(self):
            captured["closed"] = True

    monkeypatch.setattr(auth, "HTTPSConnection", Connection)
    return captured


def test_valid_supabase_identity_is_returned_without_client_claims(monkeypatch):
    captured = fake_auth(
        monkeypatch,
        payload={"id": USER_ID, "email": "hidden@example.org", "role": "owner", "tenant_id": "foreign"},
    )
    response = client.get(
        "/api/v1/auth/me?tenant_id=foreign&role=owner",
        headers={"Authorization": f"Bearer {TOKEN}", "X-User-Id": "not-trusted"},
    )
    assert response.status_code == 200
    assert response.json() == {"user_id": str(UUID(USER_ID))}
    assert "hidden@example.org" not in response.text
    assert captured["host"] == "project.supabase.co"
    assert captured["path"] == "/auth/v1/user"
    assert captured["method"] == "GET"
    assert captured["timeout"] == 3
    assert captured["headers"]["apikey"] == "publishable-test-key"
    assert captured["headers"]["Authorization"] == f"Bearer {TOKEN}"
    assert captured["context"].verify_mode == ssl.CERT_REQUIRED
    assert captured["context"].check_hostname
    assert captured["closed"]


@pytest.mark.parametrize(
    "authorization",
    [None, "", "Basic abc", "Bearer", "Bearer two tokens", "Bearer a.b", "Bearer " + "a" * 8193],
)
def test_missing_or_malformed_bearer_is_denied(authorization):
    headers = {"Authorization": authorization} if authorization else {}
    response = client.get("/api/v1/auth/me", headers=headers)
    assert response.status_code == 401
    assert response.headers["www-authenticate"] == "Bearer"


@pytest.mark.parametrize("status_code,expected", [(400, 401), (401, 401), (403, 401), (429, 503), (302, 503), (500, 503)])
def test_auth_server_denial_and_unavailability(monkeypatch, status_code, expected):
    fake_auth(monkeypatch, status_code=status_code)
    response = client.get("/api/v1/auth/me", headers={"Authorization": f"Bearer {TOKEN}"})
    assert response.status_code == expected
    assert TOKEN not in response.text


@pytest.mark.parametrize("payload", [{"id": "not-a-uuid"}, {"email": "hidden@example.org"}, ["wrong-shape"]])
def test_unusable_auth_response_fails_closed(monkeypatch, payload):
    fake_auth(monkeypatch, payload=payload)
    response = client.get("/api/v1/auth/me", headers={"Authorization": f"Bearer {TOKEN}"})
    assert response.status_code == 503
    assert "hidden@example.org" not in response.text


def test_network_error_fails_closed_without_logging_token(monkeypatch, caplog):
    fake_auth(monkeypatch, error=TimeoutError("signed.payload.signature"))
    response = client.get("/api/v1/auth/me", headers={"Authorization": f"Bearer {TOKEN}"})
    assert response.status_code == 503
    assert TOKEN not in response.text
    assert TOKEN not in caplog.text


@pytest.mark.parametrize("url", ["", "http://project.supabase.co", "https://localhost", "https://project.supabase.co:443", "https://project.supabase.co/other", "https://user@project.supabase.co", "https://[broken"])
def test_auth_destination_must_be_configured_supabase_https(monkeypatch, url):
    monkeypatch.setenv("GOGDELY_SUPABASE_URL", url)
    response = client.get("/api/v1/auth/me", headers={"Authorization": f"Bearer {TOKEN}"})
    assert response.status_code == 503


def test_missing_publishable_key_fails_closed(monkeypatch):
    monkeypatch.delenv("GOGDELY_SUPABASE_PUBLISHABLE_KEY")
    response = client.get("/api/v1/auth/me", headers={"Authorization": f"Bearer {TOKEN}"})
    assert response.status_code == 503
