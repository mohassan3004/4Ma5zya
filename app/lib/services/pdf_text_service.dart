import 'dart:async';

import 'package:pdfrx/pdfrx.dart';

import '../core/arabic_text.dart';
import '../core/errors.dart';
import '../data/models.dart';
import '../data/repositories/document_repository.dart';

/// Extracts text from PDF pages on demand (page by page, so very long documents stay fast)
/// and caches the raw text in SQLite so each page is extracted at most once.
class PdfTextService {
  PdfTextService(this._docs);

  final DocumentRepository _docs;
  PdfDocument? _open;
  String? _openPath;
  Future<void> _queue = Future<void>.value();

  /// Runs PDF engine operations one at a time.
  Future<T> _serialized<T>(Future<T> Function() task) {
    final completer = Completer<T>();
    _queue = _queue.then((_) async {
      try {
        completer.complete(await task());
      } catch (e, s) {
        completer.completeError(e, s);
      }
    });
    return completer.future;
  }

  /// Opens a PDF only to validate it and count its pages.
  static Future<int> countPages(String path) async {
    final PdfDocument doc;
    try {
      doc = await PdfDocument.openFile(path);
    } catch (_) {
      throw const AppException('تعذر فتح الملف. قد يكون تالفًا أو محميًا بكلمة مرور.', code: 'invalid_pdf');
    }
    try {
      return doc.pages.length;
    } finally {
      await doc.dispose();
    }
  }

  Future<String> _extractRaw(String path, int page) async {
    if (_openPath != path || _open == null) {
      final old = _open;
      _open = null;
      _openPath = null;
      if (old != null) await old.dispose();
      _open = await PdfDocument.openFile(path);
      _openPath = path;
    }
    final doc = _open!;
    if (page < 1 || page > doc.pages.length) return '';
    final dynamic text = await doc.pages[page - 1].loadText();
    final String? full = text?.fullText as String?;
    return full ?? '';
  }

  Future<String> rawPageText(DocumentEntity doc, int page) async {
    final cached = await _docs.rawPageText(doc.id, page);
    if (cached != null) return cached;
    final String raw;
    try {
      raw = await _serialized(() => _extractRaw(doc.filePath, page));
    } catch (_) {
      throw const AppException('تعذر استخراج النص من هذه الصفحة.', code: 'extract_failed');
    }
    await _docs.putRawPageText(doc.id, page, raw);
    return raw;
  }

  /// Clean, logical-order Arabic text for a page.
  Future<String> pageText(DocumentEntity doc, int page, {bool? reverse}) async {
    return ArabicText.cleanPageText(await rawPageText(doc, page), reverse: reverse);
  }

  /// Searches the whole document, extracting pages that were not extracted yet.
  Future<List<SearchHit>> search(
    DocumentEntity doc,
    String query, {
    bool? reverse,
    void Function(int done, int total)? onProgress,
    bool Function()? isCancelled,
    int maxHits = 200,
  }) async {
    final q = ArabicText.foldForSearch(query.trim());
    if (q.isEmpty) return const [];
    final hits = <SearchHit>[];
    for (var page = 1; page <= doc.pageCount; page++) {
      if (isCancelled?.call() ?? false) break;
      final text = ArabicText.foldForSearch(await pageText(doc, page, reverse: reverse)).replaceAll('\n', ' ');
      var from = 0;
      while (hits.length < maxHits) {
        final idx = text.indexOf(q, from);
        if (idx < 0) break;
        final start = (idx - 40).clamp(0, text.length);
        final end = (idx + q.length + 40).clamp(0, text.length);
        hits.add(SearchHit(
          page: page,
          snippet: '${start > 0 ? '…' : ''}${text.substring(start, end)}${end < text.length ? '…' : ''}',
        ));
        from = idx + q.length;
      }
      onProgress?.call(page, doc.pageCount);
      if (hits.length >= maxHits) break;
    }
    return hits;
  }

  Future<void> close() => _serialized(() async {
        final old = _open;
        _open = null;
        _openPath = null;
        if (old != null) await old.dispose();
      });
}
