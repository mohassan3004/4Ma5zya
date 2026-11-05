import 'package:just_audio/just_audio.dart';

/// Reads the duration of a local audio file. Returns null if the platform cannot decode it
/// (the backend still validates the file, so such files are not rejected locally).
Future<Duration?> probeAudioDuration(String path) async {
  final player = AudioPlayer();
  try {
    return await player.setFilePath(path).timeout(const Duration(seconds: 10));
  } catch (_) {
    return null;
  } finally {
    await player.dispose();
  }
}
