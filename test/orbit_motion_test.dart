import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:workhub_mobile/core/theme/orbit_motion.dart';
import 'package:workhub_mobile/core/theme/orbit_theme.dart';

void main() {
  Widget host({bool reduced = false, bool active = true}) => MaterialApp(
        theme: OrbitTheme.lightTheme,
        home: MediaQuery(
          data: MediaQueryData(disableAnimations: reduced),
          child: OrbitEntrance(active: active, child: const Text('Content')),
        ),
      );

  testWidgets('entrance settles and does not restart on rebuild',
      (tester) async {
    await tester.pumpWidget(host());
    await tester.pumpAndSettle();
    final fade = find.descendant(
        of: find.byType(OrbitEntrance), matching: find.byType(FadeTransition));
    expect(tester.widget<FadeTransition>(fade).opacity.value, 1);
    await tester.pumpWidget(host());
    expect(tester.widget<FadeTransition>(fade).opacity.value, 1);
  });

  testWidgets('reduced motion shows content immediately', (tester) async {
    await tester.pumpWidget(host(reduced: true));
    expect(find.text('Content'), findsOneWidget);
    expect(
        find.descendant(
            of: find.byType(OrbitEntrance),
            matching: find.byType(SlideTransition)),
        findsNothing);
    await tester.pumpAndSettle();
    expect(tester.binding.transientCallbackCount, 0);
  });

  testWidgets('activating a retained tab replays its entrance', (tester) async {
    await tester.pumpWidget(host(active: false));
    await tester.pumpWidget(host(active: true));
    await tester.pump(const Duration(milliseconds: 160));
    final fade = find.descendant(
        of: find.byType(OrbitEntrance), matching: find.byType(FadeTransition));
    final value = tester.widget<FadeTransition>(fade).opacity.value;
    expect(value, greaterThan(0));
    expect(value, lessThan(1));
    await tester.pumpAndSettle();
    expect(tester.widget<FadeTransition>(fade).opacity.value, 1);
  });

  test('text and primary controls retain accessible contrast', () {
    double contrast(Color a, Color b) {
      final x = a.computeLuminance(), y = b.computeLuminance();
      return ((x > y ? x : y) + .05) / ((x < y ? x : y) + .05);
    }

    for (final foreground in [
      OrbitColors.textPrimary,
      OrbitColors.textSecondary,
    ]) {
      expect(contrast(foreground, OrbitColors.cardSurface),
          greaterThanOrEqualTo(4.5));
    }
    expect(contrast(Colors.white, OrbitColors.primaryNavy),
        greaterThanOrEqualTo(4.5));
  });
}
