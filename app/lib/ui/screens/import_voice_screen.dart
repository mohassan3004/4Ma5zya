import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../state/voices_controller.dart';
import '../widgets/common.dart';
import '../widgets/consent_section.dart';

/// Links a voice that already exists in the provider account (e.g. created on its website).
class ImportVoiceScreen extends StatefulWidget {
  const ImportVoiceScreen({super.key});

  @override
  State<ImportVoiceScreen> createState() => _ImportVoiceScreenState();
}

class _ImportVoiceScreenState extends State<ImportVoiceScreen> {
  final _id = TextEditingController();
  final _name = TextEditingController();
  final _person = TextEditingController();
  String _type = 'self';
  bool _consent = false;

  @override
  void dispose() {
    _id.dispose();
    _name.dispose();
    _person.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_id.text.trim().length < 3 || _name.text.trim().isEmpty) {
      showSnack(context, 'أدخل معرّف الصوت واسمه.', error: true);
      return;
    }
    if (!_consent || (_type != 'self' && _person.text.trim().isEmpty)) {
      showSnack(context, 'أكمل بيانات الموافقة.', error: true);
      return;
    }
    final voices = context.read<VoicesController>();
    final v = await runWithProgress(
      context,
      'جارٍ التحقق من الصوت لدى المزود…',
      () => voices.importExisting(
        voiceId: _id.text,
        name: _name.text,
        consentType: _type,
        consentPerson: _type == 'self' ? null : _person.text.trim(),
      ),
    );
    if (v != null && mounted) {
      showSnack(context, 'تمت إضافة "${v.name}".');
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('ربط صوت موجود')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const InfoBanner(
            message: 'إذا أنشأت صوتًا مسبقًا في حسابك لدى ElevenLabs، انسخ "Voice ID" من صفحة الصوت هناك والصقه هنا.',
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _id,
            textDirection: TextDirection.ltr,
            decoration: const InputDecoration(labelText: 'معرّف الصوت (Voice ID)', prefixIcon: Icon(Icons.key_outlined)),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _name,
            maxLength: 60,
            decoration: const InputDecoration(labelText: 'اسم الصوت في التطبيق', prefixIcon: Icon(Icons.label_outline)),
          ),
          const SectionHeader('الموافقة'),
          ConsentSection(
            consentType: _type,
            personController: _person,
            confirmed: _consent,
            onTypeChanged: (t) => setState(() {
              _type = t;
              _consent = false;
            }),
            onConfirmedChanged: (v) => setState(() => _consent = v),
          ),
          const SizedBox(height: 16),
          FilledButton(onPressed: _submit, child: const Text('ربط الصوت')),
        ],
      ),
    );
  }
}
