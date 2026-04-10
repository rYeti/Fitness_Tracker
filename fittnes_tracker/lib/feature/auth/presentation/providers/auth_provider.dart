import 'dart:convert';

import 'package:ForgeForm/core/network/api_client.dart';
import 'package:ForgeForm/feature/auth/data/Models/auth_response_model.dart';
import 'package:ForgeForm/feature/auth/data/repositories/auth_repository.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AuthState {
  final bool isLoading;
  final AuthResponseModel? user;
  final String? error;

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
    final prefs = await SharedPreferences.getInstance();
    final userJson = prefs.getString('user');
    if (userJson == null) return;
    try {
      final user = AuthResponseModel.fromJson(
        Map<String, dynamic>.from(jsonDecode(userJson) as Map),
      );
      if (user.expiration.isAfter(DateTime.now())) {
        state = AuthState(user: user);
      } else {
        await prefs.remove('user');
        await prefs.remove('token');
      }
    } catch (_) {
      await prefs.remove('user');
      await prefs.remove('token');
    }
  }

  Future<void> login(String username, String password) async {
    state = const AuthState(isLoading: true);
    try {
      final prefs = await SharedPreferences.getInstance();
      final user = await _authRepository.login(username, password);
      await prefs.setString('token', user.token);
      await prefs.setString('user', jsonEncode(user.toJson()));
      state = AuthState(user: user);
    } catch (e) {
      state = AuthState(error: _friendlyError(e));
    }
  }

  Future<void> register(
    String username,
    String email,
    String password,
    String firstName,
    String lastName,
    DateTime dateOfBirth,
  ) async {
    state = const AuthState(isLoading: true);
    final prefs = await SharedPreferences.getInstance();

    try {
      final user = await _authRepository.register(
        username,
        email,
        password,
        firstName,
        lastName,
        dateOfBirth,
      );
      await prefs.setString('token', user.token);
      await prefs.setString('user', jsonEncode(user.toJson()));
      state = AuthState(user: user);
    } catch (e) {
      state = AuthState(error: _friendlyError(e));
    }
  }

  String _friendlyError(Object e) {
    final msg = e.toString();
    if (msg.contains('401')) return 'Invalid username or password.';
    if (msg.contains('400'))
      return 'Registration failed. Username or email already taken.';
    if (msg.contains('SocketException') || msg.contains('connection'))
      return 'Could not connect to server.';
    return msg;
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
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('token', updated.token);
      await prefs.setString('user', jsonEncode(updated.toJson()));
      state = AuthState(user: updated);
    } catch (e) {
      state = AuthState(user: state.user, error: e.toString());
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
      state = AuthState(user: state.user, error: e.toString());
    }
  }

  Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('token');
    await prefs.remove('user');
    state = const AuthState();
  }
}

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return AuthRepository(ApiClient(baseUrl: 'http://192.168.0.109:5033/'));
});

final authProvider = StateNotifierProvider<AuthNotifier, AuthState>((ref) {
  final repository = ref.watch(authRepositoryProvider);
  return AuthNotifier(repository);
});
