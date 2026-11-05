"""Uniform error type. Every error returned to the app carries a stable code and an Arabic message."""
from __future__ import annotations

from fastapi import Request
from fastapi.responses import JSONResponse


class ApiError(Exception):
    def __init__(self, status_code: int, code: str, message_ar: str) -> None:
        super().__init__(code)
        self.status_code = status_code
        self.code = code
        self.message_ar = message_ar


async def api_error_handler(_: Request, exc: ApiError) -> JSONResponse:
    return JSONResponse(
        status_code=exc.status_code,
        content={"error": {"code": exc.code, "message": exc.message_ar}},
    )


UNAUTHORIZED = ApiError(401, "unauthorized", "رمز الوصول إلى الخادم غير صحيح.")
