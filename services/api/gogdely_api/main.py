"""GOGDELY API for the isolated cloud foundation and local demonstration."""

import logging
import os
from pathlib import Path
from urllib.parse import quote
from uuid import UUID

from fastapi import Depends, FastAPI, HTTPException
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import JSONResponse, PlainTextResponse
from fastapi.staticfiles import StaticFiles
from pydantic import BaseModel

from gogdely_api.auth import AuthenticatedUser, authenticated_user
from gogdely_api.config import config
from gogdely_api.db_health import foundation_ready
from gogdely_api.local_orders import router as local_router
from gogdely_api.master_local import router as master_router
from gogdely_api.web_seo import https_and_security_middleware, router as seo_router

app = FastAPI(title="GOGDELY API", version="0.1.0", docs_url="/docs")
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
app.middleware("http")(https_and_security_middleware)


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


class IdentityResponse(BaseModel):
    user_id: UUID


@app.get("/api/v1/auth/me", response_model=IdentityResponse, tags=["identity"])
def current_identity(user: AuthenticatedUser = Depends(authenticated_user)) -> IdentityResponse:
    """Expose only the ID confirmed by Supabase Auth, never JWT claims."""
    return IdentityResponse(user_id=user.user_id)


@app.get("/version.json", tags=["system"])
def version() -> JSONResponse:
    return JSONResponse(
        {"commit": os.environ.get("RENDER_GIT_COMMIT", "unknown")},
        headers={"Cache-Control": "no-store"},
    )


@app.get("/ready", tags=["system"])
def ready() -> dict[str, str]:
    """Readiness is unavailable until the reviewed schema is installed."""
    database_url = os.environ.get("GOGDELY_DATABASE_URL", "")
    if not database_url:
        host = os.environ.get("GOGDELY_DATABASE_HOST", "")
        user = os.environ.get("GOGDELY_DATABASE_USER", "")
        password = os.environ.get("GOGDELY_DATABASE_PASSWORD", "")
        port = os.environ.get("GOGDELY_DATABASE_PORT", "5432")
        database = os.environ.get("GOGDELY_DATABASE_NAME", "postgres")
        if host and user and password:
            database_url = (
                f"postgresql://{quote(user, safe='')}:{quote(password, safe='')}"
                f"@{host}:{port}/{quote(database, safe='')}"
            )
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
