import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/errors.dart';
import '../../core/formatters.dart';
import '../../data/models.dart';
import '../../state/read_aloud_controller.dart';
import '../../state/voices_controller.dart';
import '../widgets/common.dart';
import '../widgets/sample_tile.dart';
import 'add_voice_screen.dart';
import 'voice_preview_screen.dart';

class VoiceDetailScreen extends StatefulWidget {
  const VoiceDetailScreen({super.key, required this.voiceId});

  final String voiceId;

  @override
  State<VoiceDetailScreen> createState() => _VoiceDetailScreenState();
}

class _VoiceDetailScreenState extends State<VoiceDetailScreen> {
  final _preview = SamplePreviewPlayer();
  late Future<List<VoiceSample>> _samples;

  @override
  void initState() {
    super.initState();
    _samples = context.read<VoicesController>().samplesOf(widget.voiceId);
  }

  @override
  void dispose() {
    _preview.dispose();
    super.dispose();
  }

  void _reloadSamples() => setState(() => _samples = context.read<VoicesController>().samplesOf(widget.voiceId));

  Future<void> _rename(VoiceProfile v) async {
    final name = await textInputDialog(context, title: 'اسم الصوت', initial: v.name);
    if (name == null || name == v.name || !mounted) return;
    await runWithProgress(context, 'جارٍ الحفظ…', () => context.read<VoicesController>().rename(v, name));
  }

  Future<void> _delete(VoiceProfile v) async {
    final ok = await confirmDialog(
      context,
      title: 'حذف الصوت؟',
      message: 'سيُحذف الصوت من حساب مزود الذكاء الاصطناعي، وتُحذف تسجيلاته والمقاطع المولدة به من جهازك. '
          'لا يمكن التراجع عن ذلك.',
      confirmLabel: 'حذف',
      destructive: true,
    );
    if (!ok || !mounted) return;
    final voices = context.read<VoicesController>();
    final reader = context.read<ReadAloudController>();
    await _preview.stop();
    try {
      await reader.onVoiceDeleted(v.voiceId);
      await voices.delete(v);
      if (mounted) Navigator.of(context).pop();
    } on AppException catch (e) {
      if (!mounted) return;
      if (e.isNetwork || e.isNotConfigured) {
        final local = await confirmDialog(
          context,
          title: 'تعذر الاتصال بالخادم',
          message: '${e.message}\n\nهل تريد حذف الصوت من هذا الجهاز فقط؟ سيبقى لدى المزود حتى تحذفه لاحقًا من حسابك.',
          confirmLabel: 'حذف من الجهاز',
          destructive: true,
        );
        if (local) {
          await voices.delete(v, localOnly: true);
          if (mounted) Navigator.of(context).pop();
        }
      } else {
        showError(context, e);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final voices = context.watch<VoicesController>();
    final reader = context.watch<ReadAloudController>();
    final v = voices.byId(widget.voiceId);
    if (v == null) {
      return Scaffold(appBar: AppBar(), body: const EmptyState(icon: Icons.error_outline, title: 'الصوت غير موجود'));
    }
    final scheme = Theme.of(context).colorScheme;

    Widget row(String label, String value) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 5),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(width: 130, child: Text(label, style: TextStyle(color: scheme.onSurfaceVariant))),
              Expanded(child: Text(value, style: const TextStyle(fontWeight: FontWeight.w600))),
            ],
          ),
        );

    return Scaffold(
      appBar: AppBar(
        title: Text(v.name),
        actions: [IconButton(tooltip: 'إعادة التسمية', onPressed: () => _rename(v), icon: const Icon(Icons.edit_outlined))],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            elevation: 0,
            color: scheme.surfaceContainerLow,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  row('الحالة', v.statusLabel),
                  row('المزود', v.provider == 'mock' ? 'تجريبي (بدون استنساخ)' : 'ElevenLabs'),
                  row('معرّف الصوت', v.voiceId),
                  row('تاريخ الإنشاء', formatDate(v.createdAt)),
                  row('صاحب الصوت', v.isOwnVoice ? 'أنا' : '${v.consentPerson ?? '—'} (بموافقة صريحة)'),
                  row('عدد التسجيلات', '${v.sampleCount}'),
                  if (v.totalSeconds != null) row('مدة التسجيلات', formatSeconds(v.totalSeconds!)),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed: () => Navigator.of(context)
                .push(MaterialPageRoute<void>(builder: (_) => VoicePreviewScreen(voiceId: v.voiceId))),
            icon: const Icon(Icons.play_circle_outline),
            label: const Text('معاينة الصوت'),
          ),
          const SizedBox(height: 8),
          if (!v.isDefault)
            OutlinedButton.icon(
              onPressed: () => voices.setDefault(v),
              icon: const Icon(Icons.star_outline),
              label: const Text('تعيين كصوت افتراضي'),
            ),
          if (reader.hasSession && reader.voice?.voiceId != v.voiceId) ...[
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: () => reader.setVoice(v),
              icon: const Icon(Icons.swap_horiz),
              label: const Text('استخدامه في القراءة الحالية'),
            ),
          ],
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: () async {
              await Navigator.of(context)
                  .push(MaterialPageRoute<void>(builder: (_) => AddVoiceScreen(existing: v)));
              if (mounted) _reloadSamples();
            },
            icon: const Icon(Icons.add_circle_outline),
            label: const Text('إضافة تسجيلات لتحسين الصوت'),
          ),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: () => runWithProgress(context, 'جارٍ التحقق من الحالة…', () => voices.refreshStatus(v)),
            icon: const Icon(Icons.sync),
            label: const Text('تحديث الحالة من الخادم'),
          ),
          const SectionHeader('التسجيلات المحفوظة على جهازك'),
          FutureBuilder<List<VoiceSample>>(
            future: _samples,
            builder: (context, snap) {
              final list = snap.data;
              if (list == null) return const Center(child: CircularProgressIndicator());
              if (list.isEmpty) {
                return Text('لا توجد نسخ محلية من التسجيلات.', style: TextStyle(color: scheme.onSurfaceVariant));
              }
              return Column(
                children: [
                  for (var i = 0; i < list.length; i++)
                    SampleTile(
                      sample: list[i],
                      index: i,
                      player: _preview,
                      onDelete: () async {
                        final ok = await confirmDialog(
                          context,
                          title: 'حذف التسجيل من جهازك؟',
                          message: 'يُحذف الملف من جهازك فقط. الصوت المُنشأ لا يتأثر.',
                          confirmLabel: 'حذف',
                          destructive: true,
                        );
                        if (!ok) return;
                        await _preview.stop();
                        await voices.deleteLocalSample(list[i]);
                        if (mounted) _reloadSamples();
                      },
                    ),
                ],
              );
            },
          ),
          const SizedBox(height: 24),
          TextButton.icon(
            style: TextButton.styleFrom(foregroundColor: scheme.error),
            onPressed: () => _delete(v),
            icon: const Icon(Icons.delete_forever_outlined),
            label: const Text('حذف الصوت نهائيًا'),
          ),
        ],
      ),
    );
  }
}
