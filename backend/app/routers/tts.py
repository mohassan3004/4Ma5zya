from __future__ import annotations

from typing import Optional

from fastapi import APIRouter, Depends
from fastapi.responses import Response
from pydantic import BaseModel, Field

from ..config import get_settings
from ..deps import get_provider, get_store
from ..errors import ApiError
from ..metadata_store import MetadataStore
from ..providers.base import ProviderError, VoiceProvider
from ..security import require_token
from ..text_utils import clean_context, clean_tts_text

router = APIRouter(prefix="/v1", tags=["tts"], dependencies=[Depends(require_token)])


class TtsBody(BaseModel):
    voice_id: str = Field(..., min_length=3, max_length=64)
    text: str
    previous_text: str = ""
    next_text: str = ""
    stability: Optional[float] = Field(default=None, ge=0.0, le=1.0)
    similarity: Optional[float] = Field(default=None, ge=0.0, le=1.0)


@router.post("/tts")
async def tts(
    body: TtsBody,
    store: MetadataStore = Depends(get_store),
    provider: VoiceProvider = Depends(get_provider),
) -> Response:
    settings = get_settings()
    if store.get(body.voice_id) is None:
        raise ApiError(404, "voice_not_found", "الصوت غير مسجّل على الخادم.")
    text = clean_tts_text(body.text, settings.max_tts_chars)
    try:
        result = await provider.synthesize(
            body.voice_id,
            text,
            previous_text=clean_context(body.previous_text, keep="tail"),
            next_text=clean_context(body.next_text, keep="head"),
            stability=body.stability,
            similarity=body.similarity,
        )
    except ProviderError as e:
        raise ApiError(e.status_code, e.code, e.message_ar)
    return Response(
        content=result.audio,
        media_type=result.media_type,
        headers={"X-Audio-Extension": result.extension, "Cache-Control": "no-store"},
    )
