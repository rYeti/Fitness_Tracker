import 'package:ForgeForm/core/network/api_client.dart';
import 'package:ForgeForm/feature/auth/data/Models/auth_response_model.dart';
import 'package:ForgeForm/feature/auth/data/repositories/auth_repository.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

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

  Future<void> login(String username, String password) async {
    state = const AuthState(isLoading: true);

    try {
      var user = await _authRepository.login(username, password);
      state = AuthState(user: user);
    } catch (e) {
      state = AuthState(error: e.toString());
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

    try {
      final user = await _authRepository.register(
        username,
        email,
        password,
        firstName,
        lastName,
        dateOfBirth,
      );
      state = AuthState(user: user);
    } catch (e) {
      state = AuthState(error: e.toString());
    }
  }

  void logout() {
    state = const AuthState();
  }
}

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return AuthRepository(ApiClient(baseUrl: 'http://10.0.2.2:5033'));
});

final authProvider = StateNotifierProvider<AuthNotifier, AuthState>((ref) {
  final repository = ref.watch(authRepositoryProvider);
  return AuthNotifier(repository);
});
