import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:ForgeForm/core/nutrition/extended_nutrients.dart';
import 'package:ForgeForm/core/providers/access_provider.dart';
import 'package:ForgeForm/core/widgets/tracked_nutrients_card.dart';
import 'package:ForgeForm/l10n/app_localizations.dart';

/// The trainee food-tracking screen's `_buildTrackedNutrients` decides, from
/// [AccessProvider] alone, whether the caller can pick their own tracked
/// nutrients: `canSelfPick = hasPremiumAccess && !isTrainerClient`, passed as
/// [TrackedNutrientsCard.onTogglePin] only when true. A linked client's pins
/// stay their trainer's to set — enforced server-side too, by
/// `SetMyNutrientPinsAsync`'s `HasActiveTrainer` refusal (see
/// `docs/revenuecat-self-managed-pins.md`) — so this is UX, not the boundary,
/// but the picker must still only ever appear where it's actually usable.
///
/// This exercises the exact widget the screen renders, driven by the exact
/// expression the screen uses to gate it — not the whole `FoodTrackingScreen`,
/// which pulls in the local database and a live API client neither of which
/// this gating decision depends on.
Widget _trackedNutrientsCard(AccessProvider access) {
  final canSelfPick = access.hasPremiumAccess && !access.isTrainerClient;
  return TrackedNutrientsCard(
    locked: !access.hasPremiumAccess,
    pinnedKeys: const [],
    nutrients: ExtendedNutrients.empty,
    dayScope: true,
    subtitle: 'What you\'re tracking',
    onTogglePin: canSelfPick ? (_) {} : null,
  );
}

Future<void> _pump(WidgetTester tester, AccessProvider access) async {
  await tester.pumpWidget(
    ChangeNotifierProvider<AccessProvider>.value(
      value: access,
      child: MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(body: Builder(builder: (context) => _trackedNutrientsCard(access))),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets(
    'a premium user with no trainer can pick their own tracked nutrients',
    (tester) async {
      await _pump(
        tester,
        AccessProvider.withState(isPremium: true, isTrainerClient: false),
      );

      final card = tester.widget<TrackedNutrientsCard>(
        find.byType(TrackedNutrientsCard),
      );
      expect(card.onTogglePin, isNotNull);
      expect(card.locked, isFalse);
    },
  );

  testWidgets(
    "a premium user's linked-client card stays read-only",
    (tester) async {
      await _pump(
        tester,
        AccessProvider.withState(isPremium: true, isTrainerClient: true),
      );

      final card = tester.widget<TrackedNutrientsCard>(
        find.byType(TrackedNutrientsCard),
      );
      expect(card.onTogglePin, isNull);
      expect(card.locked, isFalse);
    },
  );

  testWidgets('a non-premium user sees the locked card, not a picker', (
    tester,
  ) async {
    await _pump(
      tester,
      AccessProvider.withState(isPremium: false, isTrainerClient: false),
    );

    final card = tester.widget<TrackedNutrientsCard>(
      find.byType(TrackedNutrientsCard),
    );
    expect(card.onTogglePin, isNull);
    expect(card.locked, isTrue);
  });
}
