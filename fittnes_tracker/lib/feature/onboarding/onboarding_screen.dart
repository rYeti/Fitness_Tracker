import 'package:flutter/material.dart';
import '../../core/design_tokens.dart';

/// Field styling shared by the profile-setup pages.
///
/// All that remains of the old pre-auth OnboardingScreen: the welcome half is
/// now `welcome_screen.dart` and the questionnaire is `profile_setup_screen.dart`.
/// See docs/onboarding-and-roles.md.

InputDecoration onboardingFieldDecoration(BuildContext context, String label) {
  final cs = Theme.of(context).colorScheme;
  final isDark = Theme.of(context).brightness == Brightness.dark;
  // A field's border is the only thing marking where it is, so it is a
  // non-text UI component under WCAG 1.4.11 and needs 3:1 against its own
  // fill. onSurface at 10% alpha rendered #DFDFDF on the fill — about 1.1:1,
  // i.e. no perceptible box at all. This helper builds its own decoration
  // rather than taking the theme's, so fixing inputDecorationTheme did not
  // reach the four screens that use it (login, register, settings,
  // onboarding); it has to use the same tokens explicitly.
  final border = OutlineInputBorder(
    borderRadius: BorderRadius.circular(8),
    borderSide: BorderSide(
      color: isDark ? ForgeColors.borderDark : ForgeColors.borderLight,
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
