import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';

import '../../app_services.dart';
import '../../core/constants.dart';
import '../../core/formatters.dart';
import '../../data/file_storage.dart';
import '../../data/models.dart';
import '../../services/audio_probe.dart';
import '../../state/voices_controller.dart';
import '../widgets/common.dart';
import '../widgets/consent_section.dart';
import '../widgets/sample_tile.dart';
import 'cloning_progress_screen.dart';
import 'record_voice_screen.dart';
import 'voice_preview_screen.dart';

/// Creates a new voice, or (with [existing]) uploads extra recordings to improve a voice.
class AddVoiceScreen extends StatefulWidget {
  const AddVoiceScreen({super.key, this.existing});

  final VoiceProfile? existing;

  @override
  State<AddVoiceScreen> createState() => _AddVoiceScreenState();
}

class _AddVoiceScreenState extends State<AddVoiceScreen> {
  final _name = TextEditingController();
  final _person = TextEditingController();
  final _preview = SamplePreviewPlayer();
  final List<VoiceSample> _samples = [];
  String _consentType = 'self';
  bool _consent = false;
  bool _submitted = false;
  bool _importing = false;

  late final FileStorage _files;

  bool get _isNew => widget.existing == null;

  @override
  void initState() {
    super.initState();
    _files = context.read<AppServices>().files;
  }

  @override
  void dispose() {
    _name.dispose();
    _person.dispose();
    _preview.dispose();
    if (!_submitted) {
      for (final s in _samples) {
        _files.deleteQuietly(s.filePath);
      }
    }
    super.dispose();
  }

  int get _knownMs => _samples.fold<int>(0, (sum, s) => sum + (s.durationMs ?? 0));

  Future<void> _record() async {
    await _preview.stop();
    if (!mounted) return;
    final sample = await Navigator.of(context).push<VoiceSample>(
      MaterialPageRoute(builder: (_) => const RecordVoiceScreen()),
    );
    if (sample != null && mounted) setState(() => _samples.add(sample));
  }

  Future<void> _upload() async {
    await _preview.stop();
    final picked = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: supportedAudioExtensions,
      allowMultiple: true,
    );
    if (picked == null || !mounted) return;
    setState(() => _importing = true);
    final dir = _files.samplesDir;
    final rejected = <String>[];
    for (final f in picked.files) {
      final src = f.path;
      final ext = p.extension(f.name).replaceFirst('.', '').toLowerCase();
      if (src == null || !supportedAudioExtensions.contains(ext)) {
        rejected.add('${f.name} (صيغة غير مدعومة)');
        continue;
      }
      if (f.size > maxSampleBytes) {
        rejected.add('${f.name} (أكبر من 11 م.ب)');
        continue;
      }
      if (f.size < 2048) {
        rejected.add('${f.name} (ملف فارغ)');
        continue;
      }
      final dest = p.join(dir.path, '${const Uuid().v4()}.$ext');
      await File(src).copy(dest);
      final d = await probeAudioDuration(dest);
      _samples.add(VoiceSample(
        filePath: dest,
        durationMs: d?.inMilliseconds,
        source: 'imported',
        createdAt: DateTime.now(),
      ));
    }
    if (!mounted) return;
    setState(() => _importing = false);
    if (rejected.isNotEmpty) showSnack(context, 'لم تتم إضافة: ${rejected.join('، ')}', error: true);
  }

  Future<void> _removeSample(VoiceSample s) async {
    await _preview.stop();
    await _files.deleteQuietly(s.filePath);
    setState(() => _samples.remove(s));
  }

  String? _validate() {
    if (_isNew) {
      if (_name.text.trim().isEmpty) return 'اكتب اسمًا للصوت.';
      if (_consentType == 'other_with_consent' && _person.text.trim().isEmpty) return 'اكتب اسم صاحب الصوت.';
      if (!_consent) return 'يجب تأكيد الموافقة قبل المتابعة.';
    }
    return VoicesController.validateSamples(_samples, forNewVoice: _isNew);
  }

  Future<void> _submit() async {
    final problem = _validate();
    if (problem != null) {
      showSnack(context, problem, error: true);
      return;
    }
    await _preview.stop();
    if (!mounted) return;
    final nav = Navigator.of(context);
    if (_isNew) {
      final created = await nav.push<VoiceProfile>(MaterialPageRoute(
        builder: (_) => CloningProgressScreen(
          name: _name.text.trim(),
          consentType: _consentType,
          consentPerson: _consentType == 'self' ? null : _person.text.trim(),
          consentConfirmed: _consent,
          samples: List.of(_samples),
        ),
      ));
      if (created == null || !mounted) return;
      _submitted = true;
      nav.pushReplacement(MaterialPageRoute<void>(builder: (_) => VoicePreviewScreen(voiceId: created.voiceId)));
    } else {
      final voices = context.read<VoicesController>();
      final ok = await runWithProgress<bool>(context, 'جارٍ رفع التسجيلات وتحسين الصوت…', () async {
        await voices.addSamples(widget.existing!, List.of(_samples));
        return true;
      });
      if (ok == true && mounted) {
        _submitted = true;
        showSnack(context, 'تمت إضافة التسجيلات إلى "${widget.existing!.name}".');
        nav.pop();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final totalSec = _knownMs / 1000;
    final unknown = _samples.where((s) => s.durationMs == null).length;
    final scheme = Theme.of(context).colorScheme;

    return PopScope(
      canPop: _samples.isEmpty || _submitted,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        final leave = await confirmDialog(
          context,
          title: 'تجاهل التسجيلات؟',
          message: 'ستُحذف التسجيلات التي أضفتها في هذه الصفحة من جهازك.',
          confirmLabel: 'تجاهل',
          destructive: true,
        );
        if (leave && mounted) {
          for (final s in _samples) {
            await _files.deleteQuietly(s.filePath);
          }
          _samples.clear();
          if (mounted) Navigator.of(context).pop();
        }
      },
      child: Scaffold(
        appBar: AppBar(title: Text(_isNew ? 'إنشاء صوت جديد' : 'تحسين "${widget.existing!.name}"')),
        body: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 120),
          children: [
            if (_isNew) ...[
              TextField(
                controller: _name,
                maxLength: 60,
                decoration: const InputDecoration(labelText: 'اسم الصوت', hintText: 'مثال: صوتي', prefixIcon: Icon(Icons.label_outline)),
              ),
              const SectionHeader('صاحب الصوت والموافقة'),
              ConsentSection(
                consentType: _consentType,
                personController: _person,
                confirmed: _consent,
                onTypeChanged: (t) => setState(() {
                  _consentType = t;
                  _consent = false;
                }),
                onConfirmedChanged: (v) => setState(() => _consent = v),
              ),
            ],
            const SectionHeader('التسجيلات الصوتية'),
            const InfoBanner(
              icon: Icons.tips_and_updates_outlined,
              message: 'لأفضل نتيجة: سجّل في مكان هادئ، بنبرة طبيعية، دون موسيقى أو أصوات خلفية. '
                  'مجموع دقيقة ونصف إلى ثلاث دقائق من الكلام الواضح يكفي عادة.',
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: FilledButton.icon(onPressed: _record, icon: const Icon(Icons.mic), label: const Text('تسجيل')),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _importing ? null : _upload,
                    icon: const Icon(Icons.audio_file_outlined),
                    label: const Text('رفع ملفات'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              'الصيغ المدعومة: MP3، WAV، M4A، AAC، OGG، OPUS، FLAC، WEBM • حتى 11 م.ب للملف',
              style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant),
            ),
            if (_importing) const Padding(padding: EdgeInsets.only(top: 12), child: LinearProgressIndicator()),
            const SizedBox(height: 12),
            for (var i = 0; i < _samples.length; i++)
              SampleTile(
                sample: _samples[i],
                index: i,
                player: _preview,
                onDelete: () => _removeSample(_samples[i]),
              ),
            if (_samples.isNotEmpty) ...[
              const SizedBox(height: 12),
              Text(
                'المجموع: ${formatSeconds(totalSec)}${unknown > 0 ? ' (+ $unknown ملف مدته غير معروفة)' : ''}',
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 6),
              ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: LinearProgressIndicator(
                  value: (totalSec / recommendedSampleSeconds).clamp(0.0, 1.0),
                  minHeight: 8,
                  color: totalSec >= minTotalSampleSeconds ? Colors.green.shade600 : scheme.secondary,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                totalSec < minTotalSampleSeconds && _isNew
                    ? 'الحد الأدنى $minTotalSampleSeconds ثانية.'
                    : totalSec < recommendedSampleSeconds
                        ? 'مقبول. إضافة المزيد تحسّن التشابه.'
                        : 'ممتاز!',
                style: TextStyle(fontSize: 12.5, color: scheme.onSurfaceVariant),
              ),
            ],
          ],
        ),
        bottomNavigationBar: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
            child: FilledButton.icon(
              onPressed: _samples.isEmpty ? null : _submit,
              icon: Icon(_isNew ? Icons.auto_awesome : Icons.cloud_upload_outlined),
              label: Text(_isNew ? 'إنشاء الصوت' : 'رفع التسجيلات'),
            ),
          ),
        ),
      ),
    );
  }
}
