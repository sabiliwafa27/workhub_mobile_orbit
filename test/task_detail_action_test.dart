import 'dart:convert';
import 'dart:typed_data';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:workhub_mobile/core/network/api_client.dart';
import 'package:workhub_mobile/core/storage/secure_storage_service.dart';
import 'package:workhub_mobile/features/auth/providers/auth_provider.dart';
import 'package:workhub_mobile/features/tasks/screens/task_detail_screen.dart';

class _Storage extends SecureStorageService {
  @override
  Future<String> getBaseUrl() async => 'https://example.test';
  @override
  Future<String?> getToken() async => null;
}

class _Adapter implements HttpClientAdapter {
  final requests = <RequestOptions>[];
  bool pendingReview = false;
  @override
  void close({bool force = false}) {}
  @override
  Future<ResponseBody> fetch(RequestOptions options, Stream<Uint8List>? requestStream, Future<void>? cancelFuture) async {
    requests.add(options);
    final isAction = options.method == 'POST';
    final body = isAction ? {'message': 'Unavailable'} : options.path.endsWith('/payload')
        ? {'task': {'title': 'Assigned task', 'row_action': pendingReview ? null : 'request_review', 'assignees': pendingReview ? [
            {'review_requested_at': '2026-01-01', 'unassigned_at': null, 'employee': {'full_name': 'Current assignee'}},
            {'unassigned_at': '2026-01-01', 'employee': {'full_name': 'Former assignee'}},
          ] : []}}
        : {'data': {'subject': {'can_comment': false}, 'comments': [], 'pagination': {'has_older': false}}};
    return ResponseBody.fromString(jsonEncode(body), isAction ? 503 : 200, headers: {Headers.contentTypeHeader: [Headers.jsonContentType]});
  }
}

void main() {
  testWidgets('task detail fits a phone viewport', (tester) async {
    await tester.binding.setSurfaceSize(const Size(360, 640));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final api = ApiClient(customDio: Dio()..httpClientAdapter = (_Adapter()..pendingReview = true), customStorage: _Storage());
    await tester.pumpWidget(ProviderScope(overrides: [apiClientProvider.overrideWithValue(api)], child: const MaterialApp(home: TaskDetailScreen(taskId: 1))));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.text('Discussion'), 200, scrollable: find.byType(Scrollable).first);
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  testWidgets('task detail shows an active pending review', (tester) async {
    final adapter = _Adapter()..pendingReview = true;
    final api = ApiClient(customDio: Dio()..httpClientAdapter = adapter, customStorage: _Storage());
    await tester.pumpWidget(ProviderScope(overrides: [apiClientProvider.overrideWithValue(api)], child: const MaterialApp(home: TaskDetailScreen(taskId: 1))));
    await tester.pumpAndSettle();
    expect(find.text('Pending review'), findsOneWidget);
    expect(find.text('Current assignee'), findsOneWidget);
    expect(find.text('Former assignee'), findsNothing);
    expect(find.text('Request review'), findsNothing);
  });

  testWidgets('an uncertain task action requires a refresh before retrying', (tester) async {
    final adapter = _Adapter();
    final api = ApiClient(customDio: Dio()..httpClientAdapter = adapter, customStorage: _Storage());
    await tester.pumpWidget(ProviderScope(
      overrides: [apiClientProvider.overrideWithValue(api)],
      child: const MaterialApp(home: TaskDetailScreen(taskId: 1)),
    ));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Request review'));
    await tester.pumpAndSettle();
    expect(find.text('The task update could not be confirmed. Refresh before retrying.'), findsOneWidget);
    expect(adapter.requests.where((request) => request.method == 'POST').length, 1);
    await tester.tap(find.text('Refresh task'));
    await tester.pumpAndSettle();
    expect(find.text('Request review'), findsOneWidget);
    expect(adapter.requests.where((request) => request.method == 'POST').length, 1);
  });
}
