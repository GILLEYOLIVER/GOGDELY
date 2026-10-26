"""Read a verified user's store memberships under the authenticated RLS role."""

import logging
from uuid import UUID

from fastapi import HTTPException
from pydantic import BaseModel

from gogdely_api.db_health import configured_database_url, connect_database

logger = logging.getLogger(__name__)


class BranchMembership(BaseModel):
    branch_id: UUID
    name: str


class StoreMembership(BaseModel):
    tenant_id: UUID
    name: str
    role: str
    branches: list[BranchMembership]


class AuthorizedBranch(BaseModel):
    tenant_id: UUID
    tenant_name: str
    branch_id: UUID
    branch_name: str
    role: str


def _query_as_user(user_id: UUID, statement: str, **parameters):
    """Keep the verified Auth subject and RLS role inside one DB transaction."""
    database_url = configured_database_url()
    if not database_url:
        raise HTTPException(status_code=503, detail="Membership lookup is unavailable")
    connection = None
    try:
        connection = connect_database(database_url, "gogdely-memberships")
        connection.run("BEGIN")
        # The subject is taken only from Supabase Auth /user, never from request
        # JSON or unverified token claims. Scope is transaction-local.
        connection.run(
            "SELECT set_config('request.jwt.claim.sub', :subject, true)",
            subject=str(user_id),
        )
        connection.run("SET LOCAL ROLE authenticated")
        rows = connection.run(statement, subject=str(user_id), **parameters)
        connection.run("COMMIT")
        return rows
    except Exception as exc:
        # Driver errors may contain the connection string, user data or SQL.
        logger.warning("membership lookup failed: %s", type(exc).__name__)
        raise HTTPException(status_code=503, detail="Membership lookup is unavailable") from None
    finally:
        if connection is not None:
            connection.close()


def list_memberships(user_id: UUID) -> list[StoreMembership]:
    """Fail closed if the database or reviewed read policies are unavailable."""
    rows = _query_as_user(
        user_id,
        """SELECT m.tenant_id::text, t.name, m.role,
                  b.branch_id::text, b.name
           FROM gogdely.memberships AS m
           JOIN gogdely.tenants AS t ON t.tenant_id = m.tenant_id
           LEFT JOIN gogdely.branches AS b ON b.tenant_id = m.tenant_id
           WHERE m.user_id = :subject
           ORDER BY t.name, b.name""",
    )
    stores: dict[str, StoreMembership] = {}
    for tenant_id, tenant_name, role, branch_id, branch_name in rows:
        if tenant_id not in stores:
            stores[tenant_id] = StoreMembership(
                tenant_id=UUID(tenant_id), name=tenant_name, role=role, branches=[],
            )
        if branch_id is not None:
            stores[tenant_id].branches.append(
                BranchMembership(branch_id=UUID(branch_id), name=branch_name)
            )
    return list(stores.values())


def authorized_branch(user_id: UUID, tenant_id: UUID, branch_id: UUID) -> AuthorizedBranch:
    """Resolve a management branch through RLS, hiding absent and foreign IDs alike."""
    rows = _query_as_user(
        user_id,
        """SELECT t.tenant_id::text, t.name, b.branch_id::text, b.name, m.role
           FROM gogdely.branches AS b
           JOIN gogdely.tenants AS t ON t.tenant_id = b.tenant_id
           JOIN gogdely.memberships AS m ON m.tenant_id = b.tenant_id
           WHERE b.tenant_id = :tenant AND b.branch_id = :branch
             AND m.user_id = :subject AND t.status <> 'suspended'
           LIMIT 1""",
        tenant=str(tenant_id), branch=str(branch_id),
    )
    if not rows:
        raise HTTPException(status_code=404, detail="Branch not found")
    tenant, tenant_name, branch, branch_name, role = rows[0]
    return AuthorizedBranch(
        tenant_id=UUID(tenant), tenant_name=tenant_name,
        branch_id=UUID(branch), branch_name=branch_name, role=role,
    )
