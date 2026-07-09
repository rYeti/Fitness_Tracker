import 'dart:async';
import 'dart:convert';

import 'package:ForgeForm/core/network/api_client.dart';
import 'package:ForgeForm/feature/auth/data/repositories/auth_repository.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Coordinates silent access-token renewal across every [ApiClient] instance.
///
/// Kept as a plain singleton rather than wired through Riverpod/GetIt —
/// [ApiClient] is constructed ad hoc throughout the app with no access to
/// either object graph, so this avoids introducing a new circular
/// dependency just to reach auth state.
class TokenRefreshService {
  TokenRefreshService._();

  static final TokenRefreshService instance = TokenRefreshService._();

  Future<bool>? _refreshing;

  final StreamController<void> _authExpiredController =
      StreamController<void>.broadcast();

  /// Fires when a refresh definitively fails (refresh token missing, expired,
  /// or revoked) — listeners should treat this as "the user is logged out"
  /// and reset auth state / navigate to the login screen.
  Stream<void> get onAuthExpired => _authExpiredController.stream;

  /// Attempts to renew the access token using the stored refresh token.
  /// Concurrent callers share the same in-flight attempt instead of each
  /// triggering their own refresh call (which would otherwise race and
  /// invalidate each other's rotated token).
  Future<bool> refreshIfNeeded(String baseUrl) {
    return _refreshing ??= _doRefresh(
      baseUrl,
    ).whenComplete(() => _refreshing = null);
  }

  Future<bool> _doRefresh(String baseUrl) async {
    final prefs = await SharedPreferences.getInstance();
    final refreshToken = prefs.getString('refresh_token');
    if (refreshToken == null || refreshToken.isEmpty) return false;

    try {
      final repo = AuthRepository(ApiClient(baseUrl: baseUrl));
      final user = await repo.refresh(refreshToken);
      await prefs.setString('token', user.token);
      await prefs.setString('refresh_token', user.refreshToken);
      await prefs.setString('user', jsonEncode(user.toJson()));
      return true;
    } catch (_) {
      await prefs.remove('token');
      await prefs.remove('refresh_token');
      await prefs.remove('user');
      _authExpiredController.add(null);
      return false;
    }
  }
}
