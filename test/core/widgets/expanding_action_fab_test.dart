import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:workhub_mobile/core/widgets/expanding_action_fab.dart';

void main() {
  testWidgets('expanding actions reveal and collapse', (tester) async {
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(
            floatingActionButton: ExpandingActionFab(actions: [
      ExpandingFabAction(
          label: 'Create task', icon: Icons.check, onPressed: () {}),
      ExpandingFabAction(
          label: 'Create EC', icon: Icons.description, onPressed: () {}),
      ExpandingFabAction(
          label: 'New chat / DM', icon: Icons.chat, onPressed: () {}),
    ]))));
    final fadeFinder = find.byKey(const ValueKey('expanding-action-fab-fade'));
    expect(
        tester
            .widget<FadeTransition>(fadeFinder)
            .opacity
            .value,
        0);
    await tester.tap(find.byType(FloatingActionButton));
    await tester.pumpAndSettle();
    expect(find.text('Create task'), findsOneWidget);
    expect(find.text('Create EC'), findsOneWidget);
    expect(find.text('New chat / DM'), findsOneWidget);
    await tester.tap(find.byType(FloatingActionButton));
    await tester.pumpAndSettle();
    expect(
        tester
            .widget<FadeTransition>(fadeFinder)
            .opacity
            .value,
        0);
  });
}
