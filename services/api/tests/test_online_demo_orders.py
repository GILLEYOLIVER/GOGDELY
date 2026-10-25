"""Focused checks for the isolated, fictitious Supabase order journey."""

from uuid import UUID

from fastapi.testclient import TestClient

from gogdely_api.auth import AuthenticatedUser, authenticated_user
from gogdely_api.main import app
from gogdely_api import online_demo_orders as demo


USER = UUID("00000000-0000-4000-8000-000000000001")
BRANCH = "d3bdc553-639a-47c4-9cea-aad6a06725ea"
ITEM = "90100000-0000-4000-8000-000000000001"
ORDER = "00000000-0000-4000-8000-000000000010"
KEY = "00000000-0000-4000-8000-000000000011"


def test_demo_order_is_disabled_outside_homologation(monkeypatch):
    monkeypatch.setenv("GOGDELY_ENV", "producao")
    result = TestClient(app).post("/api/v1/demo/orders", json={
        "slug": "loja-ficticia-gogdely", "idempotency_key": KEY,
        "items": [{"item_id": ITEM, "quantity": 1}],
    })
    assert result.status_code == 404


def test_demo_order_uses_database_price_and_never_confirms_payment(monkeypatch):
    monkeypatch.setenv("GOGDELY_ENV", "testes")
    calls = []

    class Connection:
        def run(self, sql, **parameters):
            calls.append((sql, parameters))
            if "FROM gogdely.branches b JOIN gogdely.tenants" in sql:
                return [[str(demo.DEMO_TENANT), BRANCH]]
            if "FROM gogdely.menu_items" in sql:
                return [[ITEM, "Burger", 3210]]
            if "SELECT" in sql and "idempotency_key=:key" in sql:
                return []
            if "ON CONFLICT (tenant_id, idempotency_key) DO NOTHING" in sql:
                return [[ORDER]]
            if "SELECT order_id::text, status" in sql:
                return [[ORDER, "created", "delivery", 6420, 599,
                         7019, "2026-10-25T20:00:00Z", None, "not_processed"]]
            return []

        def close(self):
            pass

    monkeypatch.setattr(demo, "configured_database_url", lambda: "test-only")
    monkeypatch.setattr(demo, "connect_database", lambda *_: Connection())
    result = TestClient(app).post("/api/v1/demo/orders", json={
        "slug": "loja-ficticia-gogdely", "idempotency_key": KEY,
        "items": [{"item_id": ITEM, "quantity": 2}],
        "price_cents": 1, "payment_state": "provider_confirmed",
    })
    assert result.status_code == 201
    assert result.json()["total_cents"] == 7019
    assert result.json()["payment_state"] == "not_processed"
    insert = next(parameters for sql, parameters in calls
                  if "INSERT INTO gogdely.orders" in sql)
    assert insert["subtotal"] == 6420
    assert insert["delivery"] == 599
    assert insert["total"] == 7019
    assert any("INSERT INTO gogdely.order_events" in sql for sql, _ in calls)
    assert calls[-1][0] == "COMMIT"


def test_courier_routes_require_verified_auth(monkeypatch):
    monkeypatch.setenv("GOGDELY_ENV", "testes")
    client = TestClient(app)
    assert client.get("/api/v1/courier/assignments").status_code == 401
    assert client.post(f"/api/v1/courier/assignments/{ORDER}/accept").status_code == 401


def test_courier_earnings_count_only_completed_assignments(monkeypatch):
    monkeypatch.setenv("GOGDELY_ENV", "testes")
    calls = []

    class Connection:
        def run(self, sql, **parameters):
            calls.append((sql, parameters))
            if "FROM gogdely.delivery_assignments a" in sql:
                base = [str(demo.DEMO_TENANT), BRANCH, ORDER]
                return [base + ["completed", 800, "Loja Ficticia", 3809,
                                599, "Destino ficticio", "2026-10-25"],
                        base + ["in_delivery", 800, "Loja Ficticia", 3809,
                                599, "Destino ficticio", "2026-10-25"]]
            return []

        def close(self):
            pass

    monkeypatch.setattr(demo, "configured_database_url", lambda: "test-only")
    monkeypatch.setattr(demo, "connect_database", lambda *_: Connection())
    app.dependency_overrides[authenticated_user] = lambda: AuthenticatedUser(user_id=USER)
    try:
        result = TestClient(app).get("/api/v1/courier/earnings")
    finally:
        app.dependency_overrides.clear()
    assert result.status_code == 200
    assert result.json()["total_cents"] == 800
    assert result.json()["completed_count"] == 1
    assert result.json()["stores"] == [
        {"store_name": "Loja Ficticia", "earned_cents": 800}]
    query = next(parameters for sql, parameters in calls
                 if "FROM gogdely.delivery_assignments a" in sql)
    assert query["courier"] == str(USER)
    assert query["tenant"] == str(demo.DEMO_TENANT)
