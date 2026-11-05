import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/formatters.dart';
import '../../data/models.dart';
import '../../state/settings_controller.dart';
import '../../state/voices_controller.dart';
import '../widgets/common.dart';
import 'add_voice_screen.dart';
import 'home_shell.dart';
import 'import_voice_screen.dart';
import 'voice_detail_screen.dart';

class VoicesScreen extends StatefulWidget {
  const VoicesScreen({super.key});

  @override
  State<VoicesScreen> createState() => _VoicesScreenState();
}

class _VoicesScreenState extends State<VoicesScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (context.read<SettingsController>().serverConfigured) context.read<VoicesController>().sync();
    });
  }

  void _newVoice() {
    Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => const AddVoiceScreen()));
  }

  @override
  Widget build(BuildContext context) {
    final voices = context.watch<VoicesController>();
    final settings = context.watch<SettingsController>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('أصواتي'),
        actions: [
          PopupMenuButton<String>(
            onSelected: (v) {
              if (v == 'sync') voices.sync();
              if (v == 'import') {
                Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => const ImportVoiceScreen()));
              }
            },
            itemBuilder: (_) => const [
              PopupMenuItem(value: 'sync', child: ListTile(leading: Icon(Icons.sync), title: Text('مزامنة مع الخادم'))),
              PopupMenuItem(
                value: 'import',
                child: ListTile(leading: Icon(Icons.input), title: Text('ربط صوت موجود بمعرّفه')),
              ),
            ],
          ),
        ],
      ),
      floatingActionButton: settings.serverConfigured
          ? FloatingActionButton.extended(
              onPressed: _newVoice,
              icon: const Icon(Icons.add),
              label: const Text('إنشاء صوت جديد'),
            )
          : null,
      body: RefreshIndicator(
        onRefresh: settings.serverConfigured ? voices.sync : voices.load,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
          children: [
            if (!settings.serverConfigured)
              InfoBanner(
                icon: Icons.cloud_off_outlined,
                message: 'إنشاء الأصوات وتوليد الكلام يتمان عبر خادمك الخاص. أدخل عنوان الخادم ورمز الوصول أولًا.',
                action: TextButton(onPressed: () => HomeShell.switchTab(context, 3), child: const Text('الإعدادات')),
              ),
            if (voices.syncing) const Padding(padding: EdgeInsets.only(top: 8), child: LinearProgressIndicator()),
            if (voices.syncError != null)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: InfoBanner(message: voices.syncError!, isError: true, icon: Icons.sync_problem),
              ),
            if (!voices.loading && voices.voices.isEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 40),
                child: EmptyState(
                  icon: Icons.record_voice_over_outlined,
                  title: 'لا توجد أصوات بعد',
                  message: 'سجّل صوتك أو ارفع تسجيلات واضحة (دقيقة إلى ثلاث دقائق)، '
                      'وسننشئ منه صوتًا يقرأ لك مستنداتك.',
                  action: settings.serverConfigured
                      ? FilledButton.icon(
                          onPressed: _newVoice, icon: const Icon(Icons.add), label: const Text('إنشاء صوت جديد'))
                      : null,
                ),
              ),
            for (final v in voices.voices) _VoiceCard(voice: v),
          ],
        ),
      ),
    );
  }
}

class _VoiceCard extends StatelessWidget {
  const _VoiceCard({required this.voice});

  final VoiceProfile voice;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final statusColor = voice.isReady ? Colors.green.shade700 : scheme.error;
    return Card(
      elevation: 0,
      color: scheme.surfaceContainerLow,
      margin: const EdgeInsets.symmetric(vertical: 6),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: voice.isDefault ? BorderSide(color: scheme.primary, width: 1.5) : BorderSide.none,
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: () => Navigator.of(context)
            .push(MaterialPageRoute<void>(builder: (_) => VoiceDetailScreen(voiceId: voice.voiceId))),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              CircleAvatar(
                radius: 26,
                backgroundColor: scheme.primaryContainer,
                child: Icon(voice.isOwnVoice ? Icons.person : Icons.people_alt, color: scheme.onPrimaryContainer),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(voice.name,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
                        ),
                        if (voice.isDefault) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(color: scheme.primary, borderRadius: BorderRadius.circular(8)),
                            child: Text('افتراضي', style: TextStyle(color: scheme.onPrimary, fontSize: 11)),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${voice.isOwnVoice ? 'صوتي' : 'صوت ${voice.consentPerson ?? 'شخص آخر'} (بموافقته)'}'
                      ' • ${formatDate(voice.createdAt)}',
                      style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 12.5),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(Icons.circle, size: 9, color: statusColor),
                        const SizedBox(width: 6),
                        Text(voice.statusLabel, style: TextStyle(fontSize: 12.5, color: statusColor)),
                      ],
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_left),
            ],
          ),
        ),
      ),
    );
  }
}
