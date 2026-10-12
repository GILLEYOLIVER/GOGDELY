"""GOGDELY API bootstrap with an opt-in, local-only SQLite demo flow."""
from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel
from gogdely_api.local_orders import router as local_router

app = FastAPI(title="GOGDELY API", version="0.1.0", docs_url="/docs")
app.add_middleware(
    CORSMiddleware,
    allow_origin_regex=r"^http://(127\.0\.0\.1|localhost)(:\d+)?$",
    allow_methods=["GET", "POST", "PATCH", "PUT"],
    allow_headers=["content-type"],
)
app.include_router(local_router)


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
