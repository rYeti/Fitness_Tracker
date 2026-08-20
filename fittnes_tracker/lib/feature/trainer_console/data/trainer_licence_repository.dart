import 'package:dio/dio.dart';

import 'package:ForgeForm/feature/trainer_console/data/trainer_licence_api.dart';
import 'package:ForgeForm/feature/trainer_console/domain/models/trainer_licence.dart';

class TrainerLicenceRepository {
  final TrainerLicenceApi _api;

  TrainerLicenceRepository({TrainerLicenceApi? api})
    : _api = api ?? TrainerLicenceApi();

  Future<TrainerLicence> getMine() async =>
      TrainerLicence.fromJson(await _api.fetchMine());

  Future<TrainerLicence> becomeTrainer() async =>
      TrainerLicence.fromJson(await _api.becomeTrainer());

  Future<String> createCheckoutSession(LicenceTier tier) =>
      _api.createCheckoutSession(tier.wireName);

  Future<String> createPortalSession() => _api.createPortalSession();

  Future<List<PendingInvite>> getPendingInvites() async {
    final raw = await _api.fetchPendingInvites();
    return raw.map(PendingInvite.fromJson).toList();
  }

  /// Mints an invite code, or throws an [InviteException] naming why it
  /// couldn't. The server sends a machine-readable `error` alongside the
  /// message so the UI can react (offer an upgrade, say) rather than just
  /// printing text.
  Future<String> createInvite() async {
    try {
      final json = await _api.createInvite();
      return json['inviteCode'] as String? ?? '';
    } on DioException catch (e) {
      throw _asInviteException(e, const {
        'seat_limit_reached': InviteFailure.seatLimitReached,
        'licence_lapsed': InviteFailure.licenceLapsed,
        'not_a_trainer': InviteFailure.notATrainer,
      });
    }
  }

  Future<void> revokeInvite(String inviteId) => _api.revokeInvite(inviteId);

  /// Redeems a code on behalf of the signed-in trainee.
  Future<void> joinTrainer(String inviteCode) async {
    try {
      await _api.joinTrainer(inviteCode);
    } on DioException catch (e) {
      throw _asInviteException(e, const {
        'invalid_code': InviteFailure.invalidCode,
        'expired_code': InviteFailure.expiredCode,
        'self_invite': InviteFailure.selfInvite,
        'trainer_at_seat_limit': InviteFailure.trainerAtSeatLimit,
        'trainer_not_entitled': InviteFailure.trainerNotEntitled,
      });
    }
  }

  /// Translates a server error body into a typed failure. Falls back to
  /// [InviteFailure.network] for anything without a recognised `error` code —
  /// a timeout and a rejected code are different problems and shouldn't share
  /// a message.
  InviteException _asInviteException(
    DioException e,
    Map<String, InviteFailure> codes,
  ) {
    final data = e.response?.data;
    if (data is Map<String, dynamic>) {
      final failure = codes[data['error'] as String?];
      if (failure != null) {
        return InviteException(
          failure,
          data['message'] as String? ?? _fallbackMessage(failure),
        );
      }
    }
    return const InviteException(
      InviteFailure.network,
      "Couldn't reach ForgeForm. Check your connection and try again.",
    );
  }

  String _fallbackMessage(InviteFailure failure) => switch (failure) {
    InviteFailure.seatLimitReached =>
      'Your plan is full. Upgrade or free up a seat to invite another client.',
    InviteFailure.licenceLapsed =>
      'Your licence has lapsed. Renew it to take on new clients.',
    InviteFailure.notATrainer =>
      'Set up a trainer plan before inviting clients.',
    InviteFailure.invalidCode =>
      "That code doesn't match an invite. Check it and try again.",
    InviteFailure.expiredCode =>
      'That invite has expired. Ask your trainer for a new code.',
    InviteFailure.selfInvite => "That's your own invite code.",
    InviteFailure.trainerAtSeatLimit =>
      "Your trainer's plan is full. Ask them to free up a seat.",
    InviteFailure.trainerNotEntitled =>
      "Your trainer's plan isn't active. Ask them to renew it.",
    InviteFailure.network =>
      "Couldn't reach ForgeForm. Check your connection and try again.",
  };
}
