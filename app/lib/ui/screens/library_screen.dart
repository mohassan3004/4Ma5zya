import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../data/models.dart';
import '../../state/library_controller.dart';
import '../widgets/common.dart';
import '../widgets/document_tile.dart';
import 'document_info_sheet.dart';
import 'home_screen.dart';

class LibraryScreen extends StatefulWidget {
  const LibraryScreen({super.key});

  @override
  State<LibraryScreen> createState() => _LibraryScreenState();
}

class _LibraryScreenState extends State<LibraryScreen> {
  final _search = TextEditingController();
  String? _category;
  bool _favorites = false;
  LibrarySort _sort = LibrarySort.recent;

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  static const _sortLabels = {
    LibrarySort.recent: 'آخر فتح',
    LibrarySort.title: 'الاسم',
    LibrarySort.added: 'تاريخ الإضافة',
    LibrarySort.progress: 'نسبة التقدم',
  };

  @override
  Widget build(BuildContext context) {
    final library = context.watch<LibraryController>();
    final categories = library.categories;
    if (_category != null && !categories.contains(_category)) _category = null;
    final docs = library.filtered(query: _search.text, category: _category, favoritesOnly: _favorites, sort: _sort);

    return Scaffold(
      appBar: AppBar(
        title: const Text('مكتبتي'),
        actions: [
          PopupMenuButton<LibrarySort>(
            tooltip: 'الترتيب',
            icon: const Icon(Icons.sort),
            initialValue: _sort,
            onSelected: (s) => setState(() => _sort = s),
            itemBuilder: (_) => [
              for (final e in _sortLabels.entries) PopupMenuItem(value: e.key, child: Text('ترتيب حسب ${e.value}')),
            ],
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => importPdfs(context),
        icon: const Icon(Icons.upload_file),
        label: const Text('رفع PDF'),
      ),
      body: library.loading
          ? const Center(child: CircularProgressIndicator())
          : library.documents.isEmpty
              ? EmptyState(
                  icon: Icons.library_books_outlined,
                  title: 'مكتبتك فارغة',
                  message: 'ارفع ملفات PDF عربية من جهازك لتقرأها أو تستمع إليها. تبقى الملفات محفوظة على جهازك فقط.',
                  action: FilledButton.icon(
                    onPressed: () => importPdfs(context),
                    icon: const Icon(Icons.upload_file),
                    label: const Text('رفع ملف PDF'),
                  ),
                )
              : Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
                      child: TextField(
                        controller: _search,
                        onChanged: (_) => setState(() {}),
                        decoration: InputDecoration(
                          hintText: 'ابحث باسم المستند…',
                          prefixIcon: const Icon(Icons.search),
                          suffixIcon: _search.text.isEmpty
                              ? null
                              : IconButton(
                                  icon: const Icon(Icons.clear),
                                  onPressed: () => setState(_search.clear),
                                ),
                        ),
                      ),
                    ),
                    SizedBox(
                      height: 44,
                      child: ListView(
                        scrollDirection: Axis.horizontal,
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        children: [
                          _chip('الكل', _category == null && !_favorites, () => setState(() {
                                _category = null;
                                _favorites = false;
                              })),
                          _chip('المفضلة', _favorites, () => setState(() => _favorites = !_favorites)),
                          for (final c in categories)
                            _chip(c, _category == c, () => setState(() => _category = _category == c ? null : c)),
                        ],
                      ),
                    ),
                    Expanded(
                      child: docs.isEmpty
                          ? const EmptyState(icon: Icons.search_off, title: 'لا توجد نتائج مطابقة')
                          : ListView.builder(
                              padding: const EdgeInsets.fromLTRB(16, 4, 16, 96),
                              itemCount: docs.length,
                              itemBuilder: (_, i) => DocumentTile(
                                doc: docs[i],
                                onTap: () => openReader(context, docs[i]),
                                onMore: () => _showActions(docs[i]),
                              ),
                            ),
                    ),
                  ],
                ),
    );
  }

  Widget _chip(String label, bool selected, VoidCallback onTap) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4),
        child: FilterChip(label: Text(label), selected: selected, onSelected: (_) => onTap()),
      );

  void _showActions(DocumentEntity doc) => showDocumentActions(context, doc);
}
