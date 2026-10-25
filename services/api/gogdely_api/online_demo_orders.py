"""Fictitious end-to-end orders for the isolated Supabase homologation project.

The route is disabled outside the test environment. It never accepts payment
details, customer identity or a real delivery address. FastAPI is the only
writer; all totals and courier earnings are calculated server side.
"""

import logging
import os
from contextlib import contextmanager
from decimal import Decimal, ROUND_HALF_UP
from typing import Literal
from uuid import UUID

from fastapi import APIRouter, Depends, HTTPException
from pydantic import BaseModel, Field

from gogdely_api.auth import AuthenticatedUser, authenticated_user
from gogdely_api.db_health import configured_database_url, connect_database
from gogdely_api.memberships import authorized_branch

router = APIRouter(prefix="/api/v1", tags=["homologation-orders"])
logger = logging.getLogger(__name__)
DEMO_TENANT = UUID("c95d5aca-8eea-4ad4-8b50-53117abe3f01")


def _demo_only():
    if os.environ.get("GOGDELY_ENV") not in ("testes", "homologacao"):
        raise HTTPException(status_code=404, detail="Test flow unavailable")


@contextmanager
def _database():
    url = configured_database_url()
    if not url:
        raise HTTPException(status_code=503, detail="Test database unavailable")
    connection = None
    try:
        connection = connect_database(url, "gogdely-homologation-orders")
        connection.run("BEGIN")
        yield connection
        connection.run("COMMIT")
    except HTTPException:
        if connection is not None:
            connection.run("ROLLBACK")
        raise
    except Exception as exc:
        logger.warning("homologation order operation failed: %s", type(exc).__name__)
        if connection is not None:
            try:
                connection.run("ROLLBACK")
            except Exception:
                pass
        raise HTTPException(status_code=503, detail="Test operation unavailable") from None
    finally:
        if connection is not None:
            connection.close()


class TestLine(BaseModel):
    item_id: UUID
    quantity: int = Field(ge=1, le=10)


class TestOrderInput(BaseModel):
    slug: str = Field(pattern=r"^[a-z0-9]+(?:-[a-z0-9]+)*$", max_length=100)
    idempotency_key: UUID
    channel: Literal["delivery", "pickup", "table"] = "delivery"
    table_number: int | None = Field(default=None, ge=1, le=999)
    items: list[TestLine] = Field(min_length=1, max_length=20)


class StatusInput(BaseModel):
    status: Literal["accepted", "preparing", "ready", "completed"]


class CompensationInput(BaseModel):
    mode: Literal["fixed", "percent", "salary"]
    fixed_cents: int = Field(default=0, ge=0, le=1000000)
    percent: Decimal = Field(default=Decimal(0), ge=0, le=100)


class CourierInput(BaseModel):
    email: str = Field(min_length=3, max_length=254)
    active: bool = True


def _branch(user: AuthenticatedUser, tenant: UUID, branch: UUID, *, manager=False):
    _demo_only()
    if tenant != DEMO_TENANT:
        raise HTTPException(status_code=404, detail="Test store not found")
    context = authorized_branch(user.user_id, tenant, branch)
    if manager and context.role not in ("owner", "manager"):
        raise HTTPException(status_code=403, detail="Management access required")
    return context


def _order_dict(row):
    return {
        "order_id": str(row[0]), "status": row[1], "channel": row[2],
        "subtotal_cents": row[3], "delivery_fee_cents": row[4],
        "total_cents": row[5], "created_at": str(row[6]),
        "table_code": row[7], "payment_state": row[8],
    }


_ORDER_COLUMNS = """order_id::text, status, channel, subtotal_cents,
    delivery_fee_cents, total_cents, created_at, table_code, payment_state"""


@router.post("/demo/orders", status_code=201)
def create_test_order(payload: TestOrderInput):
    _demo_only()
    if (payload.channel == "table") != (payload.table_number is not None):
        raise HTTPException(status_code=422, detail="Table number is required only for table orders")
    quantities: dict[UUID, int] = {}
    for line in payload.items:
        quantities[line.item_id] = quantities.get(line.item_id, 0) + line.quantity
    if any(quantity > 10 for quantity in quantities.values()):
        raise HTTPException(status_code=422, detail="Too many units")
    with _database() as db:
        store = db.run(
            """SELECT b.tenant_id::text, b.branch_id::text
               FROM gogdely.branches b JOIN gogdely.tenants t
                 ON t.tenant_id=b.tenant_id
               WHERE b.slug=:slug AND b.status='active' AND t.status='active'""",
            slug=payload.slug,
        )
        if not store or UUID(store[0][0]) != DEMO_TENANT:
            raise HTTPException(status_code=404, detail="Test store not found")
        tenant, branch = store[0]
        previous = db.run(
            f"SELECT {_ORDER_COLUMNS} FROM gogdely.orders "
            "WHERE tenant_id=:tenant AND idempotency_key=:key",
            tenant=tenant, key=str(payload.idempotency_key),
        )
        if previous:
            return _order_dict(previous[0])
        products = db.run(
            """SELECT item_id::text, name, price_cents FROM gogdely.menu_items
               WHERE tenant_id=:tenant AND branch_id=:branch AND available""",
            tenant=tenant, branch=branch,
        )
        indexed = {UUID(row[0]): row for row in products}
        if not quantities.keys() <= indexed.keys():
            raise HTTPException(status_code=422, detail="One or more items are unavailable")
        subtotal = sum(indexed[item][2] * qty for item, qty in quantities.items())
        if subtotal > 10000000:
            raise HTTPException(status_code=422, detail="Test order exceeds limit")
        delivery = 599 if payload.channel == "delivery" else 0
        inserted = db.run(
            """INSERT INTO gogdely.orders
               (tenant_id, branch_id, idempotency_key, channel, table_code,
                address_label, subtotal_cents, delivery_fee_cents, total_cents)
               VALUES (:tenant, :branch, :key, :channel, :table,
                       'Destino ficticio - homologacao', :subtotal, :delivery, :total)
               ON CONFLICT (tenant_id, idempotency_key) DO NOTHING
               RETURNING order_id::text""",
            tenant=tenant, branch=branch, key=str(payload.idempotency_key),
            channel=payload.channel,
            table=str(payload.table_number) if payload.table_number else None,
            subtotal=subtotal, delivery=delivery, total=subtotal + delivery,
        )
        if inserted:
            order_id = inserted[0][0]
            for line_no, (item_id, qty) in enumerate(quantities.items(), 1):
                _, name, price = indexed[item_id]
                db.run(
                    """INSERT INTO gogdely.order_items
                       (tenant_id,branch_id,order_id,line_no,item_id,name_snapshot,
                        quantity,unit_price_cents)
                       VALUES (:tenant,:branch,:order_id,:line_no,:item_id,:name,:qty,:price)""",
                    tenant=tenant, branch=branch, order_id=order_id,
                    line_no=line_no, item_id=str(item_id), name=name,
                    qty=qty, price=price,
                )
            db.run(
                """INSERT INTO gogdely.order_events
                   (tenant_id,branch_id,order_id,to_status,reason)
                   VALUES (:tenant,:branch,:order_id,'created','Pedido ficticio criado no Cliente')""",
                tenant=tenant, branch=branch, order_id=order_id,
            )
        else:
            order_id = db.run(
                """SELECT order_id::text FROM gogdely.orders
                   WHERE tenant_id=:tenant AND idempotency_key=:key""",
                tenant=tenant, key=str(payload.idempotency_key),
            )[0][0]
        row = db.run(
            f"SELECT {_ORDER_COLUMNS} FROM gogdely.orders "
            "WHERE tenant_id=:tenant AND branch_id=:branch AND order_id=:order_id",
            tenant=tenant, branch=branch, order_id=order_id,
        )[0]
        return _order_dict(row)


@router.get("/demo/orders/{order_id}")
def test_order_status(order_id: UUID):
    _demo_only()
    with _database() as db:
        rows = db.run(
            f"SELECT {_ORDER_COLUMNS} FROM gogdely.orders "
            "WHERE tenant_id=:tenant AND order_id=:order_id",
            tenant=str(DEMO_TENANT), order_id=str(order_id),
        )
        if not rows:
            raise HTTPException(status_code=404, detail="Test order not found")
        return _order_dict(rows[0])


@router.get("/management/tenants/{tenant}/branches/{branch}/orders")
def management_orders(tenant: UUID, branch: UUID,
                      user: AuthenticatedUser = Depends(authenticated_user)):
    _branch(user, tenant, branch)
    with _database() as db:
        rows = db.run(
            f"SELECT {_ORDER_COLUMNS} FROM gogdely.orders "
            "WHERE tenant_id=:tenant AND branch_id=:branch "
            "ORDER BY created_at DESC LIMIT 100",
            tenant=str(tenant), branch=str(branch),
        )
        return [_order_dict(row) for row in rows]


@router.patch("/management/tenants/{tenant}/branches/{branch}/orders/{order_id}/status")
def management_status(tenant: UUID, branch: UUID, order_id: UUID,
                      payload: StatusInput,
                      user: AuthenticatedUser = Depends(authenticated_user)):
    _branch(user, tenant, branch)
    with _database() as db:
        rows = db.run(
            """SELECT status, channel FROM gogdely.orders
               WHERE tenant_id=:tenant AND branch_id=:branch AND order_id=:order_id
               FOR UPDATE""",
            tenant=str(tenant), branch=str(branch), order_id=str(order_id),
        )
        if not rows:
            raise HTTPException(status_code=404, detail="Test order not found")
        before, channel = rows[0]
        expected = {"created": "accepted", "accepted": "preparing",
                    "preparing": "ready"}
        if channel != "delivery":
            expected["ready"] = "completed"
        if expected.get(before) != payload.status:
            raise HTTPException(status_code=409, detail="Invalid order transition")
        db.run(
            """UPDATE gogdely.orders SET status=:status,updated_at=now()
               WHERE tenant_id=:tenant AND branch_id=:branch AND order_id=:order_id""",
            status=payload.status, tenant=str(tenant), branch=str(branch),
            order_id=str(order_id),
        )
        db.run(
            """INSERT INTO gogdely.order_events
               (tenant_id,branch_id,order_id,from_status,to_status,actor_user_id,reason)
               VALUES (:tenant,:branch,:order_id,:before,:after,:actor,
                       'Gestao de homologacao')""",
            tenant=str(tenant), branch=str(branch), order_id=str(order_id),
            before=before, after=payload.status, actor=str(user.user_id),
        )
        return {"order_id": str(order_id), "status": payload.status}


@router.post("/management/tenants/{tenant}/branches/{branch}/orders/{order_id}/dispatch")
def dispatch_test_order(tenant: UUID, branch: UUID, order_id: UUID,
                        user: AuthenticatedUser = Depends(authenticated_user)):
    _branch(user, tenant, branch, manager=True)
    with _database() as db:
        rows = db.run(
            """SELECT status,channel FROM gogdely.orders
               WHERE tenant_id=:tenant AND branch_id=:branch AND order_id=:order_id
               FOR UPDATE""",
            tenant=str(tenant), branch=str(branch), order_id=str(order_id),
        )
        if not rows:
            raise HTTPException(status_code=404, detail="Test order not found")
        if tuple(rows[0]) != ("ready", "delivery"):
            raise HTTPException(status_code=409, detail="Only ready delivery orders can be dispatched")
        inserted = db.run(
            """INSERT INTO gogdely.delivery_assignments
               (tenant_id,branch_id,order_id) VALUES (:tenant,:branch,:order_id)
               ON CONFLICT (tenant_id,branch_id,order_id) DO NOTHING
               RETURNING status""",
            tenant=str(tenant), branch=str(branch), order_id=str(order_id),
        )
        if not inserted:
            raise HTTPException(status_code=409, detail="Delivery already dispatched")
        return {"order_id": str(order_id), "status": "available"}


@router.get("/management/tenants/{tenant}/branches/{branch}/couriers")
def management_couriers(tenant: UUID, branch: UUID,
                        user: AuthenticatedUser = Depends(authenticated_user)):
    _branch(user, tenant, branch, manager=True)
    with _database() as db:
        rows = db.run(
            """SELECT u.email,c.active,c.user_id::text
               FROM gogdely.courier_memberships c
               JOIN auth.users u ON u.id=c.user_id
               WHERE c.tenant_id=:tenant AND c.branch_id=:branch
               ORDER BY u.email""",
            tenant=str(tenant), branch=str(branch),
        )
        return [{"email": email, "active": active, "user_id": user_id}
                for email, active, user_id in rows]


@router.put("/management/tenants/{tenant}/branches/{branch}/couriers")
def link_test_courier(tenant: UUID, branch: UUID, payload: CourierInput,
                      user: AuthenticatedUser = Depends(authenticated_user)):
    _branch(user, tenant, branch, manager=True)
    with _database() as db:
        rows = db.run(
            """SELECT id::text FROM auth.users
               WHERE lower(email)=lower(:email) AND email_confirmed_at IS NOT NULL""",
            email=payload.email.strip(),
        )
        if not rows:
            raise HTTPException(status_code=404, detail="Confirmed Auth user not found")
        courier = rows[0][0]
        db.run(
            """INSERT INTO gogdely.courier_memberships
               (tenant_id,branch_id,user_id,active)
               VALUES (:tenant,:branch,:courier,:active)
               ON CONFLICT (tenant_id,branch_id,user_id)
               DO UPDATE SET active=EXCLUDED.active""",
            tenant=str(tenant), branch=str(branch), courier=courier,
            active=payload.active,
        )
        return {"user_id": courier, "active": payload.active}


@router.get("/management/tenants/{tenant}/branches/{branch}/compensation")
def management_compensation(tenant: UUID, branch: UUID,
                            user: AuthenticatedUser = Depends(authenticated_user)):
    _branch(user, tenant, branch, manager=True)
    with _database() as db:
        rows = db.run(
            """SELECT mode,fixed_cents,percent FROM gogdely.delivery_compensation
               WHERE tenant_id=:tenant AND branch_id=:branch""",
            tenant=str(tenant), branch=str(branch),
        )
        if not rows:
            return {"mode": "salary", "fixed_cents": 0, "percent": 0}
        mode, fixed, percent = rows[0]
        return {"mode": mode, "fixed_cents": fixed, "percent": float(percent)}


@router.put("/management/tenants/{tenant}/branches/{branch}/compensation")
def set_management_compensation(tenant: UUID, branch: UUID,
                                payload: CompensationInput,
                                user: AuthenticatedUser = Depends(authenticated_user)):
    _branch(user, tenant, branch, manager=True)
    with _database() as db:
        db.run(
            """INSERT INTO gogdely.delivery_compensation
               (tenant_id,branch_id,mode,fixed_cents,percent,updated_by)
               VALUES (:tenant,:branch,:mode,:fixed,:percent,:actor)
               ON CONFLICT (tenant_id,branch_id) DO UPDATE SET
                 mode=EXCLUDED.mode,fixed_cents=EXCLUDED.fixed_cents,
                 percent=EXCLUDED.percent,updated_by=EXCLUDED.updated_by,
                 updated_at=now()""",
            tenant=str(tenant), branch=str(branch), mode=payload.mode,
            fixed=payload.fixed_cents, percent=payload.percent,
            actor=str(user.user_id),
        )
        return payload.model_dump(mode="json")


def _courier_rows(db, user_id: UUID):
    return db.run(
        """SELECT a.tenant_id::text,a.branch_id::text,a.order_id::text,
                  a.status,a.earning_cents,b.name,o.total_cents,o.delivery_fee_cents,
                  o.address_label,o.created_at
           FROM gogdely.delivery_assignments a
           JOIN gogdely.courier_memberships c
             ON c.tenant_id=a.tenant_id AND c.branch_id=a.branch_id
            AND c.user_id=:courier AND c.active
           JOIN gogdely.orders o ON o.tenant_id=a.tenant_id
             AND o.branch_id=a.branch_id AND o.order_id=a.order_id
           JOIN gogdely.branches b ON b.tenant_id=a.tenant_id
             AND b.branch_id=a.branch_id
           JOIN gogdely.tenants t ON t.tenant_id=a.tenant_id
           WHERE a.tenant_id=:tenant AND b.status='active' AND t.status='active'
             AND (a.status='available' OR a.courier_user_id=:courier)
           ORDER BY o.created_at DESC LIMIT 100""",
        tenant=str(DEMO_TENANT), courier=str(user_id),
    )


def _courier_dict(row):
    return {"tenant_id": row[0], "branch_id": row[1], "order_id": row[2],
            "status": row[3], "earning_cents": row[4], "store_name": row[5],
            "order_total_cents": row[6], "delivery_fee_cents": row[7],
            "address_label": row[8], "created_at": str(row[9])}


@router.get("/courier/assignments")
def courier_assignments(user: AuthenticatedUser = Depends(authenticated_user)):
    _demo_only()
    with _database() as db:
        return [_courier_dict(row) for row in _courier_rows(db, user.user_id)]


@router.get("/courier/earnings")
def courier_earnings(user: AuthenticatedUser = Depends(authenticated_user)):
    _demo_only()
    with _database() as db:
        rows = _courier_rows(db, user.user_id)
        completed = [row for row in rows if row[3] == "completed"]
        stores: dict[str, int] = {}
        for row in completed:
            stores[row[5]] = stores.get(row[5], 0) + row[4]
        return {"completed_count": len(completed),
                "total_cents": sum(row[4] for row in completed),
                "stores": [{"store_name": name, "earned_cents": amount}
                           for name, amount in stores.items()],
                "fictitious": True}


@router.post("/courier/assignments/{order_id}/accept")
def courier_accept(order_id: UUID,
                   user: AuthenticatedUser = Depends(authenticated_user)):
    _demo_only()
    with _database() as db:
        rows = db.run(
            """SELECT a.tenant_id::text,a.branch_id::text,a.status,
                      a.courier_user_id::text,o.delivery_fee_cents
               FROM gogdely.delivery_assignments a
               JOIN gogdely.courier_memberships c
                 ON c.tenant_id=a.tenant_id AND c.branch_id=a.branch_id
                AND c.user_id=:courier AND c.active
               JOIN gogdely.orders o ON o.tenant_id=a.tenant_id
                 AND o.branch_id=a.branch_id AND o.order_id=a.order_id
               JOIN gogdely.branches b ON b.tenant_id=a.tenant_id
                 AND b.branch_id=a.branch_id AND b.status='active'
               JOIN gogdely.tenants t ON t.tenant_id=a.tenant_id
                 AND t.status='active'
               WHERE a.tenant_id=:tenant AND a.order_id=:order_id
               FOR UPDATE OF a""",
            tenant=str(DEMO_TENANT), order_id=str(order_id),
            courier=str(user.user_id),
        )
        if not rows:
            raise HTTPException(status_code=404, detail="Delivery not available")
        tenant, branch, status, owner, fee = rows[0]
        if owner == str(user.user_id):
            return {"order_id": str(order_id), "status": status}
        if status != "available" or owner is not None:
            raise HTTPException(status_code=409, detail="Delivery already accepted")
        pay = db.run(
            """SELECT mode,fixed_cents,percent FROM gogdely.delivery_compensation
               WHERE tenant_id=:tenant AND branch_id=:branch""",
            tenant=tenant, branch=branch,
        )
        mode, fixed, percent = pay[0] if pay else ("salary", 0, Decimal(0))
        earning = (fixed if mode == "fixed" else
                   int((Decimal(fee) * percent / 100).quantize(
                       Decimal("1"), rounding=ROUND_HALF_UP)) if mode == "percent"
                   else 0)
        db.run(
            """UPDATE gogdely.delivery_assignments SET
                 courier_user_id=:courier,status='accepted',earning_cents=:earning,
                 accepted_at=now()
               WHERE tenant_id=:tenant AND branch_id=:branch AND order_id=:order_id""",
            courier=str(user.user_id), earning=earning,
            tenant=tenant, branch=branch, order_id=str(order_id),
        )
        return {"order_id": str(order_id), "status": "accepted",
                "earning_cents": earning}


def _courier_advance(order_id: UUID, user_id: UUID, before: str, after: str):
    _demo_only()
    with _database() as db:
        rows = db.run(
            """SELECT a.tenant_id::text,a.branch_id::text,a.status
               FROM gogdely.delivery_assignments a
               JOIN gogdely.courier_memberships c
                 ON c.tenant_id=a.tenant_id AND c.branch_id=a.branch_id
                AND c.user_id=:courier AND c.active
               WHERE a.tenant_id=:tenant AND a.order_id=:order_id
                 AND a.courier_user_id=:courier
               FOR UPDATE OF a""",
            tenant=str(DEMO_TENANT), order_id=str(order_id),
            courier=str(user_id),
        )
        if not rows:
            raise HTTPException(status_code=404, detail="Delivery not found")
        tenant, branch, current = rows[0]
        if current != before:
            raise HTTPException(status_code=409, detail="Invalid delivery transition")
        db.run(
            """UPDATE gogdely.delivery_assignments
               SET status=:after,completed_at=CASE WHEN :after='completed'
                   THEN now() ELSE completed_at END
               WHERE tenant_id=:tenant AND branch_id=:branch AND order_id=:order_id""",
            after=after, tenant=tenant, branch=branch, order_id=str(order_id),
        )
        order_status = "dispatched" if after == "in_delivery" else "completed"
        previous_order = "ready" if after == "in_delivery" else "dispatched"
        updated_order = db.run(
            """UPDATE gogdely.orders SET status=:after,updated_at=now()
               WHERE tenant_id=:tenant AND branch_id=:branch AND order_id=:order_id
                 AND status=:before RETURNING order_id""",
            after=order_status, before=previous_order,
            tenant=tenant, branch=branch, order_id=str(order_id),
        )
        if not updated_order:
            raise HTTPException(status_code=409, detail="Order status changed")
        db.run(
            """INSERT INTO gogdely.order_events
               (tenant_id,branch_id,order_id,from_status,to_status,actor_user_id,reason)
               VALUES (:tenant,:branch,:order_id,:before,:after,:actor,
                       'Entregador de homologacao')""",
            tenant=tenant, branch=branch, order_id=str(order_id),
            before=previous_order, after=order_status, actor=str(user_id),
        )
        return {"order_id": str(order_id), "status": after}


@router.post("/courier/assignments/{order_id}/start")
def courier_start(order_id: UUID,
                  user: AuthenticatedUser = Depends(authenticated_user)):
    return _courier_advance(order_id, user.user_id, "accepted", "in_delivery")


@router.post("/courier/assignments/{order_id}/complete")
def courier_complete(order_id: UUID,
                     user: AuthenticatedUser = Depends(authenticated_user)):
    return _courier_advance(order_id, user.user_id, "in_delivery", "completed")
