"""Isolated SQLite order flow for local cross-app demonstrations only.

This is deliberately separate from the planned PostgreSQL/Supabase production
architecture. It has no authentication, payment, GPS, or production credentials.
Routes are disabled unless GOGDELY_LOCAL_DEMO=1.
"""

import json
import os
import sqlite3
import secrets
import re
import base64
import hashlib
import binascii
from html import escape
from io import BytesIO
from contextlib import contextmanager
from datetime import datetime, timedelta, timezone
from pathlib import Path
from urllib.parse import parse_qs
from uuid import UUID
from uuid import uuid4
from typing import Literal

import qrcode
import qrcode.image.svg
from fastapi import APIRouter, HTTPException, Request
from fastapi.responses import FileResponse, HTMLResponse, RedirectResponse, Response
from pydantic import BaseModel, Field
from gogdely_api.local_catalog import STORES

router = APIRouter(prefix="/api/v1/local", tags=["local-demo"])

CATALOG = {store_id: (store["name"], {
    item["product_id"]: (item["name"], item["price_cents"])
    for item in store["products"]}) for store_id, store in STORES.items()}
EXTRAS = {"Borda recheada", "Mussarela extra", "Manjericão extra"}
DEFAULT_BURGER_ADDONS = [
    {"name": "Borda recheada", "price_cents": 300},
    {"name": "Mussarela extra", "price_cents": 300},
    {"name": "Manjericão extra", "price_cents": 300},
]
DEFAULT_PAYMENT_METHODS = ["cash", "pix", "card"]
NEXT_STATUS = {
    "created": ("preparing", "management"),
    "preparing": ("ready", "management"),
    "ready": ("in_delivery", "courier"),
    "in_delivery": ("delivered", "courier"),
}


def _enabled() -> None:
    if os.getenv("GOGDELY_LOCAL_DEMO") != "1" or os.getenv("GOGDELY_ENV", "local") != "local":
        raise HTTPException(status_code=404, detail="Local demo disabled")


def _db_path() -> Path:
    return Path(os.getenv("GOGDELY_LOCAL_DB", str(Path(__file__).resolve().parents[1] / ".local" / "gogdely.sqlite3"))).resolve()


def _connect() -> sqlite3.Connection:
    path = _db_path()
    path.parent.mkdir(parents=True, exist_ok=True)
    connection = sqlite3.connect(path, timeout=10)
    connection.row_factory = sqlite3.Row
    connection.execute("PRAGMA busy_timeout = 10000")
    connection.execute("PRAGMA journal_mode = WAL")
    connection.execute("""CREATE TABLE IF NOT EXISTS demo_orders (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        request_key TEXT NOT NULL UNIQUE,
        tenant_id TEXT NOT NULL DEFAULT 'local-demo',
        store_id TEXT NOT NULL,
        store_name TEXT NOT NULL,
        address_label TEXT NOT NULL,
        items_json TEXT NOT NULL,
        subtotal_cents INTEGER NOT NULL,
        delivery_fee_cents INTEGER NOT NULL,
        total_cents INTEGER NOT NULL,
        status TEXT NOT NULL,
        kitchen_priority TEXT NOT NULL DEFAULT 'normal',
        payment_method TEXT NOT NULL DEFAULT 'unselected',
        pickup_code TEXT,
        delivery_code TEXT,
        dispatch_mode TEXT NOT NULL DEFAULT 'internal',
        stock_reserved_json TEXT NOT NULL DEFAULT '{}',
        ingredient_reserved_json TEXT NOT NULL DEFAULT '{}',
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL
    )""")
    columns = {row["name"] for row in connection.execute("PRAGMA table_info(demo_orders)")}
    if "kitchen_priority" not in columns:
        connection.execute("ALTER TABLE demo_orders ADD COLUMN kitchen_priority TEXT NOT NULL DEFAULT 'normal'")
    if "table_code" not in columns:
        connection.execute("ALTER TABLE demo_orders ADD COLUMN table_code TEXT")
    if "order_channel" not in columns:
        connection.execute("ALTER TABLE demo_orders ADD COLUMN order_channel TEXT NOT NULL DEFAULT 'delivery'")
    if "payment_method" not in columns:
        connection.execute("ALTER TABLE demo_orders ADD COLUMN payment_method TEXT NOT NULL DEFAULT 'unselected'")
    if "pickup_code" not in columns:
        connection.execute("ALTER TABLE demo_orders ADD COLUMN pickup_code TEXT")
    if "delivery_code" not in columns:
        connection.execute("ALTER TABLE demo_orders ADD COLUMN delivery_code TEXT")
    if "dispatch_mode" not in columns:
        connection.execute("ALTER TABLE demo_orders ADD COLUMN dispatch_mode TEXT NOT NULL DEFAULT 'internal'")
    if "stock_reserved_json" not in columns:
        connection.execute("ALTER TABLE demo_orders ADD COLUMN stock_reserved_json TEXT NOT NULL DEFAULT '{}'")
    if "ingredient_reserved_json" not in columns:
        connection.execute("ALTER TABLE demo_orders ADD COLUMN ingredient_reserved_json TEXT NOT NULL DEFAULT '{}'")
    if "payment_state" not in columns:
        connection.execute(
            "ALTER TABLE demo_orders ADD COLUMN payment_state TEXT NOT NULL DEFAULT 'not_processed'")
    if "scheduled_for" not in columns:
        connection.execute("ALTER TABLE demo_orders ADD COLUMN scheduled_for TEXT")
    connection.execute("""CREATE TABLE IF NOT EXISTS demo_order_payments (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        order_id INTEGER NOT NULL REFERENCES demo_orders(id),
        request_key TEXT NOT NULL UNIQUE,
        method TEXT NOT NULL,
        amount_cents INTEGER NOT NULL CHECK(amount_cents >= 0),
        settlement TEXT NOT NULL DEFAULT 'simulated_local',
        actor TEXT NOT NULL,
        reason TEXT NOT NULL,
        created_at TEXT NOT NULL
    )""")
    connection.execute("CREATE INDEX IF NOT EXISTS demo_order_payments_order_idx ON demo_order_payments(order_id, id)")
    connection.execute("""CREATE TABLE IF NOT EXISTS demo_order_ratings (
        order_id INTEGER PRIMARY KEY REFERENCES demo_orders(id),
        store_id TEXT NOT NULL,
        stars INTEGER NOT NULL CHECK(stars BETWEEN 1 AND 5),
        comment TEXT NOT NULL DEFAULT '',
        actor TEXT NOT NULL,
        created_at TEXT NOT NULL
    )""")
    connection.execute("CREATE INDEX IF NOT EXISTS demo_order_ratings_store_idx ON demo_order_ratings(store_id, order_id)")
    for old_pickup in connection.execute(
            "SELECT id FROM demo_orders WHERE order_channel='pickup' AND pickup_code IS NULL AND status!='picked_up'"):
        connection.execute("UPDATE demo_orders SET pickup_code=? WHERE id=? AND pickup_code IS NULL",
                           (f"{secrets.randbelow(1_000_000):06d}", old_pickup["id"]))
    for old_delivery in connection.execute(
            "SELECT id FROM demo_orders WHERE order_channel='delivery' AND delivery_code IS NULL AND status!='delivered'"):
        connection.execute("UPDATE demo_orders SET delivery_code=? WHERE id=? AND delivery_code IS NULL",
                           (f"{secrets.randbelow(1_000_000):06d}", old_delivery["id"]))
    connection.execute("""CREATE TABLE IF NOT EXISTS demo_order_events (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        order_id INTEGER NOT NULL,
        from_status TEXT,
        to_status TEXT NOT NULL,
        actor TEXT NOT NULL,
        reason TEXT NOT NULL DEFAULT '',
        created_at TEXT NOT NULL,
        FOREIGN KEY (order_id) REFERENCES demo_orders(id)
    )""")
    connection.execute("CREATE INDEX IF NOT EXISTS demo_order_events_order_idx ON demo_order_events(order_id, id)")
    connection.execute("""CREATE TABLE IF NOT EXISTS demo_store_payment_settings (
        store_id TEXT PRIMARY KEY,
        methods_json TEXT NOT NULL,
        updated_at TEXT NOT NULL
    )""")
    connection.execute("""CREATE TABLE IF NOT EXISTS demo_menu_items (
        store_id TEXT NOT NULL,
        product_id TEXT NOT NULL,
        name TEXT NOT NULL,
        description TEXT NOT NULL,
        category TEXT NOT NULL,
        price_cents INTEGER NOT NULL,
        image_ref TEXT NOT NULL DEFAULT '',
        addons_json TEXT NOT NULL DEFAULT '[]',
        recipe_json TEXT NOT NULL DEFAULT '[]',
        available INTEGER NOT NULL DEFAULT 1,
        stock_quantity INTEGER CHECK(stock_quantity IS NULL OR stock_quantity >= 0),
        promo_percent INTEGER NOT NULL DEFAULT 0,
        sort_order INTEGER NOT NULL DEFAULT 0,
        updated_at TEXT NOT NULL,
        PRIMARY KEY (store_id, product_id)
    )""")
    connection.execute("""CREATE TABLE IF NOT EXISTS demo_menu_events (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        store_id TEXT NOT NULL,
        product_id TEXT NOT NULL,
        product_name TEXT NOT NULL,
        action TEXT NOT NULL,
        changes_json TEXT NOT NULL,
        actor TEXT NOT NULL,
        created_at TEXT NOT NULL
    )""")
    connection.execute("CREATE INDEX IF NOT EXISTS demo_menu_events_store_idx ON demo_menu_events(store_id, id)")
    connection.execute("""CREATE TABLE IF NOT EXISTS demo_stock_movements (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        store_id TEXT NOT NULL,
        item_kind TEXT NOT NULL,
        item_id TEXT NOT NULL,
        item_name TEXT NOT NULL,
        unit TEXT NOT NULL,
        movement_type TEXT NOT NULL,
        quantity_delta INTEGER NOT NULL,
        balance_before INTEGER,
        balance_after INTEGER NOT NULL,
        reason TEXT NOT NULL,
        order_id INTEGER,
        actor TEXT NOT NULL,
        created_at TEXT NOT NULL
    )""")
    connection.execute("CREATE INDEX IF NOT EXISTS demo_stock_movements_store_idx ON demo_stock_movements(store_id, id)")
    connection.execute("""CREATE TABLE IF NOT EXISTS demo_pos_sessions (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        store_id TEXT NOT NULL,
        open_request_key TEXT NOT NULL UNIQUE,
        close_request_key TEXT UNIQUE,
        status TEXT NOT NULL CHECK(status IN ('open', 'closed')),
        opening_cents INTEGER NOT NULL CHECK(opening_cents >= 0),
        counted_cents INTEGER CHECK(counted_cents >= 0),
        opening_reason TEXT NOT NULL,
        closing_reason TEXT,
        opened_at TEXT NOT NULL,
        closed_at TEXT
    )""")
    connection.execute("""CREATE UNIQUE INDEX IF NOT EXISTS demo_pos_one_open_idx
        ON demo_pos_sessions(store_id) WHERE status='open'""")
    connection.execute("""CREATE TABLE IF NOT EXISTS demo_pos_cash_movements (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        session_id INTEGER NOT NULL REFERENCES demo_pos_sessions(id),
        request_key TEXT NOT NULL UNIQUE,
        movement_type TEXT NOT NULL CHECK(movement_type IN ('supply', 'withdrawal')),
        amount_cents INTEGER NOT NULL CHECK(amount_cents > 0),
        reason TEXT NOT NULL,
        actor TEXT NOT NULL,
        created_at TEXT NOT NULL
    )""")
    connection.execute("CREATE INDEX IF NOT EXISTS demo_pos_cash_session_idx ON demo_pos_cash_movements(session_id, id)")
    connection.execute("""CREATE TABLE IF NOT EXISTS demo_ingredients (
        store_id TEXT NOT NULL,
        ingredient_id TEXT NOT NULL,
        name TEXT NOT NULL,
        unit TEXT NOT NULL CHECK(unit IN ('un', 'g', 'ml')),
        stock_quantity INTEGER NOT NULL CHECK(stock_quantity >= 0),
        updated_at TEXT NOT NULL,
        PRIMARY KEY (store_id, ingredient_id)
    )""")
    menu_columns = {row["name"] for row in connection.execute("PRAGMA table_info(demo_menu_items)")}
    if "addons_json" not in menu_columns:
        connection.execute("ALTER TABLE demo_menu_items ADD COLUMN addons_json TEXT NOT NULL DEFAULT '[]'")
        connection.execute("""UPDATE demo_menu_items SET addons_json=?
            WHERE store_id='burger-house' AND product_id='x-tudo'""",
            (json.dumps(DEFAULT_BURGER_ADDONS, ensure_ascii=False),))
    if "stock_quantity" not in menu_columns:
        connection.execute("ALTER TABLE demo_menu_items ADD COLUMN stock_quantity INTEGER CHECK(stock_quantity IS NULL OR stock_quantity >= 0)")
    if "recipe_json" not in menu_columns:
        connection.execute("ALTER TABLE demo_menu_items ADD COLUMN recipe_json TEXT NOT NULL DEFAULT '[]'")
    for store_id, store in STORES.items():
        for sort_order, item in enumerate(store["products"]):
            connection.execute("""INSERT OR IGNORE INTO demo_menu_items
                (store_id, product_id, name, description, category, price_cents,
                 image_ref, addons_json, promo_percent, sort_order, updated_at)
                VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)""",
                (store_id, item["product_id"], item["name"], item["description"],
                 item["category"], item["price_cents"], item["image_ref"],
                 json.dumps(DEFAULT_BURGER_ADDONS if store_id == "burger-house"
                            and item["product_id"] == "x-tudo" else [], ensure_ascii=False),
                 item["promo_percent"], sort_order,
                 datetime.now(timezone.utc).isoformat()))
    connection.commit()
    return connection


@contextmanager
def _db():
    connection = _connect()
    try:
        with connection:
            yield connection
    finally:
        connection.close()


def _order(row: sqlite3.Row) -> dict:
    result = dict(row)
    result["items"] = json.loads(result.pop("items_json"))
    result.pop("stock_reserved_json", None)
    result.pop("ingredient_reserved_json", None)
    result["payment_status"] = result.pop("payment_state")
    result["payment_settlement"] = ("simulated_local"
                                    if result["payment_status"] == "simulated" else "none")
    return result


def _same_order_request(row: sqlite3.Row, payload: "OrderInput", table_code: str | None,
                        order_channel: str, payment_method: str, address_label: str) -> bool:
    if (row["store_id"] != payload.store_id or row["address_label"] != address_label or
            row["table_code"] != table_code or row["order_channel"] != order_channel or
            row["payment_method"] != payment_method or row["scheduled_for"] != payload.scheduled_for):
        return False
    saved_items = json.loads(row["items_json"])
    return len(saved_items) == len(payload.items) and all(
        saved["product_id"] == requested.product_id and
        saved["quantity"] == requested.quantity and
        saved["size"] == requested.size and
        saved["extras"] == requested.extras
        for saved, requested in zip(saved_items, payload.items))


def _table_code(value: str) -> str:
    if not re.fullmatch(r"M(0[1-9]|[1-9][0-9])", value):
        raise HTTPException(status_code=404, detail="Mesa local não encontrada")
    return value


def _html_page(title: str, body: str, *, refresh: bool = False,
               description: str | None = None,
               canonical_path: str | None = None,
               indexable: bool = False,
               jsonld: str = "",
               extra_head: str = "") -> HTMLResponse:
    """SEO-ready HTML shell for the local pilot pages.

    GOG-020/026: pages stay `noindex` in the laboratory (operational data,
    no public domain). When GOGDELY_PUBLIC_BASE_URL is configured and the page
    is explicitly `indexable`, the template emits canonical, Open Graph and
    JSON-LD tags so the same code works on the future public deployment.
    """
    from gogdely_api.config import config
    refresh_tag = '<meta http-equiv="refresh" content="5">' if refresh else ""
    robots = "index, follow" if (indexable and config.public_web) else "noindex, nofollow"
    desc = escape(description or f"{title} no GOGDELY.")
    seo_tags = f'<meta name="description" content="{desc}">'
    seo_tags += f'<meta name="robots" content="{robots}">'
    seo_tags += '<meta name="theme-color" content="#2563EB">'
    if config.public_web and canonical_path:
        canonical_url = f"{config.public_base_url}{canonical_path}"
        seo_tags += f'<link rel="canonical" href="{escape(canonical_url, quote=True)}">'
        seo_tags += (
            f'<meta property="og:title" content="{escape(title, quote=True)}">'
            f'<meta property="og:description" content="{desc}">'
            '<meta property="og:type" content="website">'
            f'<meta property="og:url" content="{escape(canonical_url, quote=True)}">'
            f'<meta property="og:image" content="{config.public_base_url}/og-image.png">'
            '<meta property="og:locale" content="pt_BR">'
            '<meta name="twitter:card" content="summary_large_image">')
    if jsonld and config.public_web:
        seo_tags += (f'<script type="application/ld+json">{jsonld}</script>')
    return HTMLResponse(f"""<!doctype html><html lang="pt-BR"><head>
    <meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1">
    {refresh_tag}<title>{escape(title)} · GOGDELY</title>
    {seo_tags}{extra_head}
    <style>
    :root{{font-family:system-ui,sans-serif;color:#1e293b;background:#f2f5ff}}
    body{{max-width:640px;margin:0 auto;padding:20px 14px 48px}}
    header{{background:#151b2b;color:white;border-radius:20px;padding:20px;margin-bottom:16px}}
    h1{{margin:0 0 5px;font-size:27px}} h2{{font-size:18px}} p{{line-height:1.4}}
    .blue{{color:#60a5fa}} .card{{background:white;border:1px solid #dce4f2;border-radius:16px;padding:16px;margin:10px 0}}
    .row{{display:flex;align-items:center;gap:12px;justify-content:space-between}}
    .row div{{flex:1}} img{{width:78px;height:78px;object-fit:cover;border-radius:12px}}
    input[type=number]{{width:65px;padding:10px;border:1px solid #dce4f2;border-radius:10px;font-size:16px}}
    button{{background:#2563eb;color:white;border:0;border-radius:12px;padding:15px 22px;font-size:16px;font-weight:700;cursor:pointer}}
    small{{color:#64748b}} a{{color:#1d4ed8}}
    </style></head><body>{body}</body></html>""")


def _money(cents: int) -> str:
    return f"R$ {cents // 100},{cents % 100:02d}"


class ItemInput(BaseModel):
    product_id: str
    quantity: int = Field(ge=1, le=50)
    size: str = "Tradicional"
    extras: list[str] = Field(default_factory=list, max_length=10)


class OrderInput(BaseModel):
    request_key: UUID
    store_id: str
    address_label: str = Field(min_length=3, max_length=160)
    items: list[ItemInput] = Field(min_length=1, max_length=30)
    order_channel: Literal["delivery", "pickup", "counter"] = "delivery"
    payment_method: Literal["unselected", "cash", "pix", "card"] = "cash"
    # GOG-024: ISO 8601 future slot for scheduled orders.
    scheduled_for: str | None = None


class PosSaleInput(BaseModel):
    request_key: UUID
    items: list[ItemInput] = Field(min_length=1, max_length=30)
    payment_method: Literal["cash", "pix", "card"]


class PosOpenInput(BaseModel):
    request_key: UUID
    opening_cents: int = Field(ge=0, le=10000000)
    reason: str = Field(min_length=3, max_length=300)


class PosCashMovementInput(BaseModel):
    request_key: UUID
    movement_type: Literal["supply", "withdrawal"]
    amount_cents: int = Field(ge=1, le=10000000)
    reason: str = Field(min_length=3, max_length=300)


class PosCloseInput(BaseModel):
    request_key: UUID
    counted_cents: int = Field(ge=0, le=10000000)
    reason: str = Field(min_length=3, max_length=300)


class PaymentMethodsInput(BaseModel):
    methods: list[Literal["cash", "pix", "card"]] = Field(min_length=1, max_length=3)


class MenuOrderInput(BaseModel):
    product_ids: list[str] = Field(min_length=1, max_length=200)


class StatusInput(BaseModel):
    status: str
    actor: str
    pickup_code: str | None = Field(default=None, pattern=r"^\d{6}$")
    delivery_code: str | None = Field(default=None, pattern=r"^\d{6}$")
    # GOG-046: optional delivery proof note recorded with the courier event.
    proof_note: str = Field(default="", max_length=300)


class CancelInput(BaseModel):
    actor: Literal["customer", "management"]
    reason: str = Field(min_length=3, max_length=300)


class KitchenPriorityInput(BaseModel):
    priority: Literal["normal", "urgent"]
    reason: str = Field(min_length=3, max_length=300)


class PaymentSimulationInput(BaseModel):
    request_key: UUID
    reason: str = Field(min_length=3, max_length=300)


class RatingInput(BaseModel):
    stars: int = Field(ge=1, le=5)
    comment: str = Field(default="", max_length=500)


class AddonInput(BaseModel):
    name: str = Field(min_length=2, max_length=60)
    price_cents: int = Field(ge=0, le=100000)


class RecipePartInput(BaseModel):
    ingredient_id: str = Field(pattern=r"^[a-z0-9][a-z0-9-]{1,47}$")
    quantity: int = Field(ge=1, le=1000000)


class IngredientInput(BaseModel):
    ingredient_id: str = Field(pattern=r"^[a-z0-9][a-z0-9-]{1,47}$")
    name: str = Field(min_length=2, max_length=100)
    unit: Literal["un", "g", "ml"]
    stock_quantity: int = Field(ge=0, le=100000000)
    expected_updated_at: str | None = None


class StockAdjustmentInput(BaseModel):
    item_kind: Literal["product", "ingredient"]
    item_id: str = Field(pattern=r"^[a-z0-9][a-z0-9-]{1,47}$")
    movement_type: Literal["restock", "loss", "count"]
    quantity: int = Field(ge=0, le=100000000)
    reason: str = Field(min_length=3, max_length=300)


class MenuItemInput(BaseModel):
    product_id: str = Field(pattern=r"^[a-z0-9][a-z0-9-]{1,47}$")
    name: str = Field(min_length=2, max_length=100)
    description: str = Field(max_length=500)
    category: str = Field(min_length=2, max_length=60)
    price_cents: int = Field(ge=1, le=10000000)
    image_ref: str = Field(default="", max_length=500)
    available: bool = True
    stock_quantity: int | None = Field(default=None, ge=0, le=1000000)
    expected_updated_at: str | None = None
    promo_percent: int = Field(default=0, ge=0, le=90)
    addons: list[AddonInput] = Field(default_factory=list, max_length=20)
    recipe: list[RecipePartInput] = Field(default_factory=list, max_length=20)


class ImageUploadInput(BaseModel):
    data_base64: str = Field(max_length=7500000)
    mime_type: str


def _validate_addons(addons: list[AddonInput]) -> None:
    names = [addon.name.strip().casefold() for addon in addons]
    if any(len(name) < 2 for name in names) or len(names) != len(set(names)):
        raise HTTPException(status_code=422, detail="Additional item names must be unique")


def _validate_recipe(db: sqlite3.Connection, recipe: list[RecipePartInput]) -> None:
    ids = [part.ingredient_id for part in recipe]
    if len(ids) != len(set(ids)):
        raise HTTPException(status_code=422, detail="Ingredient appears twice in the recipe")
    available = {row["ingredient_id"] for row in db.execute(
        "SELECT ingredient_id FROM demo_ingredients WHERE store_id='burger-house'")}
    if any(ingredient_id not in available for ingredient_id in ids):
        raise HTTPException(status_code=422, detail="Recipe ingredient not found")


def _menu_item(row: sqlite3.Row) -> dict:
    item = dict(row)
    item["addons"] = json.loads(item.pop("addons_json"))
    item["recipe"] = json.loads(item.pop("recipe_json"))
    item["available"] = bool(item["available"])
    item["effective_price_cents"] = item["price_cents"] * (100 - item["promo_percent"]) // 100
    return item


def _orderable(item: dict, ingredient_stocks: dict[str, int]) -> bool:
    return (item["available"] and item["stock_quantity"] != 0 and
            all(ingredient_stocks.get(part["ingredient_id"], 0) >= part["quantity"]
                for part in item["recipe"]))


def _ingredient_stocks(db: sqlite3.Connection) -> dict[str, int]:
    return {row["ingredient_id"]: row["stock_quantity"] for row in db.execute(
        "SELECT ingredient_id, stock_quantity FROM demo_ingredients WHERE store_id='burger-house'")}


def _log_menu_event(db: sqlite3.Connection, action: str, before: dict | None,
                    after: dict, created_at: str, actor: str = "management_local",
                    store_id: str = "burger-house") -> None:
    tracked = ("name", "description", "category", "price_cents", "image_ref",
               "addons", "recipe", "available", "stock_quantity", "promo_percent", "sort_order")
    changes = {
        key: {"before": before.get(key) if before else None, "after": after[key]}
        for key in tracked if before is None or before.get(key) != after[key]
    }
    if changes:
        db.execute("""INSERT INTO demo_menu_events
            (store_id, product_id, product_name, action, changes_json, actor, created_at)
            VALUES (?, ?, ?, ?, ?, ?, ?)""",
            (store_id, after["product_id"], after["name"], action,
             json.dumps(changes, ensure_ascii=False), actor, created_at))


def _log_stock_movement(db: sqlite3.Connection, kind: str, item_id: str,
                        name: str, unit: str, movement_type: str,
                        before: int | None, after: int, reason: str,
                        actor: str, now: str, order_id: int | None = None,
                        store_id: str = "burger-house") -> None:
    db.execute("""INSERT INTO demo_stock_movements
        (store_id, item_kind, item_id, item_name, unit, movement_type,
         quantity_delta, balance_before, balance_after, reason, order_id, actor, created_at)
        VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)""",
        (store_id, kind, item_id, name, unit, movement_type,
         after - (before or 0), before, after, reason, order_id, actor, now))


@router.get("/stores/burger-house/stock-movements")
def list_stock_movements() -> list[dict]:
    _enabled()
    with _db() as db:
        return [dict(row) for row in db.execute("""SELECT * FROM demo_stock_movements
            WHERE store_id='burger-house' ORDER BY id DESC LIMIT 100""")]


@router.post("/stores/burger-house/stock-adjustments", status_code=201)
def adjust_stock(payload: StockAdjustmentInput) -> dict:
    _enabled()
    reason = payload.reason.strip()
    if len(reason) < 3 or (payload.movement_type != "count" and payload.quantity == 0):
        raise HTTPException(status_code=422, detail="Informe motivo e quantidade positiva")
    table, key, limit = (("demo_menu_items", "product_id", 1000000)
                         if payload.item_kind == "product" else
                         ("demo_ingredients", "ingredient_id", 100000000))
    with _db() as db:
        db.execute("BEGIN IMMEDIATE")
        row = db.execute(f"SELECT * FROM {table} WHERE store_id='burger-house' AND {key}=?",
                         (payload.item_id,)).fetchone()
        if row is None:
            raise HTTPException(status_code=404, detail="Stock item not found")
        before = row["stock_quantity"]
        if before is None and payload.movement_type != "count":
            raise HTTPException(status_code=409, detail="Define a counted balance first")
        after = (payload.quantity if payload.movement_type == "count" else
                 before + (payload.quantity if payload.movement_type == "restock" else -payload.quantity))
        if after < 0 or after > limit:
            raise HTTPException(status_code=409, detail="Stock balance outside allowed range")
        now = datetime.now(timezone.utc).isoformat()
        db.execute(f"UPDATE {table} SET stock_quantity=?, updated_at=? WHERE store_id='burger-house' AND {key}=?",
                   (after, now, payload.item_id))
        if payload.item_kind == "product":
            old = _menu_item(row)
            _log_menu_event(db, "stock_adjusted", old,
                            dict(old, stock_quantity=after), now)
        _log_stock_movement(db, payload.item_kind, payload.item_id, row["name"],
                            "un" if payload.item_kind == "product" else row["unit"],
                            payload.movement_type, before, after, reason,
                            "management_local", now)
        return dict(db.execute("SELECT * FROM demo_stock_movements WHERE id=last_insert_rowid()").fetchone())


@router.get("/stores/burger-house/menu-events")
def list_menu_events() -> list[dict]:
    _enabled()
    with _db() as db:
        events = []
        for row in db.execute("""SELECT * FROM demo_menu_events
            WHERE store_id='burger-house' ORDER BY id DESC LIMIT 50"""):
            event = dict(row)
            event["changes"] = json.loads(event.pop("changes_json"))
            events.append(event)
        return events


@router.get("/stores/burger-house/ingredients")
def list_ingredients() -> list[dict]:
    _enabled()
    with _db() as db:
        return [dict(row) for row in db.execute("""SELECT * FROM demo_ingredients
            WHERE store_id='burger-house' ORDER BY name, ingredient_id""")]


@router.post("/stores/burger-house/ingredients", status_code=201)
def create_ingredient(payload: IngredientInput) -> dict:
    _enabled()
    if len(payload.name.strip()) < 2:
        raise HTTPException(status_code=422, detail="Ingredient name is required")
    with _db() as db:
        if db.execute("SELECT 1 FROM demo_ingredients WHERE store_id='burger-house' AND ingredient_id=?",
                      (payload.ingredient_id,)).fetchone():
            raise HTTPException(status_code=409, detail="Ingredient ID already exists")
        now = datetime.now(timezone.utc).isoformat()
        db.execute("""INSERT INTO demo_ingredients
            (store_id, ingredient_id, name, unit, stock_quantity, updated_at)
            VALUES ('burger-house', ?, ?, ?, ?, ?)""",
            (payload.ingredient_id, payload.name.strip(), payload.unit,
             payload.stock_quantity, now))
        _log_stock_movement(db, "ingredient", payload.ingredient_id, payload.name.strip(),
                            payload.unit, "initial", 0, payload.stock_quantity,
                            "Saldo inicial do cadastro", "management_local", now)
        return dict(db.execute("""SELECT * FROM demo_ingredients
            WHERE store_id='burger-house' AND ingredient_id=?""",
            (payload.ingredient_id,)).fetchone())


@router.put("/stores/burger-house/ingredients/{ingredient_id}")
def update_ingredient(ingredient_id: str, payload: IngredientInput) -> dict:
    _enabled()
    if len(payload.name.strip()) < 2:
        raise HTTPException(status_code=422, detail="Ingredient name is required")
    if ingredient_id != payload.ingredient_id:
        raise HTTPException(status_code=422, detail="Ingredient ID cannot be changed")
    with _db() as db:
        db.execute("BEGIN IMMEDIATE")
        previous = db.execute("""SELECT * FROM demo_ingredients
            WHERE store_id='burger-house' AND ingredient_id=?""", (ingredient_id,)).fetchone()
        if previous is None:
            raise HTTPException(status_code=404, detail="Ingredient not found")
        if previous["unit"] != payload.unit:
            raise HTTPException(status_code=422, detail="Ingredient unit cannot be changed")
        if payload.expected_updated_at is not None and previous["updated_at"] != payload.expected_updated_at:
            raise HTTPException(status_code=409, detail="Ingredient changed; refresh before editing")
        now = datetime.now(timezone.utc).isoformat()
        db.execute("""UPDATE demo_ingredients SET name=?, stock_quantity=?, updated_at=?
            WHERE store_id='burger-house' AND ingredient_id=?""",
            (payload.name.strip(), payload.stock_quantity, now, ingredient_id))
        if previous["stock_quantity"] != payload.stock_quantity:
            _log_stock_movement(db, "ingredient", ingredient_id, payload.name.strip(),
                                payload.unit, "manual_edit", previous["stock_quantity"],
                                payload.stock_quantity, "Edição do cadastro local", "management_local", now)
        return dict(db.execute("""SELECT * FROM demo_ingredients
            WHERE store_id='burger-house' AND ingredient_id=?""", (ingredient_id,)).fetchone())


def _payment_methods(db: sqlite3.Connection, store_id: str = "burger-house") -> list[str]:
    row = db.execute("SELECT methods_json FROM demo_store_payment_settings WHERE store_id=?",
                     (store_id,)).fetchone()
    return json.loads(row["methods_json"]) if row else DEFAULT_PAYMENT_METHODS.copy()


@router.get("/stores/burger-house/payment-methods")
def get_payment_methods() -> dict:
    _enabled()
    with _db() as db:
        return {"methods": _payment_methods(db)}


@router.put("/stores/burger-house/payment-methods")
def save_payment_methods(payload: PaymentMethodsInput) -> dict:
    _enabled()
    if len(payload.methods) != len(set(payload.methods)):
        raise HTTPException(status_code=422, detail="Payment methods must be unique")
    with _db() as db:
        db.execute("""INSERT INTO demo_store_payment_settings (store_id, methods_json, updated_at)
            VALUES ('burger-house', ?, ?)
            ON CONFLICT(store_id) DO UPDATE SET methods_json=excluded.methods_json, updated_at=excluded.updated_at""",
            (json.dumps(payload.methods), datetime.now(timezone.utc).isoformat()))
    return {"methods": payload.methods}


def _validate_image(image_ref: str) -> None:
    uploaded = re.fullmatch(r"/api/v1/local/uploads/[0-9a-f]{64}\.(png|jpg|webp)", image_ref)
    bundled = {store["image"] for store in STORES.values()} | {
        item["image_ref"] for store in STORES.values() for item in store["products"]}
    if image_ref and not uploaded and image_ref not in bundled and not re.fullmatch(r"https://[^\s]+", image_ref):
        raise HTTPException(status_code=422, detail="Use an HTTPS image URL or a bundled demo image")


@router.get("/stores/burger-house/menu")
def list_menu() -> list[dict]:
    _enabled()
    with _db() as db:
        stocks = _ingredient_stocks(db)
        items = [_menu_item(row) for row in db.execute(
            "SELECT * FROM demo_menu_items WHERE store_id='burger-house' ORDER BY sort_order, product_id").fetchall()]
        for item in items:
            item["orderable"] = _orderable(item, stocks)
        return items


@router.get("/stores")
def list_demo_stores() -> list[dict]:
    _enabled()
    with _db() as db:
        counts = {row["store_id"]: row["count"] for row in db.execute(
            "SELECT store_id, COUNT(*) AS count FROM demo_menu_items WHERE available=1 GROUP BY store_id")}
    return [dict(id=store_id, name=store["name"], category=store["category"],
                 description=store["description"], eta=store["eta"],
                 image=store["image"], latitude=store["latitude"],
                 longitude=store["longitude"], product_count=counts.get(store_id, 0))
            for store_id, store in STORES.items()]


@router.get("/catalog")
def local_catalog() -> list[dict]:
    """One local read for the customer storefront; each menu stays store-scoped."""
    _enabled()
    with _db() as db:
        stocks = _ingredient_stocks(db)
        result = []
        for store_id, store in STORES.items():
            products = [_menu_item(row) for row in db.execute(
                "SELECT * FROM demo_menu_items WHERE store_id=? ORDER BY sort_order, product_id",
                (store_id,))]
            for item in products:
                item["orderable"] = _orderable(item, stocks if store_id == "burger-house" else {})
            result.append(dict(id=store_id, name=store["name"], category=store["category"],
                               description=store["description"], eta=store["eta"],
                               image=store["image"], latitude=store["latitude"],
                               longitude=store["longitude"], products=products))
        return result


@router.get("/stores/{store_id}/menu")
def list_store_menu(store_id: str) -> list[dict]:
    _enabled()
    if store_id not in STORES:
        raise HTTPException(status_code=404, detail="Demo store not found")
    with _db() as db:
        stocks = _ingredient_stocks(db) if store_id == "burger-house" else {}
        items = [_menu_item(row) for row in db.execute(
            "SELECT * FROM demo_menu_items WHERE store_id=? ORDER BY sort_order, product_id",
            (store_id,))]
        for item in items:
            item["orderable"] = _orderable(item, stocks)
        return items


@router.get("/stores/{store_id}/menu-events")
def list_store_menu_events(store_id: str) -> list[dict]:
    _enabled()
    if store_id not in STORES:
        raise HTTPException(status_code=404, detail="Demo store not found")
    with _db() as db:
        events = []
        for row in db.execute("""SELECT * FROM demo_menu_events
            WHERE store_id=? ORDER BY id DESC LIMIT 50""", (store_id,)):
            event = dict(row)
            event["changes"] = json.loads(event.pop("changes_json"))
            events.append(event)
        return events


@router.get("/stores/{store_id}/payment-methods")
def get_store_payment_methods(store_id: str) -> dict:
    _enabled()
    if store_id not in STORES:
        raise HTTPException(status_code=404, detail="Demo store not found")
    with _db() as db:
        return {"methods": _payment_methods(db, store_id)}


@router.get("/stores/burger-house/promotions")
def list_promotions() -> list[dict]:
    """GOG-021: active Burger House discounts, effective price included."""
    _enabled()
    with _db() as db:
        stocks = _ingredient_stocks(db)
        items = [_menu_item(row) for row in db.execute(
            "SELECT * FROM demo_menu_items WHERE store_id='burger-house' ORDER BY sort_order, product_id").fetchall()]
        return [
            {"product_id": item["product_id"], "name": item["name"],
             "category": item["category"], "image_ref": item["image_ref"],
             "promo_percent": item["promo_percent"],
             "original_cents": item["price_cents"],
             "effective_cents": item["effective_price_cents"]}
            for item in items
            if item["promo_percent"] > 0 and item["available"] and _orderable(item, stocks)
        ]


@router.put("/stores/burger-house/menu-order")
def reorder_menu(payload: MenuOrderInput) -> list[dict]:
    _enabled()
    with _db() as db:
        db.execute("BEGIN IMMEDIATE")
        current = {row["product_id"] for row in db.execute(
            "SELECT product_id FROM demo_menu_items WHERE store_id='burger-house'")}
        if len(payload.product_ids) != len(current) or set(payload.product_ids) != current:
            raise HTTPException(status_code=422, detail="Provide every Burger House product exactly once")
        now = datetime.now(timezone.utc).isoformat()
        before = {row["product_id"]: _menu_item(row) for row in db.execute(
            "SELECT * FROM demo_menu_items WHERE store_id='burger-house'")}
        for position, product_id in enumerate(payload.product_ids):
            db.execute("UPDATE demo_menu_items SET sort_order=?, updated_at=? WHERE store_id='burger-house' AND product_id=?",
                       (position, now, product_id))
            if before[product_id]["sort_order"] != position:
                after = dict(before[product_id], sort_order=position)
                _log_menu_event(db, "reordered", before[product_id], after, now)
        return [_menu_item(row) for row in db.execute(
            "SELECT * FROM demo_menu_items WHERE store_id='burger-house' ORDER BY sort_order, product_id")]


@router.post("/stores/burger-house/menu", status_code=201)
def create_menu_item(payload: MenuItemInput) -> dict:
    _enabled()
    _validate_image(payload.image_ref)
    _validate_addons(payload.addons)
    with _db() as db:
        _validate_recipe(db, payload.recipe)
        if db.execute("SELECT 1 FROM demo_menu_items WHERE store_id='burger-house' AND product_id=?", (payload.product_id,)).fetchone():
            raise HTTPException(status_code=409, detail="Product ID already exists")
        sort_order = db.execute("SELECT COALESCE(MAX(sort_order), -1) + 1 FROM demo_menu_items WHERE store_id='burger-house'").fetchone()[0]
        db.execute("""INSERT INTO demo_menu_items
            (store_id, product_id, name, description, category, price_cents, image_ref, addons_json, recipe_json, available, stock_quantity, promo_percent, sort_order, updated_at)
            VALUES ('burger-house', ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)""",
            (payload.product_id, payload.name, payload.description, payload.category, payload.price_cents,
             payload.image_ref, json.dumps([addon.model_dump() for addon in payload.addons], ensure_ascii=False),
             json.dumps([part.model_dump() for part in payload.recipe], ensure_ascii=False),
             payload.available, payload.stock_quantity, payload.promo_percent, sort_order, datetime.now(timezone.utc).isoformat()))
        row = db.execute("SELECT * FROM demo_menu_items WHERE store_id='burger-house' AND product_id=?", (payload.product_id,)).fetchone()
        item = _menu_item(row)
        _log_menu_event(db, "created", None, item, item["updated_at"])
        if item["stock_quantity"] is not None:
            _log_stock_movement(db, "product", item["product_id"], item["name"], "un",
                                "initial", 0, item["stock_quantity"],
                                "Saldo inicial do cadastro", "management_local", item["updated_at"])
        return item


@router.put("/stores/burger-house/menu/{product_id}")
def update_menu_item(product_id: str, payload: MenuItemInput) -> dict:
    _enabled()
    if product_id != payload.product_id:
        raise HTTPException(status_code=422, detail="Product ID cannot be changed")
    _validate_image(payload.image_ref)
    _validate_addons(payload.addons)
    with _db() as db:
        db.execute("BEGIN IMMEDIATE")
        previous = db.execute("SELECT * FROM demo_menu_items WHERE store_id='burger-house' AND product_id=?", (product_id,)).fetchone()
        if previous is None:
            raise HTTPException(status_code=404, detail="Demo product not found")
        if payload.expected_updated_at is not None and previous["updated_at"] != payload.expected_updated_at:
            raise HTTPException(status_code=409, detail="Product changed; refresh before editing")
        stock_quantity = (payload.stock_quantity if "stock_quantity" in payload.model_fields_set
                          else previous["stock_quantity"])
        recipe = (payload.recipe if "recipe" in payload.model_fields_set
                  else [RecipePartInput(**part) for part in json.loads(previous["recipe_json"])])
        _validate_recipe(db, recipe)
        cursor = db.execute("""UPDATE demo_menu_items SET name=?, description=?, category=?, price_cents=?,
            image_ref=?, addons_json=?, recipe_json=?, available=?, stock_quantity=?, promo_percent=?, updated_at=?
            WHERE store_id='burger-house' AND product_id=?""",
            (payload.name, payload.description, payload.category, payload.price_cents, payload.image_ref,
             json.dumps([addon.model_dump() for addon in payload.addons], ensure_ascii=False),
             json.dumps([part.model_dump() for part in recipe], ensure_ascii=False),
             payload.available, stock_quantity, payload.promo_percent, datetime.now(timezone.utc).isoformat(), product_id))
        if cursor.rowcount != 1:
            raise HTTPException(status_code=404, detail="Demo product not found")
        row = db.execute("SELECT * FROM demo_menu_items WHERE store_id='burger-house' AND product_id=?", (product_id,)).fetchone()
        item = _menu_item(row)
        _log_menu_event(db, "updated", _menu_item(previous), item, item["updated_at"])
        if previous["stock_quantity"] != item["stock_quantity"] and item["stock_quantity"] is not None:
            _log_stock_movement(db, "product", product_id, item["name"], "un",
                                "manual_edit", previous["stock_quantity"], item["stock_quantity"],
                                "Edição do cadastro local", "management_local", item["updated_at"])
        return item


@router.post("/stores/{store_id}/menu", status_code=201)
def create_other_store_menu_item(store_id: str, payload: MenuItemInput) -> dict:
    _enabled()
    if store_id not in STORES or store_id == "burger-house":
        raise HTTPException(status_code=404, detail="Demo store not found")
    if payload.recipe:
        raise HTTPException(status_code=422, detail="Recipe setup is only available in the Burger House pilot")
    _validate_image(payload.image_ref)
    _validate_addons(payload.addons)
    with _db() as db:
        db.execute("BEGIN IMMEDIATE")
        if db.execute("SELECT 1 FROM demo_menu_items WHERE store_id=? AND product_id=?",
                      (store_id, payload.product_id)).fetchone():
            raise HTTPException(status_code=409, detail="Product ID already exists")
        sort_order = db.execute("SELECT COALESCE(MAX(sort_order), -1) + 1 FROM demo_menu_items WHERE store_id=?",
                                (store_id,)).fetchone()[0]
        now = datetime.now(timezone.utc).isoformat()
        db.execute("""INSERT INTO demo_menu_items
            (store_id, product_id, name, description, category, price_cents,
             image_ref, addons_json, recipe_json, available, stock_quantity,
             promo_percent, sort_order, updated_at)
            VALUES (?, ?, ?, ?, ?, ?, ?, ?, '[]', ?, ?, ?, ?, ?)""",
            (store_id, payload.product_id, payload.name, payload.description,
             payload.category, payload.price_cents, payload.image_ref,
             json.dumps([addon.model_dump() for addon in payload.addons], ensure_ascii=False),
             payload.available, payload.stock_quantity, payload.promo_percent,
             sort_order, now))
        item = _menu_item(db.execute(
            "SELECT * FROM demo_menu_items WHERE store_id=? AND product_id=?",
            (store_id, payload.product_id)).fetchone())
        _log_menu_event(db, "created", None, item, now, store_id=store_id)
        return item


@router.put("/stores/{store_id}/menu/{product_id}")
def update_other_store_menu_item(store_id: str, product_id: str,
                                 payload: MenuItemInput) -> dict:
    _enabled()
    if store_id not in STORES or store_id == "burger-house":
        raise HTTPException(status_code=404, detail="Demo store not found")
    if product_id != payload.product_id:
        raise HTTPException(status_code=422, detail="Product ID cannot be changed")
    if payload.recipe:
        raise HTTPException(status_code=422, detail="Recipe setup is only available in the Burger House pilot")
    _validate_image(payload.image_ref)
    _validate_addons(payload.addons)
    with _db() as db:
        db.execute("BEGIN IMMEDIATE")
        previous = db.execute(
            "SELECT * FROM demo_menu_items WHERE store_id=? AND product_id=?",
            (store_id, product_id)).fetchone()
        if previous is None:
            raise HTTPException(status_code=404, detail="Demo product not found")
        if payload.expected_updated_at is not None and previous["updated_at"] != payload.expected_updated_at:
            raise HTTPException(status_code=409, detail="Product changed; refresh before editing")
        stock_quantity = (payload.stock_quantity if "stock_quantity" in payload.model_fields_set
                          else previous["stock_quantity"])
        now = datetime.now(timezone.utc).isoformat()
        db.execute("""UPDATE demo_menu_items SET name=?, description=?, category=?,
            price_cents=?, image_ref=?, addons_json=?, available=?,
            stock_quantity=?, promo_percent=?, updated_at=?
            WHERE store_id=? AND product_id=?""",
            (payload.name, payload.description, payload.category, payload.price_cents,
             payload.image_ref,
             json.dumps([addon.model_dump() for addon in payload.addons], ensure_ascii=False),
             payload.available, stock_quantity, payload.promo_percent,
             now, store_id, product_id))
        item = _menu_item(db.execute(
            "SELECT * FROM demo_menu_items WHERE store_id=? AND product_id=?",
            (store_id, product_id)).fetchone())
        _log_menu_event(db, "updated", _menu_item(previous), item, now, store_id=store_id)
        return item


@router.post("/uploads/images", status_code=201)
def upload_local_image(payload: ImageUploadInput) -> dict:
    _enabled()
    try:
        data = base64.b64decode(payload.data_base64, validate=True)
    except (ValueError, binascii.Error):
        raise HTTPException(status_code=422, detail="Imagem inválida") from None
    if not data or len(data) > 5_000_000:
        raise HTTPException(status_code=422, detail="Imagem deve ter no máximo 5 MB")
    formats = {
        "image/png": ("png", data.startswith(b"\x89PNG\r\n\x1a\n")),
        "image/jpeg": ("jpg", data.startswith(b"\xff\xd8\xff")),
        "image/webp": ("webp", data.startswith(b"RIFF") and data[8:12] == b"WEBP"),
    }
    selected = formats.get(payload.mime_type)
    if selected is None or not selected[1]:
        raise HTTPException(status_code=422, detail="Use PNG, JPEG ou WebP válido")
    digest = hashlib.sha256(data).hexdigest()
    filename = f"{digest}.{selected[0]}"
    directory = _db_path().parent / "uploads"
    directory.mkdir(parents=True, exist_ok=True)
    path = directory / filename
    if not path.exists():
        path.write_bytes(data)
    return {"image_ref": f"/api/v1/local/uploads/{filename}"}


@router.get("/uploads/{filename}")
def uploaded_local_image(filename: str) -> FileResponse:
    _enabled()
    match = re.fullmatch(r"[0-9a-f]{64}\.(png|jpg|webp)", filename)
    if not match:
        raise HTTPException(status_code=404, detail="Imagem não encontrada")
    path = _db_path().parent / "uploads" / filename
    if not path.is_file():
        raise HTTPException(status_code=404, detail="Imagem não encontrada")
    media_type = {"png": "image/png", "jpg": "image/jpeg", "webp": "image/webp"}[match.group(1)]
    return FileResponse(path, media_type=media_type)


@router.get("/images/{image_name}")
def local_menu_image(image_name: str) -> FileResponse:
    _enabled()
    bundled = {Path(store["image"]).name for store in STORES.values()} | {
        Path(item["image_ref"]).name for store in STORES.values()
        for item in store["products"] if item["image_ref"]}
    if image_name not in bundled:
        raise HTTPException(status_code=404, detail="Imagem local não encontrada")
    path = Path(__file__).resolve().parents[3] / "apps" / "cliente" / "assets" / "images" / image_name
    if not path.is_file():
        raise HTTPException(status_code=404, detail="Imagem local não encontrada")
    return FileResponse(path)


@router.get("/tables/burger-house/{table_code}/qr.svg")
def table_qr(table_code: str, request: Request) -> Response:
    _enabled()
    _table_code(table_code)
    target = str(request.url_for("table_menu_slug", table_code=table_code))
    qr = qrcode.QRCode(border=3, box_size=8)
    qr.add_data(target)
    qr.make(fit=True)
    output = BytesIO()
    qr.make_image(image_factory=qrcode.image.svg.SvgPathImage).save(output)
    svg = output.getvalue().replace(
        b"<svg", f"<!-- GOGDELY QR target: {target} -->\n<svg".encode(), 1)
    return Response(svg, media_type="image/svg+xml",
                    headers={"Cache-Control": "no-store"})


@router.get("/tables/burger-house/{table_code}/print")
def printable_table_qr(table_code: str) -> HTMLResponse:
    _enabled()
    _table_code(table_code)
    menu_url = f"/m/burger-house/{table_code}"
    qr_url = f"/api/v1/local/tables/burger-house/{table_code}/qr.svg"
    body = (
        '<header><h1>gog<span class="blue">dely.</span></h1>'
        f'<strong>Burger House · Mesa {escape(table_code)}</strong></header>'
        '<div class="card" style="text-align:center">'
        '<h2>Escaneie para abrir o cardápio</h2>'
        f'<img src="{qr_url}" alt="QR da Mesa {escape(table_code)}" width="300" height="300"'
        ' style="width:min(100%,300px);height:auto">'
        f'<p><a href="{menu_url}">Abrir cardápio da Mesa {escape(table_code)}</a></p>'
        '<small>Prévia local: o QR aponta para o computador que executa a API.</small></div>'
        '<button onclick="window.print()">Imprimir ficha da mesa</button>'
    )
    return _html_page(f"QR Mesa {table_code}", body,
                       description=f"Ficha para imprimir o QR da Mesa {table_code} da Burger House.",
                       indexable=False)


@router.get("/mesa/burger-house/{table_code}", name="table_menu_page", include_in_schema=False)
def table_menu_page(table_code: str) -> HTMLResponse:
    return _table_menu_page(table_code)


@router.get("/m/burger-house/{table_code}", name="table_menu_slug")
def table_menu_slug(table_code: str) -> HTMLResponse:
    """Clean public slug for the table menu (SEO-friendly URL)."""
    return _table_menu_page(table_code)


def _table_menu_page(table_code: str) -> HTMLResponse:
    _enabled()
    _table_code(table_code)
    with _db() as db:
        stocks = _ingredient_stocks(db)
        items = [_menu_item(row) for row in db.execute(
            "SELECT * FROM demo_menu_items WHERE store_id='burger-house' ORDER BY sort_order, product_id")]
        items = [item for item in items if _orderable(item, stocks)]
    cards = []
    for item in items:
        image_ref = item["image_ref"]
        if image_ref.startswith("assets/images/"):
            image_ref = f"/api/v1/local/images/{image_ref.rsplit('/', 1)[-1]}"
        image = (f'<img src="{escape(image_ref, quote=True)}" alt="{escape(item["name"], quote=True)}"'
                 ' width="78" height="78" loading="lazy" decoding="async">') if image_ref else ""
        promo = f' · {item["promo_percent"]}% OFF' if item["promo_percent"] else ""
        addons = "".join(
            f'<label style="display:block"><input type="checkbox" name="extra_{escape(item["product_id"], quote=True)}"'
            f' value="{escape(addon["name"], quote=True)}"> {escape(addon["name"])}'
            f' (+{_money(addon["price_cents"])})</label>'
            for addon in item["addons"])
        cards.append(
            f'<div class="card row">{image}<div><strong>{escape(item["name"])}</strong>'
            f'<br><small>{escape(item["category"])}{promo}</small>'
            f'<p>{escape(item["description"])}</p>'
            f'<strong>{_money(item["effective_price_cents"])}</strong>{addons}</div>'
            f'<label>Qtd.<br><input type="number" name="qty_{escape(item["product_id"], quote=True)}"'
            ' min="0" max="50" value="0" inputmode="numeric"></label></div>'
        )
    body = (
        f'<header><h1>gog<span class="blue">dely.</span></h1>'
        f'<strong>Burger House · Mesa {escape(table_code)}</strong><br>'
        '<small>Cardápio local de demonstração · sem pagamento real</small></header>'
        '<h2>Escolha seus produtos</h2>'
        f'<form method="post" action="/api/v1/local/mesa/burger-house/{escape(table_code, quote=True)}/pedidos">'
        f'<input type="hidden" name="request_key" value="{uuid4()}">'
        + "".join(cards) +
        '<p><small>O pedido será enviado à fila da cozinha com o número da mesa e horário.</small></p>'
        '<button type="submit">Enviar pedido da mesa</button></form>'
    )
    menu_jsonld = json.dumps({
        "@context": "https://schema.org",
        "@type": "MenuSection",
        "name": f"Cardápio Burger House · Mesa {table_code}",
        "hasMenu": {
            "@type": "Menu",
            "name": "Cardápio Burger House",
            "hasMenuSection": [
                {"@type": "MenuSection", "name": item["category"],
                 "hasMenuItem": [{"@type": "MenuItem", "name": item["name"],
                                  "description": item["description"],
                                  "offers": {"@type": "Offer",
                                             "price": f"{item['effective_price_cents'] / 100:.2f}",
                                             "priceCurrency": "BRL"}}]}
                for item in items
            ],
        },
    }, ensure_ascii=False)
    return _html_page(f"Cardápio Burger House · Mesa {table_code}", body,
                      description=(f"Peça pelo celular na Burger House: cardápio da Mesa {table_code} "
                                   "com preços e envio direto para a cozinha. Laboratório local."),
                      canonical_path=f"/m/burger-house/{table_code}",
                      indexable=True,
                      jsonld=menu_jsonld)


@router.post("/mesa/burger-house/{table_code}/pedidos")
async def create_table_order(table_code: str, request: Request) -> RedirectResponse:
    _enabled()
    _table_code(table_code)
    raw = await request.body()
    if len(raw) > 16384:
        raise HTTPException(status_code=413, detail="Formulário muito grande")
    try:
        form = parse_qs(raw.decode("utf-8"), keep_blank_values=True, strict_parsing=True)
        request_key = UUID(form["request_key"][0])
    except (UnicodeDecodeError, ValueError, KeyError, IndexError):
        raise HTTPException(status_code=422, detail="Formulário inválido") from None
    with _db() as db:
        stocks = _ingredient_stocks(db)
        addon_by_id = {
            item["product_id"]: {addon["name"] for addon in item["addons"]}
            for item in (_menu_item(row) for row in db.execute(
                "SELECT * FROM demo_menu_items WHERE store_id='burger-house'"))
            if _orderable(item, stocks)
        }
    selected = []
    for product_id in sorted(addon_by_id):
        values = form.get(f"qty_{product_id}", ["0"])
        if len(values) != 1 or not re.fullmatch(r"\d{1,2}", values[0]):
            raise HTTPException(status_code=422, detail="Quantidade inválida")
        quantity = int(values[0])
        if quantity > 50:
            raise HTTPException(status_code=422, detail="Quantidade inválida")
        if quantity:
            extras = form.get(f"extra_{product_id}", [])
            if (len(extras) > 10 or len(set(extras)) != len(extras) or
                    any(extra not in addon_by_id[product_id] for extra in extras)):
                raise HTTPException(status_code=422, detail="Adicional inválido")
            selected.append(ItemInput(product_id=product_id, quantity=quantity, extras=extras))
    if not selected or len(selected) > 30:
        raise HTTPException(status_code=422, detail="Escolha de 1 a 30 produtos")
    order = _create_order(OrderInput(
        request_key=request_key, store_id="burger-house",
        address_label=f"Mesa {table_code}", items=selected), table_code=table_code)
    return RedirectResponse(
        url=f"/api/v1/local/mesa/burger-house/{table_code}/pedidos/{order['id']}",
        status_code=303)


@router.get("/mesa/burger-house/{table_code}/pedidos/{order_id}")
def table_order_receipt(table_code: str, order_id: int) -> HTMLResponse:
    _enabled()
    _table_code(table_code)
    with _db() as db:
        row = db.execute("""SELECT * FROM demo_orders
            WHERE id=? AND store_id='burger-house' AND table_code=? AND order_channel='table'""",
            (order_id, table_code)).fetchone()
    if row is None:
        raise HTTPException(status_code=404, detail="Pedido da mesa não encontrado")
    order = _order(row)
    created = datetime.fromisoformat(order["created_at"]).astimezone().strftime("%d/%m/%Y às %H:%M")
    labels = {"created": "Recebido", "preparing": "Em preparo", "ready": "Pronto",
              "served": "Servido", "cancelled": "Cancelado"}
    lines = "".join(
        f'<li>{item["quantity"]} × {escape(item["name"])}'
        f'{(" · " + escape(", ".join(item["extras"]))) if item["extras"] else ""}'
        f' · {_money(item["unit_cents"] * item["quantity"])}</li>'
        for item in order["items"])
    body = (
        '<header><h1>Pedido recebido</h1>'
        f'<strong>Burger House · Mesa {escape(table_code)}</strong></header>'
        f'<div class="card"><h2>Pedido #{order_id}</h2><p>{created}</p>'
        f'<p>Status: <strong>{escape(labels.get(order["status"], order["status"]))}</strong></p>'
        f'<ul>{lines}</ul><strong>Total estimado: {_money(order["total_cents"])}</strong>'
        '<p><small>Sem pagamento real. Esta página atualiza o status automaticamente.</small></p>'
        f'<p><a href="/m/burger-house/{escape(table_code, quote=True)}">Voltar ao cardápio da Mesa {escape(table_code)}</a></p></div>'
    )
    return _html_page(f"Pedido {order_id}", body, refresh=True,
                      description=f"Acompanhamento local do pedido #{order_id} da Mesa {table_code}.",
                      indexable=False)


@router.get("/health")
def local_health() -> dict:
    _enabled()
    with _db() as db:
        db.execute("SELECT 1").fetchone()
    return {"status": "ok", "storage": "sqlite-local-demo"}


@router.post("/orders", status_code=201)
def create_order(payload: OrderInput) -> dict:
    if payload.order_channel == "counter":
        raise HTTPException(status_code=422, detail="Counter orders use the local POS endpoint")
    return _create_order(payload)


def _pos_session(db: sqlite3.Connection, row: sqlite3.Row) -> dict:
    movements = [dict(movement) for movement in db.execute("""SELECT id, movement_type,
        amount_cents, reason, actor, created_at FROM demo_pos_cash_movements
        WHERE session_id=? ORDER BY id""", (row["id"],))]
    expected = row["opening_cents"] + sum(
        movement["amount_cents"] if movement["movement_type"] == "supply"
        else -movement["amount_cents"] for movement in movements)
    result = dict(row)
    result.pop("open_request_key", None)
    result.pop("close_request_key", None)
    result["expected_cash_cents"] = expected
    result["difference_cents"] = (row["counted_cents"] - expected
                                   if row["counted_cents"] is not None else None)
    result["movements"] = movements
    return result


@router.get("/stores/burger-house/pos-register")
def get_pos_register() -> dict:
    _enabled()
    with _db() as db:
        active = db.execute("""SELECT * FROM demo_pos_sessions
            WHERE store_id='burger-house' AND status='open'""").fetchone()
        recent = db.execute("""SELECT * FROM demo_pos_sessions
            WHERE store_id='burger-house' AND status='closed'
            ORDER BY id DESC LIMIT 5""").fetchall()
        return {"active": _pos_session(db, active) if active else None,
                "recent": [_pos_session(db, row) for row in recent]}


@router.post("/stores/burger-house/pos-register/open", status_code=201)
def open_pos_register(payload: PosOpenInput) -> dict:
    _enabled()
    reason = payload.reason.strip()
    if len(reason) < 3:
        raise HTTPException(status_code=422, detail="Opening reason required")
    with _db() as db:
        db.execute("BEGIN IMMEDIATE")
        key = str(payload.request_key)
        existing = db.execute("SELECT * FROM demo_pos_sessions WHERE open_request_key=?", (key,)).fetchone()
        if existing:
            if existing["opening_cents"] != payload.opening_cents or existing["opening_reason"] != reason:
                raise HTTPException(status_code=409, detail="Opening key reused with different data")
            return _pos_session(db, existing)
        if db.execute("""SELECT 1 FROM demo_pos_sessions
            WHERE store_id='burger-house' AND status='open'""").fetchone():
            raise HTTPException(status_code=409, detail="Register already open")
        now = datetime.now(timezone.utc).isoformat()
        cursor = db.execute("""INSERT INTO demo_pos_sessions
            (store_id, open_request_key, status, opening_cents, opening_reason, opened_at)
            VALUES ('burger-house', ?, 'open', ?, ?, ?)""",
            (key, payload.opening_cents, reason, now))
        return _pos_session(db, db.execute("SELECT * FROM demo_pos_sessions WHERE id=?",
                                           (cursor.lastrowid,)).fetchone())


@router.post("/stores/burger-house/pos-register/movements", status_code=201)
def add_pos_cash_movement(payload: PosCashMovementInput) -> dict:
    _enabled()
    reason = payload.reason.strip()
    if len(reason) < 3:
        raise HTTPException(status_code=422, detail="Movement reason required")
    with _db() as db:
        db.execute("BEGIN IMMEDIATE")
        key = str(payload.request_key)
        existing = db.execute("SELECT * FROM demo_pos_cash_movements WHERE request_key=?", (key,)).fetchone()
        if existing:
            if (existing["movement_type"] != payload.movement_type or
                    existing["amount_cents"] != payload.amount_cents or
                    existing["reason"] != reason):
                raise HTTPException(status_code=409, detail="Movement key reused with different data")
            session = db.execute("SELECT * FROM demo_pos_sessions WHERE id=?",
                                 (existing["session_id"],)).fetchone()
            return {"movement": dict(existing), "session": _pos_session(db, session)}
        session = db.execute("""SELECT * FROM demo_pos_sessions
            WHERE store_id='burger-house' AND status='open'""").fetchone()
        if session is None:
            raise HTTPException(status_code=409, detail="Open the register first")
        current = _pos_session(db, session)["expected_cash_cents"]
        if payload.movement_type == "withdrawal" and payload.amount_cents > current:
            raise HTTPException(status_code=409, detail="Withdrawal exceeds declared cash")
        now = datetime.now(timezone.utc).isoformat()
        cursor = db.execute("""INSERT INTO demo_pos_cash_movements
            (session_id, request_key, movement_type, amount_cents, reason, actor, created_at)
            VALUES (?, ?, ?, ?, ?, 'management_local', ?)""",
            (session["id"], key, payload.movement_type, payload.amount_cents, reason, now))
        movement = dict(db.execute("SELECT * FROM demo_pos_cash_movements WHERE id=?",
                                   (cursor.lastrowid,)).fetchone())
        return {"movement": movement, "session": _pos_session(db, session)}


@router.post("/stores/burger-house/pos-register/close")
def close_pos_register(payload: PosCloseInput) -> dict:
    _enabled()
    reason = payload.reason.strip()
    if len(reason) < 3:
        raise HTTPException(status_code=422, detail="Closing reason required")
    with _db() as db:
        db.execute("BEGIN IMMEDIATE")
        key = str(payload.request_key)
        existing = db.execute("SELECT * FROM demo_pos_sessions WHERE close_request_key=?",
                              (key,)).fetchone()
        if existing:
            if existing["counted_cents"] != payload.counted_cents or existing["closing_reason"] != reason:
                raise HTTPException(status_code=409, detail="Closing key reused with different data")
            return _pos_session(db, existing)
        session = db.execute("""SELECT * FROM demo_pos_sessions
            WHERE store_id='burger-house' AND status='open'""").fetchone()
        if session is None:
            raise HTTPException(status_code=409, detail="No open register")
        now = datetime.now(timezone.utc).isoformat()
        db.execute("""UPDATE demo_pos_sessions SET status='closed', close_request_key=?,
            counted_cents=?, closing_reason=?, closed_at=? WHERE id=? AND status='open'""",
            (key, payload.counted_cents, reason, now, session["id"]))
        closed = db.execute("SELECT * FROM demo_pos_sessions WHERE id=?", (session["id"],)).fetchone()
        return _pos_session(db, closed)


@router.post("/stores/burger-house/pos-sales", status_code=201)
def create_pos_sale(payload: PosSaleInput) -> dict:
    return _create_order(OrderInput(
        request_key=payload.request_key, store_id="burger-house",
        address_label="Balcão Burger House", items=payload.items,
        order_channel="counter", payment_method=payload.payment_method))


def _create_order(payload: OrderInput, table_code: str | None = None) -> dict:
    _enabled()
    store = CATALOG.get(payload.store_id)
    if store is None:
        raise HTTPException(status_code=422, detail="Unknown demo store")
    store_name, products = store
    order_channel = "table" if table_code else payload.order_channel
    payment_method = "unselected" if table_code else payload.payment_method
    address_label = (f"Retirada na {store_name}" if order_channel == "pickup" else
                     f"Balcão {store_name}" if order_channel == "counter" else payload.address_label)
    request_key = str(payload.request_key)
    scheduled_for: str | None = None
    if payload.scheduled_for is not None:
        if order_channel in {"table", "counter"}:
            raise HTTPException(status_code=422,
                                detail="Only delivery and pickup orders can be scheduled")
        try:
            slot = datetime.fromisoformat(payload.scheduled_for)
        except ValueError:
            raise HTTPException(status_code=422, detail="Scheduled slot must be ISO 8601") from None
        now_check = datetime.now(timezone.utc)
        if slot.tzinfo is None:
            slot = slot.replace(tzinfo=timezone.utc)
        if slot < now_check + timedelta(minutes=30):
            raise HTTPException(status_code=422,
                                detail="Scheduled slot must be at least 30 minutes ahead")
        if slot > now_check + timedelta(days=14):
            raise HTTPException(status_code=422, detail="Scheduled slot must be within 14 days")
        scheduled_for = slot.isoformat()
    with _db() as db:
        existing = db.execute("SELECT * FROM demo_orders WHERE request_key=?", (request_key,)).fetchone()
        if existing:
            if not _same_order_request(existing, payload, table_code, order_channel, payment_method, address_label):
                raise HTTPException(status_code=409, detail="Idempotency key reused with different order")
            return _order(existing)
    with _db() as db:
        products = {
            row["product_id"]: (
                row["name"],
                row["price_cents"] * (100 - row["promo_percent"]) // 100,
                {addon["name"]: addon["price_cents"] for addon in json.loads(row["addons_json"])},
            )
            for row in db.execute(
                "SELECT * FROM demo_menu_items WHERE store_id=? AND available=1",
                (payload.store_id,))
        }
    resolved = []
    subtotal = 0
    for item in payload.items:
        product = products.get(item.product_id)
        if product is None or item.size not in {"Tradicional", "Média", "Grande"} or len(set(item.extras)) != len(item.extras):
            raise HTTPException(status_code=422, detail="Invalid demo product or option")
        name, base_cents, addon_prices = product
        if any(extra not in addon_prices for extra in item.extras):
            raise HTTPException(status_code=422, detail="Invalid demo additional item")
        extras_cents = sum(addon_prices[extra] for extra in item.extras)
        unit_cents = base_cents + {"Tradicional": 0, "Média": 400, "Grande": 800}[item.size] + extras_cents
        subtotal += unit_cents * item.quantity
        resolved.append({"product_id": item.product_id, "name": name, "quantity": item.quantity, "size": item.size, "extras": item.extras, "unit_cents": unit_cents})
    delivery_fee = 599 if order_channel == "delivery" else 0
    now = datetime.now(timezone.utc).isoformat()
    reserved: dict[str, int] = {}
    ingredient_reserved: dict[str, int] = {}
    pending_movements: list[tuple[str, str, str, str, int, int]] = []
    with _db() as db:
        db.execute("BEGIN IMMEDIATE")
        existing = db.execute("SELECT * FROM demo_orders WHERE request_key=?", (request_key,)).fetchone()
        if existing:
            if not _same_order_request(existing, payload, table_code, order_channel, payment_method, address_label):
                raise HTTPException(status_code=409, detail="Idempotency key reused with different order")
            return _order(existing)
        if order_channel != "table" and payment_method not in _payment_methods(db, payload.store_id):
            raise HTTPException(status_code=422, detail="Payment method unavailable for this store")
        if payload.store_id == "burger-house":
            quantities: dict[str, int] = {}
            for item in payload.items:
                quantities[item.product_id] = quantities.get(item.product_id, 0) + item.quantity
            current_items: dict[str, dict] = {}
            for product_id, quantity in quantities.items():
                before_row = db.execute("SELECT * FROM demo_menu_items WHERE store_id='burger-house' AND product_id=?", (product_id,)).fetchone()
                if before_row is None or not before_row["available"]:
                    raise HTTPException(status_code=409, detail="Product unavailable; refresh the menu")
                before = _menu_item(before_row)
                current_items[product_id] = before
                if before["stock_quantity"] is None:
                    continue
                if before["stock_quantity"] < quantity:
                    raise HTTPException(status_code=409, detail=f"Insufficient stock for {before['name']}")
                db.execute("""UPDATE demo_menu_items SET stock_quantity=stock_quantity-?, updated_at=?
                    WHERE store_id='burger-house' AND product_id=?""", (quantity, now, product_id))
                after = dict(before, stock_quantity=before["stock_quantity"] - quantity)
                _log_menu_event(db, "stock_deducted", before, after, now, actor="order_local")
                reserved[product_id] = quantity
                pending_movements.append(("product", product_id, before["name"], "un",
                                          before["stock_quantity"], after["stock_quantity"]))
            for requested, line in zip(payload.items, resolved):
                current = current_items[requested.product_id]
                addon_prices = {addon["name"]: addon["price_cents"] for addon in current["addons"]}
                if any(extra not in addon_prices for extra in requested.extras):
                    raise HTTPException(status_code=409, detail="Menu changed; refresh before ordering")
                current_unit = (current["effective_price_cents"] +
                                {"Tradicional": 0, "Média": 400, "Grande": 800}[requested.size] +
                                sum(addon_prices[extra] for extra in requested.extras))
                if line["name"] != current["name"] or line["unit_cents"] != current_unit:
                    raise HTTPException(status_code=409, detail="Menu changed; refresh before ordering")
                for part in current["recipe"]:
                    ingredient_id = part["ingredient_id"]
                    ingredient_reserved[ingredient_id] = (
                        ingredient_reserved.get(ingredient_id, 0) +
                        part["quantity"] * requested.quantity)
            for ingredient_id, quantity in ingredient_reserved.items():
                ingredient = db.execute("""SELECT * FROM demo_ingredients
                    WHERE store_id='burger-house' AND ingredient_id=?""", (ingredient_id,)).fetchone()
                if ingredient is None or ingredient["stock_quantity"] < quantity:
                    label = ingredient["name"] if ingredient else ingredient_id
                    raise HTTPException(status_code=409, detail=f"Insufficient ingredient stock: {label}")
                db.execute("""UPDATE demo_ingredients SET stock_quantity=stock_quantity-?, updated_at=?
                    WHERE store_id='burger-house' AND ingredient_id=?""", (quantity, now, ingredient_id))
                pending_movements.append(("ingredient", ingredient_id, ingredient["name"],
                                          ingredient["unit"], ingredient["stock_quantity"],
                                          ingredient["stock_quantity"] - quantity))
        if payload.store_id != "burger-house":
            quantities: dict[str, int] = {}
            for requested in payload.items:
                quantities[requested.product_id] = quantities.get(requested.product_id, 0) + requested.quantity
            for product_id, quantity in quantities.items():
                before_row = db.execute("""SELECT * FROM demo_menu_items
                    WHERE store_id=? AND product_id=? AND available=1""",
                    (payload.store_id, product_id)).fetchone()
                if before_row is None:
                    raise HTTPException(status_code=409, detail="Product unavailable; refresh the menu")
                if before_row["stock_quantity"] is not None:
                    if before_row["stock_quantity"] < quantity:
                        raise HTTPException(status_code=409, detail="Insufficient product stock")
                    db.execute("""UPDATE demo_menu_items SET stock_quantity=stock_quantity-?, updated_at=?
                        WHERE store_id=? AND product_id=?""",
                        (quantity, now, payload.store_id, product_id))
                    before = _menu_item(before_row)
                    after = dict(before, stock_quantity=before["stock_quantity"] - quantity)
                    _log_menu_event(db, "stock_deducted", before, after, now,
                                    actor="order_local", store_id=payload.store_id)
                    reserved[product_id] = quantity
                    pending_movements.append(("product", product_id, before["name"], "un",
                                              before["stock_quantity"], after["stock_quantity"]))
            for requested, line in zip(payload.items, resolved):
                current_row = db.execute("""SELECT * FROM demo_menu_items
                    WHERE store_id=? AND product_id=? AND available=1""",
                    (payload.store_id, requested.product_id)).fetchone()
                if current_row is None:
                    raise HTTPException(status_code=409, detail="Product unavailable; refresh the menu")
                current = _menu_item(current_row)
                addon_prices = {addon["name"]: addon["price_cents"] for addon in current["addons"]}
                current_unit = (current["effective_price_cents"] +
                                {"Tradicional": 0, "Média": 400, "Grande": 800}[requested.size] +
                                sum(addon_prices.get(extra, -1000000) for extra in requested.extras))
                if line["name"] != current["name"] or line["unit_cents"] != current_unit:
                    raise HTTPException(status_code=409, detail="Menu changed; refresh before ordering")
        cursor = db.execute("""INSERT INTO demo_orders
            (request_key, store_id, store_name, address_label, items_json, subtotal_cents, delivery_fee_cents, total_cents, status, created_at, updated_at, table_code, order_channel, payment_method, pickup_code, delivery_code, dispatch_mode, stock_reserved_json, ingredient_reserved_json, scheduled_for)
            VALUES (?, ?, ?, ?, ?, ?, ?, ?, 'created', ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)""",
            (request_key, payload.store_id, store_name, address_label, json.dumps(resolved, ensure_ascii=False), subtotal, delivery_fee, subtotal + delivery_fee, now, now, table_code, order_channel, payment_method,
             f"{secrets.randbelow(1_000_000):06d}" if order_channel == "pickup" else None,
             f"{secrets.randbelow(1_000_000):06d}" if order_channel == "delivery" else None,
             "pending" if order_channel == "delivery" else "none", json.dumps(reserved),
             json.dumps(ingredient_reserved), scheduled_for))
        for kind, item_id, name, unit, before, after in pending_movements:
            _log_stock_movement(db, kind, item_id, name, unit, "order_deduction",
                                before, after, f"Pedido #{cursor.lastrowid}",
                                "order_local", now, cursor.lastrowid,
                                store_id=payload.store_id)
        db.execute("""INSERT INTO demo_order_events
            (order_id, from_status, to_status, actor, reason, created_at)
            VALUES (?, NULL, 'created', ?, ?, ?)""",
            (cursor.lastrowid, "table_guest" if table_code else
             "management_pos" if order_channel == "counter" else "customer",
             f"Pedido agendado para {scheduled_for}" if scheduled_for else "", now))
        return _order(db.execute("SELECT * FROM demo_orders WHERE id=?", (cursor.lastrowid,)).fetchone())


@router.get("/orders")
def list_orders(store_id: str | None = None, status: str | None = None) -> list[dict]:
    _enabled()
    query = "SELECT * FROM demo_orders WHERE tenant_id='local-demo'"
    params: list[str] = []
    if store_id:
        query += " AND store_id=?"
        params.append(store_id)
    if status:
        query += " AND status=?"
        params.append(status)
    query += " ORDER BY id DESC LIMIT 100"
    with _db() as db:
        return [_order(row) for row in db.execute(query, params).fetchall()]


@router.get("/orders/{order_id}")
def get_order(order_id: int) -> dict:
    _enabled()
    with _db() as db:
        row = db.execute("SELECT * FROM demo_orders WHERE id=? AND tenant_id='local-demo'", (order_id,)).fetchone()
        if row is None:
            raise HTTPException(status_code=404, detail="Demo order not found")
        return _order(row)


@router.get("/orders/{order_id}/events")
def order_events(order_id: int) -> list[dict]:
    _enabled()
    with _db() as db:
        row = db.execute("SELECT id FROM demo_orders WHERE id=? AND tenant_id='local-demo'", (order_id,)).fetchone()
        if row is None:
            raise HTTPException(status_code=404, detail="Demo order not found")
        return [dict(event) for event in db.execute(
            "SELECT id, order_id, from_status, to_status, actor, reason, created_at FROM demo_order_events WHERE order_id=? ORDER BY id",
            (order_id,))]


@router.put("/orders/{order_id}/kitchen-priority")
def set_kitchen_priority(order_id: int, payload: KitchenPriorityInput) -> dict:
    """Prioritize one Burger House order in the local kitchen queue only."""
    _enabled()
    reason = payload.reason.strip()
    if len(reason) < 3:
        raise HTTPException(status_code=422, detail="Priority reason required")
    with _db() as db:
        db.execute("BEGIN IMMEDIATE")
        row = db.execute("""SELECT * FROM demo_orders WHERE id=?
            AND tenant_id='local-demo' AND store_id='burger-house'""", (order_id,)).fetchone()
        if row is None:
            raise HTTPException(status_code=404, detail="Burger House order not found")
        if row["status"] not in ("created", "preparing"):
            raise HTTPException(status_code=409, detail="Only pending kitchen orders can change priority")
        if row["kitchen_priority"] == payload.priority:
            return _order(row)
        now = datetime.now(timezone.utc).isoformat()
        db.execute("""UPDATE demo_orders SET kitchen_priority=?, updated_at=?
            WHERE id=?""", (payload.priority, now, order_id))
        label = "Prioridade urgente" if payload.priority == "urgent" else "Prioridade normal"
        db.execute("""INSERT INTO demo_order_events
            (order_id, from_status, to_status, actor, reason, created_at)
            VALUES (?, ?, ?, 'management_kds', ?, ?)""",
            (order_id, row["status"], row["status"], f"{label} · motivo: {reason}", now))
        updated = db.execute("SELECT * FROM demo_orders WHERE id=?", (order_id,)).fetchone()
        return _order(updated)


@router.post("/orders/{order_id}/cancel")
def cancel_order(order_id: int, payload: CancelInput) -> dict:
    _enabled()
    reason = payload.reason.strip()
    if len(reason) < 3:
        raise HTTPException(status_code=422, detail="Cancellation reason required")
    with _db() as db:
        db.execute("BEGIN IMMEDIATE")
        row = db.execute("SELECT * FROM demo_orders WHERE id=? AND tenant_id='local-demo'", (order_id,)).fetchone()
        if row is None:
            raise HTTPException(status_code=404, detail="Demo order not found")
        allowed = row["status"] == "created" or (payload.actor == "management" and row["status"] == "preparing")
        if not allowed:
            raise HTTPException(status_code=409, detail="Order can no longer be cancelled by this actor")
        now = datetime.now(timezone.utc).isoformat()
        cursor = db.execute("UPDATE demo_orders SET status='cancelled', updated_at=? WHERE id=? AND status=?",
                            (now, order_id, row["status"]))
        if cursor.rowcount != 1:
            raise HTTPException(status_code=409, detail="Order changed; refresh")
        for product_id, quantity in json.loads(row["stock_reserved_json"]).items():
            before_row = db.execute("SELECT * FROM demo_menu_items WHERE store_id=? AND product_id=?",
                                    (row["store_id"], product_id)).fetchone()
            if before_row is None or before_row["stock_quantity"] is None:
                continue
            before = _menu_item(before_row)
            db.execute("""UPDATE demo_menu_items SET stock_quantity=stock_quantity+?, updated_at=?
                WHERE store_id=? AND product_id=?""", (quantity, now, row["store_id"], product_id))
            after = dict(before, stock_quantity=before["stock_quantity"] + quantity)
            _log_menu_event(db, "stock_restored", before, after, now,
                            actor="cancellation_local", store_id=row["store_id"])
            _log_stock_movement(db, "product", product_id, before["name"], "un",
                                "cancellation_restore", before["stock_quantity"],
                                after["stock_quantity"], reason, "cancellation_local", now, order_id,
                                store_id=row["store_id"])
        if row["store_id"] == "burger-house":
            for ingredient_id, quantity in json.loads(row["ingredient_reserved_json"]).items():
                ingredient = db.execute("""SELECT * FROM demo_ingredients
                    WHERE store_id='burger-house' AND ingredient_id=?""", (ingredient_id,)).fetchone()
                if ingredient is None:
                    continue
                db.execute("""UPDATE demo_ingredients SET stock_quantity=stock_quantity+?, updated_at=?
                    WHERE store_id='burger-house' AND ingredient_id=?""", (quantity, now, ingredient_id))
                _log_stock_movement(db, "ingredient", ingredient_id, ingredient["name"],
                                    ingredient["unit"], "cancellation_restore",
                                    ingredient["stock_quantity"], ingredient["stock_quantity"] + quantity,
                                    reason, "cancellation_local", now, order_id)
        db.execute("""INSERT INTO demo_order_events
            (order_id, from_status, to_status, actor, reason, created_at)
            VALUES (?, ?, 'cancelled', ?, ?, ?)""",
            (order_id, row["status"], payload.actor, reason, now))
        return _order(db.execute("SELECT * FROM demo_orders WHERE id=?", (order_id,)).fetchone())


@router.post("/orders/{order_id}/simulate-payment")
def simulate_order_payment(order_id: int, payload: PaymentSimulationInput) -> dict:
    """Record an explicitly simulated payment for the local pilot.

    This is a laboratory declaration only: no provider, charge, transfer or
    financial settlement happens. `payment_state` stays distinct from any real
    confirmation and every record is auditable in `demo_order_payments`.
    """
    _enabled()
    reason = payload.reason.strip()
    if len(reason) < 3:
        raise HTTPException(status_code=422, detail="Simulation reason required")
    with _db() as db:
        db.execute("BEGIN IMMEDIATE")
        row = db.execute("SELECT * FROM demo_orders WHERE id=? AND tenant_id='local-demo'",
                         (order_id,)).fetchone()
        if row is None:
            raise HTTPException(status_code=404, detail="Demo order not found")
        same_key = db.execute("SELECT order_id FROM demo_order_payments WHERE request_key=?",
                              (str(payload.request_key),)).fetchone()
        if same_key is not None:
            if same_key["order_id"] == order_id:
                return _order(db.execute("SELECT * FROM demo_orders WHERE id=?", (order_id,)).fetchone())
            raise HTTPException(status_code=409, detail="Request key already used by another order")
        if db.execute("SELECT id FROM demo_order_payments WHERE order_id=?", (order_id,)).fetchone() is not None:
            raise HTTPException(status_code=409, detail="Payment was already simulated for this order")
        if row["status"] == "cancelled":
            raise HTTPException(status_code=409, detail="Cancelled orders cannot receive simulated payments")
        if row["payment_method"] == "unselected":
            raise HTTPException(status_code=409, detail="Choose a payment method before simulating payment")
        now = datetime.now(timezone.utc).isoformat()
        cursor = db.execute(
            "UPDATE demo_orders SET payment_state='simulated', updated_at=? "
            "WHERE id=? AND payment_state='not_processed'", (now, order_id))
        if cursor.rowcount != 1:
            raise HTTPException(status_code=409, detail="Order changed; refresh")
        db.execute("""INSERT INTO demo_order_payments
            (order_id, request_key, method, amount_cents, settlement, actor, reason, created_at)
            VALUES (?, ?, ?, ?, 'simulated_local', 'management', ?, ?)""",
            (order_id, str(payload.request_key), row["payment_method"], row["total_cents"], reason, now))
        db.execute("""INSERT INTO demo_order_events
            (order_id, from_status, to_status, actor, reason, created_at)
            VALUES (?, ?, ?, 'management', ?, ?)""",
            (order_id, row["status"], row["status"],
             f"Pagamento simulado ({row['payment_method']}) · {_money(row['total_cents'])} · "
             f"sem cobrança real · motivo: {reason}", now))
        return _order(db.execute("SELECT * FROM demo_orders WHERE id=?", (order_id,)).fetchone())


def _ratings_summary(db: sqlite3.Connection, store_id: str) -> dict:
    row = db.execute("""SELECT COUNT(*) AS count,
        COALESCE(AVG(stars), 0) AS average FROM demo_order_ratings WHERE store_id=?""",
        (store_id,)).fetchone()
    recent = [dict(entry) for entry in db.execute(
        """SELECT order_id, stars, comment, created_at FROM demo_order_ratings
           WHERE store_id=? ORDER BY order_id DESC LIMIT 20""", (store_id,))]
    return {"count": row["count"], "average_stars": round(row["average"], 1), "recent": recent}


@router.post("/orders/{order_id}/rating")
def rate_order(order_id: int, payload: RatingInput) -> dict:
    """Local pilot rating (GOG-022): one rating per finished order."""
    _enabled()
    with _db() as db:
        row = db.execute("SELECT * FROM demo_orders WHERE id=? AND tenant_id='local-demo'",
                         (order_id,)).fetchone()
        if row is None:
            raise HTTPException(status_code=404, detail="Demo order not found")
        if row["status"] not in ("delivered", "served", "picked_up"):
            raise HTTPException(status_code=409, detail="Only finished orders can be rated")
        if db.execute("SELECT order_id FROM demo_order_ratings WHERE order_id=?",
                      (order_id,)).fetchone() is not None:
            raise HTTPException(status_code=409, detail="Order already rated")
        now = datetime.now(timezone.utc).isoformat()
        db.execute("INSERT INTO demo_order_ratings VALUES (?, ?, ?, ?, 'customer', ?)",
                   (order_id, row["store_id"], payload.stars, payload.comment.strip(), now))
        reason = f"Avaliação {payload.stars}★ registrada"
        if payload.comment.strip():
            reason += f" · {payload.comment.strip()[:80]}"
        db.execute("""INSERT INTO demo_order_events
            (order_id, from_status, to_status, actor, reason, created_at)
            VALUES (?, ?, ?, 'customer', ?, ?)""",
            (order_id, row["status"], row["status"], reason, now))
        return _ratings_summary(db, row["store_id"])


@router.get("/stores/burger-house/ratings")
def burger_ratings() -> dict:
    _enabled()
    with _db() as db:
        return _ratings_summary(db, "burger-house")


@router.get("/orders/{order_id}/comanda")
def order_comanda(order_id: int) -> HTMLResponse:
    """GOG-031 local: printable 80mm kitchen ticket for a demo order."""
    _enabled()
    with _db() as db:
        row = db.execute("SELECT * FROM demo_orders WHERE id=? AND tenant_id='local-demo'",
                         (order_id,)).fetchone()
        if row is None:
            raise HTTPException(status_code=404, detail="Demo order not found")
        order = _order(row)
    created = datetime.fromisoformat(order["created_at"]).astimezone().strftime("%d/%m/%Y %H:%M")
    channel = {"delivery": "Entrega", "pickup": "Retirada",
               "table": "Mesa", "counter": "Balcão"}[order["order_channel"]]
    table = f" · Mesa {escape(order['table_code'])}" if order["table_code"] else ""
    lines = "".join(
        f'<tr><td>{item["quantity"]}x</td><td>{escape(item["name"])}'
        f'{("<br><small>" + escape(", ".join(item["extras"])) + f' · {escape(item["size"])}</small>') if item["extras"] else ""}'
        '</td><td style="text-align:right">—</td></tr>'
        for item in order["items"])
    body = (
        '<div class="ticket">'
        '<p style="text-align:center;font-weight:700">gogdely · comanda local</p>'
        f'<p style="text-align:center">Burger House · {channel}{table}</p>'
        f'<p>Pedido #{order["id"]} · {created}<br>Pagamento: '
        f'{order["payment_method"]} · {order["payment_status"]}</p>'
        f'<table style="width:100%">{lines}</table>'
        f'<p style="font-weight:700">Total: {_money(order["total_cents"])}</p>'
        '<p><small>Prioridade: ' + ("URGENTE" if order.get("kitchen_priority") == "urgent" else "normal")
        + ' · Comprovante do laboratório, sem valor fiscal.</small></p></div>'
        '<button onclick="window.print()">Imprimir comanda</button>'
    )
    styles = ("<style>.ticket{background:white;border:1px dashed #64748b;"
              "border-radius:8px;padding:12px;max-width:300px;font-family:monospace}</style>")
    return _html_page(f"Comanda {order_id}", body,
                      description=f"Comanda local para impressão do pedido #{order_id}.",
                      indexable=False,
                      extra_head=styles)


@router.post("/orders/{order_id}/dispatch-internal")
def dispatch_internal_order(order_id: int) -> dict:
    _enabled()
    with _db() as db:
        row = db.execute("SELECT * FROM demo_orders WHERE id=? AND tenant_id='local-demo'", (order_id,)).fetchone()
        if row is None:
            raise HTTPException(status_code=404, detail="Demo order not found")
        if row["store_id"] not in STORES or row["order_channel"] != "delivery" or row["status"] != "ready":
            raise HTTPException(status_code=409, detail="Only ready local deliveries can be dispatched")
        if row["dispatch_mode"] == "internal":
            return _order(row)
        if row["dispatch_mode"] != "pending":
            raise HTTPException(status_code=409, detail="Order cannot be dispatched")
        now = datetime.now(timezone.utc).isoformat()
        cursor = db.execute("UPDATE demo_orders SET dispatch_mode='internal', updated_at=? WHERE id=? AND status='ready' AND dispatch_mode='pending'",
                            (now, order_id))
        if cursor.rowcount != 1:
            raise HTTPException(status_code=409, detail="Order changed; refresh")
        db.execute("""INSERT INTO demo_order_events
            (order_id, from_status, to_status, actor, reason, created_at)
            VALUES (?, 'ready', 'ready', 'management', 'Encaminhado ao entregador próprio', ?)""",
            (order_id, now))
        return _order(db.execute("SELECT * FROM demo_orders WHERE id=?", (order_id,)).fetchone())


@router.patch("/orders/{order_id}/status")
def update_status(order_id: int, payload: StatusInput) -> dict:
    _enabled()
    with _db() as db:
        row = db.execute("SELECT * FROM demo_orders WHERE id=? AND tenant_id='local-demo'", (order_id,)).fetchone()
        if row is None:
            raise HTTPException(status_code=404, detail="Demo order not found")
        expected = (("served", "management") if row["order_channel"] in {"table", "counter"} and row["status"] == "ready"
                    else ("picked_up", "management") if row["order_channel"] == "pickup" and row["status"] == "ready"
                    else None if row["order_channel"] != "delivery" and row["status"] == "ready"
                    else NEXT_STATUS.get(row["status"]))
        if expected != (payload.status, payload.actor):
            raise HTTPException(status_code=409, detail="Invalid demo status transition")
        if payload.status == "in_delivery" and row["dispatch_mode"] != "internal":
            raise HTTPException(status_code=409, detail="Delivery has not been dispatched")
        if payload.status == "picked_up" and payload.pickup_code != row["pickup_code"]:
            raise HTTPException(status_code=409, detail="Pickup code does not match this order")
        if payload.status == "delivered" and payload.delivery_code != row["delivery_code"]:
            raise HTTPException(status_code=409, detail="Delivery code does not match this order")
        now = datetime.now(timezone.utc).isoformat()
        cursor = db.execute("UPDATE demo_orders SET status=?, updated_at=? WHERE id=? AND status=?", (payload.status, now, order_id, row["status"]))
        if cursor.rowcount != 1:
            raise HTTPException(status_code=409, detail="Order changed; refresh")
        note = payload.proof_note.strip()
        event_reason = (f"Comprovante da entrega: {note}"
                        if payload.status == "delivered" and note else "")
        db.execute("""INSERT INTO demo_order_events
            (order_id, from_status, to_status, actor, reason, created_at)
            VALUES (?, ?, ?, ?, ?, ?)""",
            (order_id, row["status"], payload.status, payload.actor, event_reason, now))
        return _order(db.execute("SELECT * FROM demo_orders WHERE id=?", (order_id,)).fetchone())
