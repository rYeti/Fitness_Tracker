import 'package:dio/dio.dart';

import 'package:ForgeForm/feature/trainer_console/data/trainer_licence_api.dart';
import 'package:ForgeForm/feature/trainer_console/domain/models/trainer_licence.dart';

class TrainerLicenceRepository {
  final TrainerLicenceApi _api;

  TrainerLicenceRepository({TrainerLicenceApi? api})
    : _api = api ?? TrainerLicenceApi();

  /// The caller's plan, or null when this isn't a trainer account.
  Future<TrainerLicence?> getMine() async {
    final json = await _api.fetchMine();
    return json == null ? null : TrainerLicence.fromJson(json);
  }

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
        // The message is carried for diagnostics only — the UI renders the
        // localized wording for the code. The seat numbers travel separately
        // and *are* shown, so a full plan can be described exactly without
        // borrowing the API's English.
        return InviteException(
          failure,
          data['message'] as String?,
          data['seatsUsed'] as int?,
          data['seatLimit'] as int?,
        );
      }
    }
    return const InviteException(InviteFailure.network);
  }
}
