"""Provider abstraction. Add a new AI voice provider by implementing VoiceProvider."""
from __future__ import annotations

from abc import ABC, abstractmethod
from dataclasses import dataclass
from typing import Dict, List, Optional

from ..audio_validation import ValidatedSample


class ProviderError(Exception):
    def __init__(self, status_code: int, code: str, message_ar: str) -> None:
        super().__init__(code)
        self.status_code = status_code
        self.code = code
        self.message_ar = message_ar


@dataclass
class CreatedVoice:
    voice_id: str
    status: str  # "ready" | "requires_verification"


@dataclass
class SynthesisResult:
    audio: bytes
    media_type: str  # e.g. "audio/mpeg"
    extension: str  # e.g. "mp3"


class VoiceProvider(ABC):
    name: str = "base"

    @abstractmethod
    async def create_voice(
        self, name: str, description: str, samples: List[ValidatedSample], labels: Dict[str, str]
    ) -> CreatedVoice: ...

    @abstractmethod
    async def add_samples(self, voice_id: str, name: str, samples: List[ValidatedSample]) -> None: ...

    @abstractmethod
    async def rename_voice(self, voice_id: str, name: str) -> None: ...

    @abstractmethod
    async def delete_voice(self, voice_id: str) -> None: ...

    @abstractmethod
    async def get_voice(self, voice_id: str) -> Optional[Dict[str, str]]:
        """Returns {"voice_id", "name", "status"} or None if the voice does not exist."""

    @abstractmethod
    async def synthesize(
        self,
        voice_id: str,
        text: str,
        previous_text: str = "",
        next_text: str = "",
        stability: Optional[float] = None,
        similarity: Optional[float] = None,
    ) -> SynthesisResult: ...

    async def aclose(self) -> None:
        return None
