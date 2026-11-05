import 'dart:async';

import 'package:audio_service/audio_service.dart';
import 'package:flutter/foundation.dart';
import 'package:just_audio/just_audio.dart';

import '../core/arabic_text.dart';
import '../core/errors.dart';
import '../data/models.dart';
import '../data/repositories/voice_repository.dart';
import '../services/pdf_text_service.dart';
import '../services/reader_audio_handler.dart';
import '../services/tts_service.dart';
import 'library_controller.dart';
import 'settings_controller.dart';

/// Reads a PDF aloud sentence by sentence with the selected cloned voice.
///
/// Each reading unit is generated once through the backend, cached on disk, and prefetched
/// ahead of playback. Progress (page + sentence) is saved continuously so reading resumes
/// exactly where it stopped.
class ReadAloudController extends ChangeNotifier {
  ReadAloudController({
    required this.handler,
    required PdfTextService pdfText,
    required TtsService tts,
    required VoiceRepository voices,
    required LibraryController library,
    required SettingsController settings,
  })  : _pdfText = pdfText,
        _tts = tts,
        _voices = voices,
        _library = library,
        _settings = settings {
    handler.onPlay = resume;
    handler.onPause = pause;
    handler.onStop = stop;
    handler.onNext = nextSentence;
    handler.onPrevious = previousSentence;
    _stateSub = _player.processingStateStream.listen(_onProcessingState);
    _playingSub = _player.playingStream.listen((_) => notifyListeners());
  }

  final ReaderAudioHandler handler;
  final PdfTextService _pdfText;
  final TtsService _tts;
  final VoiceRepository _voices;
  final LibraryController _library;
  final SettingsController _settings;

  late final StreamSubscription<ProcessingState> _stateSub;
  late final StreamSubscription<bool> _playingSub;

  AudioPlayer get _player => handler.player;

  DocumentEntity? doc;
  VoiceProfile? voice;
  int page = 1;
  List<String> units = const [];
  int index = 0;
  bool loading = false;
  bool finished = false;
  String? error;
  String? errorCode;

  int _session = 0;
  int _unitsPlayed = 0;

  bool get hasSession => doc != null;
  bool get isPlaying =>
      _player.playing && !loading && _player.processingState != ProcessingState.completed && error == null;
  String? get currentText => index < units.length ? units[index] : null;
  Stream<Duration> get positionStream => _player.positionStream;
  Stream<Duration?> get durationStream => _player.durationStream;
  double get speed => _settings.speed;

  String _speech(int i) => ArabicText.prepareForSpeech(units[i]);

  /// Starts (or restarts) reading [d]. Without [fromPage] it resumes from the saved position.
  Future<void> start(DocumentEntity d, {int? fromPage, int? sentence, VoiceProfile? withVoice}) async {
    final selected = withVoice ?? (doc?.id == d.id ? voice : null) ?? voice ?? await _voices.defaultVoice();
    if (selected == null) {
      throw const AppException('لا يوجد صوت افتراضي. أنشئ صوتك من قسم "أصواتي" أولًا.', code: 'no_voice');
    }
    if (!_settings.serverConfigured) {
      // Cached audio can still play offline, but a server is needed for anything not cached yet.
      debugPrint('Read aloud started without a configured server; only cached audio will play.');
    }
    voice = selected;
    doc = d;
    finished = false;
    _unitsPlayed = 0;
    await _player.setSpeed(_settings.speed);
    final startPage = (fromPage ?? d.lastPage).clamp(1, d.pageCount);
    final startSentence = sentence ?? (fromPage == null ? d.lastSentence : 0);
    await _loadPage(startPage, startSentence);
  }

  Future<void> _loadPage(int p, int sentence, {int emptySkips = 0}) async {
    final d = doc;
    if (d == null) return;
    final s = ++_session;
    page = p;
    units = const [];
    index = 0;
    loading = true;
    error = null;
    errorCode = null;
    notifyListeners();

    final String text;
    try {
      text = await _pdfText.pageText(d, p, reverse: _settings.reverseOverride);
    } on AppException catch (e) {
      if (s == _session) _fail(e);
      return;
    }
    if (s != _session) return;

    final u = ArabicText.buildReadingUnits(text);
    if (u.isEmpty) {
      if (p < d.pageCount && emptySkips < 40) {
        return _loadPage(p + 1, 0, emptySkips: emptySkips + 1);
      }
      if (emptySkips >= 40) {
        _fail(const AppException('صفحات كثيرة متتالية لا تحتوي على نص قابل للقراءة.', code: 'no_text'));
        return;
      }
      _finish();
      return;
    }
    units = u;
    index = sentence < 0 ? u.length - 1 : sentence.clamp(0, u.length - 1);
    await _playCurrent(s);
  }

  Future<void> _playCurrent(int s) async {
    final d = doc;
    final v = voice;
    if (d == null || v == null || units.isEmpty) return;
    final i = index;
    final p = page;
    loading = true;
    error = null;
    errorCode = null;
    notifyListeners();
    try {
      final file = await _tts.audioFor(
        voiceId: v.voiceId,
        text: _speech(i),
        previousText: i > 0 ? _speech(i - 1) : '',
        nextText: i + 1 < units.length ? _speech(i + 1) : '',
      );
      if (s != _session) return;
      handler.mediaItem.add(MediaItem(
        id: '${d.id}:$p:$i',
        title: d.title,
        album: 'صفحة $p من ${d.pageCount}',
        artist: v.name,
      ));
      await _player.setAudioSource(AudioSource.file(file.path));
      if (s != _session) return;
      loading = false;
      _unitsPlayed++;
      notifyListeners();
      unawaited(_library.saveProgress(d.id, p, i));
      unawaited(_prefetch(s));
      unawaited(_player.play().catchError((Object _) {}));
    } on AppException catch (e) {
      if (s == _session) _fail(e);
    } catch (_) {
      if (s == _session) _fail(const AppException('تعذر تشغيل المقطع الصوتي.', code: 'playback'));
    }
  }

  Future<void> _prefetch(int s) async {
    final d = doc;
    final v = voice;
    if (d == null || v == null) return;
    try {
      for (var k = 1; k <= 2; k++) {
        final j = index + k;
        if (s != _session || j >= units.length) break;
        await _tts.audioFor(
          voiceId: v.voiceId,
          text: _speech(j),
          previousText: _speech(j - 1),
          nextText: j + 1 < units.length ? _speech(j + 1) : '',
        );
      }
      if (s == _session && index + 2 >= units.length && page < d.pageCount) {
        final text = await _pdfText.pageText(d, page + 1, reverse: _settings.reverseOverride);
        final next = ArabicText.buildReadingUnits(text);
        if (next.isNotEmpty && s == _session) {
          await _tts.audioFor(
            voiceId: v.voiceId,
            text: ArabicText.prepareForSpeech(next.first),
            nextText: next.length > 1 ? ArabicText.prepareForSpeech(next[1]) : '',
          );
        }
      }
    } catch (_) {
      // Prefetch failures are silent; the real request will report the error if it persists.
    }
  }

  void _onProcessingState(ProcessingState state) {
    if (state == ProcessingState.completed && !loading && doc != null && error == null && !finished) {
      unawaited(_advance());
    }
    notifyListeners();
  }

  Future<void> _advance() async {
    final d = doc;
    if (d == null) return;
    if (index + 1 < units.length) {
      index++;
      await _playCurrent(++_session);
    } else if (page < d.pageCount) {
      await _loadPage(page + 1, 0);
    } else {
      _finish();
    }
  }

  void _finish() {
    loading = false;
    finished = true;
    if (_unitsPlayed == 0) {
      error = 'لا يحتوي هذا الجزء من المستند على نص قابل للاستخراج (قد يكون صورًا ممسوحة ضوئيًا).';
      errorCode = 'no_text';
    }
    unawaited(_player.pause());
    notifyListeners();
  }

  void _fail(AppException e) {
    loading = false;
    error = e.message;
    errorCode = e.code;
    unawaited(_player.pause());
    notifyListeners();
  }

  // ------------------------------------------------------------------ controls
  Future<void> pause() async {
    await _player.pause();
    final d = doc;
    if (d != null && units.isNotEmpty) await _library.saveProgress(d.id, page, index);
    notifyListeners();
  }

  Future<void> resume() async {
    if (doc == null) return;
    if (finished) {
      finished = false;
      await _loadPage(1, 0);
      return;
    }
    final st = _player.processingState;
    if (error != null || units.isEmpty || st == ProcessingState.idle || st == ProcessingState.completed) {
      if (units.isEmpty) {
        await _loadPage(page, index);
      } else {
        await _playCurrent(++_session);
      }
      return;
    }
    unawaited(_player.play().catchError((Object _) {}));
    notifyListeners();
  }

  Future<void> togglePlay() => isPlaying ? pause() : resume();

  Future<void> retry() => resume();

  Future<void> stop() async {
    final d = doc;
    _session++;
    if (d != null && units.isNotEmpty) await _library.saveProgress(d.id, page, index);
    await _player.stop();
    doc = null;
    units = const [];
    index = 0;
    loading = false;
    finished = false;
    error = null;
    errorCode = null;
    handler.mediaItem.add(null);
    notifyListeners();
  }

  Future<void> nextSentence() async {
    final d = doc;
    if (d == null) return;
    finished = false;
    if (index + 1 < units.length) {
      index++;
      await _playCurrent(++_session);
    } else if (page < d.pageCount) {
      await _loadPage(page + 1, 0);
    }
  }

  Future<void> previousSentence() async {
    if (doc == null) return;
    finished = false;
    if (index > 0) {
      index--;
      await _playCurrent(++_session);
    } else if (page > 1) {
      await _loadPage(page - 1, -1);
    } else {
      await _playCurrent(++_session);
    }
  }

  Future<void> nextPage() async {
    final d = doc;
    if (d == null || page >= d.pageCount) return;
    finished = false;
    await _loadPage(page + 1, 0);
  }

  Future<void> previousPage() async {
    if (doc == null || page <= 1) return;
    finished = false;
    await _loadPage(page - 1, 0);
  }

  Future<void> goToPage(int p) async {
    final d = doc;
    if (d == null) return;
    finished = false;
    await _loadPage(p.clamp(1, d.pageCount), 0);
  }

  Future<void> setVoice(VoiceProfile v) async {
    voice = v;
    notifyListeners();
    if (doc != null && units.isNotEmpty) await _playCurrent(++_session);
  }

  Future<void> setSpeed(double value) async {
    await _settings.setSpeed(value);
    await _player.setSpeed(value);
    notifyListeners();
  }

  /// Called when a voice is deleted elsewhere in the app.
  Future<void> onVoiceDeleted(String voiceId) async {
    if (voice?.voiceId == voiceId) {
      await stop();
      voice = null;
    }
  }

  @override
  void dispose() {
    _stateSub.cancel();
    _playingSub.cancel();
    super.dispose();
  }
}
