import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/formatters.dart';
import '../../data/models.dart';
import '../../state/library_controller.dart';
import '../../state/settings_controller.dart';
import '../../state/voices_controller.dart';
import '../widgets/common.dart';
import '../widgets/document_tile.dart';
import 'home_shell.dart';
import 'reader_screen.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  String _greeting() {
    final h = DateTime.now().hour;
    if (h < 12) return 'صباح الخير';
    if (h < 18) return 'مساء الخير';
    return 'مساء النور';
  }

  @override
  Widget build(BuildContext context) {
    final library = context.watch<LibraryController>();
    final voices = context.watch<VoicesController>();
    final settings = context.watch<SettingsController>();
    final scheme = Theme.of(context).colorScheme;
    final cont = library.continueReading;
    final recent = library.recent.take(5).toList();

    return Scaffold(
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: library.load,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
            children: [
              Text(_greeting(), style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800)),
              const SizedBox(height: 4),
              Text('ماذا تريد أن تقرأ – أو تسمع – اليوم؟', style: TextStyle(color: scheme.onSurfaceVariant)),
              const SizedBox(height: 16),
              if (!settings.serverConfigured)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: InfoBanner(
                    icon: Icons.cloud_off_outlined,
                    message: 'لتفعيل الاستماع بصوتك المستنسخ، أدخل عنوان الخادم ورمز الوصول في الإعدادات.',
                    action: TextButton(
                      onPressed: () => HomeShell.switchTab(context, 3),
                      child: const Text('فتح الإعدادات'),
                    ),
                  ),
                ),
              if (cont != null) _ContinueCard(doc: cont) else _WelcomeCard(onUpload: () => importPdfs(context)),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: _Shortcut(
                      icon: Icons.record_voice_over,
                      title: 'أصواتي',
                      subtitle: voices.defaultVoice?.name ?? 'لم تُنشئ صوتًا بعد',
                      onTap: () => HomeShell.switchTab(context, 2),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _Shortcut(
                      icon: Icons.library_books,
                      title: 'مكتبتي',
                      subtitle: '${library.documents.length} مستند',
                      onTap: () => HomeShell.switchTab(context, 1),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              FilledButton.icon(
                onPressed: () => importPdfs(context),
                icon: const Icon(Icons.upload_file),
                label: const Text('رفع ملف PDF'),
              ),
              if (recent.isNotEmpty) ...[
                const SectionHeader('المفتوحة مؤخرًا'),
                for (final d in recent)
                  DocumentTile(
                    doc: d,
                    onTap: () => openReader(context, d),
                  ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _WelcomeCard extends StatelessWidget {
  const _WelcomeCard({required this.onUpload});

  final VoidCallback onUpload;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: [scheme.primary, scheme.primary.withValues(alpha: 0.8)]),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('أهلًا بك في 4Ma5zya',
              style: TextStyle(color: scheme.onPrimary, fontSize: 20, fontWeight: FontWeight.w800)),
          const SizedBox(height: 8),
          Text(
            '١. ارفع ملف PDF عربي.\n٢. أنشئ نسخة من صوتك في "أصواتي".\n٣. استمع إلى مستنداتك بصوتك أنت.',
            style: TextStyle(color: scheme.onPrimary.withValues(alpha: 0.9), height: 1.7),
          ),
          const SizedBox(height: 14),
          FilledButton.tonalIcon(onPressed: onUpload, icon: const Icon(Icons.add), label: const Text('أضف أول مستند')),
        ],
      ),
    );
  }
}

class _ContinueCard extends StatelessWidget {
  const _ContinueCard({required this.doc});

  final DocumentEntity doc;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return InkWell(
      borderRadius: BorderRadius.circular(24),
      onTap: () => openReader(context, doc),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          gradient: LinearGradient(colors: [scheme.primary, scheme.primary.withValues(alpha: 0.8)]),
          borderRadius: BorderRadius.circular(24),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.auto_stories, color: scheme.onPrimary),
                const SizedBox(width: 8),
                Text('متابعة القراءة', style: TextStyle(color: scheme.onPrimary.withValues(alpha: 0.9))),
              ],
            ),
            const SizedBox(height: 10),
            Text(doc.title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(color: scheme.onPrimary, fontSize: 20, fontWeight: FontWeight.w800)),
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: LinearProgressIndicator(
                value: doc.progress,
                minHeight: 7,
                backgroundColor: scheme.onPrimary.withValues(alpha: 0.25),
                color: scheme.secondary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'صفحة ${doc.lastPage} من ${doc.pageCount} • ${formatPercent(doc.progress)}',
              style: TextStyle(color: scheme.onPrimary.withValues(alpha: 0.9)),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                FilledButton.tonalIcon(
                  onPressed: () => openReader(context, doc),
                  icon: const Icon(Icons.menu_book),
                  label: const Text('متابعة'),
                ),
                const SizedBox(width: 8),
                FilledButton.tonalIcon(
                  onPressed: () => openReader(context, doc, autoPlay: true),
                  icon: const Icon(Icons.headphones),
                  label: const Text('استماع'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _Shortcut extends StatelessWidget {
  const _Shortcut({required this.icon, required this.title, required this.subtitle, required this.onTap});

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: scheme.surfaceContainerLow,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, color: scheme.primary, size: 30),
              const SizedBox(height: 10),
              Text(title, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
              const SizedBox(height: 2),
              Text(subtitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 12.5)),
            ],
          ),
        ),
      ),
    );
  }
}

void openReader(BuildContext context, DocumentEntity doc, {bool autoPlay = false, int? page}) {
  Navigator.of(context).push(
    MaterialPageRoute<void>(builder: (_) => ReaderScreen(docId: doc.id, autoPlay: autoPlay, initialPage: page)),
  );
}

Future<void> importPdfs(BuildContext context) async {
  final library = context.read<LibraryController>();
  try {
    final result = await library.importPdfs();
    if (result == null || !context.mounted) return;
    if (result.failed.isNotEmpty) {
      showSnack(
        context,
        'تعذر استيراد: ${result.failed.join('، ')}. قد يكون الملف تالفًا أو محميًا بكلمة مرور.',
        error: true,
      );
    } else if (result.imported.length == 1) {
      showSnack(context, 'تمت إضافة "${result.imported.first.title}" إلى مكتبتك.');
      openReader(context, result.imported.first);
    } else {
      showSnack(context, 'تمت إضافة ${result.imported.length} مستندات إلى مكتبتك.');
      HomeShell.switchTab(context, 1);
    }
  } catch (e) {
    if (context.mounted) showError(context, e);
  }
}
