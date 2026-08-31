import 'package:flutter/material.dart';

import '../design_tokens.dart';

/// Centres a page of content and stops it stretching on a wide viewport.
///
/// [FormPane] is the same idea for a column of form fields; this is the one
/// for a screen's body. They are separate because the right width is
/// different: inputs want to stay narrow, while a list of meals with their
/// macros, or a chart, has something to spend the width on.
///
/// The trainee app had neither. Measured across its five tabs at 1440px, the
/// widest control on Dashboard, Food and Profile was 97.8% of the viewport,
/// and on Gym 95.6% — against 15% for every Trainer Console screen. The
/// console reflows into card grids; the trainee app is single-column lists
/// that simply grew.
///
/// The visible cost is not that things look stretched. It is that related
/// controls end up nowhere near each other: on Food a row's name renders at
/// x=33 and its own edit and delete buttons at x=1334, so acting on a meal
/// means crossing the screen to reach the thing that belongs to it.
class ContentPane extends StatelessWidget {
  final Widget child;

  /// Overrides [Breakpoints.contentMaxWidth] where a screen genuinely needs
  /// more room. Most callers should leave it alone.
  final double? maxWidth;

  const ContentPane({super.key, required this.child, this.maxWidth});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: maxWidth ?? Breakpoints.contentMaxWidth,
        ),
        child: child,
      ),
    );
  }
}
