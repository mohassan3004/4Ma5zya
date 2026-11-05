import 'package:sqflite/sqflite.dart';

import '../database.dart';

/// Non-sensitive preferences (key/value). Secrets go to SecureStore instead.
class SettingsRepository {
  SettingsRepository(this._db);

  final AppDatabase _db;

  Future<Map<String, String>> load() async {
    final rows = await _db.db.query('settings');
    return {for (final r in rows) r['key']! as String: r['value']! as String};
  }

  Future<void> put(String key, String value) => _db.db.insert(
        'settings',
        {'key': key, 'value': value},
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
}
