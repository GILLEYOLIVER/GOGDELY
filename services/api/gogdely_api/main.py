"""GOGDELY API bootstrap.

No external services, database, payments or production integration.
"""
from uuid import UUID

from fastapi import Depends, FastAPI
from pydantic import BaseModel

from gogdely_api.auth import AuthenticatedUser, authenticated_user

app = FastAPI(title="GOGDELY API", version="0.1.0", docs_url="/docs")


class HealthResponse(BaseModel):
    status: str
    service: str
    version: str


@app.get("/health", response_model=HealthResponse, tags=["system"])
def health() -> HealthResponse:
    return HealthResponse(status="ok", service="gogdely-api", version="0.1.0")


@app.get("/api/v1/info", tags=["system"])
def api_info() -> dict[str, str]:
    return {"name": "GOGDELY", "api_version": "v1", "environment": "local-demo"}


class IdentityResponse(BaseModel):
    user_id: UUID


@app.get("/api/v1/auth/me", response_model=IdentityResponse, tags=["identity"])
def current_identity(user: AuthenticatedUser = Depends(authenticated_user)) -> IdentityResponse:
    """Expose only the ID confirmed by Supabase Auth, never JWT claims."""
    return IdentityResponse(user_id=user.user_id)
