import 'package:ForgeForm/feature/auth/presentation/view/login_screen.dart';
import 'package:ForgeForm/feature/auth/presentation/view/register_screen.dart';
import 'package:ForgeForm/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

/// The pre-authentication screen: what ForgeForm is, then Sign in / Create
/// account.
///
/// Collects nothing. Profile setup used to live here, in front of the login
/// screen, which meant the app asked for a goal weight and a daily calorie
/// target before it had any idea who — or what kind of user — it was talking
/// to. A trainer has no such goals, and the role isn't knowable until after
/// sign-in, so that questionnaire now runs post-auth for trainees only. See
/// ProfileSetupScreen and docs/onboarding-and-roles.md.
class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      backgroundColor: cs.surface,
      body: SafeArea(
        child: Column(
          children: [
            const Expanded(child: _WelcomeBody()),
            Padding(
              padding: const EdgeInsets.fromLTRB(32, 8, 32, 24),
              child: Column(
                children: [
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: () => Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => const RegisterScreen(),
                        ),
                      ),
                      child: Text(l10n.onboardingCreateAccount),
                    ),
                  ),
                  const SizedBox(height: 8),
                  SizedBox(
                    width: double.infinity,
                    child: TextButton(
                      onPressed: () => Navigator.of(context).push(
                        MaterialPageRoute(builder: (_) => const LoginScreen()),
                      ),
                      child: Text(l10n.onboardingAlreadyHaveAccount),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _WelcomeBody extends StatelessWidget {
  const _WelcomeBody();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final cs = Theme.of(context).colorScheme;

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(32, 24, 32, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
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
          const SizedBox(height: 28),
          RichText(
            text: TextSpan(
              children: [
                TextSpan(
                  text: 'Forge',
                  style: TextStyle(
                    fontFamily: 'Montserrat',
                    fontWeight: FontWeight.w800,
                    fontSize: 36,
                    color: cs.primary,
                  ),
                ),
                TextSpan(
                  text: 'Form',
                  style: TextStyle(
                    fontFamily: 'Montserrat',
                    fontWeight: FontWeight.w800,
                    fontSize: 36,
                    color: cs.onSurface,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          Text(
            l10n.onboardingWelcomeSubtitle,
            style: TextStyle(
              fontFamily: 'Exo 2',
              fontSize: 17,
              color: cs.onSurface.withValues(alpha: 0.65),
            ),
          ),
          const SizedBox(height: 20),
          Text(
            l10n.onboardingWelcomeBody,
            style: TextStyle(
              fontFamily: 'Exo 2',
              fontSize: 15,
              height: 1.6,
              color: cs.onSurface.withValues(alpha: 0.55),
            ),
          ),
          const SizedBox(height: 32),
          ...[
            (Icons.restaurant_menu, l10n.food),
            (Icons.fitness_center, l10n.gym),
            (Icons.monitor_weight, l10n.onboardingFeatureWeight),
            (Icons.bar_chart, l10n.progress),
          ].map(
            (item) => Padding(
              padding: const EdgeInsets.only(bottom: 14),
              child: Row(
                children: [
                  Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      color: cs.primary.withValues(alpha: 0.10),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(item.$1, color: cs.primary, size: 20),
                  ),
                  const SizedBox(width: 14),
                  Text(
                    item.$2,
                    style: TextStyle(
                      fontFamily: 'Exo 2',
                      fontWeight: FontWeight.w600,
                      fontSize: 15,
                      color: cs.onSurface,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),
          GestureDetector(
            onTap: () => launchUrl(Uri.parse('https://forgefrom.netlify.app/')),
            child: Text(
              'forgefrom.netlify.app',
              style: TextStyle(
                fontFamily: 'Exo 2',
                fontSize: 13,
                color: cs.primary,
                decoration: TextDecoration.underline,
                decorationColor: cs.primary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
