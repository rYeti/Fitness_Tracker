import 'package:flutter_test/flutter_test.dart';

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
}
