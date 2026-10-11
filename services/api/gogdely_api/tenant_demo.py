"""Deterministic in-memory tenancy fixture for local tests only.

No HTTP routes or user-controlled identity headers are exposed.
"""
from uuid import UUID
from .tenancy import Branch, Membership, TenantAuthorizer

TENANT_A = UUID("00000000-0000-4000-8000-000000000001")
TENANT_B = UUID("00000000-0000-4000-8000-000000000002")
USER_A = UUID("00000000-0000-4000-8000-000000000011")
USER_B = UUID("00000000-0000-4000-8000-000000000012")
BRANCH_A = Branch(UUID("00000000-0000-4000-8000-000000000021"), TENANT_A, "Unidade A")
BRANCH_B = Branch(UUID("00000000-0000-4000-8000-000000000022"), TENANT_B, "Unidade B")


def demo_authorizer() -> TenantAuthorizer:
    return TenantAuthorizer([
        Membership(USER_A, TENANT_A, frozenset({BRANCH_A.id}), "manager"),
        Membership(USER_B, TENANT_B, frozenset({BRANCH_B.id}), "manager"),
    ])
