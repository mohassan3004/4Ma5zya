import 'package:sqflite/sqflite.dart';

import '../database.dart';
import '../models.dart';

class VoiceRepository {
  VoiceRepository(this._db);

  final AppDatabase _db;
  Database get _d => _db.db;

  Future<List<VoiceProfile>> all() async {
    final rows = await _d.query('voices', orderBy: 'is_default DESC, created_at DESC');
    return rows.map(VoiceProfile.fromMap).toList();
  }

  Future<VoiceProfile?> byId(String id) async {
    final rows = await _d.query('voices', where: 'voice_id = ?', whereArgs: [id], limit: 1);
    return rows.isEmpty ? null : VoiceProfile.fromMap(rows.first);
  }

  Future<VoiceProfile?> defaultVoice() async {
    final rows = await _d.query('voices', where: 'is_default = 1', limit: 1);
    return rows.isEmpty ? null : VoiceProfile.fromMap(rows.first);
  }

  Future<void> upsert(VoiceProfile v) =>
      _d.insert('voices', v.toMap(), conflictAlgorithm: ConflictAlgorithm.replace);

  Future<void> setDefault(String voiceId) async {
    await _d.transaction((txn) async {
      await txn.update('voices', {'is_default': 0});
      await txn.update('voices', {'is_default': 1}, where: 'voice_id = ?', whereArgs: [voiceId]);
    });
  }

  Future<void> delete(String voiceId) => _d.delete('voices', where: 'voice_id = ?', whereArgs: [voiceId]);

  Future<List<VoiceSample>> samples(String voiceId) async {
    final rows = await _d.query('voice_samples',
        where: 'voice_id = ?', whereArgs: [voiceId], orderBy: 'created_at ASC');
    return rows.map(VoiceSample.fromMap).toList();
  }

  Future<void> addSample(VoiceSample s) => _d.insert('voice_samples', s.toMap());

  Future<void> deleteSample(int id) => _d.delete('voice_samples', where: 'id = ?', whereArgs: [id]);
}
