import 'package:flutter/material.dart';

import '../../core/constants.dart';
import '../widgets/app_logo.dart';

class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    TextStyle body() => const TextStyle(height: 1.8);
    Widget section(String title, String text) => Padding(
          padding: const EdgeInsets.only(top: 18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
              const SizedBox(height: 6),
              Text(text, style: body()),
            ],
          ),
        );
    return Scaffold(
      appBar: AppBar(title: const Text('حول التطبيق')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          const Center(child: AppLogo(size: 96)),
          const SizedBox(height: 12),
          const Center(
            child: Text(AppInfo.name, textDirection: TextDirection.ltr, style: TextStyle(fontSize: 26, fontWeight: FontWeight.w800)),
          ),
          Center(child: Text('الإصدار ${AppInfo.version}', style: TextStyle(color: scheme.onSurfaceVariant))),
          section(
            'ما هو 4Ma5zya؟',
            'قارئ لملفات PDF العربية يقرأ لك مستنداتك بصوت طبيعي مُولَّد بالذكاء الاصطناعي من صوتك أنت، '
                'أو من أصوات أشخاص آخرين بموافقتهم الصريحة.',
          ),
          section(
            'ما الذي يعمل دون إنترنت؟',
            '• فتح المستندات المحفوظة وتصفحها والبحث فيها.\n'
                '• العلامات المرجعية وموضع القراءة.\n'
                '• تشغيل المقاطع الصوتية التي سبق توليدها.\n'
                '• إدارة بيانات الأصوات المحفوظة على الجهاز.',
          ),
          section(
            'ما الذي يحتاج إلى إنترنت؟',
            '• رفع التسجيلات وإنشاء الأصوات.\n'
                '• توليد الكلام لنص لم يُولَّد من قبل.\n'
                '• مزامنة الأصوات وحذفها من حساب المزود.',
          ),
          section(
            'الخصوصية',
            '• ملفات PDF تبقى على جهازك ولا تُرفع إلى أي مكان. يُرسل فقط نص الجملة المراد قراءتها إلى خادمك الخاص ثم إلى مزود الصوت.\n'
                '• التسجيلات الصوتية تُرسل إلى خادمك الخاص عند إنشاء الصوت فقط، ولا يخزنها الخادم، بل يمررها إلى مزود الصوت.\n'
                '• مفتاح مزود الذكاء الاصطناعي محفوظ على الخادم فقط، وليس داخل التطبيق.\n'
                '• يمكنك حذف أي صوت أو تسجيل في أي وقت.',
          ),
          section(
            'الاستخدام المسؤول',
            'لا تستنسخ صوت أي شخص دون موافقته الصريحة. يلتزم المستخدم بشروط مزود الخدمة والأنظمة المعمول بها.',
          ),
        ],
      ),
    );
  }
}
