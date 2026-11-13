import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:workhub_mobile/features/tasks/screens/create_work_item_screen.dart';

void main() {
  testWidgets('EC form fits a phone viewport', (tester) async {
    await tester.binding.setSurfaceSize(const Size(360, 640));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(ProviderScope(overrides: [
      ecCreationPolicyProvider
          .overrideWith((ref) async => const EcCreationPolicy(canEdit: true))
    ], child: const MaterialApp(home: CreateWorkItemScreen(isEc: true))));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Add idea'));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.text('Create'), 200,
        scrollable: find.byType(Scrollable).first);
    expect(tester.takeException(), isNull);
  });

  testWidgets('EC creation explains denied access', (tester) async {
    final request = RequestOptions(path: '/ec/today/current');
    await tester.pumpWidget(ProviderScope(overrides: [
      ecCreationPolicyProvider.overrideWith((ref) async {
        throw DioException(
            requestOptions: request,
            response: Response(requestOptions: request, statusCode: 403));
      })
    ], child: const MaterialApp(home: CreateWorkItemScreen(isEc: true))));
    await tester.pumpAndSettle();
    expect(find.text('EC creation is unavailable for your account.'),
        findsOneWidget);
    expect(
        tester
            .widget<TextField>(find.widgetWithText(TextField, 'Your idea'))
            .enabled,
        isFalse);
    expect(find.text('Create'), findsNothing);
  });

  testWidgets(
      'EC creation is unavailable when the server edit window is closed',
      (tester) async {
    await tester.pumpWidget(ProviderScope(overrides: [
      ecCreationPolicyProvider
          .overrideWith((ref) async => const EcCreationPolicy(canEdit: false))
    ], child: const MaterialApp(home: CreateWorkItemScreen(isEc: true))));
    await tester.pumpAndSettle();
    expect(find.text('EC creation is closed for today.'), findsOneWidget);
    expect(
        tester
            .widget<TextField>(find.widgetWithText(TextField, 'Your idea'))
            .enabled,
        isFalse);
    expect(find.text('Create'), findsNothing);
  });

  testWidgets('an off day hides EC submission', (tester) async {
    await tester.pumpWidget(ProviderScope(
      overrides: [
        ecCreationPolicyProvider.overrideWith((ref) async =>
            const EcCreationPolicy(
                canEdit: true, offDayAvailable: true, isOffDay: true))
      ],
      child: const MaterialApp(home: CreateWorkItemScreen(isEc: true)),
    ));
    await tester.pumpAndSettle();
    expect(find.text('Off day'), findsOneWidget);
    expect(find.text('Today is marked as an off day.'), findsOneWidget);
    expect(
        tester
            .widget<TextField>(find.widgetWithText(TextField, 'Your idea'))
            .enabled,
        isFalse);
    expect(find.text('Create'), findsNothing);
  });

  testWidgets('EC draft ideas can be added and removed before saving',
      (tester) async {
    await tester.pumpWidget(ProviderScope(overrides: [
      ecCreationPolicyProvider
          .overrideWith((ref) async => const EcCreationPolicy(canEdit: true))
    ], child: const MaterialApp(home: CreateWorkItemScreen(isEc: true))));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Add idea'));
    await tester.pump();
    expect(find.widgetWithText(TextField, 'Idea'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.close));
    await tester.pump();
    expect(find.widgetWithText(TextField, 'Idea'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('EC creation requires a title for every draft', (tester) async {
    await tester.pumpWidget(ProviderScope(overrides: [
      ecCreationPolicyProvider
          .overrideWith((ref) async => const EcCreationPolicy(canEdit: true))
    ], child: const MaterialApp(home: CreateWorkItemScreen(isEc: true))));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Add idea'));
    await tester.pump();
    await tester.enterText(
        find.widgetWithText(TextField, 'Your idea'), 'First idea');
    await tester.ensureVisible(find.text('Create'));
    await tester.tap(find.text('Create'));
    await tester.pump();
    expect(find.text('Enter a title for each idea.'), findsOneWidget);
  });
}
