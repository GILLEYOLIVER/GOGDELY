"""Audited Master commands for the isolated homologation database.

All commands require a Supabase-verified, allowlisted AAL2 session. No browser
receives database or Supabase administrative credentials. A transaction changes
the business row and appends an audit event together.
"""

import json
import logging
import re
from contextlib import contextmanager
from decimal import Decimal
from uuid import UUID

import pg8000
from fastapi import APIRouter, Depends, HTTPException
from pydantic import BaseModel, Field, field_validator

from gogdely_api.auth import AuthenticatedUser
from gogdely_api.db_health import configured_database_url, connect_database
from gogdely_api.master_online import require_master

logger = logging.getLogger(__name__)
router = APIRouter(prefix="/api/v1/master", tags=["master"])
_SLUG = re.compile(r"^[a-z0-9]+(?:-[a-z0-9]+)*$")


class CompanyCreate(BaseModel):
    request_id: UUID
    name: str = Field(min_length=2, max_length=120)
    branch_name: str = Field(min_length=2, max_length=120)
    slug: str = Field(min_length=3, max_length=100)
    reason: str = Field(min_length=8, max_length=500)

    @field_validator("name", "branch_name", "reason")
    @classmethod
    def no_blank_text(cls, value: str) -> str:
        value = value.strip()
        if not value:
            raise ValueError("Text cannot be blank")
        return value

    @field_validator("slug")
    @classmethod
    def valid_slug(cls, value: str) -> str:
        if not _SLUG.fullmatch(value):
            raise ValueError("Use lowercase letters, digits and hyphens")
        return value


class CompanyStatusChange(BaseModel):
    request_id: UUID
    status: str
    reason: str = Field(min_length=8, max_length=500)

    @field_validator("status")
    @classmethod
    def valid_status(cls, value: str) -> str:
        if value not in ("active", "suspended"):
            raise ValueError("Invalid company status")
        return value

    @field_validator("reason")
    @classmethod
    def valid_reason(cls, value: str) -> str:
        value = value.strip()
        if len(value) < 8:
            raise ValueError("Reason must have at least 8 characters")
        return value


class OwnerLink(BaseModel):
    request_id: UUID
    email: str = Field(min_length=5, max_length=254)
    reason: str = Field(min_length=8, max_length=500)

    @field_validator("email")
    @classmethod
    def valid_email(cls, value: str) -> str:
        value = value.strip().casefold()
        if not re.fullmatch(r"[^\s@]+@[^\s@]+\.[^\s@]+", value):
            raise ValueError("Invalid email")
        return value

    @field_validator("reason")
    @classmethod
    def valid_reason(cls, value: str) -> str:
        value = value.strip()
        if len(value) < 8:
            raise ValueError("Reason must have at least 8 characters")
        return value


class CommissionChange(BaseModel):
    request_id: UUID
    enabled: bool
    percentage: Decimal = Field(ge=0, le=100, max_digits=5, decimal_places=2)
    reason: str = Field(min_length=8, max_length=500)

    @field_validator("reason")
    @classmethod
    def valid_reason(cls, value: str) -> str:
        value = value.strip()
        if len(value) < 8:
            raise ValueError("Reason must have at least 8 characters")
        return value


@contextmanager
def _transaction():
    database_url = configured_database_url()
    if not database_url:
        raise HTTPException(status_code=503, detail="Master administration unavailable")
    connection = None
    try:
        connection = connect_database(database_url, "gogdely-master-admin")
        connection.run("BEGIN")
        yield connection
        connection.run("COMMIT")
    except HTTPException:
        if connection is not None:
            connection.run("ROLLBACK")
        raise
    except pg8000.DatabaseError as exc:
        if connection is not None:
            connection.run("ROLLBACK")
        fields = exc.args[0] if exc.args else None
        code = fields.get("C") if isinstance(fields, dict) else None
        logger.warning("master command SQLSTATE: %s", code if isinstance(code, str) and re.fullmatch(r"[0-9A-Z]{5}", code) else "unknown")
        if code == "23505":
            raise HTTPException(status_code=409, detail="Request or store slug already exists") from None
        raise HTTPException(status_code=503, detail="Master administration unavailable") from None
    except Exception as exc:
        if connection is not None:
            connection.run("ROLLBACK")
        logger.warning("master command failed: %s", type(exc).__name__)
        raise HTTPException(status_code=503, detail="Master administration unavailable") from None
    finally:
        if connection is not None:
            connection.close()


def _audit(connection, *, request_id: UUID, actor: UUID, tenant: UUID,
           action: str, reason: str, before: dict, after: dict):
    connection.run(
        """INSERT INTO gogdely.master_audit
             (request_id, actor_user_id, tenant_id, action, reason,
              before_state, after_state)
           VALUES (:request, :actor, :tenant, :action, :reason,
                   CAST(:before AS jsonb), CAST(:after AS jsonb))""",
        request=str(request_id), actor=str(actor), tenant=str(tenant),
        action=action, reason=reason.strip(),
        before=json.dumps(before), after=json.dumps(after),
    )


@router.post("/companies", status_code=201)
def create_company(
    command: CompanyCreate,
    user: AuthenticatedUser = Depends(require_master),
) -> dict[str, str]:
    """Create one draft company and branch; never make it public implicitly."""
    with _transaction() as connection:
        tenant = connection.run(
            """INSERT INTO gogdely.tenants (name) VALUES (:name)
               RETURNING tenant_id::text""", name=command.name,
        )[0][0]
        branch = connection.run(
            """INSERT INTO gogdely.branches (tenant_id, slug, name)
               VALUES (:tenant, :slug, :name) RETURNING branch_id::text""",
            tenant=tenant, slug=command.slug, name=command.branch_name,
        )[0][0]
        _audit(connection, request_id=command.request_id, actor=user.user_id,
               tenant=UUID(tenant), action="company.created",
               reason=command.reason, before={},
               after={"name": command.name, "branch": command.branch_name,
                      "slug": command.slug, "status": "draft"})
    return {"tenant_id": tenant, "branch_id": branch, "status": "draft"}


@router.post("/companies/{tenant_id}/owner")
def link_confirmed_owner(
    tenant_id: UUID, command: OwnerLink,
    user: AuthenticatedUser = Depends(require_master),
) -> dict[str, str]:
    """Link an existing email-confirmed Auth user; never create a login here."""
    with _transaction() as connection:
        tenant = connection.run(
            "SELECT status FROM gogdely.tenants WHERE tenant_id = :tenant FOR UPDATE",
            tenant=str(tenant_id),
        )
        if not tenant:
            raise HTTPException(status_code=404, detail="Company not found")
        if tenant[0][0] != "draft":
            raise HTTPException(status_code=409, detail="Only draft companies can receive their initial owner")
        existing = connection.run(
            """SELECT count(*) FROM gogdely.memberships
               WHERE tenant_id = :tenant AND role = 'owner'""",
            tenant=str(tenant_id),
        )[0][0]
        if existing:
            raise HTTPException(status_code=409, detail="Company already has an owner")
        users = connection.run(
            """SELECT id::text FROM auth.users
               WHERE lower(email) = :email AND email_confirmed_at IS NOT NULL""",
            email=command.email,
        )
        if len(users) != 1:
            raise HTTPException(status_code=404, detail="Confirmed account not found")
        owner_id = users[0][0]
        connection.run(
            """INSERT INTO gogdely.memberships (tenant_id, user_id, role)
               VALUES (:tenant, :owner, 'owner')""",
            tenant=str(tenant_id), owner=owner_id,
        )
        connection.run(
            """INSERT INTO gogdely.membership_branches
               (tenant_id, user_id, branch_id)
               SELECT tenant_id, :owner, branch_id FROM gogdely.branches
               WHERE tenant_id = :tenant""",
            tenant=str(tenant_id), owner=owner_id,
        )
        _audit(connection, request_id=command.request_id, actor=user.user_id,
               tenant=tenant_id, action="company.owner_linked",
               reason=command.reason, before={},
               after={"owner_user_id": owner_id})
    return {"tenant_id": str(tenant_id), "owner_user_id": owner_id}


@router.patch("/companies/{tenant_id}/status")
def change_company_status(
    tenant_id: UUID, command: CompanyStatusChange,
    user: AuthenticatedUser = Depends(require_master),
) -> dict[str, str]:
    with _transaction() as connection:
        rows = connection.run(
            "SELECT status FROM gogdely.tenants WHERE tenant_id = :tenant FOR UPDATE",
            tenant=str(tenant_id),
        )
        if not rows:
            raise HTTPException(status_code=404, detail="Company not found")
        before = rows[0][0]
        if before == command.status:
            raise HTTPException(status_code=409, detail="Company already has this status")
        if command.status == "active":
            owners = connection.run(
                """SELECT count(*) FROM gogdely.memberships
                   WHERE tenant_id = :tenant AND role = 'owner'""",
                tenant=str(tenant_id),
            )[0][0]
            if not owners:
                raise HTTPException(status_code=409, detail="An owner must accept the invitation before activation")
        connection.run(
            "UPDATE gogdely.tenants SET status = :status WHERE tenant_id = :tenant",
            status=command.status, tenant=str(tenant_id),
        )
        if command.status == "active":
            connection.run(
                """UPDATE gogdely.branches SET status = 'active'
                   WHERE tenant_id = :tenant AND status = 'draft'""",
                tenant=str(tenant_id),
            )
        _audit(connection, request_id=command.request_id, actor=user.user_id,
               tenant=tenant_id, action="company.status_changed",
               reason=command.reason, before={"status": before},
               after={"status": command.status})
    return {"tenant_id": str(tenant_id), "status": command.status}


@router.get("/companies/{tenant_id}/commission")
def get_commission(
    tenant_id: UUID, _: AuthenticatedUser = Depends(require_master),
) -> dict:
    with _transaction() as connection:
        rows = connection.run(
            """SELECT t.tenant_id::text, COALESCE(c.enabled, false),
                      COALESCE(c.percentage, 0)::text
               FROM gogdely.tenants t
               LEFT JOIN gogdely.tenant_commission_settings c
                 ON c.tenant_id = t.tenant_id
               WHERE t.tenant_id = :tenant""", tenant=str(tenant_id),
        )
    if not rows:
        raise HTTPException(status_code=404, detail="Company not found")
    return {"tenant_id": rows[0][0], "enabled": rows[0][1],
            "percentage": rows[0][2], "automatic_collection": False}


@router.patch("/companies/{tenant_id}/commission")
def change_commission(
    tenant_id: UUID, command: CommissionChange,
    user: AuthenticatedUser = Depends(require_master),
) -> dict:
    """Save policy only. No Pix, split or automatic collection is implied."""
    with _transaction() as connection:
        tenant = connection.run(
            "SELECT tenant_id FROM gogdely.tenants WHERE tenant_id = :tenant FOR UPDATE",
            tenant=str(tenant_id),
        )
        if not tenant:
            raise HTTPException(status_code=404, detail="Company not found")
        previous = connection.run(
            """SELECT enabled, percentage::text
               FROM gogdely.tenant_commission_settings
               WHERE tenant_id = :tenant""", tenant=str(tenant_id),
        )
        before = {"enabled": previous[0][0], "percentage": previous[0][1]} if previous else {"enabled": False, "percentage": "0"}
        connection.run(
            """INSERT INTO gogdely.tenant_commission_settings
               (tenant_id, enabled, percentage, updated_by)
               VALUES (:tenant, :enabled, :percentage, :actor)
               ON CONFLICT (tenant_id) DO UPDATE SET
                 enabled = EXCLUDED.enabled,
                 percentage = EXCLUDED.percentage,
                 updated_by = EXCLUDED.updated_by,
                 updated_at = now()""",
            tenant=str(tenant_id), enabled=command.enabled,
            percentage=command.percentage, actor=str(user.user_id),
        )
        after = {"enabled": command.enabled,
                 "percentage": str(command.percentage)}
        _audit(connection, request_id=command.request_id, actor=user.user_id,
               tenant=tenant_id, action="commission.changed",
               reason=command.reason, before=before, after=after)
    return {"tenant_id": str(tenant_id), **after, "automatic_collection": False}


@router.get("/audit")
def audit_events(
    _: AuthenticatedUser = Depends(require_master),
) -> list[dict]:
    with _transaction() as connection:
        rows = connection.run(
            """SELECT audit_id, actor_user_id::text, tenant_id::text, action,
                      reason, before_state::text, after_state::text,
                      created_at::text
               FROM gogdely.master_audit ORDER BY audit_id DESC LIMIT 100"""
        )
    return [{"id": row[0], "actor_user_id": row[1], "tenant_id": row[2],
             "action": row[3], "reason": row[4], "before": json.loads(row[5]),
             "after": json.loads(row[6]), "created_at": row[7]}
            for row in rows]
