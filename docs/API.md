# 4Ma5zya backend API

Base URL: your HTTPS server. Every endpoint except `/health` requires `Authorization: Bearer <APP_ACCESS_TOKEN>`.

Errors always have this shape (the message is in Arabic and shown directly in the app):
```json
{ "error": { "code": "insufficient_audio", "message": "…" } }
```

| Method | Path | Body | Returns |
|---|---|---|---|
| GET | `/health` | – | `{status, version, provider}` |
| GET | `/v1/voices` | – | `{voices: [Voice]}` |
| GET | `/v1/voices/{id}` | – | `Voice` (status refreshed from provider) |
| POST | `/v1/voices` | multipart: `name`, `consent_type` (`self`\|`other_with_consent`), `consent_confirmed` (true), `consent_person` (required for other), `description`, `files` (1–25 audio files) | `201 Voice` |
| POST | `/v1/voices/import` | JSON `{voice_id, name, consent_type, consent_confirmed, consent_person?}` | `201 Voice` |
| POST | `/v1/voices/{id}/samples` | multipart `files` | `Voice` |
| PATCH | `/v1/voices/{id}` | JSON `{name}` | `Voice` |
| DELETE | `/v1/voices/{id}` | – | `{deleted: true}` (also deletes at provider) |
| POST | `/v1/tts` | JSON `{voice_id, text (≤2500), previous_text?, next_text?, stability?, similarity?}` | audio bytes (`audio/mpeg`; `audio/wav` in mock mode); header `X-Audio-Extension` |

`Voice` = `{voice_id, name, provider, status (ready|requires_verification|missing), consent_type, consent_person, sample_count, total_seconds, created_at, updated_at}`

### Error codes
| HTTP | code | Meaning |
|---|---|---|
| 401 | `unauthorized` | Wrong or missing access token |
| 415 | `unsupported_format`, `invalid_audio` | Extension not allowed / not real audio |
| 413 | `sample_too_large`, `text_too_long` | Over the limits |
| 422 | `insufficient_audio`, `consent_required`, `consent_person_required`, `empty_text`, `invalid_name`, `provider_rejected` | Validation |
| 402 | `provider_quota`, `provider_plan` | ElevenLabs credits exhausted / plan lacks cloning |
| 404 | `voice_not_found` | Unknown voice |
| 409 | `voice_limit` | Plan's voice slots are full |
| 429 | `rate_limited`, `provider_rate_limited` | Too many requests |
| 502/503/504 | `provider_auth`, `provider_error`, `provider_unavailable`, `provider_timeout` | Upstream problems |

### Adding another provider
Implement `app/providers/base.py::VoiceProvider` (create, add samples, rename, delete, get, synthesize), then register it in `app/providers/factory.py`. The app does not need to change.
