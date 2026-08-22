import 'dart:async';
import 'dart:convert';

import 'package:ForgeForm/core/network/api_client.dart';
import 'package:ForgeForm/core/network/secure_token_storage.dart';
import 'package:ForgeForm/feature/auth/data/Models/account_type.dart';
import 'package:ForgeForm/feature/auth/data/Models/auth_failure.dart';
import 'package:ForgeForm/feature/auth/data/Models/auth_response_model.dart';
import 'package:ForgeForm/feature/auth/data/repositories/auth_repository.dart';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class AuthState {
  final bool isLoading;
  final AuthResponseModel? user;

  /// The failure case, not a sentence — the screen localizes it. See
  /// [AuthFailure].
  final AuthFailure? error;

  const AuthState({
    this.isLoading = false,
    this.user = null,
    this.error = null,
  });

  bool get isAuthenticated => user != null;
}

class AuthNotifier extends StateNotifier<AuthState> {
  final AuthRepository _authRepository;

  AuthNotifier(this._authRepository) : super(const AuthState());

  Future<void> restoreSession() async {
    final userJson = await SecureTokenStorage.getUser();
    if (userJson == null) return;
    try {
      final user = AuthResponseModel.fromJson(
        Map<String, dynamic>.from(jsonDecode(userJson) as Map),
      );
      if (user.expiration.isAfter(DateTime.now())) {
        state = AuthState(user: user);
        return;
      }

      // Access token looks expired (by the device's own clock, which may be
      // wrong) — try a silent refresh before giving up on the session.
      final refreshToken = await SecureTokenStorage.getRefreshToken();
      if (refreshToken != null && refreshToken.isNotEmpty) {
        try {
          final refreshed = await _authRepository.refresh(refreshToken);
          await SecureTokenStorage.saveSession(
            token: refreshed.token,
            refreshToken: refreshed.refreshToken,
            userJson: jsonEncode(refreshed.toJson()),
          );
          state = AuthState(user: refreshed);
          return;
        } on DioException catch (e) {
          // Only a real 401 from the server means the refresh token is
          // actually invalid/expired/revoked — clear and fall through to
          // login. A network/timeout/5xx error at cold start (e.g. no
          // connectivity yet, or the API mid-deploy) doesn't mean that: keep
          // the stale local session so the user isn't kicked to the login
          // screen just because they launched the app before Wi-Fi came up.
          if (e.response?.statusCode == 401) {
            await SecureTokenStorage.clear();
          } else {
            state = AuthState(user: user);
          }
          return;
        }
      }

      await SecureTokenStorage.clear();
    } catch (_) {
      await SecureTokenStorage.clear();
    }
  }

  Future<void> login(String username, String password) async {
    state = const AuthState(isLoading: true);
    try {
      final user = await _authRepository.login(username, password);
      await SecureTokenStorage.saveSession(
        token: user.token,
        refreshToken: user.refreshToken,
        userJson: jsonEncode(user.toJson()),
      );
      state = AuthState(user: user);
    } catch (e) {
      state = AuthState(error: classifyAuthError(e, registering: false));
    }
  }

  Future<void> register(
    String username,
    String email,
    String password,
    String firstName,
    String lastName,
    DateTime dateOfBirth,
    AccountType accountType,
  ) async {
    state = const AuthState(isLoading: true);

    try {
      final user = await _authRepository.register(
        username,
        email,
        password,
        firstName,
        lastName,
        dateOfBirth,
        accountType,
      );
      await SecureTokenStorage.saveSession(
        token: user.token,
        refreshToken: user.refreshToken,
        userJson: jsonEncode(user.toJson()),
      );
      state = AuthState(user: user);
    } catch (e) {
      state = AuthState(error: classifyAuthError(e, registering: true));
    }
  }

  Future<void> updateProfile({
    required String firstName,
    required String lastName,
    required String email,
    required DateTime dateOfBirth,
  }) async {
    final token = state.user?.token;
    if (token == null) return;
    state = AuthState(isLoading: true, user: state.user);
    try {
      final updated = await _authRepository.updateProfile(
        token: token,
        firstName: firstName,
        lastName: lastName,
        email: email,
        dateOfBirth: dateOfBirth,
      );
      await SecureTokenStorage.saveSession(
        token: updated.token,
        refreshToken: updated.refreshToken,
        userJson: jsonEncode(updated.toJson()),
      );
      state = AuthState(user: updated);
    } catch (e) {
      state = AuthState(
        user: state.user,
        error: classifyAuthError(e, registering: false),
      );
    }
  }

  Future<void> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    final token = state.user?.token;
    if (token == null) return;
    state = AuthState(isLoading: true, user: state.user);
    try {
      await _authRepository.changePassword(
        token: token,
        currentPassword: currentPassword,
        newPassword: newPassword,
      );
      state = AuthState(user: state.user);
    } catch (e) {
      state = AuthState(
        user: state.user,
        error: classifyAuthError(e, registering: false),
      );
    }
  }

  Future<bool> forgotPassword(String email) async {
    try {
      await _authRepository.forgotPassword(email);
      return true;
    } catch (_) {
      return false;
    }
  }

  /// Returns null on success, or the failure case on error — the screen
  /// localizes it, same as [AuthState.error].
  Future<ResetPasswordFailure?> resetPassword(
    String token,
    String newPassword,
  ) async {
    try {
      await _authRepository.resetPassword(token, newPassword);
      return null;
    } catch (e) {
      // A 400 is the server rejecting the token itself: already used, expired,
      // or never valid. Anything else is a problem with the request, not the
      // link, and saying "your link expired" would send the user to ask for a
      // new one that fails the same way.
      final status = e is DioException ? e.response?.statusCode : null;
      return status == 400
          ? ResetPasswordFailure.linkNoLongerValid
          : ResetPasswordFailure.unknown;
    }
  }

  Future<void> logout() async {
    final refreshToken = await SecureTokenStorage.getRefreshToken();
    if (refreshToken != null && refreshToken.isNotEmpty) {
      unawaited(_authRepository.logout(refreshToken));
    }
    await SecureTokenStorage.clear();
    state = const AuthState();
  }
}

/// SharedPreferences key and fallback for the API server URL.
const serverUrlPrefsKey = 'server_url';
const serverUrlDefault = 'https://fittracker-api-soav3zyeaa-ey.a.run.app/';

/// Holds the active API server URL. Seeded at startup from SharedPreferences
/// (see main.dart). Update this provider to instantly switch the URL at runtime.
final serverUrlProvider = StateProvider<String>((ref) => serverUrlDefault);

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  final url = ref.watch(serverUrlProvider);
  return AuthRepository(ApiClient(baseUrl: url));
});

final authProvider = StateNotifierProvider<AuthNotifier, AuthState>((ref) {
  final repository = ref.watch(authRepositoryProvider);
  return AuthNotifier(repository);
});
