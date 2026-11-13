import 'dart:convert';
import 'dart:typed_data';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:workhub_mobile/core/network/api_client.dart';
import 'package:workhub_mobile/core/storage/secure_storage_service.dart';
import 'package:workhub_mobile/features/auth/providers/auth_provider.dart';
import 'package:workhub_mobile/features/inbox/screens/discussion_panel.dart';

class _Storage extends SecureStorageService {
  @override
  Future<String> getBaseUrl() async => 'https://example.test';
  @override
  Future<String?> getToken() async => null;
}

class _Adapter implements HttpClientAdapter {
  final requests = <RequestOptions>[];
  bool canComment = false;
  bool failLoad = false;
  int postStatus = 503;
  bool repeatCursor = false;
  @override
  void close({bool force = false}) {}
  @override
  Future<ResponseBody> fetch(RequestOptions options, Stream<Uint8List>? requestStream, Future<void>? cancelFuture) async {
    requests.add(options);
    final older = options.queryParameters['before_id'] == 100;
    final body = {'data': {
      'subject': {'can_comment': canComment},
      'comments': [{'comment_id': older && !repeatCursor ? 90 : 100, 'body': older && !repeatCursor ? 'Older note' : 'Recent note', 'author': {'name': 'Alex'}}],
      'pagination': {'first_id': older && !repeatCursor ? 90 : 100, 'has_older': repeatCursor || !older},
    }};
    return ResponseBody.fromString(jsonEncode(body), options.method == 'POST' ? postStatus : failLoad ? 503 : 200, headers: {Headers.contentTypeHeader: [Headers.jsonContentType]});
  }
}

void main() {
  testWidgets('discussion stops when an older page does not advance the cursor', (tester) async {
    final adapter = _Adapter()..repeatCursor = true;
    final api = ApiClient(customDio: Dio()..httpClientAdapter = adapter, customStorage: _Storage());
    await tester.pumpWidget(ProviderScope(overrides: [apiClientProvider.overrideWithValue(api)],
      child: const MaterialApp(home: Scaffold(body: SingleChildScrollView(child: InboxDiscussion(module: 'task', subjectKey: '12'))))));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Load older comments'));
    await tester.pumpAndSettle();
    expect(find.text('Recent note'), findsOneWidget);
    expect(find.text('Load older comments'), findsNothing);
  });

  testWidgets('a rejected comment shows an actionable error', (tester) async {
    final adapter = _Adapter()..canComment = true..postStatus = 403;
    final api = ApiClient(customDio: Dio()..httpClientAdapter = adapter, customStorage: _Storage());
    await tester.pumpWidget(ProviderScope(overrides: [apiClientProvider.overrideWithValue(api)],
      child: const MaterialApp(home: Scaffold(body: SingleChildScrollView(child: InboxDiscussion(module: 'task', subjectKey: '12'))))));
    await tester.pumpAndSettle();
    await tester.enterText(find.widgetWithText(TextField, 'Add a comment'), 'Hello');
    tester.testTextInput.hide();
    await tester.pumpAndSettle();
    await tester.tap(find.text('Send'));
    await tester.pumpAndSettle();
    expect(find.text('You do not have permission to add this comment.'), findsOneWidget);
    expect(find.text('Refresh discussion'), findsNothing);
  });

  testWidgets('failed discussion refresh keeps uncertain comment locked', (tester) async {
    final adapter = _Adapter()..canComment = true;
    final api = ApiClient(customDio: Dio()..httpClientAdapter = adapter, customStorage: _Storage());
    await tester.pumpWidget(ProviderScope(overrides: [apiClientProvider.overrideWithValue(api)],
      child: const MaterialApp(home: Scaffold(body: SingleChildScrollView(child: InboxDiscussion(module: 'task', subjectKey: '12'))))));
    await tester.pumpAndSettle();
    await tester.enterText(find.widgetWithText(TextField, 'Add a comment'), 'Hello');
    tester.testTextInput.hide();
    await tester.pumpAndSettle();
    await tester.tap(find.text('Send'));
    await tester.pumpAndSettle();
    adapter.failLoad = true;
    await tester.tap(find.text('Refresh discussion'));
    await tester.pumpAndSettle();
    expect(find.text('Unable to load discussion. Tap to retry.'), findsOneWidget);
    adapter.failLoad = false;
    await tester.tap(find.text('Unable to load discussion. Tap to retry.'));
    await tester.pumpAndSettle();
    expect(tester.widget<FilledButton>(find.widgetWithText(FilledButton, 'Send')).onPressed, isNotNull);
    expect(adapter.requests.where((request) => request.method == 'POST').length, 1);
  });

  testWidgets('task discussion uses WorkHub and loads older comments with a cursor', (tester) async {
    final adapter = _Adapter();
    final api = ApiClient(customDio: Dio()..httpClientAdapter = adapter, customStorage: _Storage());
    await tester.pumpWidget(ProviderScope(
      overrides: [apiClientProvider.overrideWithValue(api)],
      child: const MaterialApp(home: Scaffold(body: SingleChildScrollView(child: InboxDiscussion(module: 'task', subjectKey: '12')))),
    ));
    await tester.pumpAndSettle();
    expect(find.text('Recent note'), findsOneWidget);
    expect(find.text('Add a comment'), findsNothing);
    expect(find.text('You can view this discussion but cannot add comments.'), findsOneWidget);
    expect(adapter.requests.first.uri.path, '/workhub/api/v1/collaboration/task/12/comments');
    await tester.tap(find.text('Load older comments'));
    await tester.pumpAndSettle();
    expect(find.text('Older note'), findsOneWidget);
    expect(find.text('Recent note'), findsOneWidget);
    expect(adapter.requests.last.queryParameters['before_id'], 100);
    expect(find.text('Load older comments'), findsNothing);
  });
}
