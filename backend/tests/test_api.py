from app.providers.mock import _tone_wav


def wav(seconds):
    return _tone_wav(seconds, rate=8000)


def create(client, auth, seconds=35.0, **extra):
    data = {"name": "صوتي", "consent_type": "self", "consent_confirmed": "true"}
    data.update(extra)
    return client.post(
        "/v1/voices",
        headers=auth,
        data=data,
        files=[("files", ("a.wav", wav(seconds), "audio/wav"))],
    )


def test_health(client):
    r = client.get("/health")
    assert r.status_code == 200 and r.json()["provider"] == "mock"


def test_requires_token(client):
    assert client.get("/v1/voices").status_code == 401
    r = client.get("/v1/voices", headers={"Authorization": "Bearer wrong"})
    assert r.status_code == 401
    assert r.json()["error"]["code"] == "unauthorized"


def test_no_public_docs(client):
    assert client.get("/docs").status_code == 404
    assert client.get("/openapi.json").status_code == 404


def test_create_list_rename_delete(client, auth):
    r = create(client, auth)
    assert r.status_code == 201, r.text
    v = r.json()
    assert v["voice_id"].startswith("mock_") and v["status"] == "ready"
    assert v["sample_count"] == 1 and round(v["total_seconds"]) == 35

    assert len(client.get("/v1/voices", headers=auth).json()["voices"]) == 1
    r = client.patch("/v1/voices/" + v["voice_id"], headers=auth, json={"name": "صوت جديد"})
    assert r.json()["name"] == "صوت جديد"
    r = client.get("/v1/voices/" + v["voice_id"], headers=auth)
    assert r.status_code == 200 and r.json()["status"] == "ready"

    r = client.post(
        "/v1/voices/{0}/samples".format(v["voice_id"]),
        headers=auth,
        files=[("files", ("b.wav", wav(10), "audio/wav"))],
    )
    assert r.status_code == 200 and r.json()["sample_count"] == 2

    assert client.delete("/v1/voices/" + v["voice_id"], headers=auth).json() == {"deleted": True}
    assert client.get("/v1/voices", headers=auth).json()["voices"] == []


def test_insufficient_audio(client, auth):
    r = create(client, auth, seconds=5)
    assert r.status_code == 422
    assert r.json()["error"]["code"] == "insufficient_audio"


def test_unsupported_and_invalid_format(client, auth):
    data = {"name": "x", "consent_type": "self", "consent_confirmed": "true"}
    r = client.post("/v1/voices", headers=auth, data=data, files=[("files", ("a.txt", b"x" * 5000, "text/plain"))])
    assert r.status_code == 415 and r.json()["error"]["code"] == "unsupported_format"
    r = client.post("/v1/voices", headers=auth, data=data, files=[("files", ("a.mp3", b"x" * 5000, "audio/mpeg"))])
    assert r.status_code == 415 and r.json()["error"]["code"] == "invalid_audio"


def test_consent_required(client, auth):
    r = create(client, auth, consent_confirmed="false")
    assert r.json()["error"]["code"] == "consent_required"
    r = create(client, auth, consent_type="other_with_consent")
    assert r.json()["error"]["code"] == "consent_person_required"
    r = create(client, auth, consent_type="other_with_consent", consent_person="أحمد")
    assert r.status_code == 201 and r.json()["consent_person"] == "أحمد"


def test_tts(client, auth):
    vid = create(client, auth).json()["voice_id"]
    r = client.post("/v1/tts", headers=auth, json={"voice_id": vid, "text": "ﺑﺴﻢ الله الرحمن الرحيم."})
    assert r.status_code == 200
    assert r.headers["content-type"] == "audio/wav"
    assert r.headers["x-audio-extension"] == "wav"
    assert r.content[:4] == b"RIFF"
    r = client.post("/v1/tts", headers=auth, json={"voice_id": vid, "text": "   "})
    assert r.json()["error"]["code"] == "empty_text"
    r = client.post("/v1/tts", headers=auth, json={"voice_id": vid, "text": "أ" * 3000})
    assert r.json()["error"]["code"] == "text_too_long"
    r = client.post("/v1/tts", headers=auth, json={"voice_id": "unknown_id", "text": "مرحبا"})
    assert r.status_code == 404


def test_import_voice(client, auth):
    body = {"voice_id": "mock_existing", "name": "مستورد", "consent_type": "self", "consent_confirmed": True}
    r = client.post("/v1/voices/import", headers=auth, json=body)
    assert r.status_code == 201 and r.json()["voice_id"] == "mock_existing"


def test_text_normalisation():
    from app.text_utils import clean_context, clean_tts_text

    # Arabic presentation forms (typical of PDF extraction) fold to base letters.
    assert clean_tts_text("ﺑﺴﻢ  الله", 100) == "بسم الله"
    assert clean_context("abcdef", keep="head", limit=3) == "abc"
    assert clean_context("abcdef", keep="tail", limit=3) == "def"
