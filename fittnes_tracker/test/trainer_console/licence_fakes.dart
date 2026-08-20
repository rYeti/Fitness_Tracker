import 'dart:async';

import 'package:ForgeForm/feature/trainer_console/data/trainer_licence_repository.dart';
import 'package:ForgeForm/feature/trainer_console/domain/models/trainer_licence.dart';

/// Builds a licence in a named state, so tests read as the situation they're
/// describing rather than as eight constructor arguments.
TrainerLicence licence({
  LicenceTier tier = LicenceTier.solo,
  LicenceStatus status = LicenceStatus.active,
  int seatsUsed = 0,
  int seatLimit = 10,
  bool? isEntitled,
  bool? grantsPro,
  DateTime? graceEndsAt,
  bool hasBillingAccount = true,
}) {
  final entitled = isEntitled ??
      (status == LicenceStatus.active ||
          status == LicenceStatus.trialing ||
          (graceEndsAt != null && graceEndsAt.isAfter(DateTime.now())));
  return TrainerLicence(
    tier: tier,
    status: status,
    seatsUsed: seatsUsed,
    seatLimit: seatLimit,
    isEntitled: entitled,
    grantsPro: grantsPro ?? (tier != LicenceTier.free && entitled),
    graceEndsAt: graceEndsAt,
    hasBillingAccount: hasBillingAccount,
  );
}

/// A free-tier licence: the console works, but nobody gets Pro.
TrainerLicence freeLicence({int seatsUsed = 0}) => licence(
      tier: LicenceTier.free,
      seatsUsed: seatsUsed,
      seatLimit: 3,
      hasBillingAccount: false,
    );

class FakeTrainerLicenceRepository implements TrainerLicenceRepository {
  TrainerLicence? current;
  List<PendingInvite> invites;

  final bool throwOnLoad;

  /// Thrown by [createInvite] when set, to drive the refusal states.
  final InviteException? inviteFailure;

  /// Thrown by [joinTrainer] when set.
  final InviteException? joinFailure;

  /// Completes only when a test says so, to hold a screen in loading.
  final Completer<void>? gate;

  final List<String> revokedInviteIds = [];
  final List<LicenceTier> checkoutTiers = [];
  final List<String> joinedCodes = [];
  int createInviteCalls = 0;
  int portalCalls = 0;

  FakeTrainerLicenceRepository({
    this.current,
    this.invites = const [],
    this.throwOnLoad = false,
    this.inviteFailure,
    this.joinFailure,
    this.gate,
  });

  @override
  Future<TrainerLicence> getMine() async {
    if (gate != null) await gate!.future;
    if (throwOnLoad) throw Exception('boom');
    return current ?? licence();
  }

  @override
  Future<List<PendingInvite>> getPendingInvites() async {
    if (gate != null) await gate!.future;
    if (throwOnLoad) throw Exception('boom');
    return invites;
  }

  @override
  Future<TrainerLicence> becomeTrainer() async => current ?? freeLicence();

  @override
  Future<String> createInvite() async {
    createInviteCalls++;
    if (inviteFailure != null) throw inviteFailure!;

    const code = 'A3F2B891C7E4';
    invites = [
      ...invites,
      PendingInvite(
        id: 'invite-$createInviteCalls',
        inviteCode: code,
        createdAt: DateTime.now(),
        expiresAt: DateTime.now().add(const Duration(days: 7)),
      ),
    ];
    // A fresh code holds a seat from the moment it exists.
    if (current != null) {
      current = licence(
        tier: current!.tier,
        status: current!.status,
        seatsUsed: current!.seatsUsed + 1,
        seatLimit: current!.seatLimit,
        graceEndsAt: current!.graceEndsAt,
        hasBillingAccount: current!.hasBillingAccount,
      );
    }
    return code;
  }

  @override
  Future<void> revokeInvite(String inviteId) async {
    revokedInviteIds.add(inviteId);
    invites = invites.where((i) => i.id != inviteId).toList();
    if (current != null) {
      current = licence(
        tier: current!.tier,
        status: current!.status,
        seatsUsed: current!.seatsUsed - 1,
        seatLimit: current!.seatLimit,
        graceEndsAt: current!.graceEndsAt,
        hasBillingAccount: current!.hasBillingAccount,
      );
    }
  }

  @override
  Future<void> joinTrainer(String inviteCode) async {
    if (gate != null) await gate!.future;
    joinedCodes.add(inviteCode);
    if (joinFailure != null) throw joinFailure!;
  }

  @override
  Future<String> createCheckoutSession(LicenceTier tier) async {
    checkoutTiers.add(tier);
    return 'https://checkout.stripe.test/session';
  }

  @override
  Future<String> createPortalSession() async {
    portalCalls++;
    return 'https://billing.stripe.test/portal';
  }
}

PendingInvite pendingInvite({
  String id = 'invite-1',
  String code = 'A3F2B891C7E4',
  int expiresInDays = 6,
}) =>
    PendingInvite(
      id: id,
      inviteCode: code,
      createdAt: DateTime.now().subtract(const Duration(days: 1)),
      expiresAt: DateTime.now().add(Duration(days: expiresInDays)),
    );
