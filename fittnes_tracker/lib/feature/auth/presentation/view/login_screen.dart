import 'package:ForgeForm/core/app_database.dart';
import 'package:ForgeForm/core/providers/access_provider.dart';
import 'package:ForgeForm/core/providers/user_goals_provider.dart';
import 'package:ForgeForm/feature/auth/data/Models/auth_failure.dart';
import 'package:ForgeForm/feature/auth/presentation/providers/auth_provider.dart';
import 'package:ForgeForm/feature/onboarding/onboarding_screen.dart'
    show onboardingFieldDecoration;
import 'package:ForgeForm/l10n/app_localizations.dart';
import 'package:ForgeForm/main.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'forgot_password_screen.dart';
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

    ref.listen<AuthState>(authProvider, (_, next) async {
      if (next.error != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(next.error!.localizedMessage(l10n))),
        );
      }
      if (next.isAuthenticated) {
        final serverUrl = ref.read(serverUrlProvider);
        final newUserId = next.user!.username;
        final db = context.read<AppDatabase>();

        // Wipe local data only when a different user is logging in
        final prefs = await SharedPreferences.getInstance();
        final lastUserId = prefs.getString('last_logged_in_user');
        if (lastUserId != null && lastUserId != newUserId) {
          await db.clearAllUserData();
          await prefs.remove('meal_templates');
          await prefs.remove('last_sync_timestamp');
          if (!context.mounted) return;
          await context.read<UserGoalsProvider>().reload();
        }
        await prefs.setString('last_logged_in_user', newUserId);

        if (!context.mounted) return;
        context.read<AccessProvider>().initialize(
          userId: newUserId,
          serverBaseUrl: serverUrl,
          bearerToken: next.user!.token,
        );
        // PostAuthHome, not HomeScreen: on web a trainer belongs in the
        // console, and that decision lives in one place.
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const PostAuthHome()),
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
                  ClipRRect(
                    borderRadius: BorderRadius.circular(20),
                    child: Image.asset(
                      'assets/icon/app_icon.png',
                      width: 72,
                      height: 72,
                      fit: BoxFit.cover,
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
                    onPressed:
                        () => setState(
                          () => _obscurePassword = !_obscurePassword,
                        ),
                  ),
                ),
                obscureText: _obscurePassword,
                textInputAction: TextInputAction.done,
                onSubmitted: (_) => _submit(),
              ),

              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const ForgotPasswordScreen(),
                    ),
                  ),
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                  ),
                  child: Text(
                    l10n.forgotPassword,
                    style: TextStyle(
                      color: theme.colorScheme.primary,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 16),

              // Login button
              FilledButton(
                onPressed: authState.isLoading ? null : _submit,
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child:
                    authState.isLoading
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
                    onPressed:
                        () => Navigator.push(
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
