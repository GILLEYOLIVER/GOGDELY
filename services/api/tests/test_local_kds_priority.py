"""Focused checks for the local Burger House kitchen priority."""

from uuid import uuid4

from fastapi.testclient import TestClient

from gogdely_api.main import app


def test_kitchen_priority_persists_and_audits_without_duplicate_events(tmp_path, monkeypatch):
    monkeypatch.setenv("GOGDELY_ENV", "local")
    monkeypatch.setenv("GOGDELY_LOCAL_DEMO", "1")
    monkeypatch.setenv("GOGDELY_LOCAL_DB", str(tmp_path / "priority.sqlite3"))
    client = TestClient(app)

    def create(store_id: str) -> dict:
        product_id = "x-tudo" if store_id == "burger-house" else "margherita"
        response = client.post("/api/v1/local/orders", json={
            "request_key": str(uuid4()),
            "store_id": store_id,
            "address_label": "Endereço de teste",
            "items": [{"product_id": product_id, "quantity": 1}],
        })
        assert response.status_code == 201
        return response.json()

    burger = create("burger-house")
    other = create("pizzaria-napoli")
    url = f"/api/v1/local/orders/{burger['id']}/kitchen-priority"
    assert burger["kitchen_priority"] == "normal"
    assert client.put(url, json={"priority": "urgent", "reason": "x"}).status_code == 422
    assert client.put(url, json={"priority": "urgent", "reason": "Pedido urgente"}).json()["kitchen_priority"] == "urgent"
    assert client.put(url, json={"priority": "urgent", "reason": "Pedido urgente"}).status_code == 200
    events = client.get(f"/api/v1/local/orders/{burger['id']}/events").json()
    assert len([event for event in events if event["actor"] == "management_kds"]) == 1
    with TestClient(app) as reopened:
        assert reopened.get(f"/api/v1/local/orders/{burger['id']}").json()["kitchen_priority"] == "urgent"
        assert reopened.put(url, json={"priority": "normal", "reason": "Fila normal"}).json()["kitchen_priority"] == "normal"
        assert reopened.put(f"/api/v1/local/orders/{other['id']}/kitchen-priority",
                            json={"priority": "urgent", "reason": "Outra loja"}).status_code == 404
        status_url = f"/api/v1/local/orders/{burger['id']}/status"
        for status in ("preparing", "ready"):
            assert reopened.patch(status_url, json={"status": status, "actor": "management"}).status_code == 200
        assert reopened.put(url, json={"priority": "urgent", "reason": "Pedido pronto"}).status_code == 409
