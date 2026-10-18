"""GOGDELY API bootstrap, without business or payment operations."""
import os

from fastapi import FastAPI, HTTPException
from fastapi.responses import JSONResponse
from pydantic import BaseModel

from gogdely_api.db_health import foundation_ready

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
    return {
        "name": "GOGDELY",
        "api_version": "v1",
        "environment": os.environ.get("GOGDELY_ENV", "local-demo"),
    }


@app.get("/version.json", tags=["system"])
def version() -> JSONResponse:
    """The deployed commit is public; no environment or database secrets."""
    return JSONResponse(
        {"commit": os.environ.get("RENDER_GIT_COMMIT", "unknown")},
        headers={"Cache-Control": "no-store"},
    )


@app.get("/ready", tags=["system"])
def ready() -> dict[str, str]:
    """Readiness is unavailable until the reviewed schema is installed."""
    database_url = os.environ.get("GOGDELY_DATABASE_URL", "")
    if not database_url or not foundation_ready(database_url):
        raise HTTPException(status_code=503, detail="managed database is not ready")
    return {"status": "ready", "service": "gogdely-api"}
