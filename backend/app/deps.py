from __future__ import annotations

from fastapi import Request

from .metadata_store import MetadataStore
from .providers.base import VoiceProvider


def get_provider(request: Request) -> VoiceProvider:
    return request.app.state.provider


def get_store(request: Request) -> MetadataStore:
    return request.app.state.store
