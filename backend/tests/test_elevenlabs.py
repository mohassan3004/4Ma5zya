"""ElevenLabs adapter tests against a fake HTTP transport (no network, no credentials)."""
import asyncio
import json

import httpx
import pytest

from app.audio_validation import ValidatedSample
from app.providers.base import ProviderError
from app.providers.elevenlabs import ElevenLabsProvider
from app.providers.mock import _tone_wav


def make(handler):
    return ElevenLabsProvider(
        api_key="sk_test",
        base_url="https://api.elevenlabs.io",
        model_id="eleven_multilingual_v2",
        output_format="mp3_44100_128",
        transport=httpx.MockTransport(handler),
    )


def sample(tmp_path):
    p = tmp_path / "s.wav"
    p.write_bytes(_tone_wav(1, 8000))
    return ValidatedSample(path=str(p), filename="sample_01.wav", mime="audio/wav", size=p.stat().st_size, duration=1.0)


def run(coro):
    return asyncio.run(coro)


def test_create_voice_request_shape(tmp_path):
    seen = {}

    def handler(req: httpx.Request):
        seen["url"] = str(req.url)
        seen["key"] = req.headers.get("xi-api-key")
        seen["body"] = req.read()
        return httpx.Response(200, json={"voice_id": "abc123", "requires_verification": False})

    async def go():
        p = make(handler)
        try:
            return await p.create_voice("صوتي", "", [sample(tmp_path)], {"language": "ar"})
        finally:
            await p.aclose()

    v = run(go())
    assert v.voice_id == "abc123" and v.status == "ready"
    assert seen["url"] == "https://api.elevenlabs.io/v1/voices/add"
    assert seen["key"] == "sk_test"
    assert b'name="files"; filename="sample_01.wav"' in seen["body"]
    assert "صوتي".encode() in seen["body"]


def test_tts_request_shape():
    seen = {}

    def handler(req: httpx.Request):
        seen["url"] = str(req.url)
        seen["json"] = json.loads(req.read())
        return httpx.Response(200, content=b"ID3fakeaudio", headers={"content-type": "audio/mpeg"})

    async def go():
        p = make(handler)
        try:
            return await p.synthesize("v1", "مرحبا.", previous_text="قبل", next_text="بعد")
        finally:
            await p.aclose()

    r = run(go())
    assert r.media_type == "audio/mpeg" and r.extension == "mp3"
    assert seen["url"] == "https://api.elevenlabs.io/v1/text-to-speech/v1?output_format=mp3_44100_128"
    assert seen["json"]["model_id"] == "eleven_multilingual_v2"
    assert seen["json"]["previous_text"] == "قبل" and seen["json"]["next_text"] == "بعد"


@pytest.mark.parametrize(
    "status,body,code",
    [
        (401, {"detail": {"status": "invalid_api_key"}}, "provider_auth"),
        (401, {"detail": {"status": "quota_exceeded"}}, "provider_quota"),
        (403, {"detail": {"status": "can_not_use_instant_voice_cloning"}}, "provider_plan"),
        (429, {"detail": {"status": "too_many_concurrent_requests"}}, "provider_rate_limited"),
        (400, {"detail": {"status": "voice_limit_reached"}}, "voice_limit"),
        (422, {"detail": [{"msg": "bad"}]}, "provider_rejected"),
        (404, {"detail": {"status": "voice_not_found"}}, "voice_not_found"),
        (500, {}, "provider_error"),
    ],
)
def test_error_mapping(status, body, code):
    def handler(req):
        return httpx.Response(status, json=body)

    async def go():
        p = make(handler)
        try:
            await p.synthesize("v1", "نص")
        finally:
            await p.aclose()

    with pytest.raises(ProviderError) as e:
        run(go())
    assert e.value.code == code


def test_network_failure():
    def handler(req):
        raise httpx.ConnectError("down")

    async def go():
        p = make(handler)
        try:
            await p.synthesize("v1", "نص")
        finally:
            await p.aclose()

    with pytest.raises(ProviderError) as e:
        run(go())
    assert e.value.code == "provider_unavailable"


def test_delete_missing_is_ok():
    def handler(req):
        return httpx.Response(404, json={"detail": {"status": "voice_not_found"}})

    async def go():
        p = make(handler)
        try:
            await p.delete_voice("gone")
        finally:
            await p.aclose()

    run(go())
