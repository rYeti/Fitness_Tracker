import 'package:flutter/material.dart';

import '../design_tokens.dart';

/// Centres a single column of form content and stops it stretching on wide
/// viewports.
///
/// Login, Register and profile setup had no width constraint at all, so at
/// 1440px they rendered 1,384px-wide inputs — 96% of the viewport. They were
/// phone layouts scaled onto a monitor, which matters more here than it would
/// elsewhere: `CLAUDE.md` makes the browser the trainer's primary surface, and
/// on web an unauthenticated visitor goes straight to login, so this is the
/// first screen of the product a trainer sees on their workstation.
///
/// Deliberately one widget rather than three inline `ConstrainedBox`es: these
/// screens are the same layout problem, and the repo convention is one shared
/// widget per repeated pattern.
class FormPane extends StatelessWidget {
  final Widget child;

  /// Horizontal inset on narrow viewports, where the constraint never binds.
  final double horizontalPadding;

  /// Overrides [Breakpoints.formMaxWidth] for a form that genuinely needs more
  /// room — a two-column field row, say. Most callers should leave it alone.
  final double? maxWidth;

  const FormPane({
    super.key,
    required this.child,
    this.horizontalPadding = 28,
    this.maxWidth,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth:
              (maxWidth ?? Breakpoints.formMaxWidth) + horizontalPadding * 2,
        ),
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: horizontalPadding),
          child: child,
        ),
      ),
    );
  }
}
