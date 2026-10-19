"""Online catalog uses verified identity, RLS roles, and audit writes."""

from uuid import UUID

from fastapi.testclient import TestClient

from gogdely_api.auth import AuthenticatedUser, authenticated_user
from gogdely_api.main import app
from gogdely_api import online_catalog
from gogdely_api.memberships import AuthorizedBranch


USER = UUID("00000000-0000-4000-8000-000000000001")
TENANT = UUID("00000000-0000-4000-8000-000000000002")
BRANCH = UUID("00000000-0000-4000-8000-000000000003")
ITEM = "00000000-0000-4000-8000-000000000004"
BASE = f"/api/v1/management/tenants/{TENANT}/branches/{BRANCH}/catalog"


def _override_user():
    app.dependency_overrides[authenticated_user] = lambda: AuthenticatedUser(user_id=USER)


def test_public_catalog_uses_anon_role_and_available_items(monkeypatch):
    calls = []

    class Connection:
        def run(self, sql, **parameters):
            calls.append((sql, parameters))
            if "FROM gogdely.branches b" in sql:
                return [[str(TENANT), str(BRANCH), "loja-a", "Loja A", ITEM,
                         "Pizza", "Queijo", "Pizzas", 3000, None, True, 0,
                         "2026-10-19 12:00:00+00"]]
            return []

        def close(self):
            calls.append(("CLOSE", {}))

    monkeypatch.setattr(online_catalog, "configured_database_url", lambda: "secret-url")
    monkeypatch.setattr(online_catalog, "connect_database", lambda *_: Connection())
    response = TestClient(app).get("/api/v1/catalog/stores/loja-a")
    assert response.status_code == 200
    assert response.json()["items"][0]["price_cents"] == 3000
    assert calls[0][0] == "BEGIN READ ONLY"
    assert calls[1][0] == "SET LOCAL ROLE anon"
    assert calls[2][1] == {"slug": "loja-a"}
    assert "i.available" in calls[2][0]
    assert calls[-2][0] == "COMMIT"


def test_management_catalog_requires_real_identity():
    assert TestClient(app).get(BASE).status_code == 401
    assert TestClient(app).post(BASE, json={}).status_code == 401


def test_management_catalog_binds_verified_subject(monkeypatch):
    calls = []

    class Connection:
        def run(self, sql, **parameters):
            calls.append((sql, parameters))
            if "FROM gogdely.branches b" in sql:
                return [[str(TENANT), str(BRANCH), "loja-a", "Loja A", None,
                         None, None, None, None, None, None, None, None,
                         "manager"]]
            return []

        def close(self):
            pass

    monkeypatch.setattr(online_catalog, "configured_database_url", lambda: "secret-url")
    monkeypatch.setattr(online_catalog, "connect_database", lambda *_: Connection())
    _override_user()
    try:
        response = TestClient(app).get(BASE + "?user_id=foreign")
    finally:
        app.dependency_overrides.clear()
    assert response.status_code == 200
    assert response.json()["role"] == "manager"
    assert response.json()["items"] == []
    assert calls[1][1] == {"subject": str(USER)}
    assert calls[2][0] == "SET LOCAL ROLE authenticated"
    assert calls[3][1]["subject"] == str(USER)


def test_catalog_write_requires_manager_and_writes_audit_in_one_transaction(monkeypatch):
    calls = []

    class Connection:
        def run(self, sql, **parameters):
            calls.append((sql, parameters))
            if "RETURNING item_id" in sql:
                return [[ITEM, "Pizza", "Queijo", "Pizzas", 3000, None,
                         True, 0, "2026-10-19 12:00:00+00"]]
            return []

        def close(self):
            calls.append(("CLOSE", {}))

    monkeypatch.setattr(online_catalog, "authorized_branch", lambda *_:
        AuthorizedBranch(tenant_id=TENANT, tenant_name="Loja A", branch_id=BRANCH,
                         branch_name="Centro", role="manager"))
    monkeypatch.setattr(online_catalog, "configured_database_url", lambda: "secret-url")
    monkeypatch.setattr(online_catalog, "connect_database", lambda *_: Connection())
    _override_user()
    try:
        response = TestClient(app).post(BASE, json={
            "name": "Pizza", "description": "Queijo", "category_name": "Pizzas",
            "price_cents": 3000, "available": True,
        })
    finally:
        app.dependency_overrides.clear()
    assert response.status_code == 201
    assert response.json()["item_id"] == ITEM
    assert calls[0][0] == "BEGIN"
    assert calls[2][0] == "SET LOCAL ROLE authenticated"
    assert "INSERT INTO gogdely.menu_items" in calls[3][0]
    assert "INSERT INTO gogdely.menu_item_events" in calls[4][0]
    assert calls[4][1]["actor"] == str(USER)
    assert calls[5][0] == "COMMIT"


def test_staff_cannot_edit_catalog(monkeypatch):
    monkeypatch.setattr(online_catalog, "authorized_branch", lambda *_:
        AuthorizedBranch(tenant_id=TENANT, tenant_name="Loja A", branch_id=BRANCH,
                         branch_name="Centro", role="staff"))
    _override_user()
    try:
        response = TestClient(app).post(BASE, json={
            "name": "Pizza", "category_name": "Pizzas", "price_cents": 3000,
        })
    finally:
        app.dependency_overrides.clear()
    assert response.status_code == 403


def test_catalog_rejects_blank_name_and_unreviewed_image_url():
    _override_user()
    try:
        blank = TestClient(app).post(BASE, json={
            "name": "   ", "category_name": "Pizzas", "price_cents": 3000,
        })
        external_image = TestClient(app).post(BASE, json={
            "name": "Pizza", "category_name": "Pizzas", "price_cents": 3000,
            "image_path": "https://example.com/tracker.png",
        })
    finally:
        app.dependency_overrides.clear()
    assert blank.status_code == 422
    assert external_image.status_code == 422


def test_stale_catalog_update_returns_conflict_without_audit(monkeypatch):
    calls = []

    class Connection:
        def run(self, sql, **parameters):
            calls.append(sql)
            return []

        def close(self):
            pass

    monkeypatch.setattr(online_catalog, "authorized_branch", lambda *_:
        AuthorizedBranch(tenant_id=TENANT, tenant_name="Loja A", branch_id=BRANCH,
                         branch_name="Centro", role="owner"))
    monkeypatch.setattr(online_catalog, "configured_database_url", lambda: "private-url")
    monkeypatch.setattr(online_catalog, "connect_database", lambda *_: Connection())
    _override_user()
    try:
        response = TestClient(app).put(BASE + f"/{ITEM}", json={
            "name": "Pizza", "category_name": "Pizzas", "price_cents": 3200,
            "expected_updated_at": "2026-10-19 12:00:00+00",
        })
    finally:
        app.dependency_overrides.clear()
    assert response.status_code == 409
    assert not any("INSERT INTO gogdely.menu_item_events" in sql for sql in calls)
    assert "GREATEST(clock_timestamp()" in calls[3]


def test_catalog_database_failure_hides_secret(monkeypatch, caplog):
    monkeypatch.setattr(online_catalog, "configured_database_url", lambda: "private-url")

    def fail(*_):
        raise RuntimeError("password=secret")

    monkeypatch.setattr(online_catalog, "connect_database", fail)
    response = TestClient(app).get("/api/v1/catalog/stores/loja-a")
    assert response.status_code == 503
    assert "secret" not in response.text
    assert "secret" not in caplog.text
