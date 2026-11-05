import 'package:record/record.dart';

/// Microphone recording (AAC in an .m4a container, mono 44.1 kHz – accepted by the provider).
class RecorderService {
  final AudioRecorder _recorder = AudioRecorder();

  Future<bool> hasPermission() => _recorder.hasPermission();

  Future<void> start(String path) => _recorder.start(
        const RecordConfig(
          encoder: AudioEncoder.aacLc,
          sampleRate: 44100,
          bitRate: 128000,
          numChannels: 1,
        ),
        path: path,
      );

  Future<String?> stop() => _recorder.stop();

  Future<void> cancel() => _recorder.cancel();

  Stream<Amplitude> amplitude() => _recorder.onAmplitudeChanged(const Duration(milliseconds: 120));

  Future<void> dispose() => _recorder.dispose();
}
