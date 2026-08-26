import 'package:flutter/material.dart';

/// The app's top bar, for the trainee app and the Trainer Console alike.
///
/// It deliberately sets **no** colours and **no** title size. `ThemeProvider`
/// already declares an identical `AppBarTheme` in both themes — charcoal
/// `#333333`, white foreground, `elevation: 0`, Montserrat w700 at 20 — so
/// every per-screen override in the app was either restating that theme or
/// diverging from it by accident. Three screens hardcoded `Color(0xFF333333)`;
/// four hardcoded `fontSize: 17`, which is simply a different size from the
/// other eleven. Neither kind of drift is visible in a diff, and both are
/// visible on a device.
///
/// The one thing this widget adds over a bare [AppBar] is that it *is* the
/// `Scaffold`'s `appBar`. That matters more than it looks: a `Scaffold` with an
/// `appBar` removes the top `MediaQuery` padding from its `body`, so the status
/// bar inset gets paid exactly once and the bar paints behind it. A bar built
/// as the first child of a `Column` instead — which is what the console did —
/// gets neither, and the inset is then paid twice over.
class ForgeAppBar extends StatelessWidget implements PreferredSizeWidget {
  /// Plain text, styled by the theme. Not a wordmark: the signed-in app names
  /// the surface you are on, and the brand mark belongs to the screens you see
  /// before signing in.
  final String title;

  final List<Widget>? actions;

  /// A `TabBar` or a `LinearProgressIndicator` under the title, for the two
  /// screens that need one.
  final PreferredSizeWidget? bottom;

  /// Set false where a back button would be wrong — a tab root, or a surface
  /// reached by switching rather than by pushing.
  final bool automaticallyImplyLeading;

  const ForgeAppBar({
    super.key,
    required this.title,
    this.actions,
    this.bottom,
    this.automaticallyImplyLeading = true,
  });

  @override
  Size get preferredSize =>
      Size.fromHeight(kToolbarHeight + (bottom?.preferredSize.height ?? 0));

  @override
  Widget build(BuildContext context) {
    return AppBar(
      title: Text(title),
      actions: actions,
      bottom: bottom,
      automaticallyImplyLeading: automaticallyImplyLeading,
    );
  }
}
