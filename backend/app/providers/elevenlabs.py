"""ElevenLabs integration (Instant Voice Cloning + multilingual TTS, which supports Arabic).

API reference: https://elevenlabs.io/docs/api-reference
The API key lives only in the backend environment and is sent only to ElevenLabs.
"""
from __future__ import annotations

import json
import logging
from contextlib import ExitStack
from typing import Any, Dict, List, Optional

import httpx

from ..audio_validation import ValidatedSample
from .base import CreatedVoice, ProviderError, SynthesisResult, VoiceProvider

log = logging.getLogger("4ma5zya.elevenlabs")

_FORMAT_MEDIA = {
    "mp3": ("audio/mpeg", "mp3"),
    "pcm": ("audio/L16", "pcm"),
    "ulaw": ("audio/basic", "ulaw"),
    "opus": ("audio/ogg", "ogg"),
}


class ElevenLabsProvider(VoiceProvider):
    name = "elevenlabs"

    def __init__(
        self,
        api_key: str,
        base_url: str,
        model_id: str,
        output_format: str,
        language_code: str = "",
        remove_background_noise: bool = False,
        transport: Optional[httpx.AsyncBaseTransport] = None,
    ) -> None:
        self._model_id = model_id
        self._output_format = output_format
        self._language_code = language_code
        self._remove_bg = remove_background_noise
        self._client = httpx.AsyncClient(
            base_url=base_url,
            headers={"xi-api-key": api_key, "Accept": "application/json"},
            timeout=httpx.Timeout(120.0, connect=15.0),
            transport=transport,
        )

    async def aclose(self) -> None:
        await self._client.aclose()

    # ---------------------------------------------------------------- helpers
    @staticmethod
    def _detail(resp: httpx.Response) -> Dict[str, Any]:
        try:
            body = resp.json()
        except Exception:
            return {}
        detail = body.get("detail") if isinstance(body, dict) else None
        if isinstance(detail, dict):
            return detail
        return {"message": str(detail)} if detail else {}

    def _raise_for(self, resp: httpx.Response) -> None:
        if resp.status_code < 400:
            return
        detail = self._detail(resp)
        status = str(detail.get("status", "")).lower()
        # Log only status codes and provider codes, never payloads, audio or keys.
        log.warning("ElevenLabs error http=%s status=%s", resp.status_code, status)
        if resp.status_code in (401, 403) and "quota" not in status:
            if "missing_permissions" in status or "subscription" in status or "can_not_use_instant_voice_cloning" in status:
                raise ProviderError(
                    402,
                    "provider_plan",
                    "خطة الاشتراك لدى مزود الصوت لا تسمح بهذه العملية (استنساخ الصوت يتطلب خطة مدفوعة).",
                )
            raise ProviderError(502, "provider_auth", "مفتاح مزود الصوت غير صالح. راجع إعدادات الخادم.")
        if "quota" in status or resp.status_code == 402:
            raise ProviderError(402, "provider_quota", "تم استهلاك رصيد الأحرف لدى مزود الصوت.")
        if "voice_limit" in status or "voice_add_edit_limit" in status:
            raise ProviderError(409, "voice_limit", "وصلت إلى الحد الأقصى لعدد الأصوات في خطتك.")
        if resp.status_code == 404 or "voice_not_found" in status:
            raise ProviderError(404, "voice_not_found", "الصوت غير موجود لدى مزود الخدمة.")
        if resp.status_code == 429:
            raise ProviderError(429, "provider_rate_limited", "مزود الصوت مشغول حاليًا. حاول بعد قليل.")
        if resp.status_code in (400, 422):
            raise ProviderError(
                422,
                "provider_rejected",
                "رفض مزود الصوت الطلب. تأكد من جودة التسجيلات ومدتها ثم حاول مجددًا.",
            )
        raise ProviderError(502, "provider_error", "حدث خطأ لدى مزود الصوت. حاول لاحقًا.")

    async def _send(self, method: str, url: str, **kw: Any) -> httpx.Response:
        try:
            resp = await self._client.request(method, url, **kw)
        except httpx.TimeoutException:
            raise ProviderError(504, "provider_timeout", "انتهت مهلة الاتصال بمزود الصوت.")
        except httpx.HTTPError:
            raise ProviderError(503, "provider_unavailable", "تعذر الاتصال بمزود الصوت.")
        self._raise_for(resp)
        return resp

    # ----------------------------------------------------------------- voices
    async def create_voice(
        self, name: str, description: str, samples: List[ValidatedSample], labels: Dict[str, str]
    ) -> CreatedVoice:
        with ExitStack() as stack:
            files = [
                ("files", (s.filename, stack.enter_context(open(s.path, "rb")), s.mime))
                for s in samples
            ]
            data = {
                "name": name,
                "description": description,
                "labels": json.dumps(labels, ensure_ascii=False),
                "remove_background_noise": "true" if self._remove_bg else "false",
            }
            resp = await self._send("POST", "/v1/voices/add", data=data, files=files)
        body = resp.json()
        voice_id = body.get("voice_id")
        if not voice_id:
            raise ProviderError(502, "provider_error", "لم يُرجع مزود الصوت معرّفًا للصوت.")
        status = "requires_verification" if body.get("requires_verification") else "ready"
        return CreatedVoice(voice_id=voice_id, status=status)

    async def add_samples(self, voice_id: str, name: str, samples: List[ValidatedSample]) -> None:
        with ExitStack() as stack:
            files = [
                ("files", (s.filename, stack.enter_context(open(s.path, "rb")), s.mime))
                for s in samples
            ]
            data = {
                "name": name,
                "remove_background_noise": "true" if self._remove_bg else "false",
            }
            await self._send("POST", "/v1/voices/{0}/edit".format(voice_id), data=data, files=files)

    async def rename_voice(self, voice_id: str, name: str) -> None:
        await self._send("POST", "/v1/voices/{0}/edit".format(voice_id), data={"name": name})

    async def delete_voice(self, voice_id: str) -> None:
        try:
            await self._send("DELETE", "/v1/voices/{0}".format(voice_id))
        except ProviderError as e:
            if e.code != "voice_not_found":  # already gone: treat as deleted
                raise

    async def get_voice(self, voice_id: str) -> Optional[Dict[str, str]]:
        try:
            resp = await self._send("GET", "/v1/voices/{0}".format(voice_id))
        except ProviderError as e:
            if e.code == "voice_not_found":
                return None
            raise
        body = resp.json()
        status = "requires_verification" if body.get("is_verification_required") else "ready"
        return {"voice_id": body.get("voice_id", voice_id), "name": body.get("name", ""), "status": status}

    # -------------------------------------------------------------------- tts
    async def synthesize(
        self,
        voice_id: str,
        text: str,
        previous_text: str = "",
        next_text: str = "",
        stability: Optional[float] = None,
        similarity: Optional[float] = None,
    ) -> SynthesisResult:
        payload: Dict[str, Any] = {
            "text": text,
            "model_id": self._model_id,
            "voice_settings": {
                "stability": 0.5 if stability is None else stability,
                "similarity_boost": 0.85 if similarity is None else similarity,
                "style": 0.0,
                "use_speaker_boost": True,
            },
        }
        if previous_text:
            payload["previous_text"] = previous_text
        if next_text:
            payload["next_text"] = next_text
        if self._language_code:
            payload["language_code"] = self._language_code
        resp = await self._send(
            "POST",
            "/v1/text-to-speech/{0}".format(voice_id),
            params={"output_format": self._output_format},
            json=payload,
            headers={"Accept": "audio/mpeg"},
        )
        prefix = self._output_format.split("_", 1)[0]
        media_type, ext = _FORMAT_MEDIA.get(prefix, ("audio/mpeg", "mp3"))
        if not resp.content:
            raise ProviderError(502, "provider_error", "أرجع مزود الصوت ملفًا فارغًا.")
        return SynthesisResult(audio=resp.content, media_type=media_type, extension=ext)
