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

  /// The access token, once read. Every outgoing request asks for it in Dio's request
  /// interceptor, and each miss is a platform-channel round trip into the keychain or
  /// EncryptedSharedPreferences — so opening a screen that fires several requests paid
  /// for several of them, serialised on that channel, before any request left the device.
  ///
  /// Only ever written by [saveSession] and cleared by [clear], which are the only two
  /// things that can change it, so it cannot go stale behind the keystore.
  static String? _cachedToken;
  static bool _tokenCached = false;

  static Future<String?> getToken() async {
    if (_tokenCached) return _cachedToken;
    _cachedToken = await _storage.read(key: _tokenKey);
    _tokenCached = true;
    return _cachedToken;
  }

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
    _cachedToken = token;
    _tokenCached = true;
  }

  static Future<void> clear() async {
    // Dropped before the writes, not after: if a delete throws, the next request must
    // not go out holding the token of the account being signed out of.
    _cachedToken = null;
    _tokenCached = false;
    await _storage.delete(key: _tokenKey);
    await _storage.delete(key: _refreshTokenKey);
    await _storage.delete(key: _userKey);
  }
}
