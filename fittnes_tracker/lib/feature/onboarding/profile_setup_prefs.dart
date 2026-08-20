import 'package:shared_preferences/shared_preferences.dart';

/// Tracks whether a given account has been through profile setup.
///
/// Keyed per account rather than per device: the same person signs in on their
/// phone and on the web, and being asked for their goal weight a second time
/// because the browser has its own storage would be a bug. It also means two
/// people sharing a device each get asked once.
///
/// Superseded key: `onboarding_complete`, a single device-wide bool from when
/// setup ran before login and there was no account to attach it to. It's still
/// honoured — see [isComplete] — so nobody who already finished gets asked
/// again after updating.
abstract final class ProfileSetupPrefs {
  static const _legacyDeviceKey = 'onboarding_complete';

  static String _keyFor(String userId) => 'profile_setup_complete_$userId';

  /// Whether [userId] has finished (or deliberately skipped) profile setup.
  static Future<bool> isComplete(String userId) async {
    final prefs = await SharedPreferences.getInstance();
    if (prefs.getBool(_keyFor(userId)) ?? false) return true;

    // Pre-migration installs only have the device-wide flag. Treat it as
    // "this account is done" and adopt it, so the answer survives the legacy
    // key being cleared and stops depending on it.
    if (prefs.getBool(_legacyDeviceKey) ?? false) {
      await prefs.setBool(_keyFor(userId), true);
      return true;
    }
    return false;
  }

  /// Records completion for [userId] only.
  ///
  /// Deliberately does not touch [_legacyDeviceKey]. Writing it would be handy
  /// for downgrades, but it's device-wide: one person finishing setup would
  /// mark everyone else on that device complete too, which is exactly the
  /// behaviour this class exists to end.
  static Future<void> markComplete(String userId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyFor(userId), true);
  }
}
