import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:ForgeForm/feature/auth/presentation/view/login_screen.dart';
import 'package:ForgeForm/main.dart' show PostAuthHome;
import 'package:ForgeForm/feature/dashboard/view/dashboard_screen.dart';
import 'package:ForgeForm/feature/food_tracking/presentation/view/food_add_screen.dart';
import 'package:ForgeForm/feature/food_tracking/presentation/view/meal_templates_screen.dart';
import 'package:ForgeForm/feature/onboarding/welcome_screen.dart';
import 'package:ForgeForm/feature/settings/settings_screen.dart';
import 'package:ForgeForm/feature/trainer_console/presentation/widgets/trainer_console_shell.dart';
import 'package:ForgeForm/feature/trainer_console/presentation/view/trainer_console_gate.dart';
import 'package:ForgeForm/feature/weight_tracking/presentation/view/weight_goal_screen.dart';
import 'package:ForgeForm/feature/weight_tracking/presentation/view/weight_tracking_screen.dart';

/// The app's routes.
///
/// Why this exists: the Trainer Console ships as a web app — `CLAUDE.md` calls
/// the browser "the trainer's workstation" — but navigation was an in-memory
/// enum over a `LazyIndexedStack`. Switching Dashboard → Messages → Nutrition
/// never changed the address bar, **browser back left the app** rather than
/// going back a section, and no section was bookmarkable or refresh-safe. That
/// is the gap between a Flutter app that compiles for web and a web app.
///
/// What this deliberately does *not* change: the landing decision. `/` still
/// resolves to [PostAuthHome], which stays the single place deciding where an
/// authenticated user goes, still wrapped in `ProfileSetupGate` and
/// `TrainerConsoleGate`. `CLAUDE.md` records that this exact path already
/// produced one bug — "that bug dropped web trainers into the trainee app" —
/// and it did so precisely because the decision got duplicated. Routing is
/// layered *around* the gates, not through them.
///
/// The gates also stay UX guards rather than security boundaries: every
/// console endpoint independently re-checks the caller against an Active
/// relationship, and a deep link to `/console/...` hits the same gate as any
/// other entry.
class AppRouter {
  /// Replaces the old `navigatorKey`: auth-expiry redirects and OS deep links
  /// both need to drive navigation from outside the widget tree.
  static final GlobalKey<NavigatorState> navigatorKey =
      GlobalKey<NavigatorState>();

  /// [isSignedIn] is a callback, not a boolean.
  ///
  /// A captured `hasToken` is the state at app start, and the router outlives
  /// that: after a successful login it still read false, so the redirect below
  /// bounced every console navigation back to `/` and the address bar never
  /// moved. Auth is live state and the redirect has to ask for it each time.
  static GoRouter build({required bool Function() isSignedIn}) {
    return GoRouter(
      navigatorKey: navigatorKey,
      initialLocation: '/',

      // The signed-out check lives here and nowhere else.
      //
      // It was originally on the '/' builder only, which meant a signed-out
      // visitor deep-linking to /console/nutrition got PostAuthHome anyway:
      // ProfileSetupGate then waited forever for a user id that never
      // arrived, and the page sat on a spinner. That is the same mistake
      // CLAUDE.md records — the landing decision duplicated, and one copy
      // wrong — reproduced in a new place. A redirect is the one construct
      // that cannot be duplicated per route.
      redirect: (context, state) {
        if (isSignedIn()) return null;
        return state.uri.path == '/' ? null : '/';
      },

      routes: [
        GoRoute(
          path: '/',
          builder: (context, state) {
            // Anything reaching a non-'/' route is authenticated: the
            // redirect above guarantees it.
            if (isSignedIn()) return const PostAuthHome();
            // Signed out, the welcome screen *is* the home — it carries both
            // Sign in and Create account. Web goes straight to login: that
            // surface is the Trainer Console, and a consumer pitch for calorie
            // tracking has no place in front of it.
            return kIsWeb ? const LoginScreen() : const WelcomeScreen();
          },
        ),

        /// The five console sections, as real paths.
        ///
        /// They resolve through [PostAuthHome] rather than mounting the
        /// console directly, so a deep link runs the same profile-setup and
        /// trainer checks a cold start does. A non-trainer landing on
        /// `/console/nutrition` gets the trainee app, exactly as they would
        /// at `/`.
        GoRoute(
          path: '/console/:section',
          builder: (context, state) => PostAuthHome(
            initialConsoleRoute: _sectionFrom(state.pathParameters['section']),
          ),
        ),

        GoRoute(path: '/dashboard', builder: (_, __) => const DashboardScreen()),
        GoRoute(path: '/settings', builder: (_, __) => const SettingsScreen()),
        GoRoute(
          path: '/weight-tracking',
          builder: (_, __) => const WeightTrackingScreen(),
        ),
        GoRoute(
          path: '/weight-goals',
          builder: (_, __) => const WeightGoalScreen(),
        ),
        GoRoute(
          path: '/meal-templates',
          builder: (_, __) => const MealTemplatesScreen(),
        ),
        GoRoute(
          path: '/add-food',
          builder: (context, state) {
            final args = state.extra as Map<String, dynamic>?;
            return FoodAddScreen(category: args?['category'] as String? ?? '');
          },
        ),

        // Reached from Settings on non-web platforms. The gate re-checks the
        // role itself, so a deep link cannot bypass the entry point. No
        // onExitConsole: this is a pushed route, so back already returns to
        // the trainee app.
        GoRoute(
          path: '/trainer-console',
          builder: (_, __) => const TrainerConsoleGate(),
        ),
      ],

      // An unknown path resolves to the landing decision rather than a 404.
      // The static host rewrites unknown paths to /index.html (CLAUDE.md,
      // "Web support"), so anything that reaches here is a stale bookmark,
      // and dropping such a visitor at the front door is the useful outcome.
      errorBuilder: (context, state) =>
          isSignedIn() ? const PostAuthHome() : const LoginScreen(),
    );
  }

  /// Path segment → section. Unknown segments fall back to the dashboard
  /// rather than throwing: the segment comes from a URL, which is user input.
  static TrainerConsoleRoute _sectionFrom(String? segment) {
    return switch (segment) {
      'messages' => TrainerConsoleRoute.messages,
      'builder' => TrainerConsoleRoute.builder,
      'nutrition' => TrainerConsoleRoute.nutrition,
      'session-review' => TrainerConsoleRoute.sessionReview,
      _ => TrainerConsoleRoute.dashboard,
    };
  }

  /// Section → path segment. The inverse of [_sectionFrom]; kept beside it so
  /// the two cannot drift.
  static String segmentFor(TrainerConsoleRoute route) {
    return switch (route) {
      TrainerConsoleRoute.dashboard => 'dashboard',
      TrainerConsoleRoute.messages => 'messages',
      TrainerConsoleRoute.builder => 'builder',
      TrainerConsoleRoute.nutrition => 'nutrition',
      TrainerConsoleRoute.sessionReview => 'session-review',
    };
  }
}
