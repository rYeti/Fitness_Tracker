import 'package:flutter/foundation.dart';

import 'package:ForgeForm/feature/trainer_console/data/trainer_licence_repository.dart';
import 'package:ForgeForm/feature/trainer_console/domain/models/trainer_licence.dart';
import 'package:ForgeForm/feature/trainer_console/domain/models/console_error.dart';

/// Drives the licence screen and the seat affordances on the Dashboard: the
/// plan, its seat usage, and the trainer's outstanding invites.
class TrainerLicenceProvider extends ChangeNotifier {
  final TrainerLicenceRepository _repository;

  TrainerLicenceProvider({TrainerLicenceRepository? repository})
    : _repository = repository ?? TrainerLicenceRepository();

  TrainerLicence? _licence;
  List<PendingInvite> _pendingInvites = [];
  bool _isLoading = false;
  ConsoleError? _error;

  /// The code minted by the most recent [createInvite], held so the sheet can
  /// display it. Cleared when the sheet is dismissed.
  String? _newInviteCode;

  /// Either a typed console failure or the refusal the server described.
  /// Held as the exception so the screen can prefer the server's wording and
  /// fall back to a localized sentence — see [InviteException.message].
  InviteException? _inviteFailure;
  ConsoleError? _inviteError;
  bool _isMinting = false;

  /// The plan, or null when this isn't a trainer account — or when the load
  /// failed, which [error] is what distinguishes.
  TrainerLicence? get licence => _licence;
  List<PendingInvite> get pendingInvites => _pendingInvites;
  bool get isLoading => _isLoading;
  ConsoleError? get error => _error;
  String? get newInviteCode => _newInviteCode;
  InviteException? get inviteFailure => _inviteFailure;
  ConsoleError? get inviteError => _inviteError;
  bool get isMinting => _isMinting;

  /// Whether the invite action should be offered at all. False when the plan is
  /// full or the licence has lapsed past grace — in both cases the server would
  /// refuse, and a button that always fails is worse than one that explains
  /// itself.
  bool get canInvite =>
      _licence != null && _licence!.isEntitled && !_licence!.isFull;

  Future<void> load() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      // Together: the seat meter is meaningless without knowing how many of
      // those seats are outstanding invites the trainer could reclaim.
      final results = await Future.wait([
        _repository.getMine(),
        _repository.getPendingInvites(),
      ]);
      _licence = results[0] as TrainerLicence?;
      _pendingInvites = results[1] as List<PendingInvite>;
    } catch (_) {
      _error = ConsoleError.loadLicence;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Mints an invite code. On refusal [inviteFailure] carries the typed reason
  /// — "your plan is full" rather than a generic failure — along with the
  /// server's own wording when it sent any.
  Future<void> createInvite() async {
    _isMinting = true;
    _inviteError = null;
    _inviteFailure = null;
    _newInviteCode = null;
    notifyListeners();

    try {
      _newInviteCode = await _repository.createInvite();
      // Refresh so the seat meter and the pending list reflect the new code
      // immediately — it holds a seat from the moment it exists.
      await _refreshQuietly();
    } on InviteException catch (e) {
      _inviteFailure = e;
    } catch (_) {
      _inviteError = ConsoleError.createInvite;
    } finally {
      _isMinting = false;
      notifyListeners();
    }
  }

  /// Withdraws an unredeemed invite, freeing its seat.
  Future<void> revokeInvite(String inviteId) async {
    try {
      await _repository.revokeInvite(inviteId);
      await _refreshQuietly();
    } catch (_) {
      _inviteError = ConsoleError.withdrawInvite;
    }
    notifyListeners();
  }

  void clearNewInvite() {
    _newInviteCode = null;
    _inviteError = null;
    _inviteFailure = null;
    notifyListeners();
  }

  /// Re-reads plan and invites without flipping [isLoading] — used after a
  /// mutation, where a skeleton would be a visual step backwards.
  Future<void> _refreshQuietly() async {
    try {
      final results = await Future.wait([
        _repository.getMine(),
        _repository.getPendingInvites(),
      ]);
      _licence = results[0] as TrainerLicence?;
      _pendingInvites = results[1] as List<PendingInvite>;
    } catch (_) {
      // Leave the last-known values; the mutation itself already succeeded.
    }
  }

  Future<String?> startCheckout(LicenceTier tier) async {
    try {
      return await _repository.createCheckoutSession(tier);
    } catch (_) {
      _error = ConsoleError.openCheckout;
      notifyListeners();
      return null;
    }
  }

  Future<String?> openBillingPortal() async {
    try {
      return await _repository.createPortalSession();
    } catch (_) {
      _error = ConsoleError.openBilling;
      notifyListeners();
      return null;
    }
  }
}
