import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/errors.dart';
import '../../data/models.dart';
import '../../state/voices_controller.dart';

/// Runs voice creation and shows each step. Pops with the created [VoiceProfile] on success.
class CloningProgressScreen extends StatefulWidget {
  const CloningProgressScreen({
    super.key,
    required this.name,
    required this.consentType,
    required this.consentConfirmed,
    required this.samples,
    this.consentPerson,
  });

  final String name;
  final String consentType;
  final String? consentPerson;
  final bool consentConfirmed;
  final List<VoiceSample> samples;

  @override
  State<CloningProgressScreen> createState() => _CloningProgressScreenState();
}

class _CloningProgressScreenState extends State<CloningProgressScreen> {
  CloneStep _step = CloneStep.validating;
  bool _running = false;
  String? _error;
  VoiceProfile? _created;

  static const _labels = {
    CloneStep.validating: 'التحقق من التسجيلات (الصيغة، الحجم، المدة)',
    CloneStep.uploading: 'رفع التسجيلات بأمان وإنشاء الصوت لدى مزود الذكاء الاصطناعي',
    CloneStep.saving: 'حفظ الصوت في مكتبة أصواتك',
    CloneStep.done: 'اكتمل إنشاء الصوت',
  };

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _run());
  }

  Future<void> _run() async {
    setState(() {
      _running = true;
      _error = null;
      _step = CloneStep.validating;
    });
    try {
      final v = await context.read<VoicesController>().create(
            name: widget.name,
            consentType: widget.consentType,
            consentPerson: widget.consentPerson,
            consentConfirmed: widget.consentConfirmed,
            samples: widget.samples,
            onStep: (s) {
              if (mounted) setState(() => _step = s);
            },
          );
      if (mounted) setState(() => _created = v);
    } catch (e) {
      if (mounted) setState(() => _error = errorMessage(e));
    } finally {
      if (mounted) setState(() => _running = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return PopScope(
      canPop: !_running,
      child: Scaffold(
        appBar: AppBar(title: const Text('إنشاء الصوت'), automaticallyImplyLeading: !_running),
        body: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            Text(widget.name, style: Theme.of(context).textTheme.headlineSmall),
            const SizedBox(height: 4),
            Text('${widget.samples.length} تسجيل', style: TextStyle(color: scheme.onSurfaceVariant)),
            const SizedBox(height: 24),
            for (final s in CloneStep.values) _stepRow(s, scheme),
            const SizedBox(height: 24),
            if (_running && _step == CloneStep.uploading)
              Text(
                'قد يستغرق ذلك دقيقة أو أكثر بحسب حجم التسجيلات وسرعة الاتصال. لا تغلق التطبيق.',
                style: TextStyle(color: scheme.onSurfaceVariant, height: 1.6),
              ),
            if (_error != null) ...[
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(color: scheme.errorContainer, borderRadius: BorderRadius.circular(16)),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.error_outline, color: scheme.onErrorContainer),
                    const SizedBox(width: 10),
                    Expanded(child: Text(_error!, style: TextStyle(color: scheme.onErrorContainer, height: 1.6))),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: const Text('تعديل التسجيلات'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(child: FilledButton(onPressed: _run, child: const Text('إعادة المحاولة'))),
                ],
              ),
            ],
            if (_created != null) ...[
              Icon(Icons.check_circle, size: 72, color: Colors.green.shade600),
              const SizedBox(height: 12),
              const Text('تم إنشاء صوتك بنجاح!', textAlign: TextAlign.center, style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
              if (!_created!.isReady)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    'حالة الصوت: ${_created!.statusLabel}. قد يطلب المزود خطوة تحقق إضافية من حسابك قبل الاستخدام.',
                    textAlign: TextAlign.center,
                  ),
                ),
              const SizedBox(height: 20),
              FilledButton.icon(
                onPressed: () => Navigator.of(context).pop(_created),
                icon: const Icon(Icons.play_circle_outline),
                label: const Text('معاينة الصوت'),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _stepRow(CloneStep s, ColorScheme scheme) {
    final idx = CloneStep.values.indexOf(s);
    final cur = CloneStep.values.indexOf(_step);
    final done = _created != null || idx < cur;
    final active = idx == cur && _running;
    final failed = idx == cur && _error != null;
    Widget icon;
    if (failed) {
      icon = Icon(Icons.cancel, color: scheme.error);
    } else if (done) {
      icon = Icon(Icons.check_circle, color: Colors.green.shade600);
    } else if (active) {
      icon = const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.5));
    } else {
      icon = Icon(Icons.radio_button_unchecked, color: scheme.outline);
    }
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        children: [
          SizedBox(width: 28, child: Center(child: icon)),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              _labels[s]!,
              style: TextStyle(fontWeight: active ? FontWeight.w700 : FontWeight.normal, height: 1.5),
            ),
          ),
        ],
      ),
    );
  }
}
