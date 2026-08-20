import 'package:flutter/material.dart';

enum TrainerConsoleRoute { dashboard, messages, builder, nutrition, sessionReview }

/// App-shell for the Trainer Console: 240px charcoal sidebar + nav on
/// desktop (>1024px), bottom tab bar on mobile (<600px). Tablet inherits
/// mobile until a screen visibly needs its own layout (see CLAUDE.md
/// breakpoints).
///
/// This does NOT own the active-client (client-switcher) state — that's
/// shared across Chat/Builder/Nutrition and should live above this shell
/// once those screens are built.
class TrainerConsoleShell extends StatelessWidget {
  final TrainerConsoleRoute currentRoute;
  final ValueChanged<TrainerConsoleRoute> onRouteSelected;
  final Widget child;

  const TrainerConsoleShell({
    super.key,
    required this.currentRoute,
    required this.onRouteSelected,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    final isDesktop = MediaQuery.of(context).size.width > 1024;

    // TODO desktop: fixed 240px charcoal sidebar (logo, nav items —
    // Dashboard/Messages/Workout Builder/Nutrition/Session Review, Schedule/
    // Settings pinned at bottom) + fluid content area, 32px padding.
    // TODO mobile: charcoal app bar + content (16px padding) + bottom tab
    // bar (Dashboard / Workouts / Messages / Nutrition / Review — 5 tabs per
    // design handoff's Session Review addition, "Review" label +
    // assignment_turned_in icon).
    // Active nav item: tinted background + orange text/icon (sidebar);
    // filled orange icon (bottom tab).
    if (isDesktop) {
      return Scaffold(body: child);
    }
    return Scaffold(body: child);
  }
}
