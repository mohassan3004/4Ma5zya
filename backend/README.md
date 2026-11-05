# 4Ma5zya backend – setup and deployment

A small FastAPI service that sits between the app and ElevenLabs. It is the **only** place where the ElevenLabs API key exists.

## What it does and what it stores
* `POST /v1/voices` receives voice samples, validates them (format, magic bytes, size, minimum total duration and explicit consent), and forwards them to ElevenLabs Instant Voice Cloning. Samples sit in a private temporary folder only during the request and are deleted immediately. **No audio is stored.**
* `POST /v1/tts` converts one sentence of Arabic text to speech with the selected voice. It passes the previous and next sentence as context for natural prosody.
* Voice *metadata* only (id, name, consent type, timestamps) is stored in `DATA_DIR/voices.db`.
* Interactive API docs (`/docs`, `/openapi.json`) are disabled on purpose. The API is documented in [../docs/API.md](../docs/API.md).
* Logs contain status codes and provider error codes only, never text, audio, tokens or keys.

## Configuration (`.env`)
Copy `.env.example` to `.env`. Required values:

| Variable | Meaning |
|---|---|
| `APP_ACCESS_TOKEN` | Long random secret (24+ chars) that the app sends as `Authorization: Bearer …`. Generate with `python -c "import secrets; print(secrets.token_urlsafe(32))"`. |
| `VOICE_PROVIDER` | `elevenlabs` (real) or `mock` (free test mode: synthetic tone, no cloning) |
| `ELEVENLABS_API_KEY` | Your ElevenLabs key (required for `elevenlabs`) |
| `ELEVENLABS_MODEL_ID` | Default `eleven_multilingual_v2` (best Arabic quality). `eleven_turbo_v2_5` / `eleven_flash_v2_5` are cheaper/faster. |
| `MIN_TOTAL_SAMPLE_SECONDS` | Minimum total recording length for a new voice (default 30) |

Never commit `.env`; it is already in `.gitignore`.

## Option 1 – Windows PC + Cloudflare quick tunnel (testing)
```powershell
cd backend
py -m venv .venv
.venv\Scripts\activate
pip install -r requirements.txt
copy .env.example .env   # edit it
uvicorn app.main:app --host 127.0.0.1 --port 8000
# second terminal:
cloudflared tunnel --url http://127.0.0.1:8000
```
Use the printed `https://….trycloudflare.com` address in the app. It changes on every restart, and the PC must stay on. For a fixed address, use a [named Cloudflare Tunnel](https://developers.cloudflare.com/cloudflare-one/connections/connect-networks/) with your own domain.

## Option 2 – VPS with Docker and automatic HTTPS (recommended for daily use)
On any small Linux VPS (1 vCPU / 1 GB RAM is plenty):
1. Point a DNS record (for example `api.yourdomain.com`) to the server.
2. Copy the `backend/` folder to the server, create `.env`, and add the line `DOMAIN=api.yourdomain.com`.
3. Run `docker compose up -d`.

Caddy obtains a Let's Encrypt certificate automatically and proxies HTTPS to the API. Voice metadata persists in the `voice_meta` volume.

## Option 3 – Managed hosting (Render, Railway, Fly.io…)
Deploy the `Dockerfile` and set the environment variables in the host's dashboard. Each of these hosts provides HTTPS. On hosts with an ephemeral disk, attach a persistent volume at `/srv/data`. Otherwise the server-side voice list resets on redeploy; the app keeps its own list, and **ربط صوت موجود** re-registers a voice by its ID.

## Running the tests
```bash
pip install -r requirements-dev.txt
python -m pytest -q
```
The tests use the mock provider and a fake ElevenLabs HTTP transport, so they need no network access and no key.

## Security checklist
- [ ] HTTPS only (tunnel, Caddy or the managed host's TLS)
- [ ] `APP_ACCESS_TOKEN` is long and random; rotate it if a phone is lost (edit `.env`, restart, re-enter in the app)
- [ ] ElevenLabs key restricted to Voices + Text to Speech
- [ ] `.env` not committed; server firewall exposes only 80/443 (VPS)
