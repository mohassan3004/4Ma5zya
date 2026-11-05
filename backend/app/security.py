"""Bearer-token authentication and a small in-memory rate limiter."""
from __future__ import annotations

import hmac
import threading
import time
from collections import defaultdict, deque
from typing import Deque, Dict, Optional

from fastapi import Header, Request

from .config import get_settings
from .errors import UNAUTHORIZED, ApiError


class RateLimiter:
    def __init__(self, per_minute: int) -> None:
        self.per_minute = per_minute
        self._hits: Dict[str, Deque[float]] = defaultdict(deque)
        self._lock = threading.Lock()

    def check(self, key: str) -> None:
        if self.per_minute <= 0:
            return
        now = time.monotonic()
        with self._lock:
            q = self._hits[key]
            while q and now - q[0] > 60:
                q.popleft()
            if len(q) >= self.per_minute:
                raise ApiError(429, "rate_limited", "عدد الطلبات كبير. حاول بعد دقيقة.")
            q.append(now)


_limiter: Optional[RateLimiter] = None


def get_limiter() -> RateLimiter:
    global _limiter
    if _limiter is None:
        _limiter = RateLimiter(get_settings().rate_limit_per_minute)
    return _limiter


async def require_token(request: Request, authorization: str = Header(default="")) -> None:
    expected = get_settings().app_access_token
    scheme, _, token = authorization.partition(" ")
    if scheme.lower() != "bearer" or not token:
        raise UNAUTHORIZED
    if not hmac.compare_digest(token.encode("utf-8"), expected.encode("utf-8")):
        raise UNAUTHORIZED
    client = request.client.host if request.client else "unknown"
    get_limiter().check(client)
