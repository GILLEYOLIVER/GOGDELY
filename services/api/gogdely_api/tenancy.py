"""Tenant-scoped demo services. NOT production authentication or persistence."""
from dataclasses import dataclass
from uuid import UUID

from fastapi import HTTPException, status


@dataclass(frozen=True)
class Membership:
    user_id: UUID
    tenant_id: UUID
    branch_ids: frozenset[UUID]
    role: str


@dataclass(frozen=True)
class Branch:
    id: UUID
    tenant_id: UUID
    name: str


class TenantAuthorizer:
    """Deny by default; memberships must come from a trusted server-side source."""

    def __init__(self, memberships: list[Membership]):
        self._memberships = tuple(memberships)

    def require_membership(self, *, user_id: UUID, tenant_id: UUID) -> Membership:
        for member in self._memberships:
            if member.user_id == user_id and member.tenant_id == tenant_id:
                return member
        raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail="Access denied")

    def require_branch(self, *, user_id: UUID, tenant_id: UUID, branch: Branch) -> Membership:
        member = self.require_membership(user_id=user_id, tenant_id=tenant_id)
        if branch.tenant_id != tenant_id or branch.id not in member.branch_ids:
            raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail="Access denied")
        return member
