import 'package:flutter_test/flutter_test.dart';

import 'package:ForgeForm/core/providers/access_provider.dart';

void main() {
  group('trainer identity from api/TrainerClient/status', () {
    test('is parsed from the payload the endpoint already returns', () {
      final access = AccessProvider.withState();

      access.applyStatusPayload(const {
        'isTrainerClient': true,
        'isTrainer': false,
        'trainerName': 'Dana Ruiz',
        'trainerId': '11111111-1111-1111-1111-111111111111',
      });

      expect(access.isTrainerClient, isTrue);
      expect(access.isTrainer, isFalse);
      // The trainee's whole chat surface hangs off this id — it is the only
      // "other party" they have.
      expect(access.trainerId, '11111111-1111-1111-1111-111111111111');
      expect(access.trainerName, 'Dana Ruiz');
    });

    test('leaves the trainer null for a user with no coach', () {
      final access = AccessProvider.withState();

      access.applyStatusPayload(const {
        'isTrainerClient': false,
        'isTrainer': true,
        'trainerName': null,
        'trainerId': null,
      });

      expect(access.trainerId, isNull);
      expect(access.trainerName, isNull);
    });

    test('tolerates a payload missing the trainer fields entirely', () {
      final access = AccessProvider.withState();

      access.applyStatusPayload(const {'isTrainerClient': false});

      expect(access.isTrainerClient, isFalse);
      expect(access.isTrainer, isFalse);
      expect(access.trainerId, isNull);
    });

    test('notifies listeners so gated UI re-renders', () {
      final access = AccessProvider.withState();
      var notifications = 0;
      access.addListener(() => notifications++);

      access.applyStatusPayload(const {
        'isTrainerClient': true,
        'trainerId': '11111111-1111-1111-1111-111111111111',
      });

      expect(notifications, greaterThan(0));
    });
  });

  test('withState can stand a trainee up with a coach for widget tests', () {
    final access = AccessProvider.withState(
      isTrainerClient: true,
      trainerId: 'trainer-1',
      trainerName: 'Dana Ruiz',
    );

    expect(access.trainerId, 'trainer-1');
    expect(access.trainerName, 'Dana Ruiz');
  });
}
