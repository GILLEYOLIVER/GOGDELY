"""Persistence and cross-role transitions against an isolated temporary DB."""
import base64
import sqlite3
import re
from uuid import uuid4

from fastapi.testclient import TestClient

from gogdely_api.main import app


def test_local_order_round_trip_and_role_boundaries(tmp_path, monkeypatch):
    monkeypatch.setenv("GOGDELY_ENV", "local")
    monkeypatch.setenv("GOGDELY_LOCAL_DEMO", "1")
    monkeypatch.setenv("GOGDELY_LOCAL_DB", str(tmp_path / "orders.sqlite3"))
    client = TestClient(app)
    assert client.get("/api/v1/local/health").json()["storage"] == "sqlite-local-demo"

    payload = {
        "request_key": str(uuid4()),
        "store_id": "burger-house",
        "address_label": "Rua das Flores, 123",
        "payment_method": "pix",
        "items": [{"product_id": "x-tudo", "quantity": 2, "size": "Média", "extras": ["Mussarela extra"]}],
    }
    created = client.post("/api/v1/local/orders", json=payload)
    assert created.status_code == 201
    order = created.json()
    assert order["total_cents"] == 2 * (2890 + 400 + 300) + 599
    assert order["status"] == "created"
    assert order["payment_method"] == "pix"
    assert order["payment_status"] == "not_processed"
    assert re.fullmatch(r"\d{6}", order["delivery_code"])
    assert client.post("/api/v1/local/orders", json=payload).json()["id"] == order["id"]
    assert client.post("/api/v1/local/orders", json={**payload, "payment_method": "card"}).status_code == 409
    assert len(client.get("/api/v1/local/orders?store_id=burger-house").json()) == 1
    assert client.get("/api/v1/local/orders?store_id=pizzaria-napoli").json() == []

    url = f"/api/v1/local/orders/{order['id']}/status"
    assert client.patch(url, json={"status": "delivered", "actor": "courier"}).status_code == 409
    for status, actor in [("preparing", "management"), ("ready", "management")]:
        response = client.patch(url, json={"status": status, "actor": actor})
        assert response.status_code == 200
        assert response.json()["status"] == status
    assert client.get(f"/api/v1/local/orders/{order['id']}").json()["dispatch_mode"] == "pending"
    assert client.patch(url, json={"status": "in_delivery", "actor": "courier"}).status_code == 409
    dispatch = client.post(f"/api/v1/local/orders/{order['id']}/dispatch-internal")
    assert dispatch.status_code == 200 and dispatch.json()["dispatch_mode"] == "internal"
    assert client.post(f"/api/v1/local/orders/{order['id']}/dispatch-internal").status_code == 200
    assert sum(event["reason"] == "Encaminhado ao entregador próprio" for event in client.get(f"/api/v1/local/orders/{order['id']}/events").json()) == 1
    response = client.patch(url, json={"status": "in_delivery", "actor": "courier"})
    assert response.status_code == 200
    assert response.json()["status"] == "in_delivery"
    assert client.patch(url, json={"status": "delivered", "actor": "courier"}).status_code == 409
    wrong_code = "999999" if order["delivery_code"] != "999999" else "000000"
    assert client.patch(url, json={"status": "delivered", "actor": "courier", "delivery_code": wrong_code}).status_code == 409
    response = client.patch(url, json={"status": "delivered", "actor": "courier", "delivery_code": order["delivery_code"]})
    assert response.status_code == 200
    assert response.json()["status"] == "delivered"
    assert client.get(f"/api/v1/local/orders/{order['id']}").json()["status"] == "delivered"

    with TestClient(app) as restarted_client:
        assert restarted_client.get(f"/api/v1/local/orders/{order['id']}").json()["total_cents"] == order["total_cents"]
        assert restarted_client.get(f"/api/v1/local/orders/{order['id']}").json()["payment_method"] == "pix"


def test_local_routes_disabled_without_opt_in(tmp_path, monkeypatch):
    monkeypatch.delenv("GOGDELY_LOCAL_DEMO", raising=False)
    monkeypatch.setenv("GOGDELY_LOCAL_DB", str(tmp_path / "unused.sqlite3"))
    client = TestClient(app)
    assert client.get("/api/v1/local/orders").status_code == 404
    assert client.get("/api/v1/local/stores/burger-house/payment-methods").status_code == 404
    assert not (tmp_path / "unused.sqlite3").exists()


def test_burger_payment_methods_are_configured_and_enforced_locally(tmp_path, monkeypatch):
    monkeypatch.setenv("GOGDELY_ENV", "local")
    monkeypatch.setenv("GOGDELY_LOCAL_DEMO", "1")
    monkeypatch.setenv("GOGDELY_LOCAL_DB", str(tmp_path / "payments.sqlite3"))
    client = TestClient(app)
    settings_url = "/api/v1/local/stores/burger-house/payment-methods"
    assert client.get(settings_url).json()["methods"] == ["cash", "pix", "card"]
    assert client.put(settings_url, json={"methods": []}).status_code == 422
    assert client.put(settings_url, json={"methods": ["pix", "pix"]}).status_code == 422
    assert client.put(settings_url, json={"methods": ["pix"]}).json()["methods"] == ["pix"]
    payload = {
        "request_key": str(uuid4()), "store_id": "burger-house",
        "address_label": "Rua das Flores, 123", "order_channel": "pickup",
        "payment_method": "cash",
        "items": [{"product_id": "x-tudo", "quantity": 1}],
    }
    assert client.post("/api/v1/local/orders", json=payload).status_code == 422
    payload["payment_method"] = "pix"
    created = client.post("/api/v1/local/orders", json=payload)
    assert created.status_code == 201
    assert created.json()["payment_status"] == "not_processed"
    with TestClient(app) as reopened:
        assert reopened.get(settings_url).json()["methods"] == ["pix"]
        assert reopened.get(f"/api/v1/local/orders/{created.json()['id']}").json()["payment_method"] == "pix"


def test_order_history_and_cancellation_boundaries(tmp_path, monkeypatch):
    monkeypatch.setenv("GOGDELY_ENV", "local")
    monkeypatch.setenv("GOGDELY_LOCAL_DEMO", "1")
    monkeypatch.setenv("GOGDELY_LOCAL_DB", str(tmp_path / "history.sqlite3"))
    client = TestClient(app)

    def create():
        response = client.post("/api/v1/local/orders", json={
            "request_key": str(uuid4()), "store_id": "burger-house",
            "address_label": "Rua das Flores, 123",
            "items": [{"product_id": "x-tudo", "quantity": 1}],
        })
        assert response.status_code == 201
        return response.json()["id"]

    first = create()
    url = f"/api/v1/local/orders/{first}"
    assert [event["to_status"] for event in client.get(f"{url}/events").json()] == ["created"]
    assert client.post(f"{url}/cancel", json={"actor": "customer", "reason": "Mudei de ideia"}).json()["status"] == "cancelled"
    assert client.post(f"{url}/cancel", json={"actor": "customer", "reason": "Outra vez"}).status_code == 409
    assert client.patch(f"{url}/status", json={"actor": "management", "status": "preparing"}).status_code == 409
    events = client.get(f"{url}/events").json()
    assert [event["to_status"] for event in events] == ["created", "cancelled"]
    assert events[-1]["reason"] == "Mudei de ideia"

    second = create()
    url = f"/api/v1/local/orders/{second}"
    assert client.patch(f"{url}/status", json={"actor": "management", "status": "preparing"}).status_code == 200
    assert client.post(f"{url}/cancel", json={"actor": "customer", "reason": "Muito tarde"}).status_code == 409
    assert client.post(f"{url}/cancel", json={"actor": "management", "reason": "Produto indisponível"}).status_code == 200
    assert [event["to_status"] for event in client.get(f"{url}/events").json()] == ["created", "preparing", "cancelled"]

    third = create()
    url = f"/api/v1/local/orders/{third}"
    for status in ("preparing", "ready"):
        assert client.patch(f"{url}/status", json={"actor": "management", "status": status}).status_code == 200
    assert client.post(f"{url}/cancel", json={"actor": "management", "reason": "Tarde demais"}).status_code == 409


def test_pickup_order_has_no_delivery_fee_or_courier_transition(tmp_path, monkeypatch):
    monkeypatch.setenv("GOGDELY_ENV", "local")
    monkeypatch.setenv("GOGDELY_LOCAL_DEMO", "1")
    monkeypatch.setenv("GOGDELY_LOCAL_DB", str(tmp_path / "pickup.sqlite3"))
    client = TestClient(app)
    payload = {
        "request_key": str(uuid4()), "store_id": "burger-house",
        "address_label": "Rua das Flores, 123", "order_channel": "pickup",
        "items": [{"product_id": "x-tudo", "quantity": 1}],
    }
    created = client.post("/api/v1/local/orders", json=payload)
    assert created.status_code == 201
    order = created.json()
    assert order["order_channel"] == "pickup"
    assert order["dispatch_mode"] == "none"
    assert re.fullmatch(r"\d{6}", order["pickup_code"])
    assert order["address_label"] == "Retirada na Burger House"
    assert order["delivery_fee_cents"] == 0
    assert order["total_cents"] == order["subtotal_cents"]
    assert client.post("/api/v1/local/orders", json=payload).json()["id"] == order["id"]
    url = f"/api/v1/local/orders/{order['id']}/status"
    for status in ("preparing", "ready"):
        assert client.patch(url, json={"status": status, "actor": "management"}).status_code == 200
    assert client.patch(url, json={"status": "in_delivery", "actor": "courier"}).status_code == 409
    assert client.post(f"/api/v1/local/orders/{order['id']}/dispatch-internal").status_code == 409
    assert client.patch(url, json={"status": "picked_up", "actor": "management"}).status_code == 409
    assert client.patch(url, json={"status": "picked_up", "actor": "management", "pickup_code": "999999" if order["pickup_code"] != "999999" else "000000"}).status_code == 409
    assert client.patch(url, json={"status": "picked_up", "actor": "management", "pickup_code": order["pickup_code"]}).status_code == 200
    assert [event["to_status"] for event in client.get(f"/api/v1/local/orders/{order['id']}/events").json()] == ["created", "preparing", "ready", "picked_up"]


def test_burger_menu_edit_is_saved_and_used_for_checkout(tmp_path, monkeypatch):
    monkeypatch.setenv("GOGDELY_ENV", "local")
    monkeypatch.setenv("GOGDELY_LOCAL_DEMO", "1")
    monkeypatch.setenv("GOGDELY_LOCAL_DB", str(tmp_path / "menu.sqlite3"))
    client = TestClient(app)
    menu_url = "/api/v1/local/stores/burger-house/menu"
    original = client.get(menu_url).json()
    assert [item["product_id"] for item in original] == ["x-tudo", "batata", "refrigerante"]
    events_url = "/api/v1/local/stores/burger-house/menu-events"
    assert client.get(events_url).json() == []
    new_item = {
        "product_id": "x-salada", "name": "X-Salada", "description": "Pedido de teste",
        "category": "Hambúrgueres", "price_cents": 2500, "image_ref": "",
        "available": True, "promo_percent": 0,
    }
    assert client.post(menu_url, json=new_item).status_code == 201
    assert client.get(events_url).json()[0]["changes"]["name"] == {"before": None, "after": "X-Salada"}
    assert len(client.get(menu_url).json()) == 4
    order_url = "/api/v1/local/stores/burger-house/menu-order"
    assert client.put(order_url, json={"product_ids": ["x-salada", "x-tudo", "batata", "refrigerante"]}).status_code == 200
    assert [item["product_id"] for item in client.get(menu_url).json()] == ["x-salada", "x-tudo", "batata", "refrigerante"]
    assert any(event["action"] == "reordered" for event in client.get(events_url).json())
    assert client.put(order_url, json={"product_ids": ["x-tudo", "batata"]}).status_code == 422
    assert client.put(order_url, json={"product_ids": ["x-tudo", "x-tudo", "batata", "refrigerante"]}).status_code == 422

    burger = next(item for item in original if item["product_id"] == "x-tudo")
    burger.update(price_cents=3500, promo_percent=20, name="X-Tudo Especial")
    assert client.put(f"{menu_url}/x-tudo", json=burger).json()["effective_price_cents"] == 2800
    assert next(item for item in client.get(menu_url).json() if item["product_id"] == "x-tudo")["name"] == "X-Tudo Especial"
    price_change = next(event["changes"]["price_cents"] for event in client.get(events_url).json()
                        if event["action"] == "updated" and "price_cents" in event["changes"])
    assert price_change == {"before": 2890, "after": 3500}

    payload = {
        "request_key": str(uuid4()), "store_id": "burger-house",
        "address_label": "Rua das Flores, 123",
        "items": [{"product_id": "x-tudo", "quantity": 1}],
    }
    order = client.post("/api/v1/local/orders", json=payload)
    assert order.status_code == 201
    assert order.json()["items"][0]["unit_cents"] == 2800
    assert order.json()["total_cents"] == 3399

    burger["addons"] = [{"name": "Bacon", "price_cents": 450}]
    assert client.put(f"{menu_url}/x-tudo", json=burger).status_code == 200
    payload["request_key"] = str(uuid4())
    payload["items"][0]["extras"] = ["Bacon"]
    with_bacon = client.post("/api/v1/local/orders", json=payload)
    assert with_bacon.status_code == 201
    assert with_bacon.json()["items"][0]["unit_cents"] == 3250
    payload["request_key"] = str(uuid4())
    payload["items"][0]["extras"] = ["Mussarela extra"]
    assert client.post("/api/v1/local/orders", json=payload).status_code == 422

    burger["available"] = False
    assert client.put(f"{menu_url}/x-tudo", json=burger).status_code == 200
    payload["request_key"] = str(uuid4())
    assert client.post("/api/v1/local/orders", json=payload).status_code == 422

    png = base64.b64decode(
        "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJ"
        "AAAADUlEQVQIHWP4z8DwHwAFgAI/ScLttAAAAABJRU5ErkJggg==")
    upload = client.post("/api/v1/local/uploads/images",
                         json={"mime_type": "image/png",
                               "data_base64": base64.b64encode(png).decode()})
    assert upload.status_code == 201
    image_ref = upload.json()["image_ref"]
    assert client.get(image_ref).content == png
    assert client.post("/api/v1/local/uploads/images",
                       json={"mime_type": "image/png",
                             "data_base64": base64.b64encode(b"not a png").decode()}).status_code == 422


def test_local_product_stock_deducts_once_and_cancel_restores(tmp_path, monkeypatch):
    monkeypatch.setenv("GOGDELY_ENV", "local")
    monkeypatch.setenv("GOGDELY_LOCAL_DEMO", "1")
    monkeypatch.setenv("GOGDELY_LOCAL_DB", str(tmp_path / "stock.sqlite3"))
    client = TestClient(app)
    menu_url = "/api/v1/local/stores/burger-house/menu"
    order_url = "/api/v1/local/orders"
    product = next(item for item in client.get(menu_url).json() if item["product_id"] == "x-tudo")
    unlimited = client.post(order_url, json={
        "request_key": str(uuid4()), "store_id": "burger-house",
        "address_label": "Rua das Flores, 123",
        "items": [{"product_id": "x-tudo", "quantity": 1}],
    })
    assert unlimited.status_code == 201
    product["stock_quantity"] = 3
    assert client.put(f"{menu_url}/x-tudo", json=product).status_code == 200
    old_client_payload = {key: value for key, value in product.items() if key != "stock_quantity"}
    assert client.put(f"{menu_url}/x-tudo", json=old_client_payload).json()["stock_quantity"] == 3
    stale = {**product, "stock_quantity": None,
             "expected_updated_at": product["updated_at"]}
    assert client.put(f"{menu_url}/x-tudo", json=stale).status_code == 409
    batata = next(item for item in client.get(menu_url).json() if item["product_id"] == "batata")
    batata["stock_quantity"] = 1
    assert client.put(f"{menu_url}/batata", json=batata).status_code == 200
    mixed = {"request_key": str(uuid4()), "store_id": "burger-house",
             "address_label": "Rua das Flores, 123",
             "items": [{"product_id": "x-tudo", "quantity": 1},
                       {"product_id": "batata", "quantity": 2}]}
    assert client.post(order_url, json=mixed).status_code == 409
    assert next(item["stock_quantity"] for item in client.get(menu_url).json()
                if item["product_id"] == "x-tudo") == 3
    assert client.post(f"{order_url}/{unlimited.json()['id']}/cancel",
                       json={"actor": "customer", "reason": "Pedido sem baixa"}).status_code == 200
    assert next(item["stock_quantity"] for item in client.get(menu_url).json()
                if item["product_id"] == "x-tudo") == 3

    payload = {"request_key": str(uuid4()), "store_id": "burger-house",
               "address_label": "Rua das Flores, 123",
               "items": [{"product_id": "x-tudo", "quantity": 2}]}
    created = client.post(order_url, json=payload)
    assert created.status_code == 201
    order_id = created.json()["id"]
    stock = lambda: next(item["stock_quantity"] for item in client.get(menu_url).json()
                         if item["product_id"] == "x-tudo")
    assert stock() == 1
    edited = next(item for item in client.get(menu_url).json() if item["product_id"] == "x-tudo")
    edited["price_cents"] += 100
    assert client.put(f"{menu_url}/x-tudo", json=edited).status_code == 200
    assert client.post(order_url, json=payload).json()["id"] == order_id
    assert stock() == 1
    too_many = {**payload, "request_key": str(uuid4()),
                "items": [{"product_id": "x-tudo", "quantity": 2}]}
    assert client.post(order_url, json=too_many).status_code == 409
    assert stock() == 1
    cancel_url = f"{order_url}/{order_id}/cancel"
    assert client.post(cancel_url, json={"actor": "customer", "reason": "Teste de saldo"}).status_code == 200
    assert stock() == 3
    assert client.post(cancel_url, json={"actor": "customer", "reason": "Teste repetido"}).status_code == 409
    assert stock() == 3
    events = client.get(f"{menu_url}-events").json()
    assert [event["action"] for event in events if event["action"].startswith("stock_")] == ["stock_restored", "stock_deducted"]

    with TestClient(app) as reopened:
        assert next(item["stock_quantity"] for item in reopened.get(menu_url).json()
                    if item["product_id"] == "x-tudo") == 3


def test_local_recipe_reserves_ingredients_and_restores_on_cancel(tmp_path, monkeypatch):
    monkeypatch.setenv("GOGDELY_ENV", "local")
    monkeypatch.setenv("GOGDELY_LOCAL_DEMO", "1")
    monkeypatch.setenv("GOGDELY_LOCAL_DB", str(tmp_path / "recipe.sqlite3"))
    client = TestClient(app)
    base = "/api/v1/local/stores/burger-house"
    ingredients_url = f"{base}/ingredients"
    menu_url = f"{base}/menu"
    assert client.post(ingredients_url, json={
        "ingredient_id": "vazio", "name": "  ", "unit": "un", "stock_quantity": 1,
    }).status_code == 422
    for ingredient_id, name, unit, stock in [
        ("pao", "Pão", "un", 2), ("carne", "Carne", "g", 360),
    ]:
        response = client.post(ingredients_url, json={
            "ingredient_id": ingredient_id, "name": name,
            "unit": unit, "stock_quantity": stock,
        })
        assert response.status_code == 201
    product = next(item for item in client.get(menu_url).json() if item["product_id"] == "x-tudo")
    product["stock_quantity"] = 5
    product["recipe"] = [{"ingredient_id": "pao", "quantity": 1},
                         {"ingredient_id": "carne", "quantity": 180}]
    assert client.put(f"{menu_url}/x-tudo", json=product).status_code == 200
    assert client.put(f"{menu_url}/x-tudo", json={**product, "recipe": [
        {"ingredient_id": "desconhecido", "quantity": 1}]}).status_code == 422

    def balances():
        return {item["ingredient_id"]: item["stock_quantity"]
                for item in client.get(ingredients_url).json()}

    payload = {"request_key": str(uuid4()), "store_id": "burger-house",
               "address_label": "Rua das Flores, 123",
               "items": [{"product_id": "x-tudo", "quantity": 3}]}
    assert client.post("/api/v1/local/orders", json=payload).status_code == 409
    assert balances() == {"carne": 360, "pao": 2}
    assert next(item["stock_quantity"] for item in client.get(menu_url).json()
                if item["product_id"] == "x-tudo") == 5

    payload["items"][0]["quantity"] = 2
    created = client.post("/api/v1/local/orders", json=payload)
    assert created.status_code == 201
    assert balances() == {"carne": 0, "pao": 0}
    assert next(item["orderable"] for item in client.get(menu_url).json()
                if item["product_id"] == "x-tudo") is False
    assert "X-Tudo" not in client.get("/api/v1/local/mesa/burger-house/M01").text
    assert client.post("/api/v1/local/orders", json=payload).json()["id"] == created.json()["id"]
    assert balances() == {"carne": 0, "pao": 0}
    movements = client.get(f"{base}/stock-movements").json()
    deductions = [row for row in movements if row["movement_type"] == "order_deduction"]
    assert len(deductions) == 3
    assert all(row["order_id"] == created.json()["id"] for row in deductions)
    payload["request_key"] = str(uuid4())
    payload["items"][0]["quantity"] = 1
    assert client.post("/api/v1/local/orders", json=payload).status_code == 409
    cancel_url = f"/api/v1/local/orders/{created.json()['id']}/cancel"
    assert client.post(cancel_url, json={"actor": "customer", "reason": "Teste de ingredientes"}).status_code == 200
    assert balances() == {"carne": 360, "pao": 2}
    assert next(item["orderable"] for item in client.get(menu_url).json()
                if item["product_id"] == "x-tudo") is True
    assert client.post(cancel_url, json={"actor": "customer", "reason": "Repetido"}).status_code == 409
    movements = client.get(f"{base}/stock-movements").json()
    assert len([row for row in movements if row["movement_type"] == "cancellation_restore"]) == 3


def test_local_stock_adjustments_and_movement_history(tmp_path, monkeypatch):
    monkeypatch.setenv("GOGDELY_ENV", "local")
    monkeypatch.setenv("GOGDELY_LOCAL_DEMO", "1")
    monkeypatch.setenv("GOGDELY_LOCAL_DB", str(tmp_path / "movements.sqlite3"))
    client = TestClient(app)
    base = "/api/v1/local/stores/burger-house"
    adjustment = f"{base}/stock-adjustments"
    history = f"{base}/stock-movements"
    assert client.post(f"{base}/ingredients", json={
        "ingredient_id": "carne", "name": "Carne", "unit": "g", "stock_quantity": 100,
    }).status_code == 201
    def change(kind, item_id, movement_type, quantity, reason="Conferência local"):
        return client.post(adjustment, json={"item_kind": kind, "item_id": item_id,
                              "movement_type": movement_type, "quantity": quantity, "reason": reason})
    assert change("ingredient", "carne", "restock", 50).json()["balance_after"] == 150
    assert change("ingredient", "carne", "loss", 20).json()["balance_after"] == 130
    assert change("ingredient", "carne", "count", 80).json()["quantity_delta"] == -50
    assert change("ingredient", "carne", "loss", 81).status_code == 409
    assert change("ingredient", "carne", "restock", 0).status_code == 422
    assert change("ingredient", "carne", "count", 80, "x").status_code == 422
    assert change("product", "x-tudo", "restock", 1).status_code == 409
    assert change("product", "x-tudo", "count", 3).json()["balance_before"] is None
    movements = client.get(history).json()
    assert [row["movement_type"] for row in movements] == [
        "count", "count", "loss", "restock", "initial"]
    assert movements[1]["reason"] == "Conferência local"
    assert next(item for item in client.get(f"{base}/ingredients").json()
                if item["ingredient_id"] == "carne")["stock_quantity"] == 80


def test_table_qr_order_reaches_kitchen_without_delivery(tmp_path, monkeypatch):
    monkeypatch.setenv("GOGDELY_ENV", "local")
    monkeypatch.setenv("GOGDELY_LOCAL_DEMO", "1")
    db_path = tmp_path / "existing.sqlite3"
    monkeypatch.setenv("GOGDELY_LOCAL_DB", str(db_path))
    with sqlite3.connect(db_path) as db:
        db.execute("""CREATE TABLE demo_orders (
            id INTEGER PRIMARY KEY AUTOINCREMENT, request_key TEXT NOT NULL UNIQUE,
            tenant_id TEXT NOT NULL DEFAULT 'local-demo', store_id TEXT NOT NULL,
            store_name TEXT NOT NULL, address_label TEXT NOT NULL, items_json TEXT NOT NULL,
            subtotal_cents INTEGER NOT NULL, delivery_fee_cents INTEGER NOT NULL,
            total_cents INTEGER NOT NULL, status TEXT NOT NULL,
            created_at TEXT NOT NULL, updated_at TEXT NOT NULL)""")
        db.execute("""INSERT INTO demo_orders
            (request_key,store_id,store_name,address_label,items_json,subtotal_cents,
             delivery_fee_cents,total_cents,status,created_at,updated_at)
            VALUES (?,'burger-house','Burger House','Rua Antiga','[]',100,599,699,
                    'created','2026-10-12T10:00:00+00:00','2026-10-12T10:00:00+00:00')""",
            (str(uuid4()),))
        db.execute("""CREATE TABLE demo_menu_items (
            store_id TEXT NOT NULL, product_id TEXT NOT NULL, name TEXT NOT NULL,
            description TEXT NOT NULL, category TEXT NOT NULL, price_cents INTEGER NOT NULL,
            image_ref TEXT NOT NULL DEFAULT '', available INTEGER NOT NULL DEFAULT 1,
            promo_percent INTEGER NOT NULL DEFAULT 0, sort_order INTEGER NOT NULL DEFAULT 0,
            updated_at TEXT NOT NULL, PRIMARY KEY (store_id, product_id))""")
        db.execute("""INSERT INTO demo_menu_items
            (store_id,product_id,name,description,category,price_cents,updated_at)
            VALUES ('burger-house','x-tudo','X-Tudo','Pedido já cadastrado',
                    'Hambúrgueres',2890,'2026-10-12T10:00:00+00:00')""")

    client = TestClient(app)
    base = "/api/v1/local"
    menu = client.get(f"{base}/mesa/burger-house/M03")
    assert menu.status_code == 200
    legacy_order = client.get(f"{base}/orders?store_id=burger-house").json()[0]
    assert re.fullmatch(r"\d{6}", legacy_order["delivery_code"])
    assert "Mesa M03" in menu.text and "X-Tudo" in menu.text
    assert "Mussarela extra" in menu.text
    qr = client.get(f"{base}/tables/burger-house/M03/qr.svg")
    assert qr.status_code == 200 and "image/svg+xml" in qr.headers["content-type"]
    assert b"<svg" in qr.content
    print_page = client.get(f"{base}/tables/burger-house/M03/print")
    assert print_page.status_code == 200 and "Imprimir ficha da mesa" in print_page.text

    created = client.post(f"{base}/mesa/burger-house/M03/pedidos",
        data={"request_key": str(uuid4()), "qty_x-tudo": "2",
              "extra_x-tudo": "Mussarela extra"},
        follow_redirects=False)
    assert created.status_code == 303
    receipt = client.get(created.headers["location"])
    assert receipt.status_code == 200 and "Mesa M03" in receipt.text
    assert "Pedido #" in receipt.text
    orders = client.get(f"{base}/orders?store_id=burger-house").json()
    assert len(orders) == 2
    assert orders[1]["address_label"] == "Rua Antiga"
    assert orders[1]["dispatch_mode"] == "internal"
    assert orders[1]["payment_method"] == "unselected"
    order = orders[0]
    assert order["table_code"] == "M03"
    assert order["order_channel"] == "table"
    assert order["delivery_fee_cents"] == 0
    assert order["total_cents"] == 6380
    assert order["items"][0]["extras"] == ["Mussarela extra"]
    assert order["created_at"]

    status_url = f"{base}/orders/{order['id']}/status"
    for status in ("preparing", "ready", "served"):
        assert client.patch(status_url, json={"status": status, "actor": "management"}).status_code == 200
    assert client.patch(status_url, json={"status": "in_delivery", "actor": "courier"}).status_code == 409
    assert "Servido" in client.get(created.headers["location"]).text
    assert client.get(f"{base}/mesa/burger-house/M00").status_code == 404
