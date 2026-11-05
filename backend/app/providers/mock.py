"""Offline mock provider for development and automated tests.

It does NOT clone voices: it returns a synthetic tone whose length follows the text length,
so the whole app flow (upload -> create -> preview -> read aloud -> cache) can be exercised
without an ElevenLabs account or any cost.
"""
from __future__ import annotations

import io
import math
import struct
import uuid
import wave
from typing import Dict, List, Optional

from ..audio_validation import ValidatedSample
from .base import CreatedVoice, ProviderError, SynthesisResult, VoiceProvider


def _tone_wav(seconds: float, rate: int = 16000) -> bytes:
    frames = int(seconds * rate)
    buf = io.BytesIO()
    with wave.open(buf, "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(rate)
        data = bytearray()
        for i in range(frames):
            t = i / rate
            # A soft pulsing tone (0.25 s on / 0.1 s off) that is easy to recognise.
            on = (t % 0.35) < 0.25
            v = int(3000 * math.sin(2 * math.pi * 220 * t)) if on else 0
            data += struct.pack("<h", v)
        w.writeframes(bytes(data))
    return buf.getvalue()


class MockProvider(VoiceProvider):
    name = "mock"

    def __init__(self) -> None:
        self._voices: Dict[str, Dict[str, str]] = {}

    async def create_voice(
        self, name: str, description: str, samples: List[ValidatedSample], labels: Dict[str, str]
    ) -> CreatedVoice:
        vid = "mock_" + uuid.uuid4().hex[:16]
        self._voices[vid] = {"voice_id": vid, "name": name, "status": "ready"}
        return CreatedVoice(voice_id=vid, status="ready")

    async def add_samples(self, voice_id: str, name: str, samples: List[ValidatedSample]) -> None:
        if voice_id not in self._voices:
            raise ProviderError(404, "voice_not_found", "الصوت غير موجود لدى مزود الخدمة.")

    async def rename_voice(self, voice_id: str, name: str) -> None:
        if voice_id not in self._voices:
            raise ProviderError(404, "voice_not_found", "الصوت غير موجود لدى مزود الخدمة.")
        self._voices[voice_id]["name"] = name

    async def delete_voice(self, voice_id: str) -> None:
        self._voices.pop(voice_id, None)

    async def get_voice(self, voice_id: str) -> Optional[Dict[str, str]]:
        if voice_id.startswith("mock_") and voice_id not in self._voices:
            # Survive restarts: mock voices are stateless.
            self._voices[voice_id] = {"voice_id": voice_id, "name": "", "status": "ready"}
        return self._voices.get(voice_id)

    async def synthesize(
        self,
        voice_id: str,
        text: str,
        previous_text: str = "",
        next_text: str = "",
        stability: Optional[float] = None,
        similarity: Optional[float] = None,
    ) -> SynthesisResult:
        seconds = max(0.6, min(20.0, len(text) * 0.06))
        return SynthesisResult(audio=_tone_wav(seconds), media_type="audio/wav", extension="wav")
