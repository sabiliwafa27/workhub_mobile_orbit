import 'dart:convert';
import 'dart:typed_data';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:workhub_mobile/core/network/api_client.dart';
import 'package:workhub_mobile/core/realtime/reverb_service.dart';
import 'package:workhub_mobile/core/storage/secure_storage_service.dart';
import 'package:workhub_mobile/features/auth/providers/auth_provider.dart';
import 'package:workhub_mobile/features/inbox/models/inbox_item_model.dart';
import 'package:workhub_mobile/features/inbox/providers/inbox_provider.dart';
import 'package:workhub_mobile/features/inbox/screens/inbox_screen.dart';

class _Storage extends SecureStorageService {
  @override
  Future<String> getBaseUrl() async => 'https://example.test';
  @override
  Future<String?> getToken() async => null;
}

class _Adapter implements HttpClientAdapter {
  final requests = <RequestOptions>[];
  bool lineAllowed = false;
  @override
  void close({bool force = false}) {}
  @override
  Future<ResponseBody> fetch(RequestOptions options,
      Stream<Uint8List>? requestStream, Future<void>? cancelFuture) async {
    requests.add(options);
    final data = options.path.endsWith('/mention/capabilities')
        ? {'can_complete': lineAllowed}
        : options.method == 'GET'
            ? {
                'data': {
                  'subject': {'can_comment': false},
                  'comments': []
                }
              }
            : {
                'data': {'inbox_status': 'complete'}
              };
    return ResponseBody.fromString(jsonEncode(data), 200, headers: {
      Headers.contentTypeHeader: [Headers.jsonContentType]
    });
  }
}

class _Repository extends InboxRepository {
  final bool allowed;
  _Repository(ApiClient client, this.allowed) : super(client);
  @override
  Future<InboxFetchResult> fetchTodos(
          {String status = 'pending', String search = ''}) async =>
      InboxFetchResult(items: [], canCompleteComment: allowed);
}

void main() {
  final item = InboxItemModel.fromJson({
    'id': 'mention-19',
    'title': 'Mention',
    'kind': 'mention',
    'notification_type': 'comment_mention',
    'comment_module_code': 'wms.logistic-out',
    'comment_subject_type': 'wms.logistic_out_po',
    'comment_subject_key': '19',
  });

  testWidgets('Logistic Out mention action uses its purchase-order identity',
      (tester) async {
    final adapter = _Adapter();
    final api = ApiClient(
        customDio: Dio()..httpClientAdapter = adapter,
        customStorage: _Storage());
    final repository = _Repository(api, true);
    await tester.pumpWidget(ProviderScope(
      overrides: [
        apiClientProvider.overrideWithValue(api),
        inboxNotifierProvider.overrideWith((ref) =>
            InboxNotifier(repository, ReverbRealtimeService(api), null))
      ],
      child: MaterialApp(
          home: Builder(
              builder: (context) => Scaffold(
                      body: TextButton(
                    onPressed: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (_) => InboxItemDetailScreen(item: item))),
                    child: const Text('Open'),
                  )))),
    ));
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Complete mention'));
    await tester.tap(find.text('Complete mention'));
    await tester.pumpAndSettle();
    expect(
        adapter.requests
            .where((request) => request.method == 'POST')
            .single
            .uri
            .path,
        '/api/v1/inbox/logistic-out/19/mention/complete');
  });

  testWidgets('Logistic Out mention action is hidden without permission',
      (tester) async {
    final api = ApiClient(
        customDio: Dio()..httpClientAdapter = _Adapter(),
        customStorage: _Storage());
    final repository = _Repository(api, false);
    await tester.pumpWidget(ProviderScope(
      overrides: [
        apiClientProvider.overrideWithValue(api),
        inboxNotifierProvider.overrideWith((ref) =>
            InboxNotifier(repository, ReverbRealtimeService(api), null))
      ],
      child: MaterialApp(home: InboxItemDetailScreen(item: item)),
    ));
    await tester.pumpAndSettle();
    expect(find.text('Complete mention'), findsNothing);
  });

  testWidgets('Logistic In mention completion checks the exact line capability',
      (tester) async {
    final adapter = _Adapter()..lineAllowed = true;
    final api = ApiClient(
        customDio: Dio()..httpClientAdapter = adapter,
        customStorage: _Storage());
    final repository = _Repository(api, false);
    final line = InboxItemModel.fromJson({
      'id': 'mention-1',
      'title': 'Mention',
      'module_code': 'logistic-in',
      'has_mention_attention': true,
      'comment_module_code': 'wms.logistic-in',
      'comment_subject_type': 'wms.logistic_in_line',
      'comment_subject_key': '23',
    });
    await tester.pumpWidget(ProviderScope(
      overrides: [
        apiClientProvider.overrideWithValue(api),
        inboxNotifierProvider.overrideWith((ref) =>
            InboxNotifier(repository, ReverbRealtimeService(api), null))
      ],
      child: MaterialApp(
          home: Builder(
              builder: (context) => Scaffold(
                      body: TextButton(
                    onPressed: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (_) => InboxItemDetailScreen(item: line))),
                    child: const Text('Open'),
                  )))),
    ));
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    expect(
        adapter.requests.any((request) =>
            request.uri.path ==
            '/api/v1/inbox/logistic-in/23/mention/capabilities'),
        isTrue);
    await tester.ensureVisible(find.text('Complete mention'));
    await tester.tap(find.text('Complete mention'));
    await tester.pumpAndSettle();
    expect(
        adapter.requests
            .where((request) => request.method == 'POST')
            .single
            .uri
            .path,
        '/api/v1/inbox/logistic-in/23/mention/complete');
  });

  testWidgets(
      'Logistic In mention completion is hidden when scoped capability is denied',
      (tester) async {
    final adapter = _Adapter();
    final api = ApiClient(
        customDio: Dio()..httpClientAdapter = adapter,
        customStorage: _Storage());
    final repository = _Repository(api, true);
    final line = InboxItemModel.fromJson({
      'title': 'Mention',
      'has_mention_attention': true,
      'subject_type': 'wms.logistic_in_line',
      'subject_key': '23'
    });
    await tester.pumpWidget(ProviderScope(
      overrides: [
        apiClientProvider.overrideWithValue(api),
        inboxNotifierProvider.overrideWith((ref) =>
            InboxNotifier(repository, ReverbRealtimeService(api), null))
      ],
      child: MaterialApp(home: InboxItemDetailScreen(item: line)),
    ));
    await tester.pumpAndSettle();
    expect(find.text('Complete mention'), findsNothing);
    expect(
        adapter.requests.where((request) => request.method == 'POST'), isEmpty);
  });
}
