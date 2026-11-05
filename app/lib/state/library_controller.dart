import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:uuid/uuid.dart';

import '../core/errors.dart';
import '../data/file_storage.dart';
import '../data/models.dart';
import '../data/repositories/document_repository.dart';
import '../services/pdf_text_service.dart';

class ImportResult {
  const ImportResult(this.imported, this.failed);
  final List<DocumentEntity> imported;
  final List<String> failed;
}

enum LibrarySort { recent, title, added, progress }

class LibraryController extends ChangeNotifier {
  LibraryController(this._repo, this._files);

  final DocumentRepository _repo;
  final FileStorage _files;

  List<DocumentEntity> documents = [];
  bool loading = true;

  Future<void> load() async {
    documents = await _repo.all();
    loading = false;
    notifyListeners();
  }

  DocumentEntity? byId(String id) {
    for (final d in documents) {
      if (d.id == id) return d;
    }
    return null;
  }

  List<DocumentEntity> get recent {
    final list = documents.where((d) => d.lastOpenedAt != null).toList()
      ..sort((a, b) => b.lastOpenedAt!.compareTo(a.lastOpenedAt!));
    return list;
  }

  DocumentEntity? get continueReading {
    final r = recent;
    return r.isEmpty ? null : r.first;
  }

  List<String> get categories {
    final set = <String>{};
    for (final d in documents) {
      if (d.category != null && d.category!.isNotEmpty) set.add(d.category!);
    }
    return set.toList()..sort();
  }

  List<DocumentEntity> filtered({String query = '', String? category, bool favoritesOnly = false, LibrarySort sort = LibrarySort.recent}) {
    final q = query.trim().toLowerCase();
    final list = documents.where((d) {
      if (favoritesOnly && !d.isFavorite) return false;
      if (category != null && d.category != category) return false;
      if (q.isNotEmpty && !d.title.toLowerCase().contains(q)) return false;
      return true;
    }).toList();
    switch (sort) {
      case LibrarySort.recent:
        list.sort((a, b) => (b.lastOpenedAt ?? b.addedAt).compareTo(a.lastOpenedAt ?? a.addedAt));
      case LibrarySort.title:
        list.sort((a, b) => a.title.compareTo(b.title));
      case LibrarySort.added:
        list.sort((a, b) => b.addedAt.compareTo(a.addedAt));
      case LibrarySort.progress:
        list.sort((a, b) => b.progress.compareTo(a.progress));
    }
    return list;
  }

  /// Lets the user pick one or more PDFs and copies them into app-private storage.
  Future<ImportResult?> importPdfs() async {
    final picked = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['pdf'],
      allowMultiple: true,
    );
    if (picked == null || picked.files.isEmpty) return null;
    final ok = <DocumentEntity>[];
    final failed = <String>[];
    for (final f in picked.files) {
      final src = f.path;
      if (src == null) {
        failed.add(f.name);
        continue;
      }
      final id = const Uuid().v4();
      final dest = p.join(_files.pdfDir.path, '$id.pdf');
      try {
        await File(src).copy(dest);
        final pages = await PdfTextService.countPages(dest);
        if (pages < 1) throw const AppException('الملف لا يحتوي على صفحات.');
        final doc = DocumentEntity(
          id: id,
          title: p.basenameWithoutExtension(f.name),
          filePath: dest,
          fileSize: await File(dest).length(),
          pageCount: pages,
          lastPage: 1,
          lastSentence: 0,
          isFavorite: false,
          addedAt: DateTime.now(),
        );
        await _repo.insert(doc);
        ok.add(doc);
      } catch (_) {
        await _files.deleteQuietly(dest);
        failed.add(f.name);
      }
    }
    await load();
    return ImportResult(ok, failed);
  }

  Future<void> delete(DocumentEntity doc) async {
    await _repo.delete(doc.id);
    await _files.deleteQuietly(doc.filePath);
    await load();
  }

  Future<void> _save(DocumentEntity updated) async {
    await _repo.update(updated);
    final i = documents.indexWhere((d) => d.id == updated.id);
    if (i >= 0) documents[i] = updated;
    notifyListeners();
  }

  Future<void> rename(DocumentEntity doc, String title) => _save(doc.copyWith(title: title.trim()));

  Future<void> setCategory(DocumentEntity doc, String? category) {
    final c = category?.trim();
    return _save(c == null || c.isEmpty ? doc.copyWith(clearCategory: true) : doc.copyWith(category: c));
  }

  Future<void> toggleFavorite(DocumentEntity doc) => _save(doc.copyWith(isFavorite: !doc.isFavorite));

  Future<void> markOpened(DocumentEntity doc) => _save((byId(doc.id) ?? doc).copyWith(lastOpenedAt: DateTime.now()));

  /// Saves the reading position (page + sentence index within the page).
  Future<void> saveProgress(String docId, int page, int sentence) async {
    await _repo.saveProgress(docId, page, sentence);
    final i = documents.indexWhere((d) => d.id == docId);
    if (i >= 0) {
      documents[i] = documents[i].copyWith(lastPage: page, lastSentence: sentence, lastOpenedAt: DateTime.now());
      notifyListeners();
    }
  }

  Future<List<Bookmark>> bookmarks(String docId) => _repo.bookmarks(docId);
  Future<void> addBookmark(String docId, int page, String? note) => _repo.addBookmark(docId, page, note);
  Future<void> deleteBookmark(int id) => _repo.deleteBookmark(id);
  Future<int> extractedPages(String docId) => _repo.extractedPageCount(docId);
}
