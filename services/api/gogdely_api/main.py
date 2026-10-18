"""GOGDELY API bootstrap with an opt-in, local-only SQLite demo flow."""
from fastapi import FastAPI, HTTPException
from fastapi.middleware.cors import CORSMiddleware
from fastapi.staticfiles import StaticFiles
from fastapi.responses import PlainTextResponse
from pydantic import BaseModel
import os
from pathlib import Path
from gogdely_api.config import config
from gogdely_api.local_orders import router as local_router
from gogdely_api.master_local import router as master_router
from gogdely_api.web_seo import https_and_security_middleware, router as seo_router

app = FastAPI(title="GOGDELY API", version="0.1.0", docs_url="/docs")
app.add_middleware(
    CORSMiddleware,
    allow_origin_regex=(
        r"^https?://(127\.0\.0\.1|localhost)(:\d+)?$"
        if not config.cors_extra_origins
        else r"^https?://(127\.0\.0\.1|localhost)(:\d+)?$|"
        + "|".join(origin.replace(".", r"\.").replace("https://", "https://").replace("http://", "http://")
                  for origin in config.cors_extra_origins)
    ),
    allow_methods=["GET", "POST", "PATCH", "PUT"],
    allow_headers=["content-type"],
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
        "environment": config.environment,
        "storage": "managed-database-configured" if config.uses_managed_database else "sqlite-local-demo",
    }


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
            version = local_pwa_build_version(_bundle)
        except FileNotFoundError as exc:
            raise HTTPException(status_code=503, detail="Local PWA build is unavailable") from exc
        return PlainTextResponse(version, headers={"Cache-Control": "no-store"})

    if _local_courier_dir:
        _courier_bundle = Path(_local_courier_dir).resolve()
        if not (_courier_bundle / "index.html").is_file():
            raise RuntimeError("Local courier bundle is missing; build Flutter web first")
        app.mount("/entregador", LocalPwaStaticFiles(directory=_courier_bundle, html=True),
                  name="local-courier-preview")
    app.mount("/", LocalPwaStaticFiles(directory=_bundle, html=True), name="local-pwa")
