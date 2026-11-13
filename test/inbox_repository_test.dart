import 'dart:convert';
import 'dart:typed_data';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:workhub_mobile/core/network/api_client.dart';
import 'package:workhub_mobile/core/storage/secure_storage_service.dart';
import 'package:workhub_mobile/features/inbox/providers/inbox_provider.dart';

class _Storage extends SecureStorageService {
  @override
  Future<String> getBaseUrl() async => 'https://example.test';
  @override
  Future<String?> getToken() async => null;
}

class _Adapter implements HttpClientAdapter {
  RequestOptions? request;
  final paths = <String>[];
  bool includeTasks = true;
  @override
  void close({bool force = false}) {}
  @override
  Future<ResponseBody> fetch(RequestOptions options, Stream<Uint8List>? requestStream, Future<void>? cancelFuture) async {
    request = options;
    paths.add(options.path);
    final pending = [{'id': 'mine:1', 'module_code': 'task-mine', 'title': 'My task', 'unread_count': 1}];
    final complete = [{'id': 'assigned:2', 'module_code': 'task-assigned', 'title': 'Assigned task', 'unread_count': 0}];
    final payload = {if (includeTasks) 'tasks': options.queryParameters['view'] == 'complete' ? complete : pending,
      'incomplete': pending, 'complete': complete, 'incomplete_count': 1, 'complete_count': 1};
    return ResponseBody.fromString(jsonEncode(payload), 200, headers: {Headers.contentTypeHeader: [Headers.jsonContentType]});
  }
}

void main() {
  test('Inbox status and unread counts use both server buckets', () async {
    final adapter = _Adapter();
    final repository = InboxRepository(ApiClient(customDio: Dio()..httpClientAdapter = adapter, customStorage: _Storage()));
    final result = await repository.fetchTodos(status: 'complete', search: 'report');
    expect(result.items.single.title, 'Assigned task');
    expect(result.incompleteUnreadCount, 1);
    expect(result.completeUnreadCount, 0);
    expect(result.sources['task-mine'], 'Assigned to Me');
    expect(result.sources['task-assigned'], 'Assigned by Me');
    expect(result.sourceCounts['task-mine'], [1, 0, 1, 0]);
    expect(result.sourceCounts['task-assigned'], [0, 1, 0, 0]);
    expect(adapter.request!.uri.path, '/api/v1/inbox/todos');
    expect(adapter.request!.queryParameters['search'], 'report');
  });

  test('complete view selects the complete bucket when tasks is absent', () async {
    final adapter = _Adapter()..includeTasks = false;
    final repository = InboxRepository(ApiClient(customDio: Dio()..httpClientAdapter = adapter, customStorage: _Storage()));
    final result = await repository.fetchTodos(status: 'complete');
    expect(result.items.single.title, 'Assigned task');
  });

  test('assignment read sends the line and exact assignment identity', () async {
    final adapter = _Adapter();
    final repository = InboxRepository(ApiClient(customDio: Dio()..httpClientAdapter = adapter, customStorage: _Storage()));
    expect(await repository.markRead('logistic-in', '23', readSubjectType: 'assignment', readSubjectKey: '5'), isTrue);
    expect(adapter.request!.uri.path, '/api/v1/inbox/logistic-in/23/mark-read');
    final body = adapter.request!.data is String ? jsonDecode(adapter.request!.data as String) : adapter.request!.data;
    expect(body, {'read_subject_type': 'assignment', 'read_subject_key': '5'});
  });

  test('unread mention notifications are sent once each to Core', () async {
    final adapter = _Adapter();
    final repository = InboxRepository(ApiClient(customDio: Dio()..httpClientAdapter = adapter, customStorage: _Storage()));
    await repository.markMentionNotificationsRead([7, 8, 7]);
    expect(adapter.paths, ['/api/v1/inbox/notifications/7/read', '/api/v1/inbox/notifications/8/read']);
  });
}
