"""Authenticated table QR links to the public hosted catalog."""

import os
from urllib.parse import urlencode, urlsplit, urlunsplit
from uuid import UUID

import qrcode
from fastapi import APIRouter, Depends, HTTPException
from pydantic import BaseModel, Field

from gogdely_api.auth import AuthenticatedUser, authenticated_user
from gogdely_api.memberships import authorized_branch
from gogdely_api.online_catalog import _read

router = APIRouter(prefix="/api/v1/management", tags=["online-tables"])


class TableQr(BaseModel):
    table_number: int = Field(ge=1, le=999)
    url: str
    matrix: list[list[bool]]


def _client_base() -> str:
    configured = os.environ.get("GOGDELY_CLIENT_PWA_URL", "")
    parts = urlsplit(configured)
    if (parts.scheme != "https" or not parts.netloc or parts.username or
            parts.password or parts.query or parts.fragment or
            not parts.path.rstrip("/").endswith("/cliente")):
        raise HTTPException(status_code=503, detail="Public client link unavailable")
    return urlunsplit((parts.scheme, parts.netloc, parts.path.rstrip("/") + "/", "", ""))


@router.get(
    "/tenants/{tenant_id}/branches/{branch_id}/tables/{table_number}/qr",
    response_model=TableQr,
)
def table_qr(
    tenant_id: UUID,
    branch_id: UUID,
    table_number: int,
    user: AuthenticatedUser = Depends(authenticated_user),
) -> TableQr:
    if not 1 <= table_number <= 999:
        raise HTTPException(status_code=422, detail="Invalid table number")
    authorized_branch(user.user_id, tenant_id, branch_id)
    base = _client_base()
    rows = _read(
        "authenticated",
        """SELECT slug FROM gogdely.branches
           WHERE tenant_id = :tenant AND branch_id = :branch""",
        user_id=user.user_id, tenant=str(tenant_id), branch=str(branch_id),
    )
    if not rows:
        raise HTTPException(status_code=404, detail="Branch not found")
    url = f"{base}?{urlencode({'loja': rows[0][0], 'mesa': table_number})}"
    code = qrcode.QRCode(error_correction=qrcode.constants.ERROR_CORRECT_M,
                         border=4, box_size=1)
    code.add_data(url)
    code.make(fit=True)
    return TableQr(table_number=table_number, url=url, matrix=code.get_matrix())
