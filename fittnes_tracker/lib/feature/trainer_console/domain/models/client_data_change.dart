/// Which part of a client's data a change touched, as the server names it in
/// `ClientDataChanged`. See `docs/sync-architecture.md`, part four.
enum ClientDataArea {
  workouts('workouts'),
  sessions('sessions'),
  nutrition('nutrition'),
  weight('weight');

  const ClientDataArea(this.wireName);

  /// The name the hub event uses.
  final String wireName;

  static ClientDataArea? fromWire(Object? name) {
    for (final area in values) {
      if (area.wireName == name) return area;
    }
    return null;
  }
}

/// "Something changed for this client": the hub's `ClientDataChanged` event.
///
/// It carries no data, on purpose. The console re-reads what it shows through
/// the endpoints it already uses, which keep their own access checks — so the
/// event says only *that* something changed and roughly where, never *what*.
class ClientDataChange {
  const ClientDataChange({required this.clientId, required this.areas});

  final String clientId;
  final Set<ClientDataArea> areas;

  /// Reads the event's one argument, `{clientId, areas}`, or returns null when
  /// it has no client to attribute the change to.
  ///
  /// An area this build doesn't know is dropped rather than failing the event:
  /// a server that names a new area must not stop an older console hearing
  /// about the ones it does know, and the roster refresh every event causes
  /// still happens.
  static ClientDataChange? tryParse(Object? json) {
    if (json is! Map) return null;
    final clientId = json['clientId'];
    if (clientId is! String || clientId.isEmpty) return null;
    final areas = json['areas'];
    return ClientDataChange(
      clientId: clientId,
      areas: {
        if (areas is List)
          for (final name in areas)
            if (ClientDataArea.fromWire(name) case final area?) area,
      },
    );
  }
}
