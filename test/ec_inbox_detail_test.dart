import 'dart:convert';
import 'dart:typed_data';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:workhub_mobile/core/network/api_client.dart';
import 'package:workhub_mobile/core/storage/secure_storage_service.dart';
import 'package:workhub_mobile/features/auth/providers/auth_provider.dart';
import 'package:workhub_mobile/features/inbox/screens/ec_inbox_detail_screen.dart';
import 'package:workhub_mobile/features/tasks/providers/ec_progress_provider.dart';

class _Storage extends SecureStorageService {
  @override
  Future<String> getBaseUrl() async => 'https://example.test';
  @override
  Future<String?> getToken() async => null;
}

class _Adapter implements HttpClientAdapter {
  final paths = <String>[];
  final requests = <RequestOptions>[];
  bool failProgress = false;
  bool failDetail = false;
  @override
  void close({bool force = false}) {}
  @override
  Future<ResponseBody> fetch(RequestOptions options,
      Stream<Uint8List>? requestStream, Future<void>? cancelFuture) async {
    paths.add(options.path);
    requests.add(options);
    final body = options.path.endsWith('/comments')
        ? {
            'data': {
              'comments': [],
              'subject': {'can_comment': false},
              'pagination': {'has_older': false}
            }
          }
        : {
            'title': 'Improve process',
            'progress_history': [],
            'current_progress': {'percentage': 50},
            'can_update_progress': true
          };
    return ResponseBody.fromString(
        jsonEncode(body),
        (failProgress && options.method == 'POST') ||
                (failDetail && options.path.endsWith('/detail'))
            ? 503
            : 200,
        headers: {
          Headers.contentTypeHeader: [Headers.jsonContentType]
        });
  }
}

void main() {
  testWidgets('EC detail fits a phone viewport', (tester) async {
    await tester.binding.setSurfaceSize(const Size(360, 640));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final api = ApiClient(
        customDio: Dio()..httpClientAdapter = _Adapter(),
        customStorage: _Storage());
    await tester.pumpWidget(ProviderScope(
        overrides: [apiClientProvider.overrideWithValue(api)],
        child: const MaterialApp(home: EcInboxDetailScreen(entryId: '42'))));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.text('Discussion'), 200,
        scrollable: find.byType(Scrollable).first);
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  testWidgets('EC detail includes its scoped discussion', (tester) async {
    final adapter = _Adapter();
    final api = ApiClient(
        customDio: Dio()..httpClientAdapter = adapter,
        customStorage: _Storage());
    await tester.pumpWidget(ProviderScope(
        overrides: [apiClientProvider.overrideWithValue(api)],
        child: const MaterialApp(home: EcInboxDetailScreen(entryId: '42'))));
    await tester.pumpAndSettle();
    expect(find.text('Improve process'), findsOneWidget);
    expect(find.text('Discussion'), findsOneWidget);
    expect(
        tester
            .widget<TextField>(find.widgetWithText(TextField, 'Progress (%)'))
            .controller!
            .text,
        '50');
    expect(
        adapter.paths, contains('/api/v1/inbox/workhub-tasks/ec/42/comments'));
  });

  testWidgets('saving EC detail refreshes dashboard progress', (tester) async {
    var loads = 0;
    final api = ApiClient(
        customDio: Dio()..httpClientAdapter = _Adapter(),
        customStorage: _Storage());
    final container = ProviderContainer(overrides: [
      apiClientProvider.overrideWithValue(api),
      ecProgressProvider.overrideWith((ref, page) async {
        loads++;
        return {'data': []};
      })
    ]);
    addTearDown(container.dispose);
    final subscription = container.listen(ecProgressProvider(1), (_, __) {});
    addTearDown(subscription.close);
    await container.read(ecProgressProvider(1).future);
    await tester.pumpWidget(UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: EcInboxDetailScreen(entryId: '42'))));
    await tester.pumpAndSettle();
    await tester.enterText(
        find.widgetWithText(TextField, 'Progress note'), 'Updated');
    tester.testTextInput.hide();
    await tester.pumpAndSettle();
    await tester
        .ensureVisible(find.widgetWithText(FilledButton, 'Update progress'));
    await tester.tap(find.widgetWithText(FilledButton, 'Update progress'));
    await tester.pumpAndSettle();
    expect(loads, greaterThan(1));
  });

  testWidgets(
      'uncertain EC progress retries with the same key and blocks changed input',
      (tester) async {
    final adapter = _Adapter()..failProgress = true;
    final api = ApiClient(
        customDio: Dio()..httpClientAdapter = adapter,
        customStorage: _Storage());
    await tester.pumpWidget(ProviderScope(
        overrides: [apiClientProvider.overrideWithValue(api)],
        child: const MaterialApp(home: EcInboxDetailScreen(entryId: '42'))));
    await tester.pumpAndSettle();
    final note = find.widgetWithText(TextField, 'Progress note');
    final button = find.widgetWithText(FilledButton, 'Update progress');
    await tester.enterText(note, 'Updated');
    tester.testTextInput.hide();
    await tester.pumpAndSettle();
    await tester.ensureVisible(button);
    await tester.tap(button);
    await tester.pumpAndSettle();
    await tester.tap(button);
    await tester.pumpAndSettle();
    final posts =
        adapter.requests.where((request) => request.method == 'POST').toList();
    Map body(RequestOptions request) => request.data is String
        ? jsonDecode(request.data as String) as Map
        : request.data as Map;
    expect(posts.length, 2);
    expect(body(posts[0])['submission_key'], body(posts[1])['submission_key']);
    await tester.enterText(note, 'Changed');
    tester.testTextInput.hide();
    await tester.pumpAndSettle();
    await tester.tap(button);
    await tester.pumpAndSettle();
    expect(adapter.requests.where((request) => request.method == 'POST').length,
        2);
    adapter.failDetail = true;
    await tester.tap(find.byTooltip('Refresh EC'));
    await tester.pumpAndSettle();
    expect(find.text('Unable to load EC. Tap to retry.'), findsOneWidget);
    adapter.failDetail = false;
    await tester.tap(find.text('Unable to load EC. Tap to retry.'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(button);
    await tester.tap(button);
    await tester.pumpAndSettle();
    expect(adapter.requests.where((request) => request.method == 'POST').length,
        2);
    await tester.tap(find.byTooltip('Refresh EC'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(button);
    await tester.tap(button);
    await tester.pumpAndSettle();
    expect(adapter.requests.where((request) => request.method == 'POST').length,
        3);
  });
}
