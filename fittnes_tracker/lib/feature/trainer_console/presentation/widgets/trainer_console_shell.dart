import 'package:flutter/material.dart';
import 'package:ForgeForm/core/design_tokens.dart';

enum TrainerConsoleRoute { dashboard, messages, builder, nutrition, sessionReview }

/// Nav metadata in one place, so the sidebar and the bottom bar can't drift
/// apart. `shortLabel` is what fits under a bottom-tab icon.
extension TrainerConsoleRouteInfo on TrainerConsoleRoute {
  String get label => switch (this) {
    TrainerConsoleRoute.dashboard => 'Dashboard',
    TrainerConsoleRoute.messages => 'Messages',
    TrainerConsoleRoute.builder => 'Workout Builder',
    TrainerConsoleRoute.nutrition => 'Nutrition',
    TrainerConsoleRoute.sessionReview => 'Session Review',
  };

  String get shortLabel => switch (this) {
    TrainerConsoleRoute.dashboard => 'Home',
    TrainerConsoleRoute.messages => 'Chat',
    TrainerConsoleRoute.builder => 'Workouts',
    TrainerConsoleRoute.nutrition => 'Nutrition',
    TrainerConsoleRoute.sessionReview => 'Review',
  };

  /// Outlined by default, filled when active — per the handoff's icon rule.
  IconData get icon => switch (this) {
    TrainerConsoleRoute.dashboard => Icons.dashboard_outlined,
    TrainerConsoleRoute.messages => Icons.forum_outlined,
    TrainerConsoleRoute.builder => Icons.fitness_center_outlined,
    TrainerConsoleRoute.nutrition => Icons.restaurant_outlined,
    TrainerConsoleRoute.sessionReview => Icons.assignment_turned_in_outlined,
  };

  IconData get activeIcon => switch (this) {
    TrainerConsoleRoute.dashboard => Icons.dashboard_rounded,
    TrainerConsoleRoute.messages => Icons.forum_rounded,
    TrainerConsoleRoute.builder => Icons.fitness_center_rounded,
    TrainerConsoleRoute.nutrition => Icons.restaurant_rounded,
    TrainerConsoleRoute.sessionReview => Icons.assignment_turned_in_rounded,
  };
}

/// App-shell for the Trainer Console: 240px charcoal sidebar + nav on
/// desktop (>1024px), bottom tab bar on mobile. Tablet inherits mobile until a
/// screen visibly needs its own layout (see CLAUDE.md breakpoints).
///
/// This does NOT own the active-client (client-switcher) state — that's shared
/// across Chat/Builder/Nutrition/Session Review and lives in an
/// ActiveClientProvider registered above this shell.
class TrainerConsoleShell extends StatelessWidget {
  final TrainerConsoleRoute currentRoute;
  final ValueChanged<TrainerConsoleRoute> onRouteSelected;
  final Widget child;

  /// Leaves the console for the trainee-facing app. Null when the console was
  /// pushed as a route (the back gesture already covers it); set on web, where
  /// the console is the landing surface and there is nothing to pop.
  final VoidCallback? onExitConsole;

  const TrainerConsoleShell({
    super.key,
    required this.currentRoute,
    required this.onRouteSelected,
    required this.child,
    this.onExitConsole,
  });

  static const _routes = TrainerConsoleRoute.values;

  @override
  Widget build(BuildContext context) {
    final isDesktop = MediaQuery.of(context).size.width > 1024;

    if (isDesktop) {
      return Scaffold(
        body: Row(
          children: [
            _Sidebar(
              currentRoute: currentRoute,
              onRouteSelected: onRouteSelected,
              onExitConsole: onExitConsole,
            ),
            Expanded(child: child),
          ],
        ),
      );
    }

    return Scaffold(
      body: Column(
        children: [
          // Narrow layouts have no sidebar to hold the exit, so it gets a slim
          // bar of its own — but only when there's no back gesture to rely on.
          if (onExitConsole != null) _ExitBar(onExitConsole: onExitConsole!),
          Expanded(child: child),
        ],
      ),
      bottomNavigationBar: _BottomNav(
        currentRoute: currentRoute,
        onRouteSelected: onRouteSelected,
      ),
    );
  }
}

class _ExitBar extends StatelessWidget {
  final VoidCallback onExitConsole;

  const _ExitBar({required this.onExitConsole});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: ForgeColors.charcoal,
      child: SafeArea(
        bottom: false,
        child: SizedBox(
          height: 44,
          child: Row(
            children: [
              const SizedBox(width: 12),
              const Text(
                'Trainer Console',
                style: TextStyle(
                  fontFamily: 'Montserrat',
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                  color: Colors.white,
                ),
              ),
              const Spacer(),
              TextButton.icon(
                onPressed: onExitConsole,
                icon: const Icon(Icons.swap_horiz_rounded, size: 17),
                label: const Text('My training'),
                style: TextButton.styleFrom(foregroundColor: Colors.white),
              ),
              const SizedBox(width: 4),
            ],
          ),
        ),
      ),
    );
  }
}

class _Sidebar extends StatelessWidget {
  final TrainerConsoleRoute currentRoute;
  final ValueChanged<TrainerConsoleRoute> onRouteSelected;
  final VoidCallback? onExitConsole;

  const _Sidebar({
    required this.currentRoute,
    required this.onRouteSelected,
    this.onExitConsole,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 240,
      // Charcoal in both themes, per the handoff — the sidebar is brand
      // chrome, not a themed surface.
      color: ForgeColors.charcoal,
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(20, 24, 20, 28),
              child: Text(
                'ForgeForm',
                style: TextStyle(
                  fontFamily: 'Montserrat',
                  fontWeight: FontWeight.w800,
                  fontSize: 19,
                  letterSpacing: -0.3,
                  color: Colors.white,
                ),
              ),
            ),
            for (final route in TrainerConsoleShell._routes)
              _SidebarItem(
                route: route,
                selected: route == currentRoute,
                onTap: () => onRouteSelected(route),
              ),
            const Spacer(),
            if (onExitConsole != null)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Semantics(
                  button: true,
                  label: 'Switch to my training',
                  excludeSemantics: true,
                  child: Material(
                    color: Colors.transparent,
                    borderRadius: BorderRadius.circular(10),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(10),
                      onTap: onExitConsole,
                      child: Container(
                        constraints: const BoxConstraints(minHeight: 44),
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        child: Row(
                          children: [
                            Icon(
                              Icons.swap_horiz_rounded,
                              size: 20,
                              color: Colors.white.withValues(alpha: 0.7),
                            ),
                            const SizedBox(width: 13),
                            Expanded(
                              child: Text(
                                'My training',
                                style: TextStyle(
                                  fontFamily: 'Exo 2',
                                  fontSize: 13.5,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.white.withValues(alpha: 0.8),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
              child: Text(
                'Trainer Console',
                style: TextStyle(
                  fontFamily: 'Exo 2',
                  fontSize: 11,
                  color: Colors.white.withValues(alpha: 0.4),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SidebarItem extends StatelessWidget {
  final TrainerConsoleRoute route;
  final bool selected;
  final VoidCallback onTap;

  const _SidebarItem({
    required this.route,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final color = selected ? ForgeColors.forgeOrange : Colors.white;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
      child: Semantics(
        selected: selected,
        button: true,
        // Explicit label: without it the icon and text announce as two loose
        // nodes and the item has no accessible name of its own.
        label: route.label,
        excludeSemantics: true,
        child: Material(
          color: selected
              ? ForgeColors.forgeOrange.withValues(alpha: 0.14)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
          child: InkWell(
            borderRadius: BorderRadius.circular(10),
            onTap: onTap,
            child: Container(
              constraints: const BoxConstraints(minHeight: 44),
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Row(
                children: [
                  Icon(
                    selected ? route.activeIcon : route.icon,
                    size: 22,
                    // Unselected icons sit back so the active one reads first.
                    color: selected ? color : color.withValues(alpha: 0.7),
                  ),
                  const SizedBox(width: 13),
                  Expanded(
                    child: Text(
                      route.label,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontFamily: 'Exo 2',
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: selected ? color : color.withValues(alpha: 0.8),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _BottomNav extends StatelessWidget {
  final TrainerConsoleRoute currentRoute;
  final ValueChanged<TrainerConsoleRoute> onRouteSelected;

  const _BottomNav({required this.currentRoute, required this.onRouteSelected});

  @override
  Widget build(BuildContext context) {
    return NavigationBar(
      selectedIndex: TrainerConsoleShell._routes.indexOf(currentRoute),
      onDestinationSelected: (index) =>
          onRouteSelected(TrainerConsoleShell._routes[index]),
      // The default indicator derives from secondaryContainer, which with
      // Forge Orange as `secondary` comes out solid orange — leaving the
      // orange selected icon invisible on top of it. Use a tint instead so
      // the filled orange glyph reads against it.
      indicatorColor: ForgeColors.forgeOrange.withValues(alpha: 0.16),
      // Five destinations don't fit with labels always shown on narrow
      // phones; the selected one stays labelled.
      labelBehavior: NavigationDestinationLabelBehavior.onlyShowSelected,
      destinations: [
        for (final route in TrainerConsoleShell._routes)
          NavigationDestination(
            icon: Icon(route.icon),
            selectedIcon: Icon(
              route.activeIcon,
              color: ForgeColors.forgeOrange,
            ),
            label: route.shortLabel,
            tooltip: route.label,
          ),
      ],
    );
  }
}
