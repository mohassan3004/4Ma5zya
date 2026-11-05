"""Runtime configuration, read exclusively from environment variables (or a local .env file).

Secrets (provider API keys, the app access token) are never hard-coded and never logged.
"""
from __future__ import annotations

import os
from dataclasses import dataclass
from functools import lru_cache
from typing import List

from dotenv import load_dotenv

load_dotenv()


def _int(name: str, default: int) -> int:
    raw = os.getenv(name)
    if raw is None or raw.strip() == "":
        return default
    return int(raw)


def _float(name: str, default: float) -> float:
    raw = os.getenv(name)
    if raw is None or raw.strip() == "":
        return default
    return float(raw)


@dataclass(frozen=True)
class Settings:
    app_access_token: str
    voice_provider: str
    elevenlabs_api_key: str
    elevenlabs_base_url: str
    elevenlabs_model_id: str
    elevenlabs_output_format: str
    elevenlabs_language_code: str
    elevenlabs_remove_background_noise: bool
    data_dir: str
    max_sample_bytes: int
    max_samples_per_request: int
    min_total_sample_seconds: float
    max_tts_chars: int
    rate_limit_per_minute: int
    cors_origins: List[str]

    def validate(self) -> None:
        if len(self.app_access_token) < 24:
            raise RuntimeError(
                "APP_ACCESS_TOKEN must be set and at least 24 characters long. "
                "Generate one with: python -c \"import secrets; print(secrets.token_urlsafe(32))\""
            )
        if self.voice_provider not in ("elevenlabs", "mock"):
            raise RuntimeError("VOICE_PROVIDER must be 'elevenlabs' or 'mock'.")
        if self.voice_provider == "elevenlabs" and not self.elevenlabs_api_key:
            raise RuntimeError("ELEVENLABS_API_KEY is required when VOICE_PROVIDER=elevenlabs.")


@lru_cache()
def get_settings() -> Settings:
    origins = [o.strip() for o in os.getenv("CORS_ORIGINS", "").split(",") if o.strip()]
    return Settings(
        app_access_token=os.getenv("APP_ACCESS_TOKEN", ""),
        voice_provider=os.getenv("VOICE_PROVIDER", "elevenlabs").strip().lower(),
        elevenlabs_api_key=os.getenv("ELEVENLABS_API_KEY", ""),
        elevenlabs_base_url=os.getenv("ELEVENLABS_BASE_URL", "https://api.elevenlabs.io"),
        elevenlabs_model_id=os.getenv("ELEVENLABS_MODEL_ID", "eleven_multilingual_v2"),
        elevenlabs_output_format=os.getenv("ELEVENLABS_OUTPUT_FORMAT", "mp3_44100_128"),
        elevenlabs_language_code=os.getenv("ELEVENLABS_LANGUAGE_CODE", "").strip(),
        elevenlabs_remove_background_noise=os.getenv(
            "ELEVENLABS_REMOVE_BACKGROUND_NOISE", "false"
        ).lower() in ("1", "true", "yes"),
        data_dir=os.getenv("DATA_DIR", "./data"),
        max_sample_bytes=_int("MAX_SAMPLE_BYTES", 11 * 1024 * 1024),
        max_samples_per_request=_int("MAX_SAMPLES_PER_REQUEST", 25),
        min_total_sample_seconds=_float("MIN_TOTAL_SAMPLE_SECONDS", 30.0),
        max_tts_chars=_int("MAX_TTS_CHARS", 2500),
        rate_limit_per_minute=_int("RATE_LIMIT_PER_MINUTE", 120),
        cors_origins=origins,
    )
