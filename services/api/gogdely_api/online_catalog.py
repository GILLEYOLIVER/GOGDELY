"""Fail-closed online catalog reads for public customers and store members."""

import logging
import json
import re
from uuid import UUID

from fastapi import APIRouter, Depends, HTTPException
from pydantic import BaseModel, Field, field_validator

from gogdely_api.auth import AuthenticatedUser, authenticated_user
from gogdely_api.db_health import configured_database_url, connect_database
from gogdely_api.memberships import authorized_branch

router = APIRouter(prefix="/api/v1", tags=["online-catalog"])
logger = logging.getLogger(__name__)
_SLUG = re.compile(r"^[a-z0-9]+(?:-[a-z0-9]+)*$")


class CatalogItem(BaseModel):
    item_id: UUID
    name: str
    description: str
    category_name: str
    price_cents: int
    image_path: str | None
    available: bool
    sort_order: int
    updated_at: str


class CatalogItemInput(BaseModel):
    name: str = Field(min_length=1, max_length=120)
    description: str = Field(default="", max_length=2000)
    category_name: str = Field(min_length=1, max_length=80)
    price_cents: int = Field(ge=0, le=100000000)
    image_path: str | None = Field(default=None, max_length=500)
    available: bool = False
    sort_order: int = Field(default=0, ge=0)

    @field_validator("name", "category_name")
    @classmethod
    def nonblank(cls, value: str) -> str:
        value = value.strip()
        if not value:
            raise ValueError("Required text cannot be blank")
        return value

    @field_validator("image_path")
    @classmethod
    def no_unreviewed_image_source(cls, value: str | None) -> str | None:
        if value is not None:
            raise ValueError("Image upload is not available online yet")
        return value


class CatalogItemUpdate(CatalogItemInput):
    expected_updated_at: str = Field(min_length=10, max_length=64)


class StoreCatalog(BaseModel):
    tenant_id: UUID
    branch_id: UUID
    slug: str
    name: str
    items: list[CatalogItem]
    role: str | None = None


def _read(role: str, statement: str, *, user_id: UUID | None = None, **parameters):
    """Run one SELECT with the DB role and verified Auth subject scoped to it."""
    database_url = configured_database_url()
    if not database_url:
        raise HTTPException(status_code=503, detail="Online catalog unavailable")
    connection = None
    try:
        connection = connect_database(database_url, "gogdely-online-catalog")
        connection.run("BEGIN READ ONLY")
        if user_id is not None:
            connection.run(
                "SELECT set_config('request.jwt.claim.sub', :subject, true)",
                subject=str(user_id),
            )
        # Both role names are constants selected by server code, never input.
        if role not in ("authenticated", "anon"):
            raise ValueError("Unexpected database role")
        connection.run(f"SET LOCAL ROLE {role}")
        rows = connection.run(statement, **parameters)
        connection.run("COMMIT")
        return rows
    except Exception as exc:
        logger.warning("online catalog query failed: %s", type(exc).__name__)
        raise HTTPException(status_code=503, detail="Online catalog unavailable") from None
    finally:
        if connection is not None:
            connection.close()


def _write_item(user_id: UUID, statement: str, *, action: str, **parameters):
    """Write one menu item as the verified user, relying on branch-scoped RLS."""
    database_url = configured_database_url()
    if not database_url:
        raise HTTPException(status_code=503, detail="Online catalog unavailable")
    connection = None
    try:
        connection = connect_database(database_url, "gogdely-catalog-write")
        connection.run("BEGIN")
        connection.run("SELECT set_config('request.jwt.claim.sub', :subject, true)",
                       subject=str(user_id))
        connection.run("SET LOCAL ROLE authenticated")
        rows = connection.run(statement, **parameters)
        if rows:
            row = rows[0]
            connection.run(
                """INSERT INTO gogdely.menu_item_events
                   (tenant_id, branch_id, item_id, actor_user_id, action, snapshot)
                   VALUES (:tenant, :branch, :item_id, :actor, :action,
                           CAST(:snapshot AS jsonb))""",
                tenant=parameters["tenant"], branch=parameters["branch"],
                item_id=row[0], actor=str(user_id), action=action,
                snapshot=json.dumps({
                    "name": row[1], "description": row[2],
                    "category_name": row[3], "price_cents": row[4],
                    "image_path": row[5], "available": row[6],
                    "sort_order": row[7], "updated_at": str(row[8]),
                }),
            )
        connection.run("COMMIT")
        return rows
    except Exception as exc:
        logger.warning("online catalog write failed: %s", type(exc).__name__)
        raise HTTPException(status_code=503, detail="Online catalog unavailable") from None
    finally:
        if connection is not None:
            connection.close()


def _catalog(rows, *, role: str | None = None) -> StoreCatalog:
    if not rows:
        raise HTTPException(status_code=404, detail="Store not found")
    first = rows[0]
    items = [
        CatalogItem(
            item_id=UUID(row[4]), name=row[5], description=row[6],
            category_name=row[7], price_cents=row[8], image_path=row[9],
            available=row[10], sort_order=row[11], updated_at=str(row[12]),
        ) for row in rows if row[4] is not None
    ]
    return StoreCatalog(
        tenant_id=UUID(first[0]), branch_id=UUID(first[1]),
        slug=first[2], name=first[3], items=items, role=role,
    )


@router.get("/catalog/stores/{slug}", response_model=StoreCatalog)
def public_catalog(slug: str) -> StoreCatalog:
    if not _SLUG.fullmatch(slug) or len(slug) > 100:
        raise HTTPException(status_code=404, detail="Store not found")
    rows = _read(
        "anon",
        """SELECT b.tenant_id::text, b.branch_id::text, b.slug, b.name,
                  i.item_id::text, i.name, i.description, i.category_name,
                  i.price_cents, i.image_path, i.available, i.sort_order,
                  i.updated_at::text
           FROM gogdely.branches b
           JOIN gogdely.tenants t ON t.tenant_id = b.tenant_id
           LEFT JOIN gogdely.menu_items i
             ON i.tenant_id = b.tenant_id AND i.branch_id = b.branch_id
            AND i.available
           WHERE b.slug = :slug AND b.status = 'active' AND t.status = 'active'
           ORDER BY i.category_name, i.sort_order, i.name""",
        slug=slug,
    )
    return _catalog(rows)


@router.get(
    "/management/tenants/{tenant_id}/branches/{branch_id}/catalog",
    response_model=StoreCatalog,
)
def management_catalog(
    tenant_id: UUID, branch_id: UUID,
    user: AuthenticatedUser = Depends(authenticated_user),
) -> StoreCatalog:
    rows = _read(
        "authenticated",
        """SELECT b.tenant_id::text, b.branch_id::text, b.slug, b.name,
                  i.item_id::text, i.name, i.description, i.category_name,
                  i.price_cents, i.image_path, i.available, i.sort_order,
                  i.updated_at::text, m.role
           FROM gogdely.branches b
           JOIN gogdely.memberships m ON m.tenant_id = b.tenant_id
           LEFT JOIN gogdely.menu_items i
             ON i.tenant_id = b.tenant_id AND i.branch_id = b.branch_id
           WHERE b.tenant_id = :tenant AND b.branch_id = :branch
             AND m.user_id = :subject
           ORDER BY i.category_name, i.sort_order, i.name""",
        user_id=user.user_id,
        tenant=str(tenant_id), branch=str(branch_id), subject=str(user.user_id),
    )
    return _catalog(rows, role=rows[0][13] if rows else None)


@router.post(
    "/management/tenants/{tenant_id}/branches/{branch_id}/catalog",
    response_model=CatalogItem, status_code=201,
)
def create_catalog_item(
    tenant_id: UUID, branch_id: UUID, item: CatalogItemInput,
    user: AuthenticatedUser = Depends(authenticated_user),
) -> CatalogItem:
    branch = authorized_branch(user.user_id, tenant_id, branch_id)
    if branch.role not in ("owner", "manager"):
        raise HTTPException(status_code=403, detail="Catalog editing is not allowed")
    rows = _write_item(
        user.user_id,
        """INSERT INTO gogdely.menu_items
             (tenant_id, branch_id, name, description, category_name,
              price_cents, image_path, available, sort_order)
           VALUES (:tenant, :branch, :name, :description, :category,
                   :price, :image, :available, :sort_order)
           RETURNING item_id::text, name, description, category_name,
                     price_cents, image_path, available, sort_order,
                     updated_at::text""",
        action="created", tenant=str(tenant_id), branch=str(branch_id),
        name=item.name.strip(), description=item.description.strip(),
        category=item.category_name.strip(), price=item.price_cents,
        image=item.image_path, available=item.available,
        sort_order=item.sort_order,
    )
    if not rows:
        raise HTTPException(status_code=503, detail="Online catalog unavailable")
    return CatalogItem(item_id=UUID(rows[0][0]), name=rows[0][1],
                       description=rows[0][2], category_name=rows[0][3],
                       price_cents=rows[0][4], image_path=rows[0][5],
                       available=rows[0][6], sort_order=rows[0][7],
                       updated_at=str(rows[0][8]))


@router.put(
    "/management/tenants/{tenant_id}/branches/{branch_id}/catalog/{item_id}",
    response_model=CatalogItem,
)
def update_catalog_item(
    tenant_id: UUID, branch_id: UUID, item_id: UUID, item: CatalogItemUpdate,
    user: AuthenticatedUser = Depends(authenticated_user),
) -> CatalogItem:
    branch = authorized_branch(user.user_id, tenant_id, branch_id)
    if branch.role not in ("owner", "manager"):
        raise HTTPException(status_code=403, detail="Catalog editing is not allowed")
    rows = _write_item(
        user.user_id,
        """UPDATE gogdely.menu_items
           SET name = :name, description = :description,
               category_name = :category, price_cents = :price,
               image_path = :image, available = :available,
               sort_order = :sort_order,
               updated_at = GREATEST(clock_timestamp(),
                                     updated_at + interval '1 microsecond')
           WHERE tenant_id = :tenant AND branch_id = :branch
             AND item_id = :item_id
             AND updated_at = CAST(:expected AS timestamptz)
           RETURNING item_id::text, name, description, category_name,
                     price_cents, image_path, available, sort_order,
                     updated_at::text""",
        action="updated", tenant=str(tenant_id), branch=str(branch_id),
        item_id=str(item_id), name=item.name.strip(),
        description=item.description.strip(), category=item.category_name.strip(),
        price=item.price_cents, image=item.image_path,
        available=item.available, sort_order=item.sort_order,
        expected=item.expected_updated_at,
    )
    if not rows:
        raise HTTPException(status_code=409, detail="Item changed or unavailable")
    row = rows[0]
    return CatalogItem(
        item_id=UUID(row[0]), name=row[1], description=row[2],
        category_name=row[3], price_cents=row[4], image_path=row[5],
        available=row[6], sort_order=row[7], updated_at=str(row[8]),
    )
