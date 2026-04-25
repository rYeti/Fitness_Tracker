import 'package:ForgeForm/core/providers/access_provider.dart';
import 'package:ForgeForm/feature/auth/presentation/providers/auth_provider.dart';
import 'package:ForgeForm/feature/onboarding/onboarding_screen.dart'
    show onboardingFieldDecoration;
import 'package:ForgeForm/l10n/app_localizations.dart';
import 'package:ForgeForm/main.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

class RegisterScreen extends ConsumerStatefulWidget {
  const RegisterScreen({super.key});

  @override
  ConsumerState<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends ConsumerState<RegisterScreen> {
  final _usernameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _firstNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  DateTime? _selectedDate;
  bool _obscurePassword = true;
  bool _obscureConfirm = true;

  @override
  void dispose() {
    _usernameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _firstNameController.dispose();
    _lastNameController.dispose();
    super.dispose();
  }

  Future<void> _pickDate(BuildContext context) async {
    final date = await showDatePicker(
      context: context,
      initialDate: DateTime(2000),
      firstDate: DateTime(1900),
      lastDate: DateTime.now(),
    );
    if (date != null) setState(() => _selectedDate = date);
  }

  void _submit(AppLocalizations l10n) {
    if (_passwordController.text != _confirmPasswordController.text) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.passwordsDoNotMatch)),
      );
      return;
    }
    if (_selectedDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.pleaseSelectDateOfBirth)),
      );
      return;
    }
    ref.read(authProvider.notifier).register(
          _usernameController.text.trim(),
          _emailController.text.trim(),
          _passwordController.text,
          _firstNameController.text.trim(),
          _lastNameController.text.trim(),
          _selectedDate!,
        );
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
              const SizedBox(height: 48),

              // Header
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
                      Icons.person_add_outlined,
                      size: 40,
                      color: theme.colorScheme.onPrimaryContainer,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    l10n.createYourAccount,
                    style: theme.textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 36),

              // First / Last name row
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _firstNameController,
                      decoration:
                          onboardingFieldDecoration(context, l10n.firstName),
                      textInputAction: TextInputAction.next,
                      textCapitalization: TextCapitalization.words,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextField(
                      controller: _lastNameController,
                      decoration:
                          onboardingFieldDecoration(context, l10n.lastName),
                      textInputAction: TextInputAction.next,
                      textCapitalization: TextCapitalization.words,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              TextField(
                controller: _usernameController,
                decoration: onboardingFieldDecoration(context, l10n.username),
                textInputAction: TextInputAction.next,
              ),
              const SizedBox(height: 16),

              TextField(
                controller: _emailController,
                decoration: onboardingFieldDecoration(context, l10n.email),
                textInputAction: TextInputAction.next,
                keyboardType: TextInputType.emailAddress,
              ),
              const SizedBox(height: 16),

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
                textInputAction: TextInputAction.next,
              ),
              const SizedBox(height: 16),

              TextField(
                controller: _confirmPasswordController,
                decoration: onboardingFieldDecoration(
                  context,
                  l10n.confirmPassword,
                ).copyWith(
                  suffixIcon: IconButton(
                    icon: Icon(
                      _obscureConfirm
                          ? Icons.visibility_outlined
                          : Icons.visibility_off_outlined,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                    onPressed: () =>
                        setState(() => _obscureConfirm = !_obscureConfirm),
                  ),
                ),
                obscureText: _obscureConfirm,
                textInputAction: TextInputAction.done,
              ),
              const SizedBox(height: 16),

              // Date of birth picker
              GestureDetector(
                onTap: () => _pickDate(context),
                child: AbsorbPointer(
                  child: TextField(
                    decoration: onboardingFieldDecoration(
                      context,
                      l10n.dateOfBirth,
                    ).copyWith(
                      hintText: l10n.selectDateOfBirth,
                      suffixIcon: Icon(
                        Icons.calendar_today_outlined,
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                    controller: TextEditingController(
                      text: _selectedDate != null
                          ? DateFormat.yMMMd().format(_selectedDate!)
                          : '',
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 32),

              FilledButton(
                onPressed: authState.isLoading ? null : () => _submit(l10n),
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
                        l10n.register,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
              ),

              const SizedBox(height: 24),

              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    l10n.alreadyHaveAccount,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 6),
                    ),
                    child: Text(
                      l10n.login,
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
