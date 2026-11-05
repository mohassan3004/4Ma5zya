import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';

/// Local SQLite database. All library, voice and cache metadata lives on the device.
class AppDatabase {
  AppDatabase._(this.db);

  final Database db;

  static Future<AppDatabase> open() async {
    final dir = await getApplicationSupportDirectory();
    final path = p.join(dir.path, 'ma5zya.db');
    final db = await openDatabase(
      path,
      version: 1,
      onConfigure: (db) async {
        await db.execute('PRAGMA foreign_keys = ON');
      },
      onCreate: (db, version) async {
        final batch = db.batch();
        batch.execute('''
          CREATE TABLE documents (
            id TEXT PRIMARY KEY,
            title TEXT NOT NULL,
            file_path TEXT NOT NULL,
            file_size INTEGER NOT NULL,
            page_count INTEGER NOT NULL,
            last_page INTEGER NOT NULL DEFAULT 1,
            last_sentence INTEGER NOT NULL DEFAULT 0,
            category TEXT,
            is_favorite INTEGER NOT NULL DEFAULT 0,
            added_at INTEGER NOT NULL,
            last_opened_at INTEGER
          )''');
        batch.execute('''
          CREATE TABLE page_texts (
            doc_id TEXT NOT NULL REFERENCES documents(id) ON DELETE CASCADE,
            page INTEGER NOT NULL,
            raw_text TEXT NOT NULL,
            PRIMARY KEY (doc_id, page)
          )''');
        batch.execute('''
          CREATE TABLE bookmarks (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            doc_id TEXT NOT NULL REFERENCES documents(id) ON DELETE CASCADE,
            page INTEGER NOT NULL,
            note TEXT,
            created_at INTEGER NOT NULL
          )''');
        batch.execute('''
          CREATE TABLE voices (
            voice_id TEXT PRIMARY KEY,
            name TEXT NOT NULL,
            provider TEXT NOT NULL,
            status TEXT NOT NULL,
            consent_type TEXT NOT NULL,
            consent_person TEXT,
            created_at INTEGER NOT NULL,
            is_default INTEGER NOT NULL DEFAULT 0,
            sample_count INTEGER NOT NULL DEFAULT 0,
            total_seconds REAL
          )''');
        batch.execute('''
          CREATE TABLE voice_samples (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            voice_id TEXT REFERENCES voices(voice_id) ON DELETE CASCADE,
            file_path TEXT NOT NULL,
            duration_ms INTEGER,
            source TEXT NOT NULL,
            created_at INTEGER NOT NULL
          )''');
        batch.execute('''
          CREATE TABLE tts_cache (
            cache_key TEXT PRIMARY KEY,
            voice_id TEXT NOT NULL,
            file_path TEXT NOT NULL,
            bytes INTEGER NOT NULL,
            created_at INTEGER NOT NULL,
            last_used_at INTEGER NOT NULL
          )''');
        batch.execute('CREATE INDEX idx_cache_used ON tts_cache(last_used_at)');
        batch.execute('''
          CREATE TABLE settings (
            key TEXT PRIMARY KEY,
            value TEXT NOT NULL
          )''');
        await batch.commit(noResult: true);
      },
    );
    return AppDatabase._(db);
  }
}
