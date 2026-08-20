import 'package:flutter_test/flutter_test.dart';

import 'package:ForgeForm/feature/trainer_console/domain/models/trainer_licence.dart';

import 'licence_fakes.dart';

/// Seat arithmetic and the JSON contract with the server.
void main() {
  group('seat arithmetic', () {
    test('reports room while under the limit', () {
      final l = licence(seatsUsed: 4, seatLimit: 10);
      expect(l.isFull, isFalse);
      expect(l.isOverLimit, isFalse);
      expect(l.seatsRemaining, 6);
    });

    test('is full exactly at the limit', () {
      final l = licence(seatsUsed: 10, seatLimit: 10);
      expect(l.isFull, isTrue);
      expect(l.isOverLimit, isFalse);
      expect(l.seatsRemaining, 0);
    });

    test('handles sitting above the limit after a downgrade', () {
      // Legitimate state: existing clients are never cut loose when a plan
      // shrinks, so a trainer can be over until relationships end.
      final l = licence(seatsUsed: 12, seatLimit: 3);
      expect(l.isFull, isTrue);
      expect(l.isOverLimit, isTrue);
      expect(l.seatsRemaining, 0, reason: 'must not go negative');
    });
  });

  group('entitlement', () {
    test('free tier works but grants no Pro', () {
      final l = freeLicence();
      expect(l.isEntitled, isTrue);
      expect(l.grantsPro, isFalse);
      expect(l.isReadOnly, isFalse);
    });

    test('a licence in grace still works and is flagged as lapsing', () {
      final l = licence(
        status: LicenceStatus.pastDue,
        graceEndsAt: DateTime.now().add(const Duration(days: 5)),
      );
      expect(l.isEntitled, isTrue);
      expect(l.grantsPro, isTrue);
      expect(l.isInGrace, isTrue);
      expect(l.isReadOnly, isFalse);
    });

    test('a licence past grace is read-only', () {
      final l = licence(
        status: LicenceStatus.canceled,
        graceEndsAt: DateTime.now().subtract(const Duration(days: 1)),
      );
      expect(l.isEntitled, isFalse);
      expect(l.grantsPro, isFalse);
      expect(l.isReadOnly, isTrue);
      expect(l.isInGrace, isFalse);
    });
  });

  group('fromJson', () {
    test('maps the server payload', () {
      final l = TrainerLicence.fromJson(const {
        'tier': 'Pro',
        'status': 'Active',
        'seatsUsed': 7,
        'seatLimit': 30,
        'isEntitled': true,
        'grantsPro': true,
        'hasBillingAccount': true,
      });

      expect(l.tier, LicenceTier.pro);
      expect(l.status, LicenceStatus.active);
      expect(l.seatsUsed, 7);
      expect(l.seatLimit, 30);
      expect(l.grantsPro, isTrue);
    });

    test('falls back to the free tier for an unknown tier name', () {
      // Failing open to a paid tier would hand out Pro on a typo.
      final l = TrainerLicence.fromJson(const {'tier': 'Enterprise'});
      expect(l.tier, LicenceTier.free);
      expect(l.grantsPro, isFalse);
    });

    test('treats an unknown status as unhealthy rather than active', () {
      final l = TrainerLicence.fromJson(const {'status': 'something_new'});
      expect(l.status, LicenceStatus.pastDue);
    });

    test('parses grace and period dates, and tolerates their absence', () {
      final withDates = TrainerLicence.fromJson(const {
        'graceEndsAt': '2026-09-03T10:00:00Z',
      });
      expect(withDates.graceEndsAt, isNotNull);

      final without = TrainerLicence.fromJson(const {});
      expect(without.graceEndsAt, isNull);
      expect(without.currentPeriodEnd, isNull);
    });
  });
}
