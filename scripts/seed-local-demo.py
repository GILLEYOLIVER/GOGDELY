"""Populate the opt-in SQLite laboratory with idempotent fictional orders.

Run with services/api/.venv/Scripts/python.exe scripts/seed-local-demo.py.
Existing orders and catalog edits are preserved. A SQLite backup is made first.
"""

from __future__ import annotations

import os
from pathlib import Path
import sqlite3
import sys
from datetime import datetime, timezone
from uuid import NAMESPACE_URL, uuid5

from fastapi.testclient import TestClient


ROOT = Path(__file__).resolve().parents[1]
API_DIR = ROOT / "services" / "api"
sys.path.insert(0, str(API_DIR))
os.environ["GOGDELY_ENV"] = "local"
os.environ["GOGDELY_LOCAL_DEMO"] = "1"
os.environ.setdefault("GOGDELY_LOCAL_DB", str(API_DIR / ".local" / "gogdely.sqlite3"))

from gogdely_api.main import app  # noqa: E402


def backup_database(path: Path) -> Path | None:
    if not path.exists():
        return None
    folder = path.parent / "backups"
    folder.mkdir(parents=True, exist_ok=True)
    backup = folder / f"gogdely-before-multistore-{datetime.now(timezone.utc):%Y%m%d-%H%M%S}.sqlite3"
    with sqlite3.connect(path) as source, sqlite3.connect(backup) as target:
        source.backup(target)
    return backup


def main() -> None:
    database = Path(os.environ["GOGDELY_LOCAL_DB"]).resolve()
    backup = backup_database(database)
    if backup:
        print(f"Backup local: {backup}")
    targets = {
        "burger-house": "created",
        "pizzaria-napoli": "preparing",
        "sushi-express": "ready",
        "acai-central": "ready",
        "cantina-brasil": "delivered",
        "padaria-aurora": "created",
        "mercado-mais": "created",
        "hortifruti-viva": "preparing",
        "farmacia-saude": "created",
        "pet-amigo": "ready",
    }
    created_count = 0
    with TestClient(app) as client:
        response = client.get("/api/v1/local/catalog")
        response.raise_for_status()
        for store in response.json():
            orderable = [item for item in store["products"] if item["orderable"]]
            if not orderable:
                print(f"Sem produto disponível: {store['name']}")
                continue
            request_key = str(uuid5(NAMESPACE_URL,
                f"gogdely-local-sample-v1:{store['id']}"))
            payload = {
                "request_key": request_key,
                "store_id": store["id"],
                "address_label": "Rua Exemplo do Laboratório, 10",
                "payment_method": "cash",
                "items": [{"product_id": orderable[0]["product_id"],
                           "quantity": 1, "size": "Tradicional", "extras": []}],
            }
            result = client.post("/api/v1/local/orders", json=payload)
            if result.status_code != 201:
                print(f"Pedido de {store['name']}: HTTP {result.status_code}; mantido sem alteração")
                continue
            order = result.json()
            # Only advance a newly created example. Re-running never changes
            # a sample order that a human has already touched.
            if order["status"] != "created" or any(
                event["to_status"] != "created" for event in client.get(
                    f"/api/v1/local/orders/{order['id']}/events").json()):
                continue
            created_count += 1
            target = targets[store["id"]]
            status_url = f"/api/v1/local/orders/{order['id']}/status"
            for status in ("preparing", "ready"):
                if target == "created":
                    break
                transition = client.patch(status_url, json={
                    "status": status, "actor": "management"})
                transition.raise_for_status()
                if target == status:
                    break
            if target in {"ready", "delivered"}:
                client.post(f"/api/v1/local/orders/{order['id']}/dispatch-internal").raise_for_status()
            if target == "delivered":
                client.patch(status_url, json={
                    "status": "in_delivery", "actor": "courier"}).raise_for_status()
                client.patch(status_url, json={
                    "status": "delivered", "actor": "courier",
                    "delivery_code": order["delivery_code"]}).raise_for_status()
            print(f"{store['name']}: pedido fictício #{order['id']} ({target})")
    print(f"Carga concluída: {created_count} amostras novas; banco {database}")


if __name__ == "__main__":
    main()
