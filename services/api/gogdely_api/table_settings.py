"""Branch-scoped payment preference for table orders (no fake settlement)."""

import logging
from uuid import UUID

from fastapi import APIRouter, Depends, HTTPException
from pydantic import BaseModel

from gogdely_api.auth import AuthenticatedUser, authenticated_user
from gogdely_api.db_health import configured_database_url, connect_database
from gogdely_api.memberships import authorized_branch

router = APIRouter(prefix="/api/v1/management", tags=["table-settings"])
logger = logging.getLogger(__name__)


class TablePaymentPreference(BaseModel):
    allow_online_payment: bool = False
    online_payment_available: bool = False


class TablePaymentChange(BaseModel):
    allow_online_payment: bool


def _query(user_id: UUID, statement: str, *, write: bool = False, **parameters):
    database_url = configured_database_url()
    if not database_url:
        raise HTTPException(status_code=503, detail="Table settings unavailable")
    connection = None
    try:
        connection = connect_database(database_url, "gogdely-table-settings")
        connection.run("BEGIN" if write else "BEGIN READ ONLY")
        connection.run("SELECT set_config('request.jwt.claim.sub', :subject, true)",
                       subject=str(user_id))
        connection.run("SET LOCAL ROLE authenticated")
        rows = connection.run(statement, **parameters)
        connection.run("COMMIT")
        return rows
    except Exception as exc:
        logger.warning("table settings query failed: %s", type(exc).__name__)
        raise HTTPException(status_code=503, detail="Table settings unavailable") from None
    finally:
        if connection is not None:
            connection.close()


@router.get("/tenants/{tenant_id}/branches/{branch_id}/table-payment",
            response_model=TablePaymentPreference)
def read_table_payment(
    tenant_id: UUID, branch_id: UUID,
    user: AuthenticatedUser = Depends(authenticated_user),
) -> TablePaymentPreference:
    authorized_branch(user.user_id, tenant_id, branch_id)
    rows = _query(user.user_id,
        """SELECT allow_online_payment FROM gogdely.table_settings
           WHERE tenant_id = :tenant AND branch_id = :branch""",
        tenant=str(tenant_id), branch=str(branch_id))
    return TablePaymentPreference(allow_online_payment=bool(rows and rows[0][0]))


@router.put("/tenants/{tenant_id}/branches/{branch_id}/table-payment",
            response_model=TablePaymentPreference)
def change_table_payment(
    tenant_id: UUID, branch_id: UUID, change: TablePaymentChange,
    user: AuthenticatedUser = Depends(authenticated_user),
) -> TablePaymentPreference:
    branch = authorized_branch(user.user_id, tenant_id, branch_id)
    if branch.role not in ("owner", "manager"):
        raise HTTPException(status_code=403, detail="Table settings change is not allowed")
    rows = _query(user.user_id,
        """INSERT INTO gogdely.table_settings
             (tenant_id, branch_id, allow_online_payment, updated_by)
           VALUES (:tenant, :branch, :enabled, :actor)
           ON CONFLICT (tenant_id, branch_id) DO UPDATE
           SET allow_online_payment = EXCLUDED.allow_online_payment,
               updated_by = EXCLUDED.updated_by, updated_at = now()
           RETURNING allow_online_payment""",
        write=True, tenant=str(tenant_id), branch=str(branch_id),
        enabled=change.allow_online_payment, actor=str(user.user_id))
    if not rows:
        raise HTTPException(status_code=503, detail="Table settings unavailable")
    return TablePaymentPreference(allow_online_payment=bool(rows[0][0]))
