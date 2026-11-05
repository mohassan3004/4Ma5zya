import os
import sys

import pytest

sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

TOKEN = "test-token-0123456789abcdefghij"


@pytest.fixture()
def client(tmp_path, monkeypatch):
    monkeypatch.setenv("APP_ACCESS_TOKEN", TOKEN)
    monkeypatch.setenv("VOICE_PROVIDER", "mock")
    monkeypatch.setenv("DATA_DIR", str(tmp_path))
    monkeypatch.setenv("MIN_TOTAL_SAMPLE_SECONDS", "30")
    monkeypatch.setenv("RATE_LIMIT_PER_MINUTE", "0")
    from app import config, security

    config.get_settings.cache_clear()
    security._limiter = None
    from fastapi.testclient import TestClient

    from app.main import app

    with TestClient(app) as c:
        yield c
    config.get_settings.cache_clear()


@pytest.fixture()
def auth():
    return {"Authorization": "Bearer " + TOKEN}
