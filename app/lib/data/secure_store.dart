import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Stores the backend URL and access token in the platform keystore/keychain.
/// (The AI provider API key is never on the device – it lives only on the backend.)
class SecureStore {
  SecureStore() : _storage = const FlutterSecureStorage(aOptions: AndroidOptions(encryptedSharedPreferences: true));

  final FlutterSecureStorage _storage;

  static const _kServerUrl = 'server_url';
  static const _kToken = 'access_token';

  Future<String?> serverUrl() => _storage.read(key: _kServerUrl);
  Future<String?> accessToken() => _storage.read(key: _kToken);

  Future<void> saveServer({required String url, required String token}) async {
    await _storage.write(key: _kServerUrl, value: url);
    await _storage.write(key: _kToken, value: token);
  }

  Future<void> clear() async {
    await _storage.delete(key: _kServerUrl);
    await _storage.delete(key: _kToken);
  }
}
