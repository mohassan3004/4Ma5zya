import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

/// App-private directories. Nothing here is visible to other apps or uploaded anywhere
/// unless the user explicitly creates a voice (samples are then sent to the private backend).
class FileStorage {
  FileStorage._(this.pdfDir, this.samplesDir, this.ttsCacheDir);

  final Directory pdfDir;
  final Directory samplesDir;
  final Directory ttsCacheDir;

  static Future<FileStorage> create() async {
    final docs = await getApplicationDocumentsDirectory();
    final support = await getApplicationSupportDirectory();
    final pdf = Directory(p.join(docs.path, 'pdfs'));
    final samples = Directory(p.join(support.path, 'voice_samples'));
    final cache = Directory(p.join(support.path, 'tts_cache'));
    for (final d in [pdf, samples, cache]) {
      if (!d.existsSync()) await d.create(recursive: true);
    }
    return FileStorage._(pdf, samples, cache);
  }

  Future<void> deleteQuietly(String path) async {
    try {
      final f = File(path);
      if (await f.exists()) await f.delete();
    } catch (_) {}
  }

  Future<int> directorySize(Directory dir) async {
    var total = 0;
    if (!await dir.exists()) return 0;
    await for (final e in dir.list(recursive: true, followLinks: false)) {
      if (e is File) {
        try {
          total += await e.length();
        } catch (_) {}
      }
    }
    return total;
  }
}
