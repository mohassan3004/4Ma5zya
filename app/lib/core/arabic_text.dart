/// Arabic text processing for PDF extraction and speech synthesis.
///
/// PDF text layers frequently contain Arabic "presentation forms" (contextual glyph code points)
/// and are sometimes stored in visual (reversed) order. This class repairs both, cleans
/// headers/footers noise, and segments text into natural reading units for TTS.
class ArabicText {
  ArabicText._();

  static final Map<int, String> _presentationForms = _buildPresentationForms();

  static Map<int, String> _buildPresentationForms() {
    final m = <int, String>{};
    void range(int start, int count, String value) {
      for (var i = 0; i < count; i++) {
        m[start + i] = value;
      }
    }

    // Presentation Forms-B: harakat
    range(0xFE70, 2, 'ً');
    m[0xFE72] = 'ٌ';
    m[0xFE74] = 'ٍ';
    range(0xFE76, 2, 'َ');
    range(0xFE78, 2, 'ُ');
    range(0xFE7A, 2, 'ِ');
    range(0xFE7C, 2, 'ّ');
    range(0xFE7E, 2, 'ْ');
    // Letters
    m[0xFE80] = 'ء';
    range(0xFE81, 2, 'آ');
    range(0xFE83, 2, 'أ');
    range(0xFE85, 2, 'ؤ');
    range(0xFE87, 2, 'إ');
    range(0xFE89, 4, 'ئ');
    range(0xFE8D, 2, 'ا');
    range(0xFE8F, 4, 'ب');
    range(0xFE93, 2, 'ة');
    range(0xFE95, 4, 'ت');
    range(0xFE99, 4, 'ث');
    range(0xFE9D, 4, 'ج');
    range(0xFEA1, 4, 'ح');
    range(0xFEA5, 4, 'خ');
    range(0xFEA9, 2, 'د');
    range(0xFEAB, 2, 'ذ');
    range(0xFEAD, 2, 'ر');
    range(0xFEAF, 2, 'ز');
    range(0xFEB1, 4, 'س');
    range(0xFEB5, 4, 'ش');
    range(0xFEB9, 4, 'ص');
    range(0xFEBD, 4, 'ض');
    range(0xFEC1, 4, 'ط');
    range(0xFEC5, 4, 'ظ');
    range(0xFEC9, 4, 'ع');
    range(0xFECD, 4, 'غ');
    range(0xFED1, 4, 'ف');
    range(0xFED5, 4, 'ق');
    range(0xFED9, 4, 'ك');
    range(0xFEDD, 4, 'ل');
    range(0xFEE1, 4, 'م');
    range(0xFEE5, 4, 'ن');
    range(0xFEE9, 4, 'ه');
    range(0xFEED, 2, 'و');
    range(0xFEEF, 2, 'ى');
    range(0xFEF1, 4, 'ي');
    // Lam-alef ligatures
    range(0xFEF5, 2, 'لآ');
    range(0xFEF7, 2, 'لأ');
    range(0xFEF9, 2, 'لإ');
    range(0xFEFB, 2, 'لا');
    // Common Forms-A ligatures
    m[0xFDF2] = 'الله';
    m[0xFDFA] = 'صلى الله عليه وسلم';
    m[0xFDFB] = 'جل جلاله';
    return m;
  }

  static final RegExp _invisible = RegExp('[​-‏‪-‮⁦-⁩﻿­ـ]');
  static final RegExp _spaces = RegExp(r'[ \t  - 　]+');
  static final RegExp _pageNumberLine = RegExp(r'^[\s\-–—]*[0-9٠-٩۰-۹]{1,4}[\s\-–—]*$');
  static final RegExp _harakat = RegExp('[ً-ْٰ]');
  static final RegExp _ltrRun = RegExp(r'[0-9A-Za-z٠-٩۰-۹][0-9A-Za-z٠-٩۰-۹.,:/%\-+]*');

  static const _mirror = <String, String>{
    '(': ')', ')': '(', '[': ']', ']': '[', '{': '}', '}': '{',
    '«': '»', '»': '«', '<': '>', '>': '<',
  };

  /// Replaces presentation-form code points with standard Arabic letters.
  static String normalizePresentationForms(String input) {
    final out = StringBuffer();
    for (final rune in input.runes) {
      final mapped = _presentationForms[rune];
      if (mapped != null) {
        out.write(mapped);
      } else {
        out.writeCharCode(rune);
      }
    }
    return out.toString();
  }

  /// Heuristic: does this text look like Arabic stored in visual (reversed) order?
  ///
  /// In logical Arabic many words start with the article "ال"; in reversed text they end with "لا".
  static bool looksReversed(String raw) {
    final text = normalizePresentationForms(raw);
    var starts = 0;
    var ends = 0;
    for (final word in text.split(RegExp(r'\s+'))) {
      final w = word.replaceAll(RegExp(r'[^ء-ي]'), '');
      if (w.length < 3) continue;
      if (w.startsWith('ال')) starts++;
      if (w.endsWith('لا')) ends++;
    }
    return ends >= 3 && ends > starts * 2;
  }

  /// Reverses a visually ordered line into logical order while keeping numbers and Latin runs intact.
  static String reverseLine(String line) {
    final reversed = String.fromCharCodes(line.runes.toList().reversed);
    final fixedRuns = reversed.replaceAllMapped(
      _ltrRun,
      (m) => String.fromCharCodes(m.group(0)!.runes.toList().reversed),
    );
    final out = StringBuffer();
    for (final ch in fixedRuns.split('')) {
      out.write(_mirror[ch] ?? ch);
    }
    return out.toString();
  }

  /// Cleans raw PDF page text into readable logical-order paragraphs separated by '\n'.
  ///
  /// [reverse]: null = auto-detect, true = force reverse, false = never reverse.
  static String cleanPageText(String raw, {bool? reverse}) {
    if (raw.trim().isEmpty) return '';
    final shouldReverse = reverse ?? looksReversed(raw);
    final lines = raw.replaceAll('\r\n', '\n').replaceAll('\r', '\n').split('\n');
    final paragraphs = <String>[];
    final current = StringBuffer();

    void flush() {
      final p = current.toString().trim();
      if (p.isNotEmpty) paragraphs.add(p);
      current.clear();
    }

    for (var line in lines) {
      if (shouldReverse) line = reverseLine(line);
      line = normalizePresentationForms(line).replaceAll(_invisible, '').replaceAll(_spaces, ' ').trim();
      if (line.isEmpty) {
        flush();
        continue;
      }
      if (_pageNumberLine.hasMatch(line)) continue;
      if (current.isNotEmpty) current.write(' ');
      current.write(line);
      if (_endsSentence(line)) flush();
    }
    flush();
    return paragraphs.join('\n');
  }

  static bool _endsSentence(String line) {
    if (line.isEmpty) return false;
    final last = line[line.length - 1];
    return '.!?؟…:'.contains(last);
  }

  static const _enders = {'.', '!', '?', '؟', '…', '؛'};
  static const _closers = {'"', '\'', '»', ')', ']', '”', '’'};

  /// Splits text into sentences while preserving their punctuation.
  static List<String> splitSentences(String text) {
    final result = <String>[];
    for (final para in text.split('\n')) {
      final p = para.trim();
      if (p.isEmpty) continue;
      var start = 0;
      var i = 0;
      while (i < p.length) {
        final c = p[i];
        if (_enders.contains(c)) {
          var j = i + 1;
          while (j < p.length && (_enders.contains(p[j]) || _closers.contains(p[j]))) {
            j++;
          }
          final atBoundary = j >= p.length || p[j] == ' ';
          if (atBoundary) {
            final s = p.substring(start, j).trim();
            if (s.isNotEmpty) result.add(s);
            start = j;
          }
          i = j;
        } else {
          i++;
        }
      }
      if (start < p.length) {
        final rest = p.substring(start).trim();
        if (rest.isNotEmpty) result.add(rest);
      }
    }
    return result;
  }

  /// Groups sentences into reading units: short sentences are merged, long ones split at
  /// commas or spaces, so each TTS request stays natural and within provider limits.
  static List<String> buildReadingUnits(String pageText, {int minLength = 40, int maxLength = 380}) {
    final units = <String>[];
    var current = '';
    for (final sentence in splitSentences(pageText)) {
      for (final piece in _splitLong(sentence, maxLength)) {
        if (current.isEmpty) {
          current = piece;
        } else if (current.length < minLength && current.length + piece.length + 1 <= maxLength) {
          current = '$current $piece';
        } else {
          units.add(current);
          current = piece;
        }
      }
    }
    if (current.isNotEmpty) units.add(current);
    return units;
  }

  static List<String> _splitLong(String s, int maxLength) {
    if (s.length <= maxLength) return [s];
    final parts = <String>[];
    var rest = s;
    while (rest.length > maxLength) {
      var cut = -1;
      for (final sep in const ['،', '؛', ',', ' و', ' ']) {
        final idx = rest.lastIndexOf(sep, maxLength);
        if (idx > maxLength ~/ 3) {
          cut = (sep == '،' || sep == '؛' || sep == ',') ? idx + 1 : idx;
          break;
        }
      }
      if (cut <= 0) cut = maxLength;
      final head = rest.substring(0, cut).trim();
      if (head.isNotEmpty) parts.add(head);
      rest = rest.substring(cut).trim();
    }
    if (rest.isNotEmpty) parts.add(rest);
    return parts;
  }

  /// Final text sent to the TTS provider. Diacritics are kept (they help pronunciation).
  static String prepareForSpeech(String unit) {
    var t = toWesternDigits(unit);
    t = t.replaceAll(RegExp(r'\[\d{1,3}\]'), ''); // footnote markers like [12]
    t = t.replaceAll('٪', '%');
    t = t.replaceAll(_spaces, ' ').trim();
    return t;
  }

  static String toWesternDigits(String s) {
    final out = StringBuffer();
    for (final r in s.runes) {
      if (r >= 0x0660 && r <= 0x0669) {
        out.writeCharCode(0x30 + r - 0x0660);
      } else if (r >= 0x06F0 && r <= 0x06F9) {
        out.writeCharCode(0x30 + r - 0x06F0);
      } else {
        out.writeCharCode(r);
      }
    }
    return out.toString();
  }

  /// Folding used for search: removes diacritics and unifies letter variants.
  static String foldForSearch(String s) {
    return toWesternDigits(normalizePresentationForms(s))
        .replaceAll(_harakat, '')
        .replaceAll(_invisible, '')
        .replaceAll(RegExp('[أإآٱ]'), 'ا')
        .replaceAll('ى', 'ي')
        .replaceAll('ة', 'ه')
        .replaceAll('ؤ', 'و')
        .replaceAll('ئ', 'ي')
        .toLowerCase();
  }
}
