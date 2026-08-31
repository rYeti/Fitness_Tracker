import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Where chat key material lives on this device.
///
/// An interface over `flutter_secure_storage` rather than the plugin itself,
/// for two reasons that both matter:
///
/// * `flutter_secure_storage` is a platform channel, so a plain `flutter test`
///   cannot touch it. Every test of the key lifecycle would otherwise have to
///   mock a method channel to assert something that has nothing to do with
///   channels.
/// * The push background isolate reads from here too (see main.dart's
///   `_firebaseBackgroundHandler`), and it has no service locator and no open
///   database. Naming the small surface it actually needs makes it obvious what
///   is safe to reach for from over there.
abstract class ChatKeyVault {
  Future<String?> read(String key);

  Future<void> write(String key, String value);

  Future<void> delete(String key);

  /// Deletes every entry whose key starts with [prefix]. Used to drop the whole
  /// peer-key cache at once when the account on this device changes.
  Future<void> deletePrefixed(String prefix);
}

/// The real one: the platform keystore/keychain, same store the JWT lives in.
class SecureChatKeyVault implements ChatKeyVault {
  static const _storage = FlutterSecureStorage();

  const SecureChatKeyVault();

  @override
  Future<String?> read(String key) => _storage.read(key: key);

  @override
  Future<void> write(String key, String value) =>
      _storage.write(key: key, value: value);

  @override
  Future<void> delete(String key) => _storage.delete(key: key);

  @override
  Future<void> deletePrefixed(String prefix) async {
    final all = await _storage.readAll();
    for (final key in all.keys) {
      if (key.startsWith(prefix)) await _storage.delete(key: key);
    }
  }
}
