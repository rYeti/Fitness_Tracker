import 'package:flutter/material.dart';

import 'package:ForgeForm/core/design_tokens.dart';

/// The orange unread count, wherever one appears.
///
/// Promoted out of `conversation_row.dart` when the console nav needed the same
/// pill: two copies of a badge is exactly the drift CLAUDE.md's "one shared
/// widget per repeated pattern" rule exists to prevent, and a count that renders
/// one way in the inbox and another on the tab that leads to it is worse than
/// either on its own.
///
/// The nav's bottom bar needs the badge *overlaid* on an icon rather than laid
/// out beside it, which Material's [Badge] already does well — so the colour and
/// type live here as constants it can borrow, rather than being duplicated into
/// a second widget.
class UnreadBadge extends StatelessWidget {
  final int count;

  const UnreadBadge({super.key, required this.count});

  static const background = ForgeColors.forgeOrange;

  static const textStyle = TextStyle(
    fontFamily: 'Montserrat',
    fontWeight: FontWeight.w700,
    fontSize: 11,
    color: Colors.white,
  );

  /// Capped, because a four-digit badge stops being a badge and starts being a
  /// layout problem. The exact number past 99 is not information anyone acts on.
  static String label(int count) => count > 99 ? '99+' : '$count';

  /// The count itself, not just a coloured dot: a dot tells a colourblind
  /// trainer nothing, and "how many" is the useful part anyway.
  @override
  Widget build(BuildContext context) {
    return Container(
      // 20px minimum keeps a single digit circular rather than a narrow oval.
      constraints: const BoxConstraints(minWidth: 20, minHeight: 20),
      alignment: Alignment.center,
      padding: const EdgeInsets.symmetric(horizontal: 6),
      decoration: const BoxDecoration(
        color: background,
        borderRadius: BorderRadius.all(Radius.circular(999)),
      ),
      child: Text(label(count), style: textStyle),
    );
  }
}
