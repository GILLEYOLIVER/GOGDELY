"""Verify Supabase user identity before any tenant-scoped API operation.

This is deliberately limited to identity. Tenant and branch authorization must
come from server-side memberships, never from claims supplied by the caller.
"""

import json
import os
import re
import ssl
from dataclasses import dataclass
from http.client import HTTPException as HTTPClientException, HTTPSConnection
from urllib.parse import urlsplit
from uuid import UUID

from fastapi import Header, HTTPException, status

_MAX_TOKEN_LENGTH = 8192
_MAX_USER_RESPONSE_BYTES = 16384
_JWT_PATTERN = re.compile(r"[A-Za-z0-9_-]+\.[A-Za-z0-9_-]+\.[A-Za-z0-9_-]+")


@dataclass(frozen=True)
class AuthenticatedUser:
    user_id: UUID


def _auth_error() -> HTTPException:
    return HTTPException(
        status_code=status.HTTP_401_UNAUTHORIZED,
        detail="Invalid or missing access token",
        headers={"WWW-Authenticate": "Bearer"},
    )


def _auth_unavailable() -> HTTPException:
    return HTTPException(
        status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
        detail="Identity verification is unavailable",
    )


def _supabase_host() -> tuple[str, str]:
    """Accept only the configured project's HTTPS Auth host.

    The URL is server configuration, not request input. Restricting its shape
    also prevents accidental token forwarding to an unrelated destination.
    """
    configured = os.environ.get("GOGDELY_SUPABASE_URL", "")
    publishable_key = os.environ.get("GOGDELY_SUPABASE_PUBLISHABLE_KEY", "")
    try:
        parsed = urlsplit(configured)
        host = parsed.hostname or ""
        port = parsed.port
    except ValueError:
        raise _auth_unavailable() from None
    if (
        parsed.scheme != "https"
        or not re.fullmatch(r"[a-z0-9-]+\.supabase\.co", host)
        or parsed.username is not None
        or parsed.password is not None
        or port is not None
        or parsed.path not in ("", "/")
        or parsed.query
        or parsed.fragment
        or not publishable_key.strip()
    ):
        raise _auth_unavailable()
    return host, publishable_key


def authenticated_user(authorization: str | None = Header(default=None)) -> AuthenticatedUser:
    """Ask Supabase Auth to verify the bearer and return its trusted user ID.

    Auth's /user endpoint handles both symmetric and asymmetric signing keys.
    The API never decodes an unverified JWT or uses its tenant/role claims.
    """
    if not authorization:
        raise _auth_error()
    scheme, separator, token = authorization.partition(" ")
    if (
        not separator
        or scheme.lower() != "bearer"
        or len(token) > _MAX_TOKEN_LENGTH
        or not _JWT_PATTERN.fullmatch(token)
    ):
        raise _auth_error()

    host, publishable_key = _supabase_host()
    connection = None
    try:
        connection = HTTPSConnection(host, timeout=3, context=ssl.create_default_context())
        connection.request(
            "GET",
            "/auth/v1/user",
            headers={
                "apikey": publishable_key,
                "Authorization": f"Bearer {token}",
                "Accept": "application/json",
            },
        )
        response = connection.getresponse()
        if response.status in (400, 401, 403):
            raise _auth_error()
        if response.status != 200:
            raise _auth_unavailable()
        payload = response.read(_MAX_USER_RESPONSE_BYTES + 1)
        if len(payload) > _MAX_USER_RESPONSE_BYTES:
            raise _auth_unavailable()
        data = json.loads(payload)
        if not isinstance(data, dict) or not isinstance(data.get("id"), str):
            raise _auth_unavailable()
        return AuthenticatedUser(user_id=UUID(data["id"]))
    except HTTPException:
        raise
    except (OSError, HTTPClientException, ValueError):
        raise _auth_unavailable() from None
    finally:
        if connection is not None:
            connection.close()
