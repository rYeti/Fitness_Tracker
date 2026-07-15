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

  @override
  Widget build(BuildContext context) {
    // TODO: colored circle (color derived deterministically from clientId
    // so it's stable across screens), initials centered, Montserrat bold.
    return const SizedBox.shrink();
  }
}
