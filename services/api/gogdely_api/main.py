"""GOGDELY API for the isolated cloud foundation and local demonstration."""

import logging
import os
from contextlib import asynccontextmanager
from pathlib import Path
from uuid import UUID

from fastapi import Depends, FastAPI, HTTPException, Request
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import JSONResponse, PlainTextResponse
from fastapi.staticfiles import StaticFiles
from pydantic import BaseModel

from gogdely_api.auth import AuthenticatedUser, authenticated_user, _supabase_host
from gogdely_api.config import config
from gogdely_api.db_health import configured_database_url, foundation_ready
from gogdely_api.homologation_migrations import main as migrate_homologation
from gogdely_api.local_orders import router as local_router
from gogdely_api.master_local import router as master_router
from gogdely_api.master_admin import router as master_admin_router
from gogdely_api.master_online import router as online_master_router
from gogdely_api.memberships import (
    AuthorizedBranch, StoreMembership, authorized_branch, list_memberships,
)
from gogdely_api.online_catalog import router as online_catalog_router
from gogdely_api.online_demo_orders import router as online_demo_orders_router
from gogdely_api.online_tables import router as online_tables_router
from gogdely_api.table_settings import router as table_settings_router
from gogdely_api.web_seo import https_and_security_middleware, router as seo_router

@asynccontextmanager
async def lifespan(_app: FastAPI):
    # The free Render service cannot use a pre-deploy job. Block activation of
    # the new API until the isolated fictitious database has been migrated.
    if os.environ.get("RENDER_SERVICE_ID") == "srv-dba163mq1p3s739u6k00" and os.environ.get("RENDER_GIT_BRANCH") == "main":
        migrate_homologation()
    yield


app = FastAPI(title="GOGDELY API", version="0.1.0", docs_url="/docs", lifespan=lifespan)
logger = logging.getLogger(__name__)
app.add_middleware(
    CORSMiddleware,
    allow_origins=config.cors_extra_origins,
    allow_origin_regex=r"^https?://(127\.0\.0\.1|localhost)(:\d+)?$",
    allow_methods=["GET", "POST", "PATCH", "PUT"],
    allow_headers=["content-type", "authorization"],
)
app.include_router(seo_router)
app.include_router(local_router)
app.include_router(master_router)
app.include_router(online_master_router)
app.include_router(master_admin_router)
app.include_router(online_catalog_router)
app.include_router(online_demo_orders_router)
app.include_router(online_tables_router)
app.include_router(table_settings_router)
app.middleware("http")(https_and_security_middleware)


@app.middleware("http")
async def local_demo_boundary(request: Request, call_next):
    """Deny every local demo route in a hosted environment, including new ones."""
    if request.url.path.startswith("/api/v1/local/") and (
        os.environ.get("GOGDELY_ENV") != "local"
        or os.environ.get("GOGDELY_LOCAL_DEMO") != "1"
    ):
        return JSONResponse({"detail": "Local demo disabled"}, status_code=404)
    return await call_next(request)


class LocalPwaStaticFiles(StaticFiles):
    """Revalidate local PWA files whenever the browser opens the app."""

    async def get_response(self, path, scope):
        response = await super().get_response(path, scope)
        response.headers["Cache-Control"] = "no-cache, max-age=0, must-revalidate"
        return response


def local_pwa_build_version(bundle: Path) -> str:
    """Change the version when a completed Flutter build replaces its bundle."""
    files = (bundle / "main.dart.js", bundle / "flutter_bootstrap.js",
             bundle / "assets" / "AssetManifest.bin")
    if not files[0].is_file():
        raise FileNotFoundError(files[0])
    return ":".join(
        f"{path.stat().st_mtime_ns:x}-{path.stat().st_size:x}"
        for path in files if path.is_file()
    )


class HealthResponse(BaseModel):
    status: str
    service: str
    version: str


@app.get("/health", response_model=HealthResponse, tags=["system"])
def health() -> HealthResponse:
    return HealthResponse(status="ok", service="gogdely-api", version="0.1.0")


@app.get("/api/v1/info", tags=["system"])
def api_info() -> dict[str, str]:
    return {
        "name": "GOGDELY",
        "api_version": "v1",
        "environment": os.environ.get("GOGDELY_ENV", "local"),
        "storage": "managed-database-configured" if config.uses_managed_database else "sqlite-local-demo",
    }


@app.get("/api/v1/client-config", tags=["system"])
def client_config() -> dict[str, str]:
    """Public Supabase Auth configuration for hosted clients; never a secret key."""
    host, publishable_key = _supabase_host()
    return {"supabase_url": f"https://{host}",
            "supabase_publishable_key": publishable_key}


class IdentityResponse(BaseModel):
    user_id: UUID


@app.get("/api/v1/auth/me", response_model=IdentityResponse, tags=["identity"])
def current_identity(user: AuthenticatedUser = Depends(authenticated_user)) -> IdentityResponse:
    """Expose only the ID confirmed by Supabase Auth, never JWT claims."""
    return IdentityResponse(user_id=user.user_id)


@app.get("/api/v1/auth/memberships", response_model=list[StoreMembership], tags=["identity"])
def current_memberships(
    user: AuthenticatedUser = Depends(authenticated_user),
) -> list[StoreMembership]:
    """Return only the verified user's stores and permitted branches."""
    return list_memberships(user.user_id)


@app.get(
    "/api/v1/management/tenants/{tenant_id}/branches/{branch_id}/context",
    response_model=AuthorizedBranch,
    tags=["management"],
)
def management_branch_context(
    tenant_id: UUID,
    branch_id: UUID,
    user: AuthenticatedUser = Depends(authenticated_user),
) -> AuthorizedBranch:
    """Resolve one branch only through the verified user's live RLS scope."""
    return authorized_branch(user.user_id, tenant_id, branch_id)


@app.get("/version.json", tags=["system"])
def version() -> JSONResponse:
    return JSONResponse(
        {"commit": os.environ.get("RENDER_GIT_COMMIT", "unknown")},
        headers={"Cache-Control": "no-store"},
    )


@app.get("/ready", tags=["system"])
def ready() -> dict[str, str]:
    """Readiness is unavailable until the reviewed schema is installed."""
    database_url = configured_database_url()
    if not database_url:
        missing = [
            key for key in (
                "GOGDELY_DATABASE_HOST",
                "GOGDELY_DATABASE_USER",
                "GOGDELY_DATABASE_PASSWORD",
            ) if not os.environ.get(key)
        ]
        logger.warning("database readiness configuration is incomplete: %s", ", ".join(missing))
        raise HTTPException(status_code=503, detail="managed database is not ready")
    if not foundation_ready(database_url):
        raise HTTPException(status_code=503, detail="managed database is not ready")
    return {"status": "ready", "service": "gogdely-api"}


# The opt-in local PWA shares an HTTPS origin with the demo API. Its static
# bundle is never mounted by normal API, test, staging or production launches.
_local_pwa_dir = os.environ.get("GOGDELY_LOCAL_PWA_DIR", "")
_local_courier_dir = os.environ.get("GOGDELY_LOCAL_COURIER_DIR", "")
if _local_pwa_dir:
    if config.environment != "local" or not config.local_demo_enabled:
        raise RuntimeError("Local PWA requires the local SQLite demo environment")
    _bundle = Path(_local_pwa_dir).resolve()
    if not (_bundle / "index.html").is_file():
        raise RuntimeError("Local PWA bundle is missing; build Flutter web first")

    @app.get("/api/v1/local/pwa-version", include_in_schema=False)
    def local_pwa_version() -> PlainTextResponse:
        try:
            build_version = local_pwa_build_version(_bundle)
        except FileNotFoundError as exc:
            raise HTTPException(status_code=503, detail="Local PWA build is unavailable") from exc
        return PlainTextResponse(build_version, headers={"Cache-Control": "no-store"})

    if _local_courier_dir:
        _courier_bundle = Path(_local_courier_dir).resolve()
        if not (_courier_bundle / "index.html").is_file():
            raise RuntimeError("Local courier bundle is missing; build Flutter web first")
        app.mount("/entregador", LocalPwaStaticFiles(directory=_courier_bundle, html=True),
                  name="local-courier-preview")
    app.mount("/", LocalPwaStaticFiles(directory=_bundle, html=True), name="local-pwa")
