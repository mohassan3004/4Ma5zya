import 'package:flutter_test/flutter_test.dart';
import 'package:ma5zya/core/arabic_text.dart';

void main() {
  group('presentation forms', () {
    test('folds contextual glyphs to base letters', () {
      // "بسم" written with initial/medial/final presentation forms.
      expect(ArabicText.normalizePresentationForms('ﺑﺴﻢ'), 'بسم');
    });
    test('expands lam-alef ligature', () {
      expect(ArabicText.normalizePresentationForms('ﻻ'), 'لا');
    });
  });

  group('reversed text', () {
    const logical = 'الكتاب الجديد في المكتبة العامة والطالب يقرأ الدرس';
    final visual = String.fromCharCodes(logical.runes.toList().reversed);

    test('detects visual order', () {
      expect(ArabicText.looksReversed(visual), isTrue);
      expect(ArabicText.looksReversed(logical), isFalse);
    });

    test('restores logical order and keeps numbers', () {
      expect(ArabicText.reverseLine(visual), logical);
      final withNumber = String.fromCharCodes('العام 2025 الماضي'.runes.toList().reversed.toList());
      // Visual-order lines store digit runs left-to-right already.
      final visualWithDigits = withNumber.replaceAll('5202', '2025');
      expect(ArabicText.reverseLine(visualWithDigits), 'العام 2025 الماضي');
    });

    test('cleanPageText auto-detects and repairs', () {
      expect(ArabicText.cleanPageText(visual), logical);
    });
  });

  group('cleanPageText', () {
    test('joins wrapped lines, drops page numbers and tatweel', () {
      const raw = 'هذا سطر أول\nيكمل الجملة.\n\n12\nفقرة ثانية جديـــدة.';
      expect(ArabicText.cleanPageText(raw, reverse: false), 'هذا سطر أول يكمل الجملة.\nفقرة ثانية جديدة.');
    });
    test('empty text', () {
      expect(ArabicText.cleanPageText('   \n  '), '');
    });
  });

  group('sentences and units', () {
    test('splits on Arabic punctuation but not decimals', () {
      final s = ArabicText.splitSentences('بلغت النسبة 3.5 بالمئة. هل هذا صحيح؟ نعم!');
      expect(s, ['بلغت النسبة 3.5 بالمئة.', 'هل هذا صحيح؟', 'نعم!']);
    });
    test('merges short sentences', () {
      final u = ArabicText.buildReadingUnits('نعم. لا. ربما هذه جملة طويلة بما يكفي لتكون وحدة مستقلة للقراءة.');
      expect(u.length, lessThanOrEqualTo(2));
      expect(u.first.startsWith('نعم. لا.'), isTrue);
    });
    test('splits very long sentences at commas', () {
      final long = List.filled(40, 'هذه عبارة متوسطة الطول،').join(' ');
      final u = ArabicText.buildReadingUnits(long, maxLength: 200);
      expect(u.length, greaterThan(1));
      for (final x in u) {
        expect(x.length, lessThanOrEqualTo(200));
      }
      expect(u.join(' ').replaceAll(' ', ''), long.replaceAll(' ', ''));
    });
  });

  group('speech preparation and search', () {
    test('converts Arabic-Indic digits and strips footnote markers', () {
      expect(ArabicText.prepareForSpeech('عام ٢٠٢٥ وفق المرجع [3] بنسبة ٥٪'), 'عام 2025 وفق المرجع بنسبة 5%');
    });
    test('search folding ignores diacritics and alef variants', () {
      expect(ArabicText.foldForSearch('إِنَّ الأمرَ'), ArabicText.foldForSearch('ان الامر'));
    });
  });
}
