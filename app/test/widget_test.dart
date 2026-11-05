import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ma5zya/core/theme.dart';
import 'package:ma5zya/ui/screens/about_screen.dart';
import 'package:ma5zya/ui/widgets/common.dart';

Widget _wrap(Widget child) => MaterialApp(
      theme: buildTheme(Brightness.light),
      home: Directionality(textDirection: TextDirection.rtl, child: child),
    );

void main() {
  testWidgets('EmptyState renders Arabic RTL content', (tester) async {
    await tester.pumpWidget(_wrap(const Scaffold(
      body: EmptyState(icon: Icons.library_books, title: 'مكتبتك فارغة', message: 'ارفع ملفًا'),
    )));
    expect(find.text('مكتبتك فارغة'), findsOneWidget);
    final dir = Directionality.of(tester.element(find.text('مكتبتك فارغة')));
    expect(dir, TextDirection.rtl);
  });

  testWidgets('confirmDialog returns true on confirm', (tester) async {
    bool? result;
    await tester.pumpWidget(_wrap(Builder(
      builder: (context) => Scaffold(
        body: TextButton(
          onPressed: () async => result = await confirmDialog(context, title: 'حذف؟', message: 'تأكيد'),
          child: const Text('افتح'),
        ),
      ),
    )));
    await tester.tap(find.text('افتح'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('تأكيد').last);
    await tester.pumpAndSettle();
    expect(result, isTrue);
  });

  testWidgets('About screen explains offline and online features', (tester) async {
    await tester.pumpWidget(_wrap(const AboutScreen()));
    await tester.pump();
    expect(find.text('ما الذي يعمل دون إنترنت؟'), findsOneWidget);
  });
}
