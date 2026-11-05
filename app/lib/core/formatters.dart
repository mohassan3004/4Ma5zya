import 'package:intl/intl.dart';

String formatBytes(int bytes) {
  if (bytes < 1024) return '$bytes بايت';
  if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(0)} ك.ب';
  if (bytes < 1024 * 1024 * 1024) {
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} م.ب';
  }
  return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(2)} ج.ب';
}

String formatDuration(Duration d) {
  final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
  final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
  if (d.inHours > 0) return '${d.inHours}:$m:$s';
  return '$m:$s';
}

String formatSeconds(double seconds) => formatDuration(Duration(milliseconds: (seconds * 1000).round()));

String formatDate(DateTime date) => DateFormat('d MMMM y', 'ar').format(date.toLocal());

String formatDateTime(DateTime date) => DateFormat('d MMMM y – h:mm a', 'ar').format(date.toLocal());

String formatPercent(double v) => '${(v * 100).clamp(0, 100).round()}٪';
