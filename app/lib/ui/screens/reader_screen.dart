import 'dart:async';

import 'package:flutter/material.dart';
import 'package:pdfrx/pdfrx.dart';
import 'package:provider/provider.dart';

import '../../app_services.dart';
import '../../core/errors.dart';
import '../../data/models.dart';
import '../../state/library_controller.dart';
import '../../state/read_aloud_controller.dart';
import '../../state/settings_controller.dart';
import '../widgets/common.dart';
import '../widgets/mini_player.dart';
import 'document_info_sheet.dart';
import 'home_shell.dart';

class ReaderScreen extends StatefulWidget {
  const ReaderScreen({super.key, required this.docId, this.autoPlay = false, this.initialPage});

  final String docId;
  final bool autoPlay;
  final int? initialPage;

  @override
  State<ReaderScreen> createState() => _ReaderScreenState();
}

class _ReaderScreenState extends State<ReaderScreen> {
  final _pdf = PdfViewerController();
  late final ReadAloudController _reader;
  late final SettingsController _settings;
  late final LibraryController _library;
  DocumentEntity? _doc;
  int _page = 1;
  bool _ready = false;
  Timer? _saveTimer;

  @override
  void initState() {
    super.initState();
    _reader = context.read<ReadAloudController>();
    _settings = context.read<SettingsController>();
    _library = context.read<LibraryController>();
    _doc = _library.byId(widget.docId);
    final d = _doc;
    if (d != null) {
      _page = (widget.initialPage ?? d.lastPage).clamp(1, d.pageCount);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _library.markOpened(d);
        if (widget.autoPlay) _listen();
      });
    }
    _reader.addListener(_onReaderChanged);
  }

  @override
  void dispose() {
    _reader.removeListener(_onReaderChanged);
    _saveTimer?.cancel();
    super.dispose();
  }

  bool get _readingThisDoc => _reader.doc?.id == widget.docId;

  void _onReaderChanged() {
    if (!_ready || !_readingThisDoc || !_settings.followPage) return;
    if (_reader.page != _page) {
      _page = _reader.page;
      _pdf.goToPage(pageNumber: _reader.page);
      if (mounted) setState(() {});
    }
  }

  void _onPageChanged(int? p) {
    if (p == null || !mounted) return;
    setState(() => _page = p);
    // While listening, the audio engine owns the saved position.
    if (_readingThisDoc) return;
    _saveTimer?.cancel();
    _saveTimer = Timer(const Duration(milliseconds: 800), () {
      final d = _library.byId(widget.docId);
      if (d == null) return;
      _library.saveProgress(d.id, p, p == d.lastPage ? d.lastSentence : 0);
    });
  }

  Future<void> _listen() async {
    final d = _library.byId(widget.docId);
    if (d == null) return;
    if (_readingThisDoc) {
      await _reader.togglePlay();
      return;
    }
    try {
      await _reader.start(d, fromPage: _page == d.lastPage ? null : _page);
    } on AppException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(e.message),
        action: e.code == 'no_voice'
            ? SnackBarAction(
                label: 'أصواتي',
                onPressed: () {
                  Navigator.of(context).popUntil((r) => r.isFirst);
                  HomeShell.switchTab(context, 2);
                },
              )
            : null,
      ));
    }
  }

  Future<void> _goToPageDialog() async {
    final d = _doc;
    if (d == null) return;
    final v = await textInputDialog(
      context,
      title: 'الانتقال إلى صفحة (1 – ${d.pageCount})',
      initial: '$_page',
      keyboardType: TextInputType.number,
      maxLength: 6,
      confirmLabel: 'انتقال',
    );
    final n = int.tryParse(v ?? '');
    if (n == null) return;
    if (n < 1 || n > d.pageCount) {
      if (mounted) showSnack(context, 'رقم الصفحة خارج النطاق.', error: true);
      return;
    }
    await _jumpTo(n);
  }

  Future<void> _jumpTo(int page) async {
    await _pdf.goToPage(pageNumber: page);
    if (_readingThisDoc) await _reader.goToPage(page);
  }

  Future<void> _addBookmark() async {
    final note = await textInputDialog(
      context,
      title: 'علامة مرجعية – صفحة $_page',
      hint: 'ملاحظة (اختياري)',
      maxLength: 80,
      allowEmpty: true,
      confirmLabel: 'إضافة',
    );
    if (note == null) return;
    await _library.addBookmark(widget.docId, _page, note);
    if (mounted) showSnack(context, 'تمت إضافة علامة مرجعية للصفحة $_page.');
  }

  void _showBookmarks() {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (ctx) => _BookmarksSheet(docId: widget.docId, onOpen: (p) {
        Navigator.pop(ctx);
        _jumpTo(p);
      }),
    );
  }

  void _showSearch() {
    final d = _library.byId(widget.docId);
    if (d == null) return;
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (ctx) => _SearchSheet(doc: d, onOpen: (p) {
        Navigator.pop(ctx);
        _jumpTo(p);
      }),
    );
  }

  @override
  Widget build(BuildContext context) {
    final doc = context.select<LibraryController, DocumentEntity?>((l) => l.byId(widget.docId));
    if (doc == null) {
      return Scaffold(
        appBar: AppBar(),
        body: const EmptyState(icon: Icons.error_outline, title: 'المستند غير موجود', message: 'ربما تم حذفه.'),
      );
    }
    _doc = doc;
    final reader = context.watch<ReadAloudController>();
    final readingHere = reader.doc?.id == doc.id;
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: Text(doc.title, maxLines: 1, overflow: TextOverflow.ellipsis),
        actions: [
          IconButton(tooltip: 'بحث في النص', onPressed: _showSearch, icon: const Icon(Icons.search)),
          IconButton(tooltip: 'العلامات المرجعية', onPressed: _showBookmarks, icon: const Icon(Icons.bookmarks_outlined)),
          PopupMenuButton<String>(
            onSelected: (v) {
              switch (v) {
                case 'bookmark':
                  _addBookmark();
                case 'goto':
                  _goToPageDialog();
                case 'zoom_in':
                  _pdf.zoomUp();
                case 'zoom_out':
                  _pdf.zoomDown();
                case 'info':
                  showDocumentActions(context, doc);
              }
            },
            itemBuilder: (_) => const [
              PopupMenuItem(value: 'bookmark', child: ListTile(leading: Icon(Icons.bookmark_add_outlined), title: Text('إضافة علامة مرجعية'))),
              PopupMenuItem(value: 'goto', child: ListTile(leading: Icon(Icons.find_in_page_outlined), title: Text('الانتقال إلى صفحة'))),
              PopupMenuItem(value: 'zoom_in', child: ListTile(leading: Icon(Icons.zoom_in), title: Text('تكبير'))),
              PopupMenuItem(value: 'zoom_out', child: ListTile(leading: Icon(Icons.zoom_out), title: Text('تصغير'))),
              PopupMenuItem(value: 'info', child: ListTile(leading: Icon(Icons.info_outline), title: Text('معلومات المستند'))),
            ],
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: Container(
              color: scheme.surfaceContainerHighest.withValues(alpha: 0.5),
              child: PdfViewer.file(
                doc.filePath,
                controller: _pdf,
                initialPageNumber: _page,
                params: PdfViewerParams(
                  maxScale: 8,
                  onViewerReady: (document, controller) {
                    if (mounted) setState(() => _ready = true);
                  },
                  onPageChanged: _onPageChanged,
                ),
              ),
            ),
          ),
          if (readingHere) const MiniPlayer(showTitle: false),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
              child: Row(
                children: [
                  IconButton(
                    tooltip: 'الصفحة السابقة',
                    onPressed: _page > 1 ? () => _jumpTo(_page - 1) : null,
                    icon: const Icon(Icons.chevron_right),
                  ),
                  InkWell(
                    onTap: _goToPageDialog,
                    borderRadius: BorderRadius.circular(8),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                      child: Text('$_page / ${doc.pageCount}', style: const TextStyle(fontWeight: FontWeight.w700)),
                    ),
                  ),
                  IconButton(
                    tooltip: 'الصفحة التالية',
                    onPressed: _page < doc.pageCount ? () => _jumpTo(_page + 1) : null,
                    icon: const Icon(Icons.chevron_left),
                  ),
                  const Spacer(),
                  FilledButton.icon(
                    onPressed: _listen,
                    style: FilledButton.styleFrom(minimumSize: const Size(0, 46)),
                    icon: Icon(readingHere && reader.isPlaying ? Icons.pause : Icons.headphones),
                    label: Text(readingHere ? (reader.isPlaying ? 'إيقاف مؤقت' : 'متابعة الاستماع') : 'استمع'),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _BookmarksSheet extends StatefulWidget {
  const _BookmarksSheet({required this.docId, required this.onOpen});

  final String docId;
  final ValueChanged<int> onOpen;

  @override
  State<_BookmarksSheet> createState() => _BookmarksSheetState();
}

class _BookmarksSheetState extends State<_BookmarksSheet> {
  late Future<List<Bookmark>> _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<List<Bookmark>> _load() => context.read<LibraryController>().bookmarks(widget.docId);

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: SizedBox(
        height: MediaQuery.of(context).size.height * 0.5,
        child: FutureBuilder<List<Bookmark>>(
          future: _future,
          builder: (context, snap) {
            if (!snap.hasData) return const Center(child: CircularProgressIndicator());
            final items = snap.data!;
            if (items.isEmpty) {
              return const EmptyState(
                icon: Icons.bookmark_border,
                title: 'لا توجد علامات مرجعية',
                message: 'أضف علامة من قائمة الخيارات أثناء القراءة.',
              );
            }
            return ListView.builder(
              itemCount: items.length,
              itemBuilder: (_, i) {
                final b = items[i];
                return ListTile(
                  leading: const Icon(Icons.bookmark),
                  title: Text('صفحة ${b.page}'),
                  subtitle: b.note == null ? null : Text(b.note!),
                  onTap: () => widget.onOpen(b.page),
                  trailing: IconButton(
                    tooltip: 'حذف',
                    icon: const Icon(Icons.delete_outline),
                    onPressed: () async {
                      await context.read<LibraryController>().deleteBookmark(b.id);
                      if (!mounted) return;
                      setState(() => _future = _load());
                    },
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }
}

class _SearchSheet extends StatefulWidget {
  const _SearchSheet({required this.doc, required this.onOpen});

  final DocumentEntity doc;
  final ValueChanged<int> onOpen;

  @override
  State<_SearchSheet> createState() => _SearchSheetState();
}

class _SearchSheetState extends State<_SearchSheet> {
  final _query = TextEditingController();
  List<SearchHit>? _hits;
  bool _busy = false;
  int _done = 0;
  bool _cancelled = false;
  String? _error;

  @override
  void dispose() {
    _cancelled = true;
    _query.dispose();
    super.dispose();
  }

  Future<void> _run() async {
    final q = _query.text.trim();
    if (q.length < 2) return;
    final services = context.read<AppServices>();
    final settings = context.read<SettingsController>();
    setState(() {
      _busy = true;
      _done = 0;
      _hits = null;
      _error = null;
    });
    try {
      final hits = await services.pdfText.search(
        widget.doc,
        q,
        reverse: settings.reverseOverride,
        isCancelled: () => _cancelled,
        onProgress: (done, _) {
          if (mounted) setState(() => _done = done);
        },
      );
      if (mounted) setState(() => _hits = hits);
    } catch (e) {
      if (mounted) setState(() => _error = errorMessage(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final hits = _hits;
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: SafeArea(
        child: SizedBox(
          height: MediaQuery.of(context).size.height * 0.7,
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                child: TextField(
                  controller: _query,
                  autofocus: true,
                  textInputAction: TextInputAction.search,
                  onSubmitted: (_) => _run(),
                  decoration: InputDecoration(
                    hintText: 'ابحث في نص المستند…',
                    prefixIcon: const Icon(Icons.search),
                    suffixIcon: IconButton(icon: const Icon(Icons.arrow_back), onPressed: _run, tooltip: 'بحث'),
                  ),
                ),
              ),
              if (_busy)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Column(
                    children: [
                      LinearProgressIndicator(value: widget.doc.pageCount == 0 ? null : _done / widget.doc.pageCount),
                      const SizedBox(height: 6),
                      Text('جارٍ البحث… صفحة $_done من ${widget.doc.pageCount}'),
                    ],
                  ),
                ),
              if (_error != null) Padding(padding: const EdgeInsets.all(16), child: InfoBanner(message: _error!, isError: true)),
              Expanded(
                child: hits == null
                    ? const SizedBox.shrink()
                    : hits.isEmpty
                        ? const EmptyState(
                            icon: Icons.search_off,
                            title: 'لا توجد نتائج',
                            message: 'إذا كان المستند صورًا ممسوحة ضوئيًا فلن يحتوي على نص قابل للبحث.',
                          )
                        : ListView.separated(
                            itemCount: hits.length,
                            separatorBuilder: (_, __) => const Divider(height: 1),
                            itemBuilder: (_, i) => ListTile(
                              leading: CircleAvatar(child: Text('${hits[i].page}', style: const TextStyle(fontSize: 12))),
                              title: Text(hits[i].snippet, maxLines: 3, overflow: TextOverflow.ellipsis),
                              onTap: () => widget.onOpen(hits[i].page),
                            ),
                          ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
