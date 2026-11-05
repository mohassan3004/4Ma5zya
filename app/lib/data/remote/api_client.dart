import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:http/http.dart' as http;
import 'package:path/path.dart' as p;

import '../../core/errors.dart';
import '../secure_store.dart';

class TtsAudio {
  const TtsAudio(this.bytes, this.extension);
  final Uint8List bytes;
  final String extension;
}

/// Client for the private 4Ma5zya backend. All AI-provider calls go through it.
class ApiClient {
  ApiClient(this._secure, {http.Client? client}) : _http = client ?? http.Client();

  final SecureStore _secure;
  final http.Client _http;

  static const _jsonTimeout = Duration(seconds: 45);
  static const _ttsTimeout = Duration(seconds: 120);
  static const _uploadTimeout = Duration(minutes: 6);

  static const offline = AppException(
    'لا يوجد اتصال بالإنترنت أو تعذر الوصول إلى الخادم. ميزات الصوت بالذكاء الاصطناعي تحتاج إلى اتصال.',
    code: 'offline',
  );

  /// Validates a server URL. HTTPS is mandatory except for local development hosts.
  static String? validateServerUrl(String url) {
    final u = Uri.tryParse(url.trim());
    if (u == null || !u.hasScheme || u.host.isEmpty) return 'عنوان غير صالح. مثال: https://api.example.com';
    const localHosts = {'localhost', '127.0.0.1', '10.0.2.2'};
    if (u.scheme == 'https') return null;
    if (u.scheme == 'http' && localHosts.contains(u.host)) return null;
    return 'يجب أن يبدأ العنوان بـ https:// لحماية بياناتك وتسجيلاتك.';
  }

  Future<Uri> _uri(String path, {String? baseOverride}) async {
    final base = (baseOverride ?? await _secure.serverUrl())?.trim();
    if (base == null || base.isEmpty) {
      throw const AppException(
        'لم يتم إعداد الخادم بعد. افتح الإعدادات وأدخل عنوان الخادم ورمز الوصول.',
        code: 'not_configured',
      );
    }
    final problem = validateServerUrl(base);
    if (problem != null) throw AppException(problem, code: 'invalid_url');
    return Uri.parse(base.replaceAll(RegExp(r'/+$'), '') + path);
  }

  Future<Map<String, String>> _headers({String? tokenOverride, bool json = false}) async {
    final token = tokenOverride ?? await _secure.accessToken() ?? '';
    return {
      'Authorization': 'Bearer $token',
      'Accept': 'application/json',
      if (json) 'Content-Type': 'application/json; charset=utf-8',
    };
  }

  Future<T> _guard<T>(Future<T> Function() run) async {
    try {
      return await run();
    } on AppException {
      rethrow;
    } on TimeoutException {
      throw const AppException('انتهت مهلة الاتصال بالخادم. حاول مرة أخرى.', code: 'timeout');
    } on HandshakeException {
      throw const AppException('تعذر إنشاء اتصال آمن (HTTPS) مع الخادم.', code: 'tls');
    } on SocketException {
      throw offline;
    } on http.ClientException {
      throw offline;
    }
  }

  AppException _errorFrom(http.Response r) {
    try {
      final body = jsonDecode(utf8.decode(r.bodyBytes));
      final err = (body as Map<String, dynamic>)['error'] as Map<String, dynamic>;
      return AppException(err['message'] as String, code: err['code'] as String? ?? 'http_${r.statusCode}');
    } catch (_) {
      if (r.statusCode == 401) {
        return const AppException('رمز الوصول إلى الخادم غير صحيح.', code: 'unauthorized');
      }
      if (r.statusCode == 413) {
        return const AppException('حجم الملفات المرسلة أكبر من المسموح به على الخادم.', code: 'too_large');
      }
      return AppException('استجاب الخادم بخطأ (${r.statusCode}).', code: 'http_${r.statusCode}');
    }
  }

  Map<String, dynamic> _json(http.Response r) {
    if (r.statusCode >= 400) throw _errorFrom(r);
    return jsonDecode(utf8.decode(r.bodyBytes)) as Map<String, dynamic>;
  }

  // ------------------------------------------------------------------ endpoints
  /// Checks reachability and token validity. Returns the provider name.
  Future<String> testConnection({required String url, required String token}) => _guard(() async {
        final health = _json(await _http.get(await _uri('/health', baseOverride: url)).timeout(_jsonTimeout));
        final r = await _http
            .get(await _uri('/v1/voices', baseOverride: url), headers: await _headers(tokenOverride: token))
            .timeout(_jsonTimeout);
        _json(r);
        return health['provider'] as String? ?? '';
      });

  Future<List<Map<String, dynamic>>> listVoices() => _guard(() async {
        final r = await _http.get(await _uri('/v1/voices'), headers: await _headers()).timeout(_jsonTimeout);
        final list = _json(r)['voices'] as List<dynamic>;
        return list.cast<Map<String, dynamic>>();
      });

  Future<Map<String, dynamic>> getVoice(String voiceId) => _guard(() async {
        final r = await _http
            .get(await _uri('/v1/voices/${Uri.encodeComponent(voiceId)}'), headers: await _headers())
            .timeout(_jsonTimeout);
        return _json(r);
      });

  Future<Map<String, dynamic>> createVoice({
    required String name,
    required String consentType,
    required bool consentConfirmed,
    String? consentPerson,
    required List<String> samplePaths,
  }) =>
      _guard(() async {
        final req = http.MultipartRequest('POST', await _uri('/v1/voices'))
          ..headers.addAll(await _headers())
          ..fields['name'] = name
          ..fields['consent_type'] = consentType
          ..fields['consent_confirmed'] = consentConfirmed ? 'true' : 'false'
          ..fields['description'] = 'Arabic reading voice created in 4Ma5zya';
        if (consentPerson != null && consentPerson.trim().isNotEmpty) {
          req.fields['consent_person'] = consentPerson.trim();
        }
        for (final path in samplePaths) {
          req.files.add(await http.MultipartFile.fromPath('files', path, filename: p.basename(path)));
        }
        final streamed = await _http.send(req).timeout(_uploadTimeout);
        final r = await http.Response.fromStream(streamed).timeout(_uploadTimeout);
        return _json(r);
      });

  Future<Map<String, dynamic>> addSamples(String voiceId, List<String> samplePaths) => _guard(() async {
        final req = http.MultipartRequest('POST', await _uri('/v1/voices/${Uri.encodeComponent(voiceId)}/samples'))
          ..headers.addAll(await _headers());
        for (final path in samplePaths) {
          req.files.add(await http.MultipartFile.fromPath('files', path, filename: p.basename(path)));
        }
        final streamed = await _http.send(req).timeout(_uploadTimeout);
        return _json(await http.Response.fromStream(streamed).timeout(_uploadTimeout));
      });

  Future<Map<String, dynamic>> importVoice({
    required String voiceId,
    required String name,
    required String consentType,
    String? consentPerson,
  }) =>
      _guard(() async {
        final r = await _http
            .post(
              await _uri('/v1/voices/import'),
              headers: await _headers(json: true),
              body: jsonEncode({
                'voice_id': voiceId,
                'name': name,
                'consent_type': consentType,
                'consent_confirmed': true,
                'consent_person': consentPerson,
              }),
            )
            .timeout(_jsonTimeout);
        return _json(r);
      });

  Future<Map<String, dynamic>> renameVoice(String voiceId, String name) => _guard(() async {
        final r = await _http
            .patch(
              await _uri('/v1/voices/${Uri.encodeComponent(voiceId)}'),
              headers: await _headers(json: true),
              body: jsonEncode({'name': name}),
            )
            .timeout(_jsonTimeout);
        return _json(r);
      });

  Future<void> deleteVoice(String voiceId) => _guard(() async {
        final r = await _http
            .delete(await _uri('/v1/voices/${Uri.encodeComponent(voiceId)}'), headers: await _headers())
            .timeout(_jsonTimeout);
        if (r.statusCode == 404) return; // already removed on the server
        _json(r);
      });

  Future<TtsAudio> synthesize({
    required String voiceId,
    required String text,
    String previousText = '',
    String nextText = '',
  }) =>
      _guard(() async {
        final r = await _http
            .post(
              await _uri('/v1/tts'),
              headers: await _headers(json: true),
              body: jsonEncode({
                'voice_id': voiceId,
                'text': text,
                'previous_text': previousText,
                'next_text': nextText,
              }),
            )
            .timeout(_ttsTimeout);
        if (r.statusCode >= 400) throw _errorFrom(r);
        if (r.bodyBytes.isEmpty) {
          throw const AppException('أرجع الخادم ملفًا صوتيًا فارغًا.', code: 'empty_audio');
        }
        final ext = r.headers['x-audio-extension'] ?? 'mp3';
        return TtsAudio(r.bodyBytes, ext);
      });
}
