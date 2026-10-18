"""Local-only Master management endpoints for the GOGDELY laboratory.

GOG-010/096 prototype scope: platform overview, company registry with a
simulated approval flow (GOG-025), static plan catalog (GOG-058/059/060/061/062)
and a merged audit trail. Everything runs on the local SQLite demo database.
There is no real authentication, no MFA verification and no production data;
the Master app must label all critical actions as simulated.
"""
import json
import sqlite3
from datetime import datetime, timezone

from fastapi import APIRouter, HTTPException
from pydantic import BaseModel, Field

from gogdely_api.local_orders import _db, _enabled, _payment_methods

router = APIRouter(prefix="/api/v1/local/master", tags=["local-master"])

MASTER_STORES = [
    ("burger-house", "Burger House", "Restaurantes", "starter"),
    ("pizzaria-napoli", "Pizzaria Napoli", "Restaurantes", "growth"),
    ("mercado-bem-estar", "Mercado Bem-Estar", "Mercado", "starter"),
]

LOCAL_PLANS = [
    {
        "plan_id": "starter",
        "name": "Starter",
        "monthly_fee_cents": 14900,
        "commission_percent": 8,
        "trial_days": 7,
        "notes": "Plano fixo mensal com comissão percentual sobre produtos.",
    },
    {
        "plan_id": "growth",
        "name": "Growth",
        "monthly_fee_cents": 29900,
        "commission_percent": 6,
        "trial_days": 7,
        "notes": "Plano fixo mensal com comissão reduzida sobre produtos.",
    },
    {
        "plan_id": "enterprise",
        "name": "Enterprise",
        "monthly_fee_cents": 0,
        "commission_percent": 5,
        "trial_days": 0,
        "notes": "Contrato personalizado; valores apenas ilustrativos no laboratório.",
    },
]


class ApprovalInput(BaseModel):
    actor: str = Field(min_length=3, max_length=60)
    decision: str = Field(pattern=r"^(approve|reject)$")
    reason: str = Field(min_length=3, max_length=300)


def _ensure_companies(db: sqlite3.Connection) -> None:
    db.execute("""CREATE TABLE IF NOT EXISTS demo_companies (
        tenant_id TEXT NOT NULL,
        store_id TEXT NOT NULL,
        name TEXT NOT NULL,
        category TEXT NOT NULL,
        plan_id TEXT NOT NULL,
        status TEXT NOT NULL CHECK(status IN ('pending', 'approved', 'rejected')),
        created_at TEXT NOT NULL,
        PRIMARY KEY (tenant_id, store_id)
    )""")
    db.execute("""CREATE TABLE IF NOT EXISTS demo_master_events (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        store_id TEXT NOT NULL,
        actor TEXT NOT NULL,
        action TEXT NOT NULL,
        detail TEXT NOT NULL,
        created_at TEXT NOT NULL
    )""")
    now = datetime.now(timezone.utc).isoformat()
    for store_id, name, category, plan in MASTER_STORES:
        db.execute(
            "INSERT OR IGNORE INTO demo_companies VALUES (?, ?, ?, ?, ?, ?, ?)",
            ("local-demo", store_id, name, category, plan,
             "approved" if store_id == "burger-house" else "pending", now))
    db.execute("INSERT OR IGNORE INTO demo_master_events (store_id, actor, action, detail, created_at) "
               "VALUES ('burger-house', 'master_local', 'seed', 'Empresa piloto aprovada no laboratório', ?)", (now,))


def _company(row: sqlite3.Row) -> dict:
    result = dict(row)
    plan = next((entry for entry in LOCAL_PLANS if entry["plan_id"] == result["plan_id"]), None)
    result["plan"] = plan
    return result


@router.get("/overview")
def master_overview() -> dict:
    _enabled()
    with _db() as db:
        _ensure_companies(db)
        companies = db.execute("SELECT * FROM demo_companies WHERE tenant_id='local-demo'").fetchall()
        orders = db.execute("SELECT * FROM demo_orders WHERE tenant_id='local-demo'").fetchall()
        active = [order for order in orders if order["status"] != "cancelled"]
        simulated_payments = db.execute(
            "SELECT COUNT(*) AS total, COALESCE(SUM(amount_cents), 0) AS amount FROM demo_order_payments").fetchone()
        commission_cents = 0
        for order in active:
            plan = _company(next(row for row in companies if row["store_id"] == order["store_id"]))["plan"] \
                if any(row["store_id"] == order["store_id"] for row in companies) else None
            if plan:
                commission_cents += (order["subtotal_cents"] * plan["commission_percent"]) // 100
        return {
            "environment": "local-demo",
            "companies": {
                "approved": sum(1 for row in companies if row["status"] == "approved"),
                "pending": sum(1 for row in companies if row["status"] == "pending"),
                "rejected": sum(1 for row in companies if row["status"] == "rejected"),
            },
            "orders": {
                "total": len(orders),
                "active": len(active),
                "cancelled": len(orders) - len(active),
                "gross_cents": sum(order["total_cents"] for order in active),
            },
            "payments": {
                "settlement": "none",
                "simulated_count": simulated_payments["total"],
                "simulated_cents": simulated_payments["amount"],
                "warning": "Nenhum pagamento real foi processado; valores são simulações locais.",
            },
            "commissions": {
                "estimated_cents": commission_cents,
                "warning": "Estimativa sobre produtos sem frete; cobrança real não implementada.",
            },
        }


@router.get("/companies")
def master_companies() -> list[dict]:
    _enabled()
    with _db() as db:
        _ensure_companies(db)
        rows = db.execute(
            "SELECT * FROM demo_companies WHERE tenant_id='local-demo' ORDER BY status, store_id").fetchall()
        return [_company(row) for row in rows]


@router.get("/plans")
def master_plans() -> list[dict]:
    _enabled()
    return LOCAL_PLANS


@router.post("/companies/{store_id}/approval")
def master_company_approval(store_id: str, payload: ApprovalInput) -> dict:
    """Simulated approval flow (GOG-025): local audit only, no production effect."""
    _enabled()
    with _db() as db:
        _ensure_companies(db)
        row = db.execute(
            "SELECT * FROM demo_companies WHERE tenant_id='local-demo' AND store_id=?", (store_id,)).fetchone()
        if row is None:
            raise HTTPException(status_code=404, detail="Empresa não encontrada no laboratório")
        status = "approved" if payload.decision == "approve" else "rejected"
        if row["status"] == status:
            raise HTTPException(status_code=409, detail="Empresa já está nesse estado")
        if row["store_id"] == "burger-house":
            raise HTTPException(status_code=409, detail="A empresa piloto permanece aprovada no laboratório")
        now = datetime.now(timezone.utc).isoformat()
        db.execute("UPDATE demo_companies SET status=? WHERE tenant_id='local-demo' AND store_id=?",
                   (status, store_id))
        db.execute("INSERT INTO demo_master_events (store_id, actor, action, detail, created_at) "
                   "VALUES (?, ?, ?, ?, ?)",
                   (store_id, payload.actor, f"approval_{status}",
                    f"{'Aprovação' if status == 'approved' else 'Recusa'} simulada · motivo: {payload.reason}", now))
        updated = db.execute(
            "SELECT * FROM demo_companies WHERE tenant_id='local-demo' AND store_id=?", (store_id,)).fetchone()
        return _company(updated)


@router.get("/audit")
def master_audit(limit: int = 100) -> list[dict]:
    """Merged local audit trail across every pilot source, newest first."""
    _enabled()
    with _db() as db:
        _ensure_companies(db)
        entries: list[dict] = []
        for row in db.execute(
                "SELECT order_id, from_status, to_status, actor, reason, created_at FROM demo_order_events"):
            entries.append({"source": "order", "ref": f"pedido #{row['order_id']}",
                            "actor": row["actor"], "detail": row["reason"] or row["to_status"],
                            "created_at": row["created_at"]})
        for row in db.execute(
                "SELECT store_id, product_name, action, actor, changes_json, created_at FROM demo_menu_events"):
            changes = json.loads(row["changes_json"])
            entries.append({"source": "menu", "ref": row["product_name"],
                            "actor": row["actor"], "detail": f"{row['action']} · {json.dumps(changes, ensure_ascii=False)[:120]}",
                            "created_at": row["created_at"]})
        for row in db.execute(
                "SELECT order_id, method, amount_cents, settlement, reason, created_at FROM demo_order_payments"):
            entries.append({"source": "payment", "ref": f"pedido #{row['order_id']}",
                            "actor": "management", "detail": f"Pagamento simulado ({row['method']}) · "
                            f"{row['amount_cents'] / 100:.2f} · {row['settlement']} · {row['reason']}",
                            "created_at": row["created_at"]})
        for row in db.execute(
                "SELECT item_name, movement_type, quantity_delta, reason, order_id, created_at FROM demo_stock_movements"):
            order_ref = f" · pedido #{row['order_id']}" if row["order_id"] else ""
            entries.append({"source": "stock", "ref": row["item_name"],
                            "actor": "stock_local", "detail": f"{row['movement_type']} · {row['quantity_delta']:+d}"
                            f"{order_ref} · {row['reason']}",
                            "created_at": row["created_at"]})
        for row in db.execute(
                "SELECT id, status, opening_cents, counted_cents, difference_cents, opened_at, closed_at, opening_reason FROM demo_pos_sessions"):
            if row["status"] == "open":
                entries.append({"source": "pos", "ref": f"caixa #{row['id']}",
                                "actor": "pos_local", "detail": f"aberto · {row['opening_cents'] / 100:.2f} · {row['opening_reason']}",
                                "created_at": row["opened_at"]})
            else:
                entries.append({"source": "pos", "ref": f"caixa #{row['id']}",
                                "actor": "pos_local", "detail": f"fechado · contado {row['counted_cents'] / 100:.2f} · "
                                f"diferença {(row['difference_cents'] or 0) / 100:.2f}",
                                "created_at": row["closed_at"] or row["opened_at"]})
        for row in db.execute(
                "SELECT store_id, actor, action, detail, created_at FROM demo_master_events"):
            entries.append({"source": "master", "ref": row["store_id"], "actor": row["actor"],
                            "detail": f"{row['action']} · {row['detail']}", "created_at": row["created_at"]})
        entries.sort(key=lambda entry: entry["created_at"], reverse=True)
        return entries[:max(1, min(limit, 200))]


@router.get("/payment-methods")
def master_payment_methods() -> dict:
    """Read-only view of the pilot payment configuration for Master."""
    _enabled()
    with _db() as db:
        return {"store_id": "burger-house", "methods": _payment_methods(db)}
