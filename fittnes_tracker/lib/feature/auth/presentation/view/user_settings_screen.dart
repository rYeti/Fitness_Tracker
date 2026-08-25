import 'package:ForgeForm/feature/auth/presentation/sign_out.dart';
import 'package:ForgeForm/feature/auth/presentation/providers/auth_provider.dart';
import 'package:ForgeForm/feature/auth/presentation/view/login_screen.dart';
import 'package:ForgeForm/feature/onboarding/onboarding_screen.dart'
    show onboardingFieldDecoration;
import 'package:ForgeForm/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

class UserSettingsScreen extends ConsumerStatefulWidget {
  const UserSettingsScreen({super.key});

  @override
  ConsumerState<UserSettingsScreen> createState() => _UserSettingsScreenState();
}

class _UserSettingsScreenState extends ConsumerState<UserSettingsScreen> {
  // Profile fields
  final _firstNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  final _emailController = TextEditingController();
  DateTime? _dateOfBirth;
  bool _profileDirty = false;

  // Change password fields
  final _currentPasswordController = TextEditingController();
  final _newPasswordController = TextEditingController();
  final _confirmNewPasswordController = TextEditingController();
  bool _showPasswordSection = false;
  bool _obscureCurrent = true;
  bool _obscureNew = true;
  bool _obscureConfirm = true;

  @override
  void initState() {
    super.initState();
    final user = ref.read(authProvider).user;
    if (user != null) {
      _firstNameController.text = user.firstName;
      _lastNameController.text = user.lastName;
      _emailController.text = user.email;
      _dateOfBirth = user.dateOfBirth;
    }
    for (final c in [_firstNameController, _lastNameController, _emailController]) {
      c.addListener(() => setState(() => _profileDirty = true));
    }
  }

  @override
  void dispose() {
    _firstNameController.dispose();
    _lastNameController.dispose();
    _emailController.dispose();
    _currentPasswordController.dispose();
    _newPasswordController.dispose();
    _confirmNewPasswordController.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _dateOfBirth ?? DateTime(1990),
      firstDate: DateTime(1900),
      lastDate: DateTime.now(),
    );
    if (date != null) setState(() { _dateOfBirth = date; _profileDirty = true; });
  }

  static final _emailRegex = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');

  Future<void> _saveProfile(AppLocalizations l10n) async {
    if (_dateOfBirth == null) return;
    final firstName = _firstNameController.text.trim();
    final lastName = _lastNameController.text.trim();
    final email = _emailController.text.trim();
    if (firstName.isEmpty || lastName.isEmpty || email.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.fieldRequired)),
      );
      return;
    }
    if (!_emailRegex.hasMatch(email)) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.invalidEmailFormat)),
      );
      return;
    }
    await ref.read(authProvider.notifier).updateProfile(
          firstName: _firstNameController.text.trim(),
          lastName: _lastNameController.text.trim(),
          email: _emailController.text.trim(),
          dateOfBirth: _dateOfBirth!,
        );
    if (!mounted) return;
    final error = ref.read(authProvider).error;
    if (error == null) {
      setState(() => _profileDirty = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.saveChanges)),
      );
    }
  }

  Future<void> _changePassword(AppLocalizations l10n) async {
    if (_currentPasswordController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.fieldRequired)),
      );
      return;
    }
    if (_newPasswordController.text.length < 8) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.passwordTooShort)),
      );
      return;
    }
    if (_newPasswordController.text != _confirmNewPasswordController.text) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.passwordsDoNotMatch)),
      );
      return;
    }
    await ref.read(authProvider.notifier).changePassword(
          currentPassword: _currentPasswordController.text,
          newPassword: _newPasswordController.text,
        );
    if (!mounted) return;
    final error = ref.read(authProvider).error;
    if (error == null) {
      _currentPasswordController.clear();
      _newPasswordController.clear();
      _confirmNewPasswordController.clear();
      setState(() => _showPasswordSection = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.saveChanges)),
      );
    }
  }

  Future<void> _signOut() async {
    final signedOut = await confirmAndSignOut(context, ref);
    if (!signedOut || !mounted) return;
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const LoginScreen()),
      (_) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context)!;
    final authState = ref.watch(authProvider);
    final user = authState.user;

    if (user == null) return const SizedBox.shrink();

    final initials =
        '${user.firstName.isNotEmpty ? user.firstName[0] : ''}${user.lastName.isNotEmpty ? user.lastName[0] : ''}'
            .toUpperCase();

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.accountSettings),
        actions: [
          if (_profileDirty)
            TextButton(
              onPressed: authState.isLoading ? null : () => _saveProfile(l10n),
              child: Text(
                l10n.save,
                style: TextStyle(
                  color: theme.colorScheme.primary,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
        ],
      ),
      body: authState.isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
              children: [
                // Avatar + username header
                Center(
                  child: Column(
                    children: [
                      CircleAvatar(
                        radius: 40,
                        backgroundColor: theme.colorScheme.primaryContainer,
                        child: Text(
                          initials,
                          style: theme.textTheme.headlineMedium?.copyWith(
                            color: theme.colorScheme.onPrimaryContainer,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        '@${user.username}',
                        style: theme.textTheme.titleMedium?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 32),

                // Profile section
                _SectionHeader(label: l10n.profile),
                const SizedBox(height: 12),

                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _firstNameController,
                        decoration: onboardingFieldDecoration(context, l10n.firstName),
                        textCapitalization: TextCapitalization.words,
                        textInputAction: TextInputAction.next,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextField(
                        controller: _lastNameController,
                        decoration: onboardingFieldDecoration(context, l10n.lastName),
                        textCapitalization: TextCapitalization.words,
                        textInputAction: TextInputAction.next,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                TextField(
                  controller: _emailController,
                  decoration: onboardingFieldDecoration(context, l10n.email),
                  keyboardType: TextInputType.emailAddress,
                  textInputAction: TextInputAction.done,
                ),
                const SizedBox(height: 16),

                // Date of birth
                GestureDetector(
                  onTap: _pickDate,
                  child: AbsorbPointer(
                    child: TextField(
                      decoration: onboardingFieldDecoration(
                        context,
                        l10n.dateOfBirth,
                      ).copyWith(
                        suffixIcon: Icon(
                          Icons.calendar_today_outlined,
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                      controller: TextEditingController(
                        text: _dateOfBirth != null
                            ? DateFormat.yMMMd().format(_dateOfBirth!)
                            : '',
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 32),

                // Security section
                _SectionHeader(label: l10n.security),
                const SizedBox(height: 12),

                Card(
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: BorderSide(color: theme.dividerColor),
                  ),
                  child: Column(
                    children: [
                      ListTile(
                        leading: Icon(
                          Icons.lock_outline,
                          color: theme.colorScheme.primary,
                        ),
                        title: Text(l10n.changePassword),
                        trailing: Icon(
                          _showPasswordSection
                              ? Icons.expand_less
                              : Icons.expand_more,
                        ),
                        onTap: () => setState(
                          () => _showPasswordSection = !_showPasswordSection,
                        ),
                      ),
                      if (_showPasswordSection) ...[
                        const Divider(height: 1),
                        Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            children: [
                              _PasswordField(
                                controller: _currentPasswordController,
                                label: l10n.currentPassword,
                                obscure: _obscureCurrent,
                                onToggle: () => setState(
                                  () => _obscureCurrent = !_obscureCurrent,
                                ),
                              ),
                              const SizedBox(height: 12),
                              _PasswordField(
                                controller: _newPasswordController,
                                label: l10n.newPassword,
                                obscure: _obscureNew,
                                onToggle: () => setState(
                                  () => _obscureNew = !_obscureNew,
                                ),
                              ),
                              const SizedBox(height: 12),
                              _PasswordField(
                                controller: _confirmNewPasswordController,
                                label: l10n.confirmPassword,
                                obscure: _obscureConfirm,
                                onToggle: () => setState(
                                  () => _obscureConfirm = !_obscureConfirm,
                                ),
                              ),
                              const SizedBox(height: 16),
                              SizedBox(
                                width: double.infinity,
                                child: FilledButton(
                                  onPressed: () => _changePassword(l10n),
                                  style: FilledButton.styleFrom(
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                  ),
                                  child: Text(l10n.saveChanges),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                ),

                const SizedBox(height: 32),

                // Sign out
                OutlinedButton.icon(
                  onPressed: _signOut,
                  icon: Icon(Icons.logout, color: theme.colorScheme.error),
                  label: Text(
                    l10n.signOut,
                    style: TextStyle(color: theme.colorScheme.error),
                  ),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    side: BorderSide(color: theme.colorScheme.error),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),

                const SizedBox(height: 32),
              ],
            ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String label;
  const _SectionHeader({required this.label});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Text(
      label.toUpperCase(),
      style: theme.textTheme.labelSmall?.copyWith(
        color: theme.colorScheme.primary,
        fontWeight: FontWeight.bold,
        letterSpacing: 1.2,
      ),
    );
  }
}

class _PasswordField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final bool obscure;
  final VoidCallback onToggle;

  const _PasswordField({
    required this.controller,
    required this.label,
    required this.obscure,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return TextField(
      controller: controller,
      obscureText: obscure,
      decoration: onboardingFieldDecoration(context, label).copyWith(
        suffixIcon: IconButton(
          icon: Icon(
            obscure ? Icons.visibility_outlined : Icons.visibility_off_outlined,
            color: theme.colorScheme.onSurfaceVariant,
          ),
          onPressed: onToggle,
        ),
      ),
    );
  }
}
