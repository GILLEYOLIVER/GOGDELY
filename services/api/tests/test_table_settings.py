"""Payment preference is branch scoped and never implies real settlement."""

from uuid import UUID

from fastapi.testclient import TestClient

from gogdely_api.auth import AuthenticatedUser, authenticated_user
from gogdely_api.main import app
from gogdely_api import table_settings
from gogdely_api.memberships import AuthorizedBranch

USER = UUID("00000000-0000-4000-8000-000000000001")
TENANT = UUID("00000000-0000-4000-8000-000000000002")
BRANCH = UUID("00000000-0000-4000-8000-000000000003")
URL = f"/api/v1/management/tenants/{TENANT}/branches/{BRANCH}/table-payment"


def test_settings_require_identity():
    assert TestClient(app).get(URL).status_code == 401
    assert TestClient(app).put(URL, json={"allow_online_payment": True}).status_code == 401


def test_owner_can_save_preference_without_enabling_fake_payment(monkeypatch):
    calls = []

    class Connection:
        def run(self, sql, **params):
            calls.append((sql, params))
            if "RETURNING allow_online_payment" in sql:
                return [[True]]
            return []

        def close(self):
            pass

    monkeypatch.setattr(table_settings, "authorized_branch", lambda *_:
        AuthorizedBranch(tenant_id=TENANT, tenant_name="Loja A", branch_id=BRANCH,
                         branch_name="Centro", role="owner"))
    monkeypatch.setattr(table_settings, "configured_database_url", lambda: "private-url")
    monkeypatch.setattr(table_settings, "connect_database", lambda *_: Connection())
    app.dependency_overrides[authenticated_user] = lambda: AuthenticatedUser(user_id=USER)
    try:
        response = TestClient(app).put(URL, json={"allow_online_payment": True})
    finally:
        app.dependency_overrides.clear()
    assert response.status_code == 200
    assert response.json() == {
        "allow_online_payment": True, "online_payment_available": False,
    }
    assert calls[0][0] == "BEGIN"
    assert calls[1][1] == {"subject": str(USER)}
    assert calls[2][0] == "SET LOCAL ROLE authenticated"
    assert calls[3][1]["tenant"] == str(TENANT)
    assert calls[3][1]["branch"] == str(BRANCH)


def test_staff_cannot_change_preference(monkeypatch):
    monkeypatch.setattr(table_settings, "authorized_branch", lambda *_:
        AuthorizedBranch(tenant_id=TENANT, tenant_name="Loja A", branch_id=BRANCH,
                         branch_name="Centro", role="staff"))
    app.dependency_overrides[authenticated_user] = lambda: AuthenticatedUser(user_id=USER)
    try:
        response = TestClient(app).put(URL, json={"allow_online_payment": True})
    finally:
        app.dependency_overrides.clear()
    assert response.status_code == 403


def test_public_config_contains_only_publishable_key(monkeypatch):
    monkeypatch.setenv("GOGDELY_SUPABASE_URL", "https://example.supabase.co")
    monkeypatch.setenv("GOGDELY_SUPABASE_PUBLISHABLE_KEY", "sb_publishable_example")
    response = TestClient(app).get("/api/v1/client-config")
    assert response.status_code == 200
    assert response.json() == {
        "supabase_url": "https://example.supabase.co",
        "supabase_publishable_key": "sb_publishable_example",
    }
