"""Hosted Master authorization must fail closed before accessing platform data."""

import base64
import json
from uuid import UUID

from fastapi.testclient import TestClient

from gogdely_api.auth import AuthenticatedUser, authenticated_user
from gogdely_api.main import app
from gogdely_api import master_online


OWNER = UUID("9f4b4987-59de-4e69-9f12-b8b5d7d254e5")
OTHER = UUID("7ae62e0d-41a7-4e73-a307-40980bbc84c1")
client = TestClient(app)


def _token(user_id: UUID, aal: str) -> str:
    payload = base64.urlsafe_b64encode(
        json.dumps({"sub": str(user_id), "aal": aal}).encode()
    ).decode().rstrip("=")
    return f"signed.{payload}.signature"


def _as(user_id: UUID):
    app.dependency_overrides[authenticated_user] = lambda: AuthenticatedUser(user_id)


def _clear():
    app.dependency_overrides.clear()


def test_master_requires_verified_identity_even_for_eligibility(monkeypatch):
    monkeypatch.setenv("GOGDELY_MASTER_USER_IDS", str(OWNER))
    try:
        assert client.get("/api/v1/master/eligibility").status_code == 401
        assert client.get("/api/v1/master/overview").status_code == 401
    finally:
        _clear()


def test_master_missing_or_invalid_allowlist_fails_closed(monkeypatch):
    _as(OWNER)
    try:
        for setting in ("", "not-a-uuid"):
            monkeypatch.setenv("GOGDELY_MASTER_USER_IDS", setting)
            assert client.get("/api/v1/master/eligibility").status_code == 503
    finally:
        _clear()


def test_other_user_cannot_enroll_through_master_or_read(monkeypatch):
    monkeypatch.setenv("GOGDELY_MASTER_USER_IDS", str(OWNER))
    _as(OTHER)
    try:
        assert client.get("/api/v1/master/eligibility").status_code == 403
        response = client.get("/api/v1/master/overview", headers={
            "Authorization": f"Bearer {_token(OTHER, 'aal2')}"})
        assert response.status_code == 403
    finally:
        _clear()


def test_owner_requires_matching_aal2_bearer(monkeypatch):
    monkeypatch.setenv("GOGDELY_MASTER_USER_IDS", str(OWNER))
    _as(OWNER)
    try:
        assert client.get("/api/v1/master/eligibility").json() == {"eligible": True}
        for token in (_token(OWNER, "aal1"), _token(OTHER, "aal2"), "bad.token.value"):
            response = client.get("/api/v1/master/overview", headers={
                "Authorization": f"Bearer {token}"})
            assert response.status_code == 403
            assert "MFA required" in response.text
    finally:
        _clear()


def test_authorized_owner_reads_real_overview_and_companies(monkeypatch):
    monkeypatch.setenv("GOGDELY_MASTER_USER_IDS", str(OWNER))
    queries = []

    def fake_read(statement):
        queries.append(statement)
        if "LEFT JOIN" in statement:
            return [[str(OTHER), "Loja Exemplo", "active", 2, 1, "2026-10-19"]]
        return [[1, 1, 2, 3]]

    monkeypatch.setattr(master_online, "_read", fake_read)
    _as(OWNER)
    headers = {"Authorization": f"Bearer {_token(OWNER, 'aal2')}"}
    try:
        overview = client.get("/api/v1/master/overview", headers=headers)
        companies = client.get("/api/v1/master/companies", headers=headers)
        assert overview.status_code == 200
        assert overview.json() == {"companies": 1, "active_companies": 1,
                                   "branches": 2, "orders": 3}
        assert companies.status_code == 200
        assert companies.json()[0]["tenant_id"] == str(OTHER)
        assert len(queries) == 2
    finally:
        _clear()
