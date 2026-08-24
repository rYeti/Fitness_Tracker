import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:ForgeForm/core/design_tokens.dart';
import 'package:ForgeForm/feature/chat/presentation/providers/chat_provider.dart';
import 'package:ForgeForm/feature/chat/presentation/widgets/unread_badge.dart';
import 'package:ForgeForm/l10n/app_localizations.dart';

enum TrainerConsoleRoute { dashboard, messages, builder, nutrition, sessionReview }

/// Nav metadata in one place, so the sidebar and the bottom bar can't drift
/// apart. `shortLabel` is what fits under a bottom-tab icon.
extension TrainerConsoleRouteInfo on TrainerConsoleRoute {
  String label(AppLocalizations l10n) => switch (this) {
    TrainerConsoleRoute.dashboard => l10n.consoleNavDashboard,
    TrainerConsoleRoute.messages => l10n.consoleNavMessages,
    TrainerConsoleRoute.builder => l10n.consoleNavBuilder,
    TrainerConsoleRoute.nutrition => l10n.consoleNavNutrition,
    TrainerConsoleRoute.sessionReview => l10n.consoleNavSessionReview,
  };

  String shortLabel(AppLocalizations l10n) => switch (this) {
    TrainerConsoleRoute.dashboard => l10n.consoleNavDashboardShort,
    TrainerConsoleRoute.messages => l10n.consoleNavMessagesShort,
    TrainerConsoleRoute.builder => l10n.consoleNavBuilderShort,
    TrainerConsoleRoute.nutrition => l10n.consoleNavNutritionShort,
    TrainerConsoleRoute.sessionReview => l10n.consoleNavSessionReviewShort,
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

    // Nullable on purpose: TrainerConsoleHome only registers a ChatProvider when
    // the chat stack could be built, and the other four sections have nothing to
    // do with chat. `provider` returns null for a nullable type rather than
    // throwing, which is exactly the behaviour wanted here — no badge, no crash.
    //
    // Watching from the shell rather than passing a count in from the console:
    // the shell already sits inside the provider, and `child` is constructed by
    // the parent, so a rebuild here re-inserts the identical widget instance and
    // never reaches the five sections underneath it.
    final unread = context.watch<ChatProvider?>()?.totalUnread ?? 0;

    if (isDesktop) {
      return Scaffold(
        body: Row(
          children: [
            _Sidebar(
              currentRoute: currentRoute,
              onRouteSelected: onRouteSelected,
              onExitConsole: onExitConsole,
              unread: unread,
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
        unread: unread,
      ),
    );
  }
}

class _ExitBar extends StatelessWidget {
  final VoidCallback onExitConsole;

  const _ExitBar({required this.onExitConsole});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Material(
      color: ForgeColors.charcoal,
      child: SafeArea(
        bottom: false,
        child: SizedBox(
          height: 44,
          child: Row(
            children: [
              const SizedBox(width: 12),
              Text(
                l10n.trainerConsole,
                style: const TextStyle(
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
                label: Text(l10n.consoleMyTraining),
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
  final int unread;

  const _Sidebar({
    required this.currentRoute,
    required this.onRouteSelected,
    required this.unread,
    this.onExitConsole,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
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
                // Only Messages carries a count; the badge hides itself at zero.
                unread: route == TrainerConsoleRoute.messages ? unread : 0,
              ),
            const Spacer(),
            if (onExitConsole != null)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Semantics(
                  button: true,
                  label: l10n.consoleSwitchToMyTraining,
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
                                l10n.consoleMyTraining,
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
                l10n.trainerConsole,
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
  final int unread;

  const _SidebarItem({
    required this.route,
    required this.selected,
    required this.onTap,
    this.unread = 0,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final color = selected ? ForgeColors.forgeOrange : Colors.white;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
      child: Semantics(
        selected: selected,
        button: true,
        // Explicit label: without it the icon and text announce as two loose
        // nodes and the item has no accessible name of its own. The count goes
        // in the label rather than being left to the badge — `excludeSemantics`
        // drops the badge's own text, and an orange pill nobody announces is
        // invisible to a screen reader.
        label: unread > 0
            ? '${route.label(l10n)}, ${l10n.chatUnreadCount(unread)}'
            : route.label(l10n),
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
                      route.label(l10n),
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontFamily: 'Exo 2',
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: selected ? color : color.withValues(alpha: 0.8),
                      ),
                    ),
                  ),
                  if (unread > 0) ...[
                    const SizedBox(width: 8),
                    UnreadBadge(count: unread),
                  ],
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
  final int unread;

  const _BottomNav({
    required this.currentRoute,
    required this.onRouteSelected,
    required this.unread,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
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
            icon: _maybeBadge(route, Icon(route.icon)),
            selectedIcon: _maybeBadge(
              route,
              Icon(route.activeIcon, color: ForgeColors.forgeOrange),
            ),
            label: route.shortLabel(l10n),
            // NavigationDestination builds its own semantics from `label`, and
            // the badge is decoration as far as that is concerned. The tooltip
            // is the one string here a screen reader will read out, so the count
            // rides along in it.
            tooltip: route == TrainerConsoleRoute.messages && unread > 0
                ? '${route.label(l10n)}, ${l10n.chatUnreadCount(unread)}'
                : route.label(l10n),
          ),
      ],
    );
  }

  /// Overlays the unread count on the Messages icon, and leaves every other
  /// destination untouched.
  ///
  /// Material's [Badge] rather than [UnreadBadge] here: a bottom-tab count has
  /// to sit *on* the icon, and getting that overlay right inside a
  /// NavigationBar (which clips) is exactly the fiddly bit Badge already
  /// solves. The colour and type come from UnreadBadge's constants so the pill
  /// on the tab and the pill in the inbox cannot drift apart.
  Widget _maybeBadge(TrainerConsoleRoute route, Widget icon) {
    if (route != TrainerConsoleRoute.messages || unread <= 0) return icon;
    return Badge(
      backgroundColor: UnreadBadge.background,
      textStyle: UnreadBadge.textStyle,
      label: Text(UnreadBadge.label(unread)),
      child: icon,
    );
  }
}
