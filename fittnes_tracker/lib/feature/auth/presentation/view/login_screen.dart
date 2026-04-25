import 'package:ForgeForm/core/providers/access_provider.dart';
import 'package:ForgeForm/feature/auth/presentation/providers/auth_provider.dart';
import 'package:ForgeForm/feature/onboarding/onboarding_screen.dart'
    show onboardingFieldDecoration;
import 'package:ForgeForm/l10n/app_localizations.dart';
import 'package:ForgeForm/main.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:provider/provider.dart';
import 'register_screen.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscurePassword = true;

  @override
  void dispose() {
    _usernameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _submit() {
    final username = _usernameController.text.trim();
    final password = _passwordController.text;
    if (username.isEmpty || password.isEmpty) return;
    ref.read(authProvider.notifier).login(username, password);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context)!;
    final authState = ref.watch(authProvider);

    ref.listen<AuthState>(authProvider, (_, next) {
      if (next.error != null) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(next.error!)));
      }
      if (next.isAuthenticated) {
        final serverUrl = ref.read(serverUrlProvider);
        context.read<AccessProvider>().initialize(
          userId: next.user!.username,
          serverBaseUrl: serverUrl,
          bearerToken: next.user!.token,
        );
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => HomeScreen()),
        );
      }
    });

    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 28),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 64),

              // Brand header
              Column(
                children: [
                  Container(
                    width: 72,
                    height: 72,
                    decoration: BoxDecoration(
                      color: theme.colorScheme.primaryContainer,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Icon(
                      Icons.fitness_center,
                      size: 40,
                      color: theme.colorScheme.onPrimaryContainer,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'ForgeForm',
                    style: theme.textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: theme.colorScheme.onSurface,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    l10n.loginToYourAccount,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 48),

              // Username
              TextField(
                controller: _usernameController,
                decoration: onboardingFieldDecoration(context, l10n.username),
                textInputAction: TextInputAction.next,
                keyboardType: TextInputType.emailAddress,
              ),
              const SizedBox(height: 16),

              // Password
              TextField(
                controller: _passwordController,
                decoration: onboardingFieldDecoration(
                  context,
                  l10n.password,
                ).copyWith(
                  suffixIcon: IconButton(
                    icon: Icon(
                      _obscurePassword
                          ? Icons.visibility_outlined
                          : Icons.visibility_off_outlined,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                    onPressed: () =>
                        setState(() => _obscurePassword = !_obscurePassword),
                  ),
                ),
                obscureText: _obscurePassword,
                textInputAction: TextInputAction.done,
                onSubmitted: (_) => _submit(),
              ),

              const SizedBox(height: 32),

              // Login button
              FilledButton(
                onPressed: authState.isLoading ? null : _submit,
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: authState.isLoading
                    ? SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: theme.colorScheme.onPrimary,
                        ),
                      )
                    : Text(
                        l10n.login,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
              ),

              const SizedBox(height: 24),

              // Register link
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    l10n.noAccountQuestion,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  TextButton(
                    onPressed: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const RegisterScreen(),
                      ),
                    ),
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 6),
                    ),
                    child: Text(
                      l10n.register,
                      style: TextStyle(
                        color: theme.colorScheme.primary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
}
