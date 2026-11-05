/// Application error with an Arabic, user-facing message.
class AppException implements Exception {
  const AppException(this.message, {this.code = 'error'});

  final String message;
  final String code;

  bool get isNetwork => code == 'offline' || code == 'timeout';
  bool get isNotConfigured => code == 'not_configured';

  @override
  String toString() => message;
}

String errorMessage(Object error) {
  if (error is AppException) return error.message;
  return 'حدث خطأ غير متوقع. حاول مرة أخرى.';
}
