import 'dart:async';

import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import 'package:provider/provider.dart';

import '../../app_services.dart';
import '../../core/arabic_text.dart';
import '../../core/constants.dart';
import '../../core/errors.dart';
import '../../state/read_aloud_controller.dart';
import '../../state/voices_controller.dart';
import '../widgets/common.dart';

/// Generates and plays a short AI speech sample with a voice.
class VoicePreviewScreen extends StatefulWidget {
  const VoicePreviewScreen({super.key, required this.voiceId});

  final String voiceId;

  @override
  State<VoicePreviewScreen> createState() => _VoicePreviewScreenState();
}

class _VoicePreviewScreenState extends State<VoicePreviewScreen> {
  final _text = TextEditingController(text: defaultPreviewText);
  final _player = AudioPlayer();
  bool _busy = false;
  String? _error;
  StreamSubscription<PlayerState>? _sub;

  @override
  void initState() {
    super.initState();
    _sub = _player.playerStateStream.listen((_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _sub?.cancel();
    _player.dispose();
    _text.dispose();
    super.dispose();
  }

  bool get _playing => _player.playing && _player.processingState != ProcessingState.completed;

  Future<void> _generate() async {
    final text = _text.text.trim();
    if (text.isEmpty) return;
    final reader = context.read<ReadAloudController>();
    final tts = context.read<AppServices>().tts;
    if (reader.isPlaying) await reader.pause();
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final file = await tts.audioFor(voiceId: widget.voiceId, text: ArabicText.prepareForSpeech(text));
      await _player.setFilePath(file.path);
      unawaited(_player.play().catchError((Object _) {}));
    } catch (e) {
      _error = errorMessage(e);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final voices = context.watch<VoicesController>();
    final voice = voices.byId(widget.voiceId);
    final scheme = Theme.of(context).colorScheme;
    if (voice == null) {
      return Scaffold(appBar: AppBar(), body: const EmptyState(icon: Icons.error_outline, title: 'الصوت غير موجود'));
    }
    return Scaffold(
      appBar: AppBar(title: Text('معاينة "${voice.name}"')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (!voice.isReady)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: InfoBanner(message: 'حالة الصوت: ${voice.statusLabel}. قد لا تنجح المعاينة قبل أن يصبح جاهزًا.', isError: true),
            ),
          const Text('اكتب نصًا عربيًا للاستماع إليه بهذا الصوت:'),
          const SizedBox(height: 8),
          TextField(controller: _text, maxLines: 5, maxLength: 500),
          const SizedBox(height: 8),
          FilledButton.icon(
            onPressed: _busy ? null : (_playing ? _player.stop : _generate),
            icon: _busy
                ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2.5))
                : Icon(_playing ? Icons.stop : Icons.play_arrow),
            label: Text(_busy ? 'جارٍ توليد الكلام…' : (_playing ? 'إيقاف' : 'توليد واستماع')),
          ),
          if (_error != null) ...[
            const SizedBox(height: 12),
            InfoBanner(message: _error!, isError: true),
          ],
          const SizedBox(height: 24),
          if (voice.isDefault)
            Row(
              children: [
                Icon(Icons.check_circle, color: scheme.primary),
                const SizedBox(width: 8),
                const Text('هذا هو صوت القراءة الافتراضي.'),
              ],
            )
          else
            OutlinedButton.icon(
              onPressed: () async {
                await voices.setDefault(voice);
                if (context.mounted) showSnack(context, 'أصبح "${voice.name}" صوت القراءة الافتراضي.');
              },
              icon: const Icon(Icons.star_outline),
              label: const Text('تعيين كصوت القراءة الافتراضي'),
            ),
          const SizedBox(height: 12),
          Text(
            'يُحفظ الصوت المُولَّد على جهازك، فإعادة الاستماع إلى النص نفسه لا تستهلك رصيدًا إضافيًا.',
            style: TextStyle(fontSize: 12.5, color: scheme.onSurfaceVariant),
          ),
        ],
      ),
    );
  }
}
