"""Table QR generation requires a verified member and a configured HTTPS PWA."""

from uuid import UUID

import pytest
from fastapi import HTTPException
from fastapi.testclient import TestClient

from gogdely_api.auth import AuthenticatedUser, authenticated_user
from gogdely_api.main import app
from gogdely_api import online_tables
from gogdely_api.memberships import AuthorizedBranch

USER = UUID("00000000-0000-4000-8000-000000000001")
TENANT = UUID("00000000-0000-4000-8000-000000000002")
BRANCH = UUID("00000000-0000-4000-8000-000000000003")
PATH = f"/api/v1/management/tenants/{TENANT}/branches/{BRANCH}/tables/2/qr"


def test_table_qr_requires_login():
    assert TestClient(app).get(PATH).status_code == 401


def test_table_qr_encodes_store_and_table_only_after_scope_check(monkeypatch):
    calls = []
    app.dependency_overrides[authenticated_user] = lambda: AuthenticatedUser(user_id=USER)
    monkeypatch.setenv("GOGDELY_CLIENT_PWA_URL", "https://pwa.example.test/cliente/")

    def scope(*args):
        calls.append("scope")
        return AuthorizedBranch(tenant_id=TENANT, tenant_name="Loja A",
                                branch_id=BRANCH, branch_name="Centro", role="owner")

    def read(*args, **kwargs):
        calls.append((args[0], kwargs["user_id"], kwargs["tenant"], kwargs["branch"]))
        return [["loja-a"]]

    monkeypatch.setattr(online_tables, "authorized_branch", scope)
    monkeypatch.setattr(online_tables, "_read", read)
    try:
        response = TestClient(app).get(PATH)
    finally:
        app.dependency_overrides.clear()
    assert response.status_code == 200
    assert response.json()["url"] == "https://pwa.example.test/cliente/?loja=loja-a&mesa=2"
    assert len(response.json()["matrix"]) > 20
    assert calls[0] == "scope"
    assert calls[1] == ("authenticated", USER, str(TENANT), str(BRANCH))


def test_table_qr_refuses_unconfigured_public_link(monkeypatch):
    app.dependency_overrides[authenticated_user] = lambda: AuthenticatedUser(user_id=USER)
    monkeypatch.setenv("GOGDELY_CLIENT_PWA_URL", "http://localhost:3000/cliente/")
    monkeypatch.setattr(online_tables, "authorized_branch", lambda *_: None)
    try:
        response = TestClient(app).get(PATH)
    finally:
        app.dependency_overrides.clear()
    assert response.status_code == 503


def test_foreign_branch_cannot_generate_qr(monkeypatch):
    app.dependency_overrides[authenticated_user] = lambda: AuthenticatedUser(user_id=USER)
    monkeypatch.setenv("GOGDELY_CLIENT_PWA_URL", "https://pwa.example.test/cliente/")

    def deny(*_):
        raise HTTPException(status_code=404, detail="Branch not found")

    monkeypatch.setattr(online_tables, "authorized_branch", deny)
    monkeypatch.setattr(online_tables, "_read", lambda *_, **__: pytest.fail("read after denial"))
    try:
        response = TestClient(app).get(PATH)
    finally:
        app.dependency_overrides.clear()
    assert response.status_code == 404
