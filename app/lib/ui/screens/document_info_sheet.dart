import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/formatters.dart';
import '../../data/models.dart';
import '../../state/library_controller.dart';
import '../../state/read_aloud_controller.dart';
import '../widgets/common.dart';
import 'home_screen.dart';

/// Bottom sheet with document information and organisation actions.
Future<void> showDocumentActions(BuildContext context, DocumentEntity doc) {
  return showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (sheetContext) => _DocumentSheet(docId: doc.id, hostContext: context),
  );
}

class _DocumentSheet extends StatelessWidget {
  const _DocumentSheet({required this.docId, required this.hostContext});

  final String docId;
  final BuildContext hostContext;

  @override
  Widget build(BuildContext context) {
    final library = context.watch<LibraryController>();
    final doc = library.byId(docId);
    if (doc == null) return const SizedBox(height: 80);
    final scheme = Theme.of(context).colorScheme;

    Widget info(String label, String value) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Row(
            children: [
              SizedBox(width: 120, child: Text(label, style: TextStyle(color: scheme.onSurfaceVariant))),
              Expanded(child: Text(value, style: const TextStyle(fontWeight: FontWeight.w600))),
            ],
          ),
        );

    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(doc.title, style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 12),
            info('عدد الصفحات', '${doc.pageCount}'),
            info('الحجم', formatBytes(doc.fileSize)),
            info('التصنيف', doc.category ?? 'بدون تصنيف'),
            info('آخر صفحة', '${doc.lastPage} (${formatPercent(doc.progress)})'),
            info('تاريخ الإضافة', formatDate(doc.addedAt)),
            if (doc.lastOpenedAt != null) info('آخر فتح', formatDateTime(doc.lastOpenedAt!)),
            const Divider(height: 28),
            ListTile(
              leading: const Icon(Icons.menu_book_outlined),
              title: const Text('فتح'),
              onTap: () {
                Navigator.pop(context);
                openReader(hostContext, doc);
              },
            ),
            ListTile(
              leading: Icon(doc.isFavorite ? Icons.star_rounded : Icons.star_outline_rounded),
              title: Text(doc.isFavorite ? 'إزالة من المفضلة' : 'إضافة إلى المفضلة'),
              onTap: () => library.toggleFavorite(doc),
            ),
            ListTile(
              leading: const Icon(Icons.edit_outlined),
              title: const Text('إعادة التسمية'),
              onTap: () async {
                final name = await textInputDialog(context, title: 'اسم المستند', initial: doc.title, maxLength: 120);
                if (name != null) await library.rename(doc, name);
              },
            ),
            ListTile(
              leading: const Icon(Icons.folder_outlined),
              title: const Text('تعيين تصنيف'),
              subtitle: const Text('مثل: عقود، كتب، مذكرات'),
              onTap: () async {
                final c = await textInputDialog(
                  context,
                  title: 'التصنيف',
                  initial: doc.category ?? '',
                  hint: 'اتركه فارغًا لإزالة التصنيف',
                  maxLength: 30,
                  allowEmpty: true,
                );
                if (c != null) await library.setCategory(doc, c);
              },
            ),
            ListTile(
              leading: Icon(Icons.delete_outline, color: scheme.error),
              title: Text('حذف المستند', style: TextStyle(color: scheme.error)),
              onTap: () async {
                final ok = await confirmDialog(
                  context,
                  title: 'حذف المستند؟',
                  message: 'سيُحذف الملف وعلاماته المرجعية وموضع القراءة من جهازك نهائيًا.',
                  confirmLabel: 'حذف',
                  destructive: true,
                );
                if (!ok || !context.mounted) return;
                final reader = context.read<ReadAloudController>();
                if (reader.doc?.id == doc.id) await reader.stop();
                await library.delete(doc);
                if (context.mounted) Navigator.pop(context);
              },
            ),
          ],
        ),
      ),
    );
  }
}
