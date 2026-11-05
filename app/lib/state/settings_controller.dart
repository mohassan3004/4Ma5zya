import 'package:flutter/material.dart';

import '../data/remote/api_client.dart';
import '../data/repositories/settings_repository.dart';
import '../data/secure_store.dart';
import '../services/tts_service.dart';

class SettingsController extends ChangeNotifier {
  SettingsController(this._repo, this._secure, this._api, this._tts);

  final SettingsRepository _repo;
  final SecureStore _secure;
  final ApiClient _api;
  final TtsService _tts;

  ThemeMode themeMode = ThemeMode.light;
  double speed = 1.0;

  /// 'auto' | 'on' | 'off' – how to treat Arabic PDFs stored in visual (reversed) order.
  String reverseMode = 'auto';
  bool followPage = true;
  int cacheLimitMb = 500;
  String? serverUrl;
  bool hasToken = false;

  bool get serverConfigured => (serverUrl?.isNotEmpty ?? false) && hasToken;
  bool? get reverseOverride => reverseMode == 'auto' ? null : reverseMode == 'on';

  Future<void> load() async {
    final m = await _repo.load();
    themeMode = switch (m['theme_mode']) {
      'dark' => ThemeMode.dark,
      'system' => ThemeMode.system,
      _ => ThemeMode.light,
    };
    speed = double.tryParse(m['speed'] ?? '') ?? 1.0;
    reverseMode = m['reverse_mode'] ?? 'auto';
    followPage = (m['follow_page'] ?? '1') == '1';
    cacheLimitMb = int.tryParse(m['cache_limit_mb'] ?? '') ?? 500;
    _tts.cacheLimitBytes = cacheLimitMb * 1024 * 1024;
    serverUrl = await _secure.serverUrl();
    hasToken = (await _secure.accessToken())?.isNotEmpty ?? false;
    notifyListeners();
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    themeMode = mode;
    notifyListeners();
    await _repo.put('theme_mode', mode.name);
  }

  Future<void> setSpeed(double value) async {
    speed = value;
    notifyListeners();
    await _repo.put('speed', value.toString());
  }

  Future<void> setReverseMode(String mode) async {
    reverseMode = mode;
    notifyListeners();
    await _repo.put('reverse_mode', mode);
  }

  Future<void> setFollowPage(bool value) async {
    followPage = value;
    notifyListeners();
    await _repo.put('follow_page', value ? '1' : '0');
  }

  Future<void> setCacheLimitMb(int mb) async {
    cacheLimitMb = mb;
    _tts.cacheLimitBytes = mb * 1024 * 1024;
    notifyListeners();
    await _repo.put('cache_limit_mb', mb.toString());
  }

  /// Verifies the server and token, then stores them securely. Returns the provider name.
  Future<String> saveServer(String url, String token) async {
    final cleanUrl = url.trim().replaceAll(RegExp(r'/+$'), '');
    final provider = await _api.testConnection(url: cleanUrl, token: token.trim());
    await _secure.saveServer(url: cleanUrl, token: token.trim());
    serverUrl = cleanUrl;
    hasToken = token.trim().isNotEmpty;
    notifyListeners();
    return provider;
  }

  Future<void> clearServer() async {
    await _secure.clear();
    serverUrl = null;
    hasToken = false;
    notifyListeners();
  }
}
