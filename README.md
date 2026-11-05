# 4Ma5zya – Arabic PDF reader with your own AI voice

4Ma5zya is a private Android/iOS app (Flutter) that imports Arabic PDF files and reads them aloud in a natural voice cloned from your own recordings (ElevenLabs). It also manages other voices, used only with the owner's explicit consent.

```
4ma5zya/
├── app/                 Flutter app (Arabic, RTL, Material 3)
├── backend/             FastAPI private backend (holds the ElevenLabs key)
├── docs/                API reference, testing guide, architecture notes
└── .github/workflows/   Cloud build: backend tests + release APK + unsigned iOS build
```

## How it works

```
Phone (4Ma5zya) ──HTTPS + access token──▶ Your backend (FastAPI) ──API key──▶ ElevenLabs
  PDFs, library, bookmarks, generated audio     no audio stored, no PDFs           voice cloning + Arabic TTS
  all stay on the phone
```

* **The ElevenLabs API key never touches the phone.** The app only knows your backend URL and a long access token, both kept in Android Keystore / iOS Keychain.
* PDFs stay on the device. The only thing sent out is the text of the sentence being read.
* Every generated sentence is cached on the phone, so re-listening works offline and does not use credits again.

## Quick start (Windows PC + Android phone)

You need three things: (1) an ElevenLabs account, (2) a running backend with an HTTPS address, and (3) the APK installed on your phone.

### 1. ElevenLabs account and API key – read the pricing note first
1. Create an account at <https://elevenlabs.io>.
2. **Voice cloning requires a paid plan.** Instant Voice Cloning is not available on the free tier. At the time of writing, the cheapest plan that includes it is *Starter* (about USD 5/month, ~30,000 credits). On `eleven_multilingual_v2`, one character costs roughly one credit. An average Arabic page is about 1,500–2,500 characters, so Starter covers roughly 12–20 pages a month, *Creator* (~USD 22, ~100k credits) about 50–65 pages, and *Pro* (~USD 99, ~500k credits) about 250+ pages. **Check <https://elevenlabs.io/pricing> for current figures before subscribing.** Cached audio is never billed twice.
3. Go to *Settings → API Keys*, create a key, and restrict it to **Voices** and **Text to Speech**. Keep it secret: it goes only into the backend `.env` file, never into the app or a Git repository.

### 2. Run the backend (choose one)
See [backend/README.md](backend/README.md) for full instructions. Short version for a Windows PC:

```powershell
cd backend
py -m venv .venv
.venv\Scripts\activate
pip install -r requirements.txt
copy .env.example .env      # then edit .env: APP_ACCESS_TOKEN and ELEVENLABS_API_KEY
py -c "import secrets; print(secrets.token_urlsafe(32))"   # use this as APP_ACCESS_TOKEN
uvicorn app.main:app --host 127.0.0.1 --port 8000
```

Give it an HTTPS address that the phone can reach. The quickest way is a free Cloudflare quick tunnel:

```powershell
winget install --id Cloudflare.cloudflared
cloudflared tunnel --url http://127.0.0.1:8000
```

The tunnel prints an address such as `https://something.trycloudflare.com`. The phone must reach the backend over HTTPS; plain `http://` is rejected by design. A quick-tunnel address changes every time it restarts. For permanent use, deploy to a VPS or a cloud host (see the backend guide).

> Want to try the whole app first without paying? Set `VOICE_PROVIDER=mock` in `.env`. The backend then accepts recordings and "creates" voices, but speech is a test tone instead of your voice. Switch to `elevenlabs` when ready.

### 3. Build and install the APK

This project was written in an environment without the Flutter/Android toolchain. **The APK has not been built or tested on a device yet.** Build it in one of two ways:

**Option A – GitHub Actions (no installs on your PC)**
1. Create a **private** GitHub repository and upload this folder (the contents of the ZIP).
2. Open the repository's **Actions** tab. The *Build 4Ma5zya* workflow runs on every push, or start it manually with *Run workflow*.
3. When it finishes, download the **4Ma5zya-android-apk** artifact. It contains `app-release.apk`.
4. Copy the APK to your phone, open it, and allow "Install unknown apps" for your file manager when Android asks.

**Option B – build on your Windows PC**
1. Install Flutter 3.27.4: <https://docs.flutter.dev/get-started/install/windows/mobile> (it also sets up Android Studio and the Android SDK).
2. In a terminal:
   ```powershell
   cd app
   dart run tool/prepare_platforms.dart
   flutter pub get
   dart run flutter_launcher_icons
   flutter test
   flutter build apk --release
   ```
3. The APK is at `app/build/app/outputs/flutter-apk/app-release.apk`. Alternatively, connect the phone with USB debugging enabled and run `flutter install`.

#### Signing (recommended)
Without your own keystore, the APK is signed with a debug key. It installs fine, but each CI run may use a different debug key, so an update may require uninstalling first. To fix this, create a keystore once:
```powershell
keytool -genkey -v -keystore release.jks -keyalg RSA -keysize 2048 -validity 10000 -alias ma5zya
```
For CI, add these repository secrets: `ANDROID_KEYSTORE_BASE64` (the base64 of `release.jks`), `ANDROID_KEYSTORE_PASSWORD`, `ANDROID_KEY_ALIAS` and `ANDROID_KEY_PASSWORD`. For local builds, create `app/android/key.properties` with `storeFile=`, `storePassword=`, `keyAlias=` and `keyPassword=`, and place `release.jks` in `app/android/app/`. Never commit either file.

### 4. First run on the phone
1. Open **الإعدادات → الخادم الخاص**, then enter the HTTPS URL and the `APP_ACCESS_TOKEN`. The app tests the connection before saving.
2. Open **أصواتي → إنشاء صوت جديد**. Name the voice, confirm consent, and record or upload 1.5–3 minutes of clear speech. Then tap **إنشاء الصوت**.
3. Preview the voice and set it as the default.
4. Open **مكتبتي → رفع PDF**, open a document, and tap **استمع**.

## iOS
`tool/prepare_platforms.dart` configures the iOS project: display name, microphone permission text, background audio and iOS 13 minimum. The CI workflow produces an **unsigned** IPA that only proves the project compiles; an unsigned IPA cannot be installed. Installing on an iPhone needs signing:
* **Free Apple ID**: open `app/ios/Runner.xcworkspace` in Xcode on a Mac, choose your team, and run on a connected iPhone. The app expires after 7 days.
* **Apple Developer Program** (USD 99/year): sign with a distribution certificate and provisioning profile. Distribute privately with Ad Hoc (registered devices) or through TestFlight. No public App Store listing is needed.

## Internet requirements
| Works offline | Needs internet |
|---|---|
| Opening, browsing and searching imported PDFs | Creating or improving a voice (upload) |
| Bookmarks and resuming the reading position | Generating speech for text not heard before |
| Playing any sentence already generated (cached) | Syncing, renaming or deleting voices at the provider |
| Voice list and local recordings | Previewing a new voice |

When an online feature is unavailable, the app shows an Arabic message and keeps working offline.

## Known limitations (read before relying on the app)
* **Not yet compiled or run on a device.** All Dart files were syntax-checked and the Arabic text logic and backend were tested, but full Flutter analysis and the Android build have **not** run yet (see `docs/TESTING.md`). The first GitHub Actions run is the first real compile; small fixes may be needed.
* **Scanned PDFs** (images only) contain no text layer, so they cannot be read aloud. OCR is not included.
* Some PDFs store Arabic in *visual* (reversed) order. The app detects this automatically, and you can force a direction under *Settings → اتجاه النص المستخرج*.
* Lock-screen controls offer play/pause and previous/next sentence. Page jumps are available inside the app.
* The cloned-voice quality depends on your recordings and on ElevenLabs. Arabic pronunciation of rare words or undiacritized text may be imperfect; adding diacritics in the source improves it.
