/// The purchasable plans. Mirrors `LicenceTier` on the server.
///
/// [free] is an entry state, never a downgrade target — moving a full roster
/// onto it would hand the trainer those seats permanently, because going over
/// the limit blocks new invites rather than revoking existing clients.
enum LicenceTier { free, solo, pro, studio }

/// Mirrors `LicenceStatus`. Anything the server doesn't recognise arrives as
/// [pastDue] rather than being assumed healthy.
enum LicenceStatus { active, trialing, pastDue, canceled }

extension LicenceTierLabel on LicenceTier {
  String get label => switch (this) {
    LicenceTier.free => 'Free',
    LicenceTier.solo => 'Solo',
    LicenceTier.pro => 'Pro',
    LicenceTier.studio => 'Studio',
  };

  /// The wire value the checkout endpoint expects.
  String get wireName => name;
}

extension LicenceStatusLabel on LicenceStatus {
  String get label => switch (this) {
    LicenceStatus.active => 'Active',
    LicenceStatus.trialing => 'Trial',
    LicenceStatus.pastDue => 'Payment failed',
    LicenceStatus.canceled => 'Cancelled',
  };
}

/// A trainer's plan: how many clients it covers, and whether it grants Pro.
class TrainerLicence {
  final LicenceTier tier;
  final LicenceStatus status;

  /// Active clients plus outstanding invites. An unredeemed invite holds a seat
  /// because otherwise a trainer could mint codes indefinitely under the limit
  /// and blow past it the moment they were all redeemed.
  final int seatsUsed;
  final int seatLimit;

  /// Whether the console works at all: paid and current, trialing, or still
  /// inside the grace window after a lapse.
  final bool isEntitled;

  /// Whether this plan grants Pro to the trainer and their clients. Always
  /// false on the free tier, whatever its status.
  final bool grantsPro;

  /// Set only while lapsed but still in grace. The console shows a banner
  /// naming this date.
  final DateTime? graceEndsAt;

  final DateTime? currentPeriodEnd;
  final bool hasUsedTrial;

  /// Whether there's a Stripe customer behind this, and so whether "Manage
  /// billing" can open the portal.
  final bool hasBillingAccount;

  const TrainerLicence({
    required this.tier,
    required this.status,
    required this.seatsUsed,
    required this.seatLimit,
    required this.isEntitled,
    required this.grantsPro,
    this.graceEndsAt,
    this.currentPeriodEnd,
    this.hasUsedTrial = false,
    this.hasBillingAccount = false,
  });

  /// True when the roster already fills the plan and no new client can be
  /// invited. Reads `>=` rather than `==` because a trainer can legitimately
  /// sit *above* their limit: existing clients are never cut loose when a plan
  /// shrinks, so a downgrade leaves them over until relationships end.
  bool get isFull => seatsUsed >= seatLimit;

  bool get isOverLimit => seatsUsed > seatLimit;

  int get seatsRemaining => (seatLimit - seatsUsed).clamp(0, seatLimit);

  /// Lapsed and past grace: reads still work, writes don't.
  bool get isReadOnly => !isEntitled;

  /// Lapsed but still working, for now.
  bool get isInGrace => isEntitled && graceEndsAt != null;

  factory TrainerLicence.fromJson(Map<String, dynamic> json) {
    return TrainerLicence(
      tier: _tierFrom(json['tier'] as String?),
      status: _statusFrom(json['status'] as String?),
      seatsUsed: json['seatsUsed'] as int? ?? 0,
      seatLimit: json['seatLimit'] as int? ?? 0,
      isEntitled: json['isEntitled'] as bool? ?? false,
      grantsPro: json['grantsPro'] as bool? ?? false,
      graceEndsAt: _dateFrom(json['graceEndsAt']),
      currentPeriodEnd: _dateFrom(json['currentPeriodEnd']),
      hasUsedTrial: json['hasUsedTrial'] as bool? ?? false,
      hasBillingAccount: json['hasBillingAccount'] as bool? ?? false,
    );
  }

  static LicenceTier _tierFrom(String? raw) => switch (raw?.toLowerCase()) {
    'solo' => LicenceTier.solo,
    'pro' => LicenceTier.pro,
    'studio' => LicenceTier.studio,
    _ => LicenceTier.free,
  };

  // An unrecognised status must not read as healthy — that would keep handing
  // out Pro on a state we've never seen.
  static LicenceStatus _statusFrom(String? raw) => switch (raw?.toLowerCase()) {
    'active' => LicenceStatus.active,
    'trialing' => LicenceStatus.trialing,
    'canceled' || 'cancelled' => LicenceStatus.canceled,
    _ => LicenceStatus.pastDue,
  };

  static DateTime? _dateFrom(Object? raw) =>
      raw is String ? DateTime.tryParse(raw)?.toLocal() : null;
}

/// One outstanding invite in the trainer's pending list.
class PendingInvite {
  final String id;
  final String inviteCode;
  final DateTime createdAt;
  final DateTime expiresAt;

  const PendingInvite({
    required this.id,
    required this.inviteCode,
    required this.createdAt,
    required this.expiresAt,
  });

  factory PendingInvite.fromJson(Map<String, dynamic> json) {
    return PendingInvite(
      id: json['id'] as String? ?? '',
      inviteCode: json['inviteCode'] as String? ?? '',
      createdAt:
          DateTime.tryParse(json['createdAt'] as String? ?? '')?.toLocal() ??
          DateTime.now(),
      expiresAt:
          DateTime.tryParse(json['expiresAt'] as String? ?? '')?.toLocal() ??
          DateTime.now(),
    );
  }
}

/// Why an invite couldn't be minted or redeemed. Each case gets its own message
/// — telling a trainee their code is invalid when their trainer has simply run
/// out of seats sends them looking for the wrong problem.
enum InviteFailure {
  seatLimitReached,
  licenceLapsed,
  notATrainer,
  invalidCode,
  expiredCode,
  selfInvite,
  trainerAtSeatLimit,
  trainerNotEntitled,
  network,
}

class InviteException implements Exception {
  final InviteFailure failure;
  final String message;

  const InviteException(this.failure, this.message);

  @override
  String toString() => message;
}
