/// One roster entry for the trainer's Dashboard/Client Detail/Chat/etc.
///
/// Maps to `TrainerClientResponseDto` from `api/TrainerClient/my-clients`.
/// Fields below the divider aren't returned by that endpoint yet — they're
/// placeholders until adherence/program/attendance endpoints exist.
class TrainerClientSummary {
  final String relationshipId;
  final String clientId;
  final String clientName;
  final String status; // "Pending" | "Active" | "Revoked" — see TrainerClientStatus

  // TODO: wire these up once the backend exposes them.
  final String? programLabel;
  final double? adherencePercent;

  const TrainerClientSummary({
    required this.relationshipId,
    required this.clientId,
    required this.clientName,
    required this.status,
    this.programLabel,
    this.adherencePercent,
  });

  factory TrainerClientSummary.fromJson(Map<String, dynamic> json) {
    return TrainerClientSummary(
      relationshipId: json['id'] as String,
      clientId: json['clientId'] as String,
      clientName: json['clientName'] as String,
      status: json['status'] as String,
    );
  }

  String get initials => clientName.isNotEmpty ? clientName[0].toUpperCase() : '?';
}
