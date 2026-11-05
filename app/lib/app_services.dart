import 'data/database.dart';
import 'data/file_storage.dart';
import 'data/remote/api_client.dart';
import 'data/repositories/document_repository.dart';
import 'data/repositories/settings_repository.dart';
import 'data/repositories/voice_repository.dart';
import 'data/secure_store.dart';
import 'services/pdf_text_service.dart';
import 'services/reader_audio_handler.dart';
import 'services/tts_service.dart';
import 'state/library_controller.dart';
import 'state/read_aloud_controller.dart';
import 'state/settings_controller.dart';
import 'state/voices_controller.dart';

/// Composition root: builds every service and controller once at startup.
class AppServices {
  AppServices._({
    required this.files,
    required this.api,
    required this.pdfText,
    required this.tts,
    required this.settings,
    required this.library,
    required this.voices,
    required this.readAloud,
  });

  final FileStorage files;
  final ApiClient api;
  final PdfTextService pdfText;
  final TtsService tts;
  final SettingsController settings;
  final LibraryController library;
  final VoicesController voices;
  final ReadAloudController readAloud;

  static Future<AppServices> create(ReaderAudioHandler handler) async {
    final db = await AppDatabase.open();
    final files = await FileStorage.create();
    final secure = SecureStore();
    final api = ApiClient(secure);
    final docsRepo = DocumentRepository(db);
    final voiceRepo = VoiceRepository(db);
    final pdfText = PdfTextService(docsRepo);
    final tts = TtsService(api, db, files);
    final settings = SettingsController(SettingsRepository(db), secure, api, tts);
    final library = LibraryController(docsRepo, files);
    final voices = VoicesController(voiceRepo, api, tts, files);
    await Future.wait([settings.load(), library.load(), voices.load()]);
    final readAloud = ReadAloudController(
      handler: handler,
      pdfText: pdfText,
      tts: tts,
      voices: voiceRepo,
      library: library,
      settings: settings,
    );
    return AppServices._(
      files: files,
      api: api,
      pdfText: pdfText,
      tts: tts,
      settings: settings,
      library: library,
      voices: voices,
      readAloud: readAloud,
    );
  }
}
