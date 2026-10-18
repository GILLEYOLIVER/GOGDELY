"""GOGDELY API bootstrap, without business or payment operations."""
import os

from fastapi import FastAPI
from pydantic import BaseModel

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
