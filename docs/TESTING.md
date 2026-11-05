# Testing

## Verified so far (honest status)
| Check | Result |
|---|---|
| Backend unit/API tests (`backend/tests`, 22 tests: auth, validation, consent, formats, TTS, error mapping, ElevenLabs request shapes with a fake transport) | **Passed** |
| Backend live smoke test (uvicorn, mock provider, `/health`) | **Passed** |
| Dart syntax of every file in `app/lib`, `app/test` (`dart format` parse) | **Passed** |
| Arabic text engine (presentation forms, reversed-PDF repair, sentence splitting, chunking, digits, search folding) – 15 checks with Dart 3.6.2 | **Passed** |
| `tool/prepare_platforms.dart` static analysis | **Passed** |
| `flutter analyze`, `flutter test`, `flutter build apk` | **Not yet run.** The development machine had no Flutter/Android SDK and too little disk space. They run automatically in GitHub Actions (`.github/workflows/build.yml`). |
| On-device scenarios below | **Not yet run** |
| Real ElevenLabs cloning / Arabic TTS | **Not yet run** (needs your paid account) |

## Automated
```bash
cd backend && pip install -r requirements-dev.txt && python -m pytest -q
cd app && dart run tool/prepare_platforms.dart && flutter pub get && flutter analyze && flutter test
```

## Manual device test plan (run after installing the APK)
| # | Scenario | Steps | Expected |
|---|---|---|---|
| 1 | Import Arabic PDF | مكتبتي → رفع PDF | Document appears with page count; opens in reader |
| 2 | Navigate PDF | Swipe, chevrons, page number → go to page, zoom menu | Pages render, page indicator updates |
| 3 | Record sample | أصواتي → إنشاء صوت جديد → تسجيل | Mic permission prompt; timer and level move; preview plays |
| 4 | Upload sample | رفع ملفات → pick MP3/M4A/WAV | Listed with duration; unsupported types rejected with Arabic message |
| 5 | Create voice | Name + consent + ≥30 s → إنشاء الصوت | Progress steps; success; voice listed as جاهز |
| 6 | Preview voice | معاينة → توليد واستماع | Arabic sentence in the cloned voice |
| 7 | Generate speech | Open PDF → استمع | Mini player shows page/sentence; audio plays |
| 8 | Play | — | Sentences follow each other; PDF page follows audio |
| 9 | Pause / resume | Pause, lock phone, resume from lock screen | Resumes at same sentence |
| 10 | Switch voice | Player screen → الصوت dropdown | Current sentence restarts with new voice |
| 11 | Resume position | Stop, close app, reopen → متابعة القراءة → استماع | Starts at saved page + sentence |
| 12 | Cached offline | Listen to a page, enable airplane mode, replay same page | Plays without network |
| 13 | Network failure | Airplane mode on an unheard page | Arabic offline message + إعادة المحاولة |
| 14 | Large PDF | Import a 300+ page PDF, jump to page 250, search a word | Responsive; search shows progress |
| 15 | Reversed-text PDF | If speech sounds garbled → Settings → اتجاه النص → عكس | Speech becomes correct |
| 16 | Delete voice | Voice detail → حذف | Removed in app and in ElevenLabs dashboard |

Free end-to-end testing: set `VOICE_PROVIDER=mock` on the backend (a test tone replaces the voice).
