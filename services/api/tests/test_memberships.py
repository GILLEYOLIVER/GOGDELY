"""Membership tests use a fake database and never contact Supabase."""

from uuid import UUID

import pytest
from fastapi.testclient import TestClient

from gogdely_api.auth import AuthenticatedUser, authenticated_user
from gogdely_api.main import app
from gogdely_api import memberships

USER = UUID("00000000-0000-4000-8000-000000000001")
TENANT = "00000000-0000-4000-8000-000000000002"
BRANCH = "00000000-0000-4000-8000-000000000003"


def test_memberships_require_identity() -> None:
    response = TestClient(app).get("/api/v1/auth/memberships")
    assert response.status_code == 401


def test_memberships_use_verified_identity_and_rls_role(monkeypatch) -> None:
    calls = []

    class Connection:
        def run(self, sql, **parameters):
            calls.append((sql, parameters))
            if "SELECT m.tenant_id" in sql:
                return [[TENANT, "Loja A", "owner", BRANCH, "Centro"]]
            return []

        def close(self):
            calls.append(("CLOSE", {}))

    monkeypatch.setattr(memberships, "configured_database_url", lambda: "private-url")
    monkeypatch.setattr(memberships, "connect_database", lambda *_: Connection())
    app.dependency_overrides[authenticated_user] = lambda: AuthenticatedUser(user_id=USER)
    try:
        response = TestClient(app).get(
            "/api/v1/auth/memberships?user_id=00000000-0000-4000-8000-000000000099"
        )
    finally:
        app.dependency_overrides.clear()
    assert response.status_code == 200
    assert response.json() == [{
        "tenant_id": TENANT, "name": "Loja A", "role": "owner",
        "branches": [{"branch_id": BRANCH, "name": "Centro"}],
    }]
    assert calls[0][0] == "BEGIN"
    assert calls[1][1] == {"subject": str(USER)}
    assert calls[2][0] == "SET LOCAL ROLE authenticated"
    assert calls[3][1] == {"subject": str(USER)}
    assert calls[4][0] == "COMMIT"
    assert calls[5][0] == "CLOSE"


@pytest.mark.parametrize("configured", [False, True])
def test_membership_lookup_fails_closed(monkeypatch, configured, caplog) -> None:
    monkeypatch.setattr(
        memberships, "configured_database_url",
        lambda: "private-url" if configured else "",
    )
    if configured:
        def fail(*_):
            raise RuntimeError("password=secret")
        monkeypatch.setattr(memberships, "connect_database", fail)
    app.dependency_overrides[authenticated_user] = lambda: AuthenticatedUser(user_id=USER)
    try:
        response = TestClient(app).get("/api/v1/auth/memberships")
    finally:
        app.dependency_overrides.clear()
    assert response.status_code == 503
    assert "secret" not in response.text
    assert "secret" not in caplog.text
