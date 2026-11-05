import 'package:flutter/material.dart';

/// Consent capture required before cloning any voice.
class ConsentSection extends StatelessWidget {
  const ConsentSection({
    super.key,
    required this.consentType,
    required this.personController,
    required this.confirmed,
    required this.onTypeChanged,
    required this.onConfirmedChanged,
  });

  final String consentType; // 'self' | 'other_with_consent'
  final TextEditingController personController;
  final bool confirmed;
  final ValueChanged<String> onTypeChanged;
  final ValueChanged<bool> onConfirmedChanged;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isSelf = consentType == 'self';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SegmentedButton<String>(
          segments: const [
            ButtonSegment(value: 'self', icon: Icon(Icons.person), label: Text('صوتي أنا')),
            ButtonSegment(value: 'other_with_consent', icon: Icon(Icons.people_alt), label: Text('شخص آخر')),
          ],
          selected: {consentType},
          onSelectionChanged: (s) => onTypeChanged(s.first),
        ),
        if (!isSelf) ...[
          const SizedBox(height: 12),
          TextField(
            controller: personController,
            maxLength: 60,
            decoration: const InputDecoration(labelText: 'اسم صاحب الصوت', prefixIcon: Icon(Icons.badge_outlined)),
          ),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: scheme.errorContainer.withValues(alpha: 0.6),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Text(
              'لا يجوز استنساخ صوت أي شخص دون موافقته الصريحة والمسبقة. '
              'احتفظ بما يثبت موافقته، والتزم بشروط مزود الخدمة.',
              style: TextStyle(color: scheme.onErrorContainer, height: 1.6),
            ),
          ),
        ],
        const SizedBox(height: 8),
        CheckboxListTile(
          value: confirmed,
          onChanged: (v) => onConfirmedChanged(v ?? false),
          controlAffinity: ListTileControlAffinity.leading,
          contentPadding: EdgeInsets.zero,
          title: Text(
            isSelf
                ? 'أؤكد أن هذه التسجيلات بصوتي أنا، وأوافق على إرسالها إلى مزود الذكاء الاصطناعي لإنشاء نسخة من صوتي.'
                : 'أؤكد أن صاحب الصوت منحني موافقة صريحة على استنساخ صوته واستخدامه في هذا التطبيق.',
            style: const TextStyle(fontSize: 14, height: 1.5),
          ),
        ),
      ],
    );
  }
}
