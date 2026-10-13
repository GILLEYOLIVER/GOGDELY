"""GOGDELY API bootstrap with an opt-in, local-only SQLite demo flow."""
from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel
from gogdely_api.config import config
from gogdely_api.local_orders import router as local_router
from gogdely_api.master_local import router as master_router

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
app.include_router(local_router)
app.include_router(master_router)


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
