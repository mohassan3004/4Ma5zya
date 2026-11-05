import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

import '../data/database.dart';
import '../data/file_storage.dart';
import '../data/remote/api_client.dart';

/// Generates speech through the backend and caches every generated chunk on the device,
/// so text that was already read is never generated (or paid for) twice and plays offline.
class TtsService {
  TtsService(this._api, this._db, this._files);

  final ApiClient _api;
  final AppDatabase _db;
  final FileStorage _files;
  final Map<String, Future<File>> _inflight = {};

  int cacheLimitBytes = 500 * 1024 * 1024;

  static String cacheKey(String voiceId, String text) =>
      sha256.convert(utf8.encode('$voiceId\u0000$text')).toString();

  Future<File?> cached(String voiceId, String text) async {
    final key = cacheKey(voiceId, text);
    final rows = await _db.db.query('tts_cache', where: 'cache_key = ?', whereArgs: [key], limit: 1);
    if (rows.isEmpty) return null;
    final file = File(rows.first['file_path']! as String);
    if (!await file.exists()) {
      await _db.db.delete('tts_cache', where: 'cache_key = ?', whereArgs: [key]);
      return null;
    }
    await _db.db.update(
      'tts_cache',
      {'last_used_at': DateTime.now().millisecondsSinceEpoch},
      where: 'cache_key = ?',
      whereArgs: [key],
    );
    return file;
  }

  Future<File> audioFor({
    required String voiceId,
    required String text,
    String previousText = '',
    String nextText = '',
  }) async {
    final hit = await cached(voiceId, text);
    if (hit != null) return hit;
    final key = cacheKey(voiceId, text);
    final running = _inflight[key];
    if (running != null) return running;
    final future = _generate(key, voiceId, text, previousText, nextText);
    _inflight[key] = future;
    try {
      return await future;
    } finally {
      _inflight.remove(key);
    }
  }

  Future<File> _generate(String key, String voiceId, String text, String prev, String next) async {
    final audio = await _api.synthesize(voiceId: voiceId, text: text, previousText: prev, nextText: next);
    final ext = RegExp(r'^[a-z0-9]{2,5}$').hasMatch(audio.extension) ? audio.extension : 'mp3';
    final path = p.join(_files.ttsCacheDir.path, '$key.$ext');
    final tmp = File('$path.part');
    await tmp.writeAsBytes(audio.bytes, flush: true);
    final file = await tmp.rename(path);
    final now = DateTime.now().millisecondsSinceEpoch;
    await _db.db.insert(
      'tts_cache',
      {
        'cache_key': key,
        'voice_id': voiceId,
        'file_path': path,
        'bytes': audio.bytes.length,
        'created_at': now,
        'last_used_at': now,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
    unawaited(_evictIfNeeded());
    return file;
  }

  Future<int> totalBytes() async {
    final r = await _db.db.rawQuery('SELECT COALESCE(SUM(bytes), 0) AS s FROM tts_cache');
    return (r.first['s'] as num?)?.toInt() ?? 0;
  }

  Future<void> _evictIfNeeded() async {
    var total = await totalBytes();
    if (total <= cacheLimitBytes) return;
    final target = (cacheLimitBytes * 0.9).round();
    final rows = await _db.db.query('tts_cache', orderBy: 'last_used_at ASC', limit: 500);
    for (final row in rows) {
      if (total <= target) break;
      await _files.deleteQuietly(row['file_path']! as String);
      await _db.db.delete('tts_cache', where: 'cache_key = ?', whereArgs: [row['cache_key']]);
      total -= row['bytes']! as int;
    }
  }

  /// Deletes cached audio (all of it, or only for one voice).
  Future<void> clear({String? voiceId}) async {
    final rows = voiceId == null
        ? await _db.db.query('tts_cache')
        : await _db.db.query('tts_cache', where: 'voice_id = ?', whereArgs: [voiceId]);
    for (final row in rows) {
      await _files.deleteQuietly(row['file_path']! as String);
    }
    if (voiceId == null) {
      await _db.db.delete('tts_cache');
    } else {
      await _db.db.delete('tts_cache', where: 'voice_id = ?', whereArgs: [voiceId]);
    }
  }
}
