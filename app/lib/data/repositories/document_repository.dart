import 'package:sqflite/sqflite.dart';

import '../database.dart';
import '../models.dart';

class DocumentRepository {
  DocumentRepository(this._db);

  final AppDatabase _db;
  Database get _d => _db.db;

  Future<List<DocumentEntity>> all() async {
    final rows = await _d.query('documents', orderBy: 'COALESCE(last_opened_at, added_at) DESC');
    return rows.map(DocumentEntity.fromMap).toList();
  }

  Future<DocumentEntity?> byId(String id) async {
    final rows = await _d.query('documents', where: 'id = ?', whereArgs: [id], limit: 1);
    return rows.isEmpty ? null : DocumentEntity.fromMap(rows.first);
  }

  Future<void> insert(DocumentEntity doc) => _d.insert('documents', doc.toMap());

  Future<void> update(DocumentEntity doc) =>
      _d.update('documents', doc.toMap(), where: 'id = ?', whereArgs: [doc.id]);

  Future<void> saveProgress(String id, int page, int sentence) => _d.update(
        'documents',
        {
          'last_page': page,
          'last_sentence': sentence,
          'last_opened_at': DateTime.now().millisecondsSinceEpoch,
        },
        where: 'id = ?',
        whereArgs: [id],
      );

  Future<void> delete(String id) => _d.delete('documents', where: 'id = ?', whereArgs: [id]);

  // ---- page text cache (raw extracted text) --------------------------------------
  Future<String?> rawPageText(String docId, int page) async {
    final rows = await _d.query(
      'page_texts',
      columns: ['raw_text'],
      where: 'doc_id = ? AND page = ?',
      whereArgs: [docId, page],
      limit: 1,
    );
    return rows.isEmpty ? null : rows.first['raw_text'] as String;
  }

  Future<void> putRawPageText(String docId, int page, String text) => _d.insert(
        'page_texts',
        {'doc_id': docId, 'page': page, 'raw_text': text},
        conflictAlgorithm: ConflictAlgorithm.replace,
      );

  Future<int> extractedPageCount(String docId) async {
    final r = await _d.rawQuery('SELECT COUNT(*) AS c FROM page_texts WHERE doc_id = ?', [docId]);
    return (r.first['c'] as int?) ?? 0;
  }

  // ---- bookmarks ---------------------------------------------------------------------
  Future<List<Bookmark>> bookmarks(String docId) async {
    final rows = await _d.query('bookmarks', where: 'doc_id = ?', whereArgs: [docId], orderBy: 'page ASC');
    return rows.map(Bookmark.fromMap).toList();
  }

  Future<void> addBookmark(String docId, int page, String? note) => _d.insert('bookmarks', {
        'doc_id': docId,
        'page': page,
        'note': (note == null || note.trim().isEmpty) ? null : note.trim(),
        'created_at': DateTime.now().millisecondsSinceEpoch,
      });

  Future<void> deleteBookmark(int id) => _d.delete('bookmarks', where: 'id = ?', whereArgs: [id]);
}
