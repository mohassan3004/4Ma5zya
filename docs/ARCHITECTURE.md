# Architecture

## Flutter app (`app/lib`)
| Layer | Folder | Contents |
|---|---|---|
| Presentation | `ui/screens`, `ui/widgets` | 16 Arabic RTL screens, reusable widgets (mini player, consent, sample tiles, dialogs) |
| Business logic | `state/` | `ChangeNotifier` controllers: library, voices, settings, read-aloud engine |
| Services | `services/` | PDF text extraction (pdfrx/PDFium), TTS + on-disk cache, recorder, OS media session |
| Data | `data/` | SQLite schema, repositories, secure storage, file storage, backend API client |
| Core | `core/` | Arabic text processing, theme, constants, error type, formatters |

`app_services.dart` is the composition root; `app.dart` boots the app (splash → providers → home).

### Read-aloud pipeline
1. `PdfTextService` extracts one page at a time (cached raw in SQLite → long PDFs stay fast).
2. `ArabicText.cleanPageText` folds presentation forms, repairs visually-reversed lines, removes page-number lines and tatweel, joins wrapped lines.
3. `ArabicText.buildReadingUnits` splits into sentences on Arabic punctuation (`. ؟ ! ؛ …`), merges very short ones and splits long ones at `،`.
4. `TtsService` requests each unit from the backend with previous/next sentences as prosody context, writes the MP3 to `tts_cache/<sha256(voice+text)>.mp3`, LRU-evicts by size limit.
5. `ReadAloudController` plays unit by unit through `ReaderAudioHandler` (audio_service + just_audio), prefetches the next 2 units and the next page's first unit, saves `(page, sentence)` after every unit, and drives the PDF viewer page.

### Screens (requirement → file)
Splash `splash_screen` · Home `home_screen` · PDF Library `library_screen` (+ `document_info_sheet`) · PDF Reader `reader_screen` (search, bookmarks, zoom, go-to-page) · My Voices `voices_screen` · Voice detail `voice_detail_screen` · Add New Voice `add_voice_screen` · Voice Recording `record_voice_screen` · Cloning Progress `cloning_progress_screen` · Voice Preview `voice_preview_screen` · Import existing voice `import_voice_screen` · Audio Player `audio_player_screen` · Settings `settings_screen` · About `about_screen`.

### Local database (SQLite)
`documents`, `page_texts`, `bookmarks`, `voices`, `voice_samples`, `tts_cache`, `settings`. Server URL and token live in `flutter_secure_storage`, not SQLite.

### Android permissions
`INTERNET`, `RECORD_AUDIO` (voice samples), `WAKE_LOCK`, `FOREGROUND_SERVICE`, `FOREGROUND_SERVICE_MEDIA_PLAYBACK` (background reading), `POST_NOTIFICATIONS` (media controls on Android 13+). No storage permission: files are chosen with the system picker. Cleartext HTTP is disabled; backups are disabled so recordings are not copied to cloud backups.

### iOS permissions
`NSMicrophoneUsageDescription`, `UIBackgroundModes: audio`.
