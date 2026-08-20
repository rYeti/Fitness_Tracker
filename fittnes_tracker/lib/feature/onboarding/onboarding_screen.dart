import 'package:flutter/material.dart';

/// Field styling shared by the profile-setup pages.
///
/// All that remains of the old pre-auth OnboardingScreen: the welcome half is
/// now `welcome_screen.dart` and the questionnaire is `profile_setup_screen.dart`.
/// See docs/onboarding-and-roles.md.

InputDecoration onboardingFieldDecoration(BuildContext context, String label) {
  final cs = Theme.of(context).colorScheme;
  final border = OutlineInputBorder(
    borderRadius: BorderRadius.circular(8),
    borderSide: BorderSide(
      color: cs.onSurface.withValues(alpha: 0.10),
      width: 0.5,
    ),
  );
  return InputDecoration(
    labelText: label,
    filled: true,
    fillColor: cs.onSurface.withValues(alpha: 0.07),
    border: border,
    enabledBorder: border,
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(8),
      borderSide: BorderSide(color: cs.primary, width: 1),
    ),
    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
  );
}
