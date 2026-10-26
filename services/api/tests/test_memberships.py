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


def test_management_context_requires_identity() -> None:
    response = TestClient(app).get(
        f"/api/v1/management/tenants/{TENANT}/branches/{BRANCH}/context"
    )
    assert response.status_code == 401


def test_management_context_binds_verified_user_and_requested_scope(monkeypatch) -> None:
    calls = []

    class Connection:
        def run(self, sql, **parameters):
            calls.append((sql, parameters))
            if "FROM gogdely.branches AS b" in sql:
                return [[TENANT, "Loja A", BRANCH, "Centro", "manager"]]
            return []

        def close(self):
            calls.append(("CLOSE", {}))

    monkeypatch.setattr(memberships, "configured_database_url", lambda: "private-url")
    monkeypatch.setattr(memberships, "connect_database", lambda *_: Connection())
    app.dependency_overrides[authenticated_user] = lambda: AuthenticatedUser(user_id=USER)
    try:
        response = TestClient(app).get(
            f"/api/v1/management/tenants/{TENANT}/branches/{BRANCH}/context"
            "?user_id=00000000-0000-4000-8000-000000000099&role=owner"
        )
    finally:
        app.dependency_overrides.clear()

    assert response.status_code == 200
    assert response.json() == {
        "tenant_id": TENANT, "tenant_name": "Loja A",
        "branch_id": BRANCH, "branch_name": "Centro", "role": "manager",
    }
    assert calls[0][0] == "BEGIN"
    assert calls[1][1] == {"subject": str(USER)}
    assert calls[2][0] == "SET LOCAL ROLE authenticated"
    assert calls[3][1] == {
        "subject": str(USER), "tenant": TENANT, "branch": BRANCH,
    }
    assert "WHERE b.tenant_id = :tenant AND b.branch_id = :branch" in calls[3][0]
    assert calls[4][0] == "COMMIT"
    assert calls[5][0] == "CLOSE"


def test_management_context_hides_absent_foreign_and_revoked_scope(monkeypatch) -> None:
    visible = True

    class Connection:
        def run(self, sql, **_):
            if "FROM gogdely.branches AS b" in sql and visible:
                return [[TENANT, "Loja A", BRANCH, "Centro", "staff"]]
            return []

        def close(self):
            pass

    monkeypatch.setattr(memberships, "configured_database_url", lambda: "private-url")
    monkeypatch.setattr(memberships, "connect_database", lambda *_: Connection())
    app.dependency_overrides[authenticated_user] = lambda: AuthenticatedUser(user_id=USER)
    url = f"/api/v1/management/tenants/{TENANT}/branches/{BRANCH}/context"
    try:
        assert TestClient(app).get(url).status_code == 200
        visible = False  # A live membership revocation is seen on the next call.
        revoked = TestClient(app).get(url)
        foreign = TestClient(app).get(
            "/api/v1/management/tenants/00000000-0000-4000-8000-000000000088"
            "/branches/00000000-0000-4000-8000-000000000077/context"
        )
    finally:
        app.dependency_overrides.clear()
    assert revoked.status_code == foreign.status_code == 404
    assert revoked.json() == foreign.json() == {"detail": "Branch not found"}


def test_management_context_fails_closed_without_database(monkeypatch, caplog) -> None:
    monkeypatch.setattr(memberships, "configured_database_url", lambda: "private-url")

    def fail(*_):
        raise RuntimeError("password=secret")

    monkeypatch.setattr(memberships, "connect_database", fail)
    app.dependency_overrides[authenticated_user] = lambda: AuthenticatedUser(user_id=USER)
    try:
        response = TestClient(app).get(
            f"/api/v1/management/tenants/{TENANT}/branches/{BRANCH}/context"
        )
    finally:
        app.dependency_overrides.clear()
    assert response.status_code == 503
    assert "secret" not in response.text
    assert "secret" not in caplog.text
