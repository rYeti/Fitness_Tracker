import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:ForgeForm/core/forge_motion.dart';

/// Reduced motion went unhonoured at nine of ten animation sites, and nothing
/// noticed — there is no compiler error and no rendering difference unless the
/// setting is actually on. These tests pin the helper's behaviour so the
/// default path stays the respectful one.
void main() {
  Future<T> readUnder<T>(
    WidgetTester tester,
    bool disableAnimations,
    T Function(BuildContext) read,
  ) async {
    late T value;
    await tester.pumpWidget(
      MediaQuery(
        data: MediaQueryData(disableAnimations: disableAnimations),
        child: Builder(
          builder: (context) {
            value = read(context);
            return const SizedBox();
          },
        ),
      ),
    );
    return value;
  }

  group('ForgeMotion.of', () {
    testWidgets('passes the duration through by default', (tester) async {
      final d = await readUnder(tester, false, (c) => ForgeMotion.of(c));
      expect(d, ForgeMotion.standard);
    });

    testWidgets('collapses to zero when the viewer asks for reduced motion', (
      tester,
    ) async {
      final d = await readUnder(tester, true, (c) => ForgeMotion.of(c));
      // Zero, not "skip the animation": the state change still has to happen,
      // it just arrives instantly. CLAUDE.md is explicit that falling back
      // must not drop the transition itself.
      expect(d, Duration.zero);
    });

    testWidgets('respects an explicit duration', (tester) async {
      final d = await readUnder(
        tester,
        false,
        (c) => ForgeMotion.of(c, ForgeMotion.quick),
      );
      expect(d, ForgeMotion.quick);
    });
  });

  group('ForgeMotion.isReduced', () {
    testWidgets('reports the setting for cases a duration cannot express', (
      tester,
    ) async {
      // A looping decorative animation has no instant version, so callers
      // have to stop driving it — the barcode scanner's scan line is the one
      // in this codebase.
      expect(await readUnder(tester, true, ForgeMotion.isReduced), isTrue);
      expect(await readUnder(tester, false, ForgeMotion.isReduced), isFalse);
    });
  });

  group('durations stay inside the CLAUDE.md ceiling', () {
    test('no UI chrome duration exceeds 300ms', () {
      for (final d in [
        ForgeMotion.quick,
        ForgeMotion.standard,
        ForgeMotion.emphasis,
      ]) {
        expect(
          d.inMilliseconds,
          lessThanOrEqualTo(300),
          reason: 'CLAUDE.md: 150-250ms for state changes, nothing over 300ms '
              'for UI chrome',
        );
      }
    });
  });
}
