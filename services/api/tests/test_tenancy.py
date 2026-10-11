"""Tenant isolation unit tests. Not a substitute for PostgreSQL RLS tests."""
import pytest
from fastapi import HTTPException
from gogdely_api.tenant_demo import (
    TENANT_A, TENANT_B, USER_A, USER_B, BRANCH_A, BRANCH_B, demo_authorizer,
)


def test_user_can_access_own_tenant_and_branch():
    auth = demo_authorizer()
    assert auth.require_membership(user_id=USER_A, tenant_id=TENANT_A).role == "manager"
    assert auth.require_branch(user_id=USER_A, tenant_id=TENANT_A, branch=BRANCH_A).tenant_id == TENANT_A


def test_cross_tenant_access_is_denied():
    with pytest.raises(HTTPException) as err:
        demo_authorizer().require_membership(user_id=USER_A, tenant_id=TENANT_B)
    assert err.value.status_code == 403


def test_cross_tenant_branch_is_denied():
    with pytest.raises(HTTPException) as err:
        demo_authorizer().require_branch(user_id=USER_A, tenant_id=TENANT_A, branch=BRANCH_B)
    assert err.value.status_code == 403


def test_other_user_is_denied():
    with pytest.raises(HTTPException) as err:
        demo_authorizer().require_membership(user_id=USER_B, tenant_id=TENANT_A)
    assert err.value.status_code == 403
