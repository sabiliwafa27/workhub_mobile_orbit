import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:workhub_mobile/core/widgets/workhub_navigation_bar.dart';

void main() {
  testWidgets(
      'navigation bar displays floating rounded pill with destinations and reports selection',
      (tester) async {
    int? selected;
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        extendBody: true,
        bottomNavigationBar: WorkHubNavigationBar(
          selectedIndex: 0,
          inboxCount: 4,
          onSelected: (index) => selected = index,
        ),
      ),
    ));

    expect(find.byType(NavigationBar), findsOneWidget);
    expect(find.byType(ClipRRect), findsOneWidget);
    expect(find.byType(BackdropFilter), findsOneWidget);
    expect(find.byType(Scaffold).first, findsOneWidget);
    expect(find.text('Home'), findsOneWidget);
    expect(find.text('Inbox'), findsOneWidget);
    expect(find.text('DM'), findsOneWidget);
    expect(find.text('Projects'), findsOneWidget);
    expect(find.text('4'), findsOneWidget);

    final navBar = tester.widget<NavigationBar>(find.byType(NavigationBar));
    expect(navBar.backgroundColor, Colors.transparent);
    expect(navBar.surfaceTintColor, Colors.transparent);
    expect(navBar.elevation, 0);
    expect(navBar.indicatorShape, const StadiumBorder());

    final clipRRect = tester.widget<ClipRRect>(find.byType(ClipRRect));
    expect(clipRRect.borderRadius, BorderRadius.circular(999));

    final backdropFilter = tester.widget<BackdropFilter>(find.descendant(
      of: find.byType(ClipRRect),
      matching: find.byType(BackdropFilter),
    ));
    expect(backdropFilter.filter, ImageFilter.blur(sigmaX: 16, sigmaY: 16));

    final decoratedBoxes = tester
        .widgetList<DecoratedBox>(find.descendant(
          of: find.byType(WorkHubNavigationBar),
          matching: find.byType(DecoratedBox),
        ))
        .where((box) =>
            box.decoration is BoxDecoration &&
            (box.decoration as BoxDecoration).borderRadius ==
                BorderRadius.circular(999))
        .toList();
    expect(decoratedBoxes, isNotEmpty);
    final pillDecoration = decoratedBoxes.first.decoration as BoxDecoration;
    expect(pillDecoration.color, Colors.white.withValues(alpha: 0.80));
    expect(pillDecoration.boxShadow, isNotNull);
    expect(pillDecoration.boxShadow, isNotEmpty);

    await tester.tap(find.text('DM'));
    expect(selected, 2);
  });
}
