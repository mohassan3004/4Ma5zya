import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';

import '../../app_services.dart';
import '../../core/constants.dart';
import '../../core/formatters.dart';
import '../../data/file_storage.dart';
import '../../data/models.dart';
import '../../services/recorder_service.dart';
import '../widgets/common.dart';
import '../widgets/sample_tile.dart';

enum _RecState { idle, recording, recorded }

/// Records one voice sample. Returns a [VoiceSample] via Navigator.pop when saved.
class RecordVoiceScreen extends StatefulWidget {
  const RecordVoiceScreen({super.key});

  @override
  State<RecordVoiceScreen> createState() => _RecordVoiceScreenState();
}

class _RecordVoiceScreenState extends State<RecordVoiceScreen> {
  final _recorder = RecorderService();
  final _preview = SamplePreviewPlayer();
  late final FileStorage _files;
  _RecState _state = _RecState.idle;
  String? _path;
  Duration _elapsed = Duration.zero;
  double _level = 0;
  int _script = 0;
  bool _saved = false;
  Timer? _timer;
  StreamSubscription<dynamic>? _ampSub;
  DateTime? _startedAt;

  static const _maxDuration = Duration(minutes: 5);
  static const _minDuration = Duration(seconds: 5);

  @override
  void initState() {
    super.initState();
    _files = context.read<AppServices>().files;
  }

  @override
  void dispose() {
    _timer?.cancel();
    _ampSub?.cancel();
    if (_state == _RecState.recording) _recorder.cancel();
    _recorder.dispose();
    _preview.dispose();
    if (!_saved && _path != null) _files.deleteQuietly(_path!);
    super.dispose();
  }

  Future<void> _start() async {
    if (!await _recorder.hasPermission()) {
      if (mounted) {
        showSnack(context, 'يحتاج التطبيق إلى إذن الميكروفون. فعّله من إعدادات الجهاز ثم حاول مجددًا.', error: true);
      }
      return;
    }
    await _preview.stop();
    if (_path != null) await _files.deleteQuietly(_path!);
    final path = p.join(_files.samplesDir.path, '${const Uuid().v4()}.m4a');
    try {
      await _recorder.start(path);
    } catch (_) {
      if (mounted) showSnack(context, 'تعذر بدء التسجيل.', error: true);
      return;
    }
    _path = path;
    _startedAt = DateTime.now();
    _ampSub = _recorder.amplitude().listen((a) {
      // dBFS: about -60 (silence) .. 0 (max)
      final v = ((a.current + 60) / 60).clamp(0.0, 1.0);
      if (mounted) setState(() => _level = v);
    });
    _timer = Timer.periodic(const Duration(milliseconds: 200), (_) {
      final e = DateTime.now().difference(_startedAt!);
      if (mounted) setState(() => _elapsed = e);
      if (e >= _maxDuration) _stop();
    });
    setState(() {
      _state = _RecState.recording;
      _elapsed = Duration.zero;
    });
  }

  Future<void> _stop() async {
    _timer?.cancel();
    await _ampSub?.cancel();
    _ampSub = null;
    final out = await _recorder.stop();
    if (out != null) _path = out;
    if (!mounted) return;
    setState(() {
      _state = _RecState.recorded;
      _level = 0;
    });
    if (_elapsed < _minDuration) {
      showSnack(context, 'التسجيل قصير جدًا. سجّل ${_minDuration.inSeconds} ثوانٍ على الأقل.', error: true);
    }
  }

  void _save() {
    final path = _path;
    if (path == null || !File(path).existsSync()) return;
    if (_elapsed < _minDuration) {
      showSnack(context, 'التسجيل قصير جدًا.', error: true);
      return;
    }
    _saved = true;
    Navigator.of(context).pop(VoiceSample(
      filePath: path,
      durationMs: _elapsed.inMilliseconds,
      source: 'recorded',
      createdAt: DateTime.now(),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final recording = _state == _RecState.recording;
    return Scaffold(
      appBar: AppBar(title: const Text('تسجيل صوتك')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text('اقرأ النص التالي بصوت واضح ونبرة طبيعية:', style: TextStyle(color: scheme.onSurfaceVariant)),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(color: scheme.surfaceContainerLow, borderRadius: BorderRadius.circular(18)),
            child: Text(recordingScripts[_script], style: const TextStyle(fontSize: 19, height: 1.9)),
          ),
          Align(
            alignment: AlignmentDirectional.centerEnd,
            child: TextButton.icon(
              onPressed: () => setState(() => _script = (_script + 1) % recordingScripts.length),
              icon: const Icon(Icons.refresh),
              label: const Text('نص آخر'),
            ),
          ),
          const SizedBox(height: 24),
          Center(
            child: Text(
              formatDuration(_elapsed),
              style: TextStyle(fontSize: 44, fontWeight: FontWeight.w300, color: recording ? scheme.error : scheme.onSurface),
            ),
          ),
          const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 40),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: LinearProgressIndicator(value: recording ? _level : 0, minHeight: 10),
            ),
          ),
          const SizedBox(height: 28),
          Center(
            child: SizedBox(
              width: 96,
              height: 96,
              child: FloatingActionButton.large(
                heroTag: 'rec',
                backgroundColor: recording ? scheme.error : scheme.primary,
                foregroundColor: Colors.white,
                onPressed: recording ? _stop : _start,
                tooltip: recording ? 'إيقاف التسجيل' : 'بدء التسجيل',
                child: Icon(recording ? Icons.stop : Icons.mic, size: 44),
              ),
            ),
          ),
          const SizedBox(height: 12),
          Center(
            child: Text(
              recording
                  ? 'جارٍ التسجيل… اضغط للإيقاف (الحد الأقصى 5 دقائق)'
                  : _state == _RecState.recorded
                      ? 'استمع إلى التسجيل ثم احفظه أو أعد التسجيل'
                      : 'اضغط على الميكروفون لبدء التسجيل',
              style: TextStyle(color: scheme.onSurfaceVariant),
            ),
          ),
          if (_state == _RecState.recorded && _path != null) ...[
            const SizedBox(height: 20),
            SampleTile(
              sample: VoiceSample(
                filePath: _path!,
                durationMs: _elapsed.inMilliseconds,
                source: 'recorded',
                createdAt: DateTime.now(),
              ),
              index: 0,
              player: _preview,
            ),
          ],
        ],
      ),
      bottomNavigationBar: _state == _RecState.recorded
          ? SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                child: Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _start,
                        icon: const Icon(Icons.replay),
                        label: const Text('إعادة التسجيل'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: FilledButton.icon(onPressed: _save, icon: const Icon(Icons.check), label: const Text('حفظ')),
                    ),
                  ],
                ),
              ),
            )
          : null,
    );
  }
}
