import 'package:flutter/material.dart';

import 'package:ForgeForm/core/design_tokens.dart';
import 'package:ForgeForm/feature/chat/presentation/widgets/unread_badge.dart';

/// One destination in a [ForgeNavBar].
///
/// Carries both icon forms because the handoff's rule is "outlined default,
/// filled + orange when active" — a single icon cannot express a selection
/// state, and letting each call site pick its own pair is how the two clients
/// drifted apart in the first place.
class ForgeNavDestination {
  /// Shown under the icon when this destination is the selected one.
  final String label;

  /// Outlined. What an unselected destination shows.
  final IconData icon;

  /// Filled. What the selected destination shows, in Forge Orange.
  final IconData activeIcon;

  /// Overlaid on the icon when greater than zero. Zero hides the badge.
  final int badgeCount;

  /// What a screen reader announces, when it should differ from [label].
  ///
  /// [NavigationDestination] builds its semantics from `label` alone, so a
  /// badge is decoration as far as accessibility is concerned — an orange
  /// pill nobody announces is invisible. Callers that show a count put the
  /// spoken form here, phrased in their own localisations; `core` has no
  /// business knowing how to say "3 unread" in German.
  final String? semanticLabel;

  const ForgeNavDestination({
    required this.label,
    required this.icon,
    required this.activeIcon,
    this.badgeCount = 0,
    this.semanticLabel,
  });
}

/// The app's bottom navigation, for the trainee app and the Trainer Console
/// alike.
///
/// Both clients used to build their own. The console had already moved to
/// Material 3's [NavigationBar] while the trainee app stayed on the Material 2
/// [BottomNavigationBar], so the same five-tab gesture produced a pill
/// indicator and a selected-only label on one surface and always-on labels
/// with no indicator on the other. Nothing was broken, which is precisely why
/// it survived: two bars that each look deliberate read as one app that isn't.
///
/// The decisions below were all made once, for the console, and are kept
/// verbatim rather than re-derived.
class ForgeNavBar extends StatelessWidget {
  final List<ForgeNavDestination> destinations;
  final int selectedIndex;
  final ValueChanged<int> onSelected;

  const ForgeNavBar({
    super.key,
    required this.destinations,
    required this.selectedIndex,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    // The indicator colour is not set here: it lives in `navigationBarTheme`
    // so that it is declared once for both themes rather than at each call
    // site. See ThemeProvider for why the M3 default is unusable with Forge
    // Orange as `secondary`.
    // Five destinations don't fit labelled on a narrow phone, so there the
    // selected one carries the label alone. Above the mobile breakpoint they
    // fit easily -- at 1440px each destination gets 288px -- and hiding four
    // of five labels there is a phone constraint applied where it does not
    // apply. The console never showed this because its wide layout uses a
    // sidebar and never reaches this widget.
    final labelBehavior = Breakpoints.isMobile(context)
        ? NavigationDestinationLabelBehavior.onlyShowSelected
        : NavigationDestinationLabelBehavior.alwaysShow;

    return NavigationBar(
      selectedIndex: selectedIndex,
      onDestinationSelected: onSelected,
      labelBehavior: labelBehavior,
      destinations: [
        for (final destination in destinations)
          NavigationDestination(
            icon: _maybeBadge(destination, Icon(destination.icon)),
            selectedIcon: _maybeBadge(
              destination,
              Icon(destination.activeIcon, color: ForgeColors.forgeOrange),
            ),
            label: destination.label,
            tooltip: destination.semanticLabel ?? destination.label,
          ),
      ],
    );
  }

  /// Overlays the count on an icon, and leaves a destination without one
  /// untouched.
  ///
  /// Material's [Badge] rather than [UnreadBadge]: a bottom-tab count has to
  /// sit *on* the icon, and getting that overlay right inside a
  /// [NavigationBar] (which clips) is exactly the fiddly bit [Badge] already
  /// solves. The colour and type come from [UnreadBadge]'s constants so the
  /// pill on the tab and the pill in the inbox cannot drift apart.
  Widget _maybeBadge(ForgeNavDestination destination, Widget icon) {
    if (destination.badgeCount <= 0) return icon;
    return Badge(
      backgroundColor: UnreadBadge.background,
      textStyle: UnreadBadge.textStyle,
      label: Text(UnreadBadge.label(destination.badgeCount)),
      child: icon,
    );
  }
}
