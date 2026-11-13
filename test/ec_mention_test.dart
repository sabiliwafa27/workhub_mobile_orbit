import 'dart:convert';
import 'dart:typed_data';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:workhub_mobile/core/network/api_client.dart';
import 'package:workhub_mobile/core/storage/secure_storage_service.dart';
import 'package:workhub_mobile/features/auth/providers/auth_provider.dart';
import 'package:workhub_mobile/features/tasks/screens/create_work_item_screen.dart';

class _Storage extends SecureStorageService {
  @override
  Future<String> getBaseUrl() async => 'https://example.test';
  @override
  Future<String?> getToken() async => null;
}

class _Adapter implements HttpClientAdapter {
  final requests = <RequestOptions>[];
  bool failCreate = false;
  @override
  void close({bool force = false}) {}
  @override
  Future<ResponseBody> fetch(RequestOptions options, Stream<Uint8List>? requestStream, Future<void>? cancelFuture) async {
    requests.add(options);
    final response = options.method == 'GET'
        ? {'data': options.queryParameters['search'] == 'José' ? [{'employee_id': 5, 'full_name': 'José'}] : [{'employee_id': 2, 'full_name': 'First'}]}
        : {'message': 'Created'};
    return ResponseBody.fromString(jsonEncode(response), options.method == 'GET' ? 200 : failCreate ? 503 : 201,
        headers: {Headers.contentTypeHeader: [Headers.jsonContentType]});
  }
}

void main() {
  testWidgets('uncertain EC batch retries with the original keys', (tester) async {
    await tester.binding.setSurfaceSize(const Size(800, 1600));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final adapter = _Adapter()..failCreate = true;
    final api = ApiClient(customDio: Dio()..httpClientAdapter = adapter, customStorage: _Storage());
    await tester.pumpWidget(ProviderScope(
      overrides: [apiClientProvider.overrideWithValue(api), ecCreationPolicyProvider.overrideWith((ref) async => const EcCreationPolicy(canEdit: true))],
      child: const MaterialApp(home: CreateWorkItemScreen(isEc: true)),
    ));
    await tester.pumpAndSettle();
    await tester.enterText(find.widgetWithText(TextField, 'Your idea'), 'First idea');
    tester.testTextInput.hide();
    await tester.pumpAndSettle();
    await tester.tap(find.text('Add idea'));
    await tester.pumpAndSettle();
    await tester.enterText(find.widgetWithText(TextField, 'Idea'), 'Second idea');
    tester.testTextInput.hide();
    await tester.pumpAndSettle();
    await tester.tap(find.text('Create'));
    await tester.pumpAndSettle();
    expect(tester.widget<IconButton>(find.ancestor(of: find.byIcon(Icons.close), matching: find.byType(IconButton)).first).onPressed, isNull);
    await tester.tap(find.text('Create'));
    await tester.pumpAndSettle();
    final posts = adapter.requests.where((request) => request.method == 'POST').toList();
    expect(posts.length, 2);
    Map body(RequestOptions request) => request.data is String ? jsonDecode(request.data as String) as Map : request.data as Map;
    expect(body(posts[0])['ideas'], body(posts[1])['ideas']);
  });

  testWidgets('uncertain EC creation cannot retry with changed ideas', (tester) async {
    final adapter = _Adapter()..failCreate = true;
    final api = ApiClient(customDio: Dio()..httpClientAdapter = adapter, customStorage: _Storage());
    await tester.pumpWidget(ProviderScope(
      overrides: [apiClientProvider.overrideWithValue(api), ecCreationPolicyProvider.overrideWith((ref) async => const EcCreationPolicy(canEdit: true))],
      child: const MaterialApp(home: CreateWorkItemScreen(isEc: true)),
    ));
    await tester.pumpAndSettle();
    final idea = find.widgetWithText(TextField, 'Your idea');
    await tester.enterText(idea, 'First idea');
    tester.testTextInput.hide();
    await tester.pumpAndSettle();
    await tester.tap(find.text('Create'));
    await tester.pumpAndSettle();
    await tester.enterText(idea, 'Changed idea');
    tester.testTextInput.hide();
    await tester.pumpAndSettle();
    await tester.tap(find.text('Create'));
    await tester.pumpAndSettle();
    expect(adapter.requests.where((request) => request.method == 'POST').length, 1);
    expect(find.text('The previous submission could not be confirmed. Restore the same ideas to retry, or check today’s EC before starting again.'), findsOneWidget);
  });

  testWidgets('typing @ searches colleagues inline and replaces the query', (tester) async {
    final adapter = _Adapter();
    final api = ApiClient(customDio: Dio()..httpClientAdapter = adapter, customStorage: _Storage());
    await tester.pumpWidget(ProviderScope(
      overrides: [apiClientProvider.overrideWithValue(api), ecCreationPolicyProvider.overrideWith((ref) async => const EcCreationPolicy(canEdit: true))],
      child: const MaterialApp(home: CreateWorkItemScreen(isEc: true)),
    ));
    await tester.pumpAndSettle();
    final idea = find.widgetWithText(TextField, 'Your idea');
    await tester.enterText(idea, 'Hello ');
    await tester.enterText(idea, 'Hello @José');
    await tester.pump(const Duration(milliseconds: 250));
    await tester.pumpAndSettle();
    expect(find.widgetWithText(ListTile, 'José'), findsOneWidget);
    await tester.tap(find.widgetWithText(ListTile, 'José'));
    await tester.pumpAndSettle();
    expect(tester.widget<TextField>(idea).controller!.text, 'Hello @José ');
  });

  testWidgets('EC mentions search and shift using Unicode character positions', (tester) async {
    final adapter = _Adapter();
    final api = ApiClient(customDio: Dio()..httpClientAdapter = adapter, customStorage: _Storage());
    await tester.pumpWidget(ProviderScope(
      overrides: [apiClientProvider.overrideWithValue(api), ecCreationPolicyProvider.overrideWith((ref) async => const EcCreationPolicy(canEdit: true))],
      child: MaterialApp(home: Builder(builder: (context) => Scaffold(body: TextButton(
        onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const CreateWorkItemScreen(isEc: true))),
        child: const Text('Open form'),
      )))),
    ));
    await tester.tap(find.text('Open form'));
    await tester.pumpAndSettle();
    await tester.enterText(find.widgetWithText(TextField, 'Your idea'), 'Hi 😀 ');
    tester.testTextInput.hide();
    await tester.pumpAndSettle();
    await tester.tap(find.text('Mention colleague'));
    await tester.pumpAndSettle();
    await tester.enterText(find.widgetWithText(TextField, 'Search colleagues'), 'José');
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pumpAndSettle();
    expect(find.widgetWithText(ListTile, 'José'), findsOneWidget);
    await tester.tap(find.widgetWithText(ListTile, 'José'));
    await tester.pumpAndSettle();
    await tester.enterText(find.widgetWithText(TextField, 'Your idea'), 'Start Hi 😀 @José ');
    tester.testTextInput.hide();
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Create'));
    await tester.tap(find.text('Create'));
    await tester.pumpAndSettle();

    final request = adapter.requests.last;
    expect(request.uri.path, '/workhub/api/v1/ec/entries');
    final data = request.data is String ? jsonDecode(request.data as String) as Map : request.data as Map;
    final mention = (data['mentions'] as List).single as Map;
    expect(mention['employee_id'], 5);
    expect(mention['label'], '@José');
    expect(mention['start'], 'Start Hi 😀 '.runes.length);
    expect(mention['length'], '@José'.runes.length);
  });
}
