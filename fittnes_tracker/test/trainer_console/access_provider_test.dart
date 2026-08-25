import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:ForgeForm/core/providers/access_provider.dart';

/// The truth table for premium access.
///
/// The case that matters is the second one: being someone's client must not, on
/// its own, grant Pro. That's the leak this whole licensing feature exists to
/// close — invite codes are free to mint, so if redeeming one granted premium,
/// premium would be free to anyone with a spare email address.
void main() {
  test('a plain free user has no premium access', () {
    final access = AccessProvider.withState();
    expect(access.hasPremiumAccess, isFalse);
  });

  test('being a trainer client grants nothing by itself', () {
    // The regression test. If this fails, someone has reintroduced
    // `|| isTrainerClient` and given away Pro.
    final access = AccessProvider.withState(
      isTrainerClient: true,
      proFromLicence: false,
    );

    expect(access.isTrainerClient, isTrue);
    expect(access.hasPremiumAccess, isFalse);
  });

  test('a licence that grants Pro grants premium access', () {
    final access = AccessProvider.withState(
      isTrainerClient: true,
      proFromLicence: true,
    );
    expect(access.hasPremiumAccess, isTrue);
  });

  test('an own purchase grants premium access with no licence', () {
    final access = AccessProvider.withState(isPremium: true);
    expect(access.hasPremiumAccess, isTrue);
  });

  test('an own purchase survives the licence lapsing', () {
    final access = AccessProvider.withState(
      isPremium: true,
      isTrainerClient: true,
      proFromLicence: false,
    );
    expect(access.hasPremiumAccess, isTrue);
  });

  group('lapse warning', () {
    test('is silent while nothing is expiring', () {
      final access = AccessProvider.withState(proFromLicence: true);
      expect(access.proIsLapsing, isFalse);
    });

    test('fires while the granting licence is in its grace window', () {
      final ends = DateTime.now().add(const Duration(days: 9));
      final access = AccessProvider.withState(
        isTrainerClient: true,
        proFromLicence: true,
        proEndsAt: ends,
      );

      // Still has Pro, but needs telling before it stops.
      expect(access.hasPremiumAccess, isTrue);
      expect(access.proIsLapsing, isTrue);
      expect(access.proEndsAt, ends);
    });

    test('does not fire once Pro has already gone', () {
      final access = AccessProvider.withState(
        isTrainerClient: true,
        proFromLicence: false,
        proEndsAt: DateTime.now().subtract(const Duration(days: 1)),
      );
      expect(access.proIsLapsing, isFalse);
    });
  });

  group('role', () {
    test('a trainer is a trainer regardless of premium', () {
      final access = AccessProvider.withState(isTrainer: true);
      expect(access.isTrainer, isTrue);
      // A free-tier trainer gets the console but no Pro.
      expect(access.hasPremiumAccess, isFalse);
    });
  });

  /// What the cache is allowed to answer with, and for whom.
  ///
  /// `isTrainer` is a bool, so "not a trainer" and "nobody has asked yet" look
  /// the same to every caller — and the flags are per *account*, on a device
  /// that may have been someone else's. Reading either wrong sends a brand-new
  /// trainer to the trainee dashboard, so both are pinned here.
  group('cached access flags', () {
    // Refused instantly, so initialize() gets through its status check without
    // a real server and without waiting out a timeout.
    const unreachable = 'http://127.0.0.1:1/';

    setUp(() => TestWidgetsFlutterBinding.ensureInitialized());

    /// Runs initialize() and returns what was true at the first notification —
    /// the moment the cache has been restored and the network check has not
    /// come back, which is exactly when the UI decides where to send someone.
    Future<AccessProvider> restoreFor(
      String userId, {
      required void Function(AccessProvider) onCacheRestored,
    }) async {
      final access = AccessProvider();
      var captured = false;
      access.addListener(() {
        if (captured) return;
        captured = true;
        onCacheRestored(access);
      });
      await access.initialize(
        userId: userId,
        serverBaseUrl: unreachable,
        bearerToken: 'token',
      );
      return access;
    }

    test('a first sign-in leaves the role unknown, not false', () async {
      SharedPreferences.setMockInitialValues({});

      bool? roleKnown;
      await restoreFor('coach', onCacheRestored: (a) => roleKnown = a.roleKnown);

      // The registration case. Callers must wait rather than read the default.
      expect(roleKnown, isFalse);
    });

    test("another account's flags are not restored", () async {
      SharedPreferences.setMockInitialValues({
        'access_cached_user_id': 'alice',
        'access_is_trainer': false,
        'access_is_trainer_client': true,
        'access_is_premium': true,
        'access_pro_from_licence': true,
        'access_trainer_id': 'coach-1',
        'access_trainer_name': 'Alex Rowe',
      });

      bool? roleKnown;
      final access = await restoreFor(
        'coach',
        onCacheRestored: (a) => roleKnown = a.roleKnown,
      );

      // Alice's "not a trainer" must not answer for the new account...
      expect(roleKnown, isFalse);
      // ...and neither must her Pro or her coach.
      expect(access.hasPremiumAccess, isFalse);
      expect(access.isTrainerClient, isFalse);
      expect(access.trainerId, isNull);
      expect(access.trainerName, isNull);
    });

    test('the same account\'s own cached role is an answer', () async {
      SharedPreferences.setMockInitialValues({
        'access_cached_user_id': 'coach',
        'access_is_trainer': true,
      });

      bool? roleKnown;
      bool? isTrainer;
      await restoreFor('coach', onCacheRestored: (a) {
        roleKnown = a.roleKnown;
        isTrainer = a.isTrainer;
      });

      // A returning trainer opens straight into the console, offline included.
      expect(roleKnown, isTrue);
      expect(isTrainer, isTrue);
    });

    test('the check resolves the role even when it fails', () async {
      SharedPreferences.setMockInitialValues({});

      final access = await restoreFor('coach', onCacheRestored: (_) {});

      // Nothing may hang forever waiting for a better answer than "offline".
      expect(access.roleResolved, isTrue);
      expect(access.roleKnown, isTrue);
    });
  });
}
