from __future__ import annotations

from ..config import Settings
from .base import VoiceProvider


def build_provider(settings: Settings) -> VoiceProvider:
    if settings.voice_provider == "mock":
        from .mock import MockProvider

        return MockProvider()
    from .elevenlabs import ElevenLabsProvider

    return ElevenLabsProvider(
        api_key=settings.elevenlabs_api_key,
        base_url=settings.elevenlabs_base_url,
        model_id=settings.elevenlabs_model_id,
        output_format=settings.elevenlabs_output_format,
        language_code=settings.elevenlabs_language_code,
        remove_background_noise=settings.elevenlabs_remove_background_noise,
    )
