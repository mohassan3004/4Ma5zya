import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../app_services.dart';
import '../../core/constants.dart';
import '../../core/formatters.dart';
import '../../data/remote/api_client.dart';
import '../../state/settings_controller.dart';
import '../../state/voices_controller.dart';
import '../widgets/common.dart';
import 'about_screen.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  int? _cacheBytes;

  @override
  void initState() {
    super.initState();
    _refreshCache();
  }

  Future<void> _refreshCache() async {
    final bytes = await context.read<AppServices>().tts.totalBytes();
    if (mounted) setState(() => _cacheBytes = bytes);
  }

  Future<void> _editServer(SettingsController s) async {
    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => _ServerSheet(initialUrl: s.serverUrl ?? ''),
    );
    if (saved == true && mounted) {
      showSnack(context, 'تم الاتصال بالخادم وحفظ الإعدادات بأمان.');
      context.read<VoicesController>().sync();
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = context.watch<SettingsController>();
    final voices = context.watch<VoicesController>();
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('الإعدادات')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
        children: [
          const SectionHeader('الخادم الخاص (للذكاء الاصطناعي)'),
          Card(
            elevation: 0,
            color: scheme.surfaceContainerLow,
            child: Column(
              children: [
                ListTile(
                  leading: Icon(s.serverConfigured ? Icons.cloud_done_outlined : Icons.cloud_off_outlined,
                      color: s.serverConfigured ? Colors.green.shade700 : scheme.error),
                  title: Text(s.serverConfigured ? 'متصل بالخادم' : 'لم يتم إعداد الخادم'),
                  subtitle: Text(
                    s.serverUrl ?? 'أدخل عنوان خادمك ورمز الوصول لتفعيل الأصوات وتوليد الكلام.',
                    textDirection: s.serverUrl == null ? null : TextDirection.ltr,
                    textAlign: TextAlign.start,
                  ),
                  trailing: const Icon(Icons.chevron_left),
                  onTap: () => _editServer(s),
                ),
                if (s.serverConfigured)
                  ListTile(
                    leading: const Icon(Icons.link_off),
                    title: const Text('فصل الخادم'),
                    subtitle: const Text('يحذف العنوان ورمز الوصول من هذا الجهاز'),
                    onTap: () async {
                      final ok = await confirmDialog(
                        context,
                        title: 'فصل الخادم؟',
                        message: 'لن تتمكن من توليد كلام جديد حتى تعيد الإعداد. المقاطع المحفوظة ستبقى تعمل.',
                        confirmLabel: 'فصل',
                      );
                      if (ok) await s.clearServer();
                    },
                  ),
              ],
            ),
          ),
          const SectionHeader('القراءة الصوتية'),
          Card(
            elevation: 0,
            color: scheme.surfaceContainerLow,
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.record_voice_over_outlined),
                  title: const Text('صوت القراءة الافتراضي'),
                  subtitle: Text(voices.defaultVoice?.name ?? 'لم يتم اختيار صوت'),
                  trailing: voices.voices.isEmpty
                      ? null
                      : DropdownButton<String>(
                          value: voices.defaultVoice?.voiceId,
                          underline: const SizedBox.shrink(),
                          hint: const Text('اختر'),
                          items: [
                            for (final v in voices.voices) DropdownMenuItem(value: v.voiceId, child: Text(v.name)),
                          ],
                          onChanged: (id) {
                            final v = id == null ? null : voices.byId(id);
                            if (v != null) voices.setDefault(v);
                          },
                        ),
                ),
                ListTile(
                  leading: const Icon(Icons.speed),
                  title: const Text('سرعة التشغيل'),
                  trailing: DropdownButton<double>(
                    value: playbackSpeeds.contains(s.speed) ? s.speed : 1.0,
                    underline: const SizedBox.shrink(),
                    items: [
                      for (final v in playbackSpeeds)
                        DropdownMenuItem(value: v, child: Text('${v}x', textDirection: TextDirection.ltr)),
                    ],
                    onChanged: (v) {
                      if (v != null) s.setSpeed(v);
                    },
                  ),
                ),
                SwitchListTile(
                  secondary: const Icon(Icons.sync_alt),
                  title: const Text('مزامنة الصفحة مع الصوت'),
                  subtitle: const Text('تنتقل صفحة PDF تلقائيًا إلى الصفحة التي تُقرأ'),
                  value: s.followPage,
                  onChanged: s.setFollowPage,
                ),
                ListTile(
                  leading: const Icon(Icons.format_textdirection_r_to_l),
                  title: const Text('اتجاه النص المستخرج'),
                  subtitle: const Text('بعض ملفات PDF تخزن العربية معكوسة. غيّر هذا الخيار إذا سمعت كلامًا غير مفهوم.'),
                  isThreeLine: true,
                  trailing: DropdownButton<String>(
                    value: s.reverseMode,
                    underline: const SizedBox.shrink(),
                    items: const [
                      DropdownMenuItem(value: 'auto', child: Text('تلقائي')),
                      DropdownMenuItem(value: 'off', child: Text('عادي')),
                      DropdownMenuItem(value: 'on', child: Text('عكس')),
                    ],
                    onChanged: (v) {
                      if (v != null) s.setReverseMode(v);
                    },
                  ),
                ),
              ],
            ),
          ),
          const SectionHeader('التخزين'),
          Card(
            elevation: 0,
            color: scheme.surfaceContainerLow,
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.storage_outlined),
                  title: const Text('المقاطع الصوتية المحفوظة'),
                  subtitle: Text(_cacheBytes == null ? '…' : formatBytes(_cacheBytes!)),
                  trailing: TextButton(
                    onPressed: () async {
                      final ok = await confirmDialog(
                        context,
                        title: 'مسح المقاطع المحفوظة؟',
                        message: 'ستحتاج إلى اتصال لإعادة توليدها، وقد يستهلك ذلك رصيدًا لدى مزود الصوت.',
                        confirmLabel: 'مسح',
                        destructive: true,
                      );
                      if (!ok || !context.mounted) return;
                      await context.read<AppServices>().tts.clear();
                      await _refreshCache();
                    },
                    child: const Text('مسح'),
                  ),
                ),
                ListTile(
                  leading: const Icon(Icons.data_usage),
                  title: const Text('الحد الأقصى للمقاطع المحفوظة'),
                  trailing: DropdownButton<int>(
                    value: const [200, 500, 1000, 2000].contains(s.cacheLimitMb) ? s.cacheLimitMb : 500,
                    underline: const SizedBox.shrink(),
                    items: const [
                      DropdownMenuItem(value: 200, child: Text('200 م.ب')),
                      DropdownMenuItem(value: 500, child: Text('500 م.ب')),
                      DropdownMenuItem(value: 1000, child: Text('1 ج.ب')),
                      DropdownMenuItem(value: 2000, child: Text('2 ج.ب')),
                    ],
                    onChanged: (v) {
                      if (v != null) s.setCacheLimitMb(v);
                    },
                  ),
                ),
              ],
            ),
          ),
          const SectionHeader('المظهر'),
          Card(
            elevation: 0,
            color: scheme.surfaceContainerLow,
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: SegmentedButton<ThemeMode>(
                segments: const [
                  ButtonSegment(value: ThemeMode.light, icon: Icon(Icons.light_mode_outlined), label: Text('فاتح')),
                  ButtonSegment(value: ThemeMode.dark, icon: Icon(Icons.dark_mode_outlined), label: Text('داكن')),
                  ButtonSegment(value: ThemeMode.system, icon: Icon(Icons.brightness_auto_outlined), label: Text('النظام')),
                ],
                selected: {s.themeMode},
                onSelectionChanged: (v) => s.setThemeMode(v.first),
              ),
            ),
          ),
          const SizedBox(height: 12),
          ListTile(
            leading: const Icon(Icons.info_outline),
            title: const Text('حول التطبيق والخصوصية'),
            trailing: const Icon(Icons.chevron_left),
            onTap: () => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => const AboutScreen())),
          ),
        ],
      ),
    );
  }
}

class _ServerSheet extends StatefulWidget {
  const _ServerSheet({required this.initialUrl});

  final String initialUrl;

  @override
  State<_ServerSheet> createState() => _ServerSheetState();
}

class _ServerSheetState extends State<_ServerSheet> {
  late final _url = TextEditingController(text: widget.initialUrl);
  final _token = TextEditingController();
  bool _obscure = true;
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _url.dispose();
    _token.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final problem = ApiClient.validateServerUrl(_url.text);
    if (problem != null) {
      setState(() => _error = problem);
      return;
    }
    if (_token.text.trim().length < 24) {
      setState(() => _error = 'رمز الوصول قصير جدًا. انسخه كاملًا من ملف إعدادات الخادم (APP_ACCESS_TOKEN).');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final provider = await context.read<SettingsController>().saveServer(_url.text, _token.text);
      if (!mounted) return;
      if (provider == 'mock') {
        showSnack(context, 'تنبيه: الخادم يعمل في الوضع التجريبي (نغمة اختبار بدل الصوت الحقيقي).');
      }
      Navigator.of(context).pop(true);
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(20, 0, 20, 20 + MediaQuery.of(context).viewInsets.bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('إعداد الخادم', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 6),
          const Text(
            'يحفظ العنوان ورمز الوصول في التخزين الآمن لجهازك. مفتاح مزود الذكاء الاصطناعي يبقى على الخادم فقط.',
            style: TextStyle(height: 1.6),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _url,
            keyboardType: TextInputType.url,
            textDirection: TextDirection.ltr,
            autocorrect: false,
            decoration: const InputDecoration(labelText: 'عنوان الخادم', hintText: 'https://api.example.com', prefixIcon: Icon(Icons.dns_outlined)),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _token,
            obscureText: _obscure,
            textDirection: TextDirection.ltr,
            autocorrect: false,
            enableSuggestions: false,
            decoration: InputDecoration(
              labelText: 'رمز الوصول (APP_ACCESS_TOKEN)',
              prefixIcon: const Icon(Icons.lock_outline),
              suffixIcon: IconButton(
                icon: Icon(_obscure ? Icons.visibility : Icons.visibility_off),
                onPressed: () => setState(() => _obscure = !_obscure),
              ),
            ),
          ),
          if (_error != null) ...[
            const SizedBox(height: 12),
            InfoBanner(message: _error!, isError: true),
          ],
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: _busy ? null : _save,
            icon: _busy
                ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2.5))
                : const Icon(Icons.check),
            label: Text(_busy ? 'جارٍ اختبار الاتصال…' : 'اختبار الاتصال والحفظ'),
          ),
        ],
      ),
    );
  }
}
