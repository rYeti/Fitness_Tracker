import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Stores the access token, refresh token, and cached user session in the
/// platform keystore/keychain instead of plain [SharedPreferences], so they
/// aren't readable from an unencrypted prefs file on a compromised device or
/// backup.
class SecureTokenStorage {
  SecureTokenStorage._();

  static const _storage = FlutterSecureStorage();

  static const _tokenKey = 'token';
  static const _refreshTokenKey = 'refresh_token';
  static const _userKey = 'user';

  static Future<String?> getToken() => _storage.read(key: _tokenKey);

  static Future<String?> getRefreshToken() =>
      _storage.read(key: _refreshTokenKey);

  static Future<String?> getUser() => _storage.read(key: _userKey);

  static Future<void> saveSession({
    required String token,
    required String refreshToken,
    required String userJson,
  }) async {
    await _storage.write(key: _tokenKey, value: token);
    await _storage.write(key: _refreshTokenKey, value: refreshToken);
    await _storage.write(key: _userKey, value: userJson);
  }

  static Future<void> clear() async {
    await _storage.delete(key: _tokenKey);
    await _storage.delete(key: _refreshTokenKey);
    await _storage.delete(key: _userKey);
  }
}
