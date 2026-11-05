"""4Ma5zya backend: a thin, private proxy between the mobile app and the AI voice provider."""
from __future__ import annotations

import logging
from contextlib import asynccontextmanager
from typing import AsyncIterator

from fastapi import FastAPI, Request
from fastapi.exceptions import RequestValidationError
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import JSONResponse

from .config import get_settings
from .errors import ApiError, api_error_handler
from .metadata_store import MetadataStore
from .providers import build_provider
from .routers import tts, voices

logging.basicConfig(level=logging.INFO, format="%(asctime)s %(levelname)s %(name)s: %(message)s")

APP_VERSION = "1.0.0"


@asynccontextmanager
async def lifespan(app: FastAPI) -> AsyncIterator[None]:
    settings = get_settings()
    settings.validate()
    app.state.provider = build_provider(settings)
    app.state.store = MetadataStore(settings.data_dir)
    logging.getLogger("4ma5zya").info("started provider=%s", settings.voice_provider)
    try:
        yield
    finally:
        await app.state.provider.aclose()
        app.state.store.close()


app = FastAPI(
    title="4Ma5zya API",
    version=APP_VERSION,
    lifespan=lifespan,
    docs_url=None,  # no public interactive docs on a private server
    redoc_url=None,
    openapi_url=None,
)
app.add_exception_handler(ApiError, api_error_handler)  # type: ignore[arg-type]


@app.exception_handler(RequestValidationError)
async def validation_handler(_: Request, exc: RequestValidationError) -> JSONResponse:
    return JSONResponse(
        status_code=422,
        content={"error": {"code": "invalid_request", "message": "بيانات الطلب غير مكتملة أو غير صحيحة."}},
    )


@app.exception_handler(Exception)
async def unhandled_handler(_: Request, exc: Exception) -> JSONResponse:
    logging.getLogger("4ma5zya").exception("unhandled error: %s", type(exc).__name__)
    return JSONResponse(
        status_code=500,
        content={"error": {"code": "server_error", "message": "حدث خطأ غير متوقع في الخادم."}},
    )


_origins = get_settings().cors_origins
if _origins:
    app.add_middleware(CORSMiddleware, allow_origins=_origins, allow_methods=["*"], allow_headers=["*"])


@app.get("/health")
async def health(request: Request) -> dict:
    return {"status": "ok", "version": APP_VERSION, "provider": request.app.state.provider.name}


app.include_router(voices.router)
app.include_router(tts.router)
