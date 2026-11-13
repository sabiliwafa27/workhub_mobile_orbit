import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:workhub_mobile/core/widgets/workhub_navigation_bar.dart';

void main() {
  testWidgets('navigation bar displays destinations and reports selection',
      (tester) async {
    int? selected;
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        bottomNavigationBar: WorkHubNavigationBar(
          selectedIndex: 0,
          inboxCount: 4,
          onSelected: (index) => selected = index,
        ),
      ),
    ));

    expect(find.byType(NavigationBar), findsOneWidget);
    expect(find.text('Home'), findsOneWidget);
    expect(find.text('Inbox'), findsOneWidget);
    expect(find.text('Chat'), findsOneWidget);
    expect(find.text('Projects'), findsOneWidget);
    expect(find.text('4'), findsOneWidget);

    await tester.tap(find.text('Chat'));
    expect(selected, 2);
  });
}
