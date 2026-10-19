"""Master writes require AAL2, validation and an audit event in one session."""

import base64
import json
from contextlib import contextmanager
from uuid import UUID

from fastapi.testclient import TestClient

from gogdely_api.auth import AuthenticatedUser, authenticated_user
from gogdely_api.main import app
from gogdely_api import master_admin

OWNER = UUID("9f4b4987-59de-4e69-9f12-b8b5d7d254e5")
TENANT = UUID("7ae62e0d-41a7-4e73-a307-40980bbc84c1")
REQUEST = UUID("24688df2-4694-41ad-99bb-f5719e332c6d")
client = TestClient(app)


def _headers(aal: str) -> dict[str, str]:
    payload = base64.urlsafe_b64encode(
        json.dumps({"sub": str(OWNER), "aal": aal}).encode()
    ).decode().rstrip("=")
    return {"Authorization": f"Bearer signed.{payload}.signature"}


class FakeConnection:
    def __init__(self, *, owners=1):
        self.statements = []
        self.owners = owners

    def run(self, statement, **parameters):
        self.statements.append((statement, parameters))
        if "INSERT INTO gogdely.tenants" in statement:
            return [[str(TENANT)]]
        if "INSERT INTO gogdely.branches" in statement:
            return [[str(REQUEST)]]
        if "SELECT status FROM gogdely.tenants" in statement:
            return [["draft"]]
        if "SELECT count(*) FROM gogdely.memberships" in statement:
            return [[self.owners]]
        if "SELECT id::text FROM auth.users" in statement:
            return [[str(OWNER)]]
        if "SELECT tenant_id FROM gogdely.tenants" in statement:
            return [[str(TENANT)]]
        if "FROM gogdely.tenant_commission_settings" in statement:
            return []
        return []


def _as_owner(monkeypatch, connection):
    monkeypatch.setenv("GOGDELY_MASTER_USER_IDS", str(OWNER))
    app.dependency_overrides[authenticated_user] = lambda: AuthenticatedUser(OWNER)

    @contextmanager
    def fake_transaction():
        yield connection

    monkeypatch.setattr(master_admin, "_transaction", fake_transaction)


def _clear():
    app.dependency_overrides.clear()


def test_company_creation_requires_mfa_and_records_audit(monkeypatch):
    connection = FakeConnection()
    _as_owner(monkeypatch, connection)
    command = {"request_id": str(REQUEST), "name": "Loja Alfa",
               "branch_name": "Loja Alfa Centro", "slug": "loja-alfa-centro",
               "reason": "Cadastro para homologação"}
    try:
        assert client.post("/api/v1/master/companies", json=command,
                           headers=_headers("aal1")).status_code == 403
        assert connection.statements == []
        response = client.post("/api/v1/master/companies", json=command,
                               headers=_headers("aal2"))
        assert response.status_code == 201
        assert response.json()["status"] == "draft"
        assert ["INSERT INTO gogdely.tenants" in sql for sql, _ in connection.statements] == [True, False, False]
        assert "INSERT INTO gogdely.master_audit" in connection.statements[-1][0]
        assert connection.statements[-1][1]["actor"] == str(OWNER)
    finally:
        _clear()


def test_invalid_slug_or_reason_never_writes(monkeypatch):
    connection = FakeConnection()
    _as_owner(monkeypatch, connection)
    try:
        response = client.post("/api/v1/master/companies", headers=_headers("aal2"),
            json={"request_id": str(REQUEST), "name": "Alfa",
                  "branch_name": "Centro", "slug": "Invalid Space",
                  "reason": "short"})
        assert response.status_code == 422
        assert connection.statements == []
    finally:
        _clear()


def test_activation_needs_owner_membership(monkeypatch):
    connection = FakeConnection(owners=0)
    _as_owner(monkeypatch, connection)
    try:
        response = client.patch(f"/api/v1/master/companies/{TENANT}/status",
            headers=_headers("aal2"), json={"request_id": str(REQUEST),
                "status": "active", "reason": "Loja pronta para abrir"})
        assert response.status_code == 409
        assert all("UPDATE gogdely.tenants" not in sql for sql, _ in connection.statements)
        assert all("INSERT INTO gogdely.master_audit" not in sql for sql, _ in connection.statements)
    finally:
        _clear()


def test_commission_policy_is_audited_but_not_collected(monkeypatch):
    connection = FakeConnection()
    _as_owner(monkeypatch, connection)
    try:
        response = client.patch(f"/api/v1/master/companies/{TENANT}/commission",
            headers=_headers("aal2"), json={"request_id": str(REQUEST),
                "enabled": True, "percentage": "5.50",
                "reason": "Plano de homologação aprovado"})
        assert response.status_code == 200
        assert response.json()["automatic_collection"] is False
        assert any("tenant_commission_settings" in sql for sql, _ in connection.statements)
        assert "INSERT INTO gogdely.master_audit" in connection.statements[-1][0]
    finally:
        _clear()


def test_existing_confirmed_owner_is_linked_with_audit(monkeypatch):
    connection = FakeConnection(owners=0)
    _as_owner(monkeypatch, connection)
    try:
        response = client.post(f"/api/v1/master/companies/{TENANT}/owner",
            headers=_headers("aal2"), json={"request_id": str(REQUEST),
                "email": "owner@example.com", "reason": "Responsável da loja confirmado"})
        assert response.status_code == 200
        assert response.json()["owner_user_id"] == str(OWNER)
        assert any("INSERT INTO gogdely.memberships " in sql for sql, _ in connection.statements)
        assert any("INSERT INTO gogdely.membership_branches" in sql for sql, _ in connection.statements)
        assert connection.statements[-1][1]["action"] == "company.owner_linked"
        assert "owner@example.com" not in str(connection.statements[-1])
    finally:
        _clear()
