import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/constants.dart';
import '../../core/formatters.dart';
import '../../state/read_aloud_controller.dart';
import '../../state/voices_controller.dart';
import '../widgets/common.dart';
import 'home_screen.dart';

class AudioPlayerScreen extends StatelessWidget {
  const AudioPlayerScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final c = context.watch<ReadAloudController>();
    final voices = context.watch<VoicesController>();
    final scheme = Theme.of(context).colorScheme;
    final doc = c.doc;

    if (doc == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('المشغّل')),
        body: const EmptyState(
          icon: Icons.headphones_outlined,
          title: 'لا توجد قراءة صوتية حالية',
          message: 'افتح مستندًا واضغط "استمع".',
        ),
      );
    }

    final ready = voices.voices.where((v) => v.isReady || v.voiceId == c.voice?.voiceId).toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('القراءة الصوتية'),
        actions: [
          IconButton(
            tooltip: 'فتح المستند',
            icon: const Icon(Icons.menu_book_outlined),
            onPressed: () => openReader(context, doc, page: c.page),
          ),
        ],
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
          children: [
            Text(doc.title, textAlign: TextAlign.center, style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 4),
            Text(
              'صفحة ${c.page} من ${doc.pageCount}${c.units.isEmpty ? '' : ' • جملة ${c.index + 1} من ${c.units.length}'}',
              textAlign: TextAlign.center,
              style: TextStyle(color: scheme.onSurfaceVariant),
            ),
            const SizedBox(height: 16),
            Container(
              constraints: const BoxConstraints(minHeight: 160),
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(color: scheme.surfaceContainerLow, borderRadius: BorderRadius.circular(20)),
              child: c.loading && c.currentText == null
                  ? const Center(child: CircularProgressIndicator())
                  : Text(
                      c.currentText ?? '',
                      style: const TextStyle(fontSize: 20, height: 1.9),
                    ),
            ),
            if (c.error != null) ...[
              const SizedBox(height: 12),
              InfoBanner(
                message: c.error!,
                isError: true,
                action: TextButton(onPressed: c.retry, child: const Text('إعادة المحاولة')),
              ),
            ],
            if (c.finished && c.error == null) ...[
              const SizedBox(height: 12),
              const InfoBanner(icon: Icons.check_circle_outline, message: 'انتهت قراءة المستند.'),
            ],
            const SizedBox(height: 16),
            StreamBuilder<Duration?>(
              stream: c.durationStream,
              builder: (context, durSnap) {
                final total = durSnap.data ?? Duration.zero;
                return StreamBuilder<Duration>(
                  stream: c.positionStream,
                  builder: (context, posSnap) {
                    var pos = posSnap.data ?? Duration.zero;
                    if (pos > total) pos = total;
                    final value = total.inMilliseconds == 0 ? 0.0 : pos.inMilliseconds / total.inMilliseconds;
                    return Column(
                      children: [
                        LinearProgressIndicator(value: c.loading ? null : value, minHeight: 6),
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            Text(formatDuration(pos), style: const TextStyle(fontSize: 12)),
                            const Spacer(),
                            Text(formatDuration(total), style: const TextStyle(fontSize: 12)),
                          ],
                        ),
                      ],
                    );
                  },
                );
              },
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                const Text('تقدم المستند', style: TextStyle(fontSize: 12)),
                const SizedBox(width: 8),
                Expanded(child: LinearProgressIndicator(value: doc.pageCount == 0 ? 0 : c.page / doc.pageCount)),
              ],
            ),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                IconButton(
                  tooltip: 'الصفحة السابقة',
                  iconSize: 30,
                  onPressed: c.page > 1 ? c.previousPage : null,
                  icon: const Icon(Icons.keyboard_double_arrow_right),
                ),
                IconButton(
                  tooltip: 'الجملة السابقة',
                  iconSize: 36,
                  onPressed: c.previousSentence,
                  icon: const Icon(Icons.skip_next),
                ),
                SizedBox(
                  width: 76,
                  height: 76,
                  child: c.loading
                      ? const Padding(padding: EdgeInsets.all(18), child: CircularProgressIndicator(strokeWidth: 3))
                      : IconButton.filled(
                          tooltip: c.isPlaying ? 'إيقاف مؤقت' : 'تشغيل',
                          iconSize: 44,
                          onPressed: c.togglePlay,
                          icon: Icon(c.isPlaying ? Icons.pause : Icons.play_arrow),
                        ),
                ),
                IconButton(
                  tooltip: 'الجملة التالية',
                  iconSize: 36,
                  onPressed: c.nextSentence,
                  icon: const Icon(Icons.skip_previous),
                ),
                IconButton(
                  tooltip: 'الصفحة التالية',
                  iconSize: 30,
                  onPressed: c.page < doc.pageCount ? c.nextPage : null,
                  icon: const Icon(Icons.keyboard_double_arrow_left),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Center(
              child: TextButton.icon(
                onPressed: () async {
                  await c.stop();
                  if (context.mounted) Navigator.of(context).pop();
                },
                icon: const Icon(Icons.stop_circle_outlined),
                label: const Text('إيقاف القراءة'),
              ),
            ),
            const SectionHeader('سرعة التشغيل'),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final s in playbackSpeeds)
                  ChoiceChip(
                    label: Text('${s}x', textDirection: TextDirection.ltr),
                    selected: (c.speed - s).abs() < 0.01,
                    onSelected: (_) => c.setSpeed(s),
                  ),
              ],
            ),
            const SectionHeader('الصوت'),
            DropdownButtonFormField<String>(
              value: ready.any((v) => v.voiceId == c.voice?.voiceId) ? c.voice?.voiceId : null,
              items: [
                for (final v in ready) DropdownMenuItem(value: v.voiceId, child: Text(v.name)),
              ],
              onChanged: (id) {
                final v = id == null ? null : voices.byId(id);
                if (v != null) c.setVoice(v);
              },
              decoration: const InputDecoration(prefixIcon: Icon(Icons.record_voice_over_outlined)),
            ),
            const SizedBox(height: 8),
            Text(
              'المقاطع المُولَّدة تُحفظ على جهازك وتعمل دون اتصال عند إعادة الاستماع.',
              style: TextStyle(fontSize: 12.5, color: scheme.onSurfaceVariant),
            ),
          ],
        ),
      ),
    );
  }
}
