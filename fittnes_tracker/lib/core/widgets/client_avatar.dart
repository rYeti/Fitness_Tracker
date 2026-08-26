import 'package:flutter/material.dart';

/// Initials-in-colored-circle avatar. One shared widget reused across
/// Roster, Chat, and Client Detail — never re-implement inline per screen.
class ClientAvatar extends StatelessWidget {
  final String initials;
  final String clientId;
  final double size;

  const ClientAvatar({
    super.key,
    required this.initials,
    required this.clientId,
    this.size = 40,
  });

  /// Up to two letters ("Robert Meyer" -> "RM"), matching the avatars in the
  /// design handoff.
  ///
  /// Written four times over before it lived here — in the coach chat header,
  /// the console's client detail, the account screen and `ConversationSummary`
  /// — with four slightly different answers for an empty name. It belongs next
  /// to the widget that renders the result.
  static String initialsFor(String name) {
    final parts = name.split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
    if (parts.isEmpty) return '?';
    if (parts.length == 1) return parts.first[0].toUpperCase();
    return (parts.first[0] + parts.last[0]).toUpperCase();
  }

  /// Deliberately excludes Forge Orange: the brand accent means "active/
  /// selected" everywhere else in the console, so an avatar that happened to
  /// land on it would read as a selection state.
  static const _palette = <Color>[
    Color(0xFF1E88E5), // blue
    Color(0xFF43A047), // green
    Color(0xFF8E24AA), // purple
    Color(0xFF00897B), // teal
    Color(0xFFD81B60), // pink
    Color(0xFF5E35B1), // deep purple
    Color(0xFF00838F), // cyan
  ];

  /// Stable across screens and app launches: same client, same colour, in
  /// roster / chat / detail alike. Uses the id rather than the name so a
  /// rename doesn't move a familiar face to a new colour.
  Color get _color {
    if (clientId.isEmpty) return _palette.first;
    var hash = 0;
    for (final unit in clientId.codeUnits) {
      hash = (hash * 31 + unit) & 0x7FFFFFFF;
    }
    return _palette[hash % _palette.length];
  }

  @override
  Widget build(BuildContext context) {
    final color = _color;
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
      child: Text(
        initials,
        style: TextStyle(
          fontFamily: 'Montserrat',
          fontWeight: FontWeight.w700,
          // Tracks the circle so the same widget works at 24px in a chip and
          // 64px in the chat context panel.
          fontSize: size * 0.4,
          // The palette is fixed and mid-dark, so white always clears AA here
          // — no need to compute contrast per colour.
          color: Colors.white,
          height: 1,
        ),
      ),
    );
  }
}
