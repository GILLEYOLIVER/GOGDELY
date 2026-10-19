"""Fail-closed platform overview for the hosted Master application.

The Master identity is verified by Supabase Auth, restricted to configured
user IDs and required to have a verified second factor. These read-only
endpoints never expose local demo data or mutate a tenant.
"""

import base64
import json
import logging
import os
from uuid import UUID

from fastapi import APIRouter, Depends, Header, HTTPException
from pydantic import BaseModel

from gogdely_api.auth import AuthenticatedUser, authenticated_user
from gogdely_api.db_health import configured_database_url, connect_database

logger = logging.getLogger(__name__)
router = APIRouter(prefix="/api/v1/master", tags=["master"])


class MasterOverview(BaseModel):
    companies: int
    active_companies: int
    branches: int
    orders: int


class MasterCompany(BaseModel):
    tenant_id: UUID
    name: str
    status: str
    branches: int
    created_at: str


def _allowed_user(user: AuthenticatedUser) -> AuthenticatedUser:
    """Restrict platform access to explicit Auth user IDs, never email text."""
    configured = os.environ.get("GOGDELY_MASTER_USER_IDS", "")
    try:
        allowed = {UUID(value.strip()) for value in configured.split(",") if value.strip()}
    except ValueError:
        raise HTTPException(status_code=503, detail="Master access is unavailable") from None
    if not allowed:
        raise HTTPException(status_code=503, detail="Master access is unavailable")
    if user.user_id not in allowed:
        raise HTTPException(status_code=403, detail="Master access denied")
    return user


@router.get("/eligibility")
def eligibility(user: AuthenticatedUser = Depends(authenticated_user)) -> dict[str, bool]:
    """Check authorization before asking a non-admin to enroll a MFA factor."""
    _allowed_user(user)
    return {"eligible": True}


def require_master(
    user: AuthenticatedUser = Depends(authenticated_user),
    authorization: str | None = Header(default=None),
) -> AuthenticatedUser:
    """Require the allowlist and Supabase AAL2 on every data request.

    The bearer was already validated with Supabase Auth by authenticated_user.
    Only then may its AAL claim be read.
    """
    _allowed_user(user)
    try:
        token = (authorization or "").split(" ", 1)[1]
        encoded = token.split(".")[1]
        payload = json.loads(base64.urlsafe_b64decode(encoded + "=" * (-len(encoded) % 4)))
    except (IndexError, ValueError, UnicodeDecodeError, TypeError):
        raise HTTPException(status_code=403, detail="MFA required") from None
    if payload.get("sub") != str(user.user_id) or payload.get("aal") != "aal2":
        raise HTTPException(status_code=403, detail="MFA required")
    return user


def _read(statement: str):
    database_url = configured_database_url()
    if not database_url:
        raise HTTPException(status_code=503, detail="Master data is unavailable")
    connection = None
    try:
        connection = connect_database(database_url, "gogdely-master-read")
        return connection.run(statement)
    except Exception as exc:
        logger.warning("master read failed: %s", type(exc).__name__)
        raise HTTPException(status_code=503, detail="Master data is unavailable") from None
    finally:
        if connection is not None:
            connection.close()


@router.get("/overview", response_model=MasterOverview)
def overview(_: AuthenticatedUser = Depends(require_master)) -> MasterOverview:
    rows = _read(
        """SELECT (SELECT count(*) FROM gogdely.tenants),
                  (SELECT count(*) FROM gogdely.tenants WHERE status = 'active'),
                  (SELECT count(*) FROM gogdely.branches),
                  (SELECT count(*) FROM gogdely.orders)"""
    )
    return MasterOverview(
        companies=rows[0][0], active_companies=rows[0][1],
        branches=rows[0][2], orders=rows[0][3],
    )


@router.get("/companies", response_model=list[MasterCompany])
def companies(_: AuthenticatedUser = Depends(require_master)) -> list[MasterCompany]:
    rows = _read(
        """SELECT t.tenant_id::text, t.name, t.status,
                  count(b.branch_id)::int, t.created_at::text
           FROM gogdely.tenants AS t
           LEFT JOIN gogdely.branches AS b ON b.tenant_id = t.tenant_id
           GROUP BY t.tenant_id, t.name, t.status, t.created_at
           ORDER BY t.created_at DESC, t.name LIMIT 200"""
    )
    return [MasterCompany(tenant_id=UUID(row[0]), name=row[1], status=row[2],
                          branches=row[3], created_at=row[4]) for row in rows]
