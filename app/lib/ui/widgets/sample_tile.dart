import 'dart:async';

import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import 'package:path/path.dart' as p;

import '../../core/formatters.dart';
import '../../data/models.dart';

/// Shared preview player for local voice recordings (independent from the reading player).
class SamplePreviewPlayer extends ChangeNotifier {
  final AudioPlayer _player = AudioPlayer();
  String? playingPath;
  StreamSubscription<PlayerState>? _sub;

  SamplePreviewPlayer() {
    _sub = _player.playerStateStream.listen((s) {
      if (s.processingState == ProcessingState.completed) {
        playingPath = null;
        _player.stop();
      }
      notifyListeners();
    });
  }

  bool isPlaying(String path) => playingPath == path && _player.playing;

  Future<void> toggle(String path) async {
    if (playingPath == path && _player.playing) {
      await _player.pause();
      playingPath = null;
      notifyListeners();
      return;
    }
    try {
      playingPath = path;
      notifyListeners();
      await _player.setFilePath(path);
      unawaited(_player.play().catchError((Object _) {}));
    } catch (_) {
      playingPath = null;
      notifyListeners();
      rethrow;
    }
  }

  Future<void> stop() async {
    playingPath = null;
    await _player.stop();
    notifyListeners();
  }

  @override
  void dispose() {
    _sub?.cancel();
    _player.dispose();
    super.dispose();
  }
}

class SampleTile extends StatelessWidget {
  const SampleTile({
    super.key,
    required this.sample,
    required this.index,
    required this.player,
    this.onDelete,
  });

  final VoiceSample sample;
  final int index;
  final SamplePreviewPlayer player;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return ListenableBuilder(
      listenable: player,
      builder: (context, _) {
        final playing = player.isPlaying(sample.filePath);
        return Card(
          elevation: 0,
          color: scheme.surfaceContainerLow,
          margin: const EdgeInsets.symmetric(vertical: 4),
          child: ListTile(
            leading: IconButton.filledTonal(
              tooltip: playing ? 'إيقاف' : 'استماع',
              icon: Icon(playing ? Icons.stop : Icons.play_arrow),
              onPressed: () async {
                try {
                  await player.toggle(sample.filePath);
                } catch (_) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('لا يمكن تشغيل هذا الملف على جهازك، لكن يمكن رفعه.')),
                    );
                  }
                }
              },
            ),
            title: Text('تسجيل ${index + 1}'),
            subtitle: Text(
              '${sample.source == 'recorded' ? 'تسجيل مباشر' : p.extension(sample.filePath).replaceFirst('.', '').toUpperCase()}'
              ' • ${sample.duration == null ? 'مدة غير معروفة' : formatDuration(sample.duration!)}',
            ),
            trailing: onDelete == null
                ? null
                : IconButton(tooltip: 'حذف', icon: const Icon(Icons.delete_outline), onPressed: onDelete),
          ),
        );
      },
    );
  }
}
