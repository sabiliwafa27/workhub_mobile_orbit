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
  bool offDay = false;
  final requests = <RequestOptions>[];
  @override
  void close({bool force = false}) {}
  @override
  Future<ResponseBody> fetch(RequestOptions options, Stream<Uint8List>? requestStream, Future<void>? cancelFuture) async {
    requests.add(options);
    if (options.method == 'POST') {
      final data = options.data is String ? jsonDecode(options.data as String) as Map : options.data as Map;
      offDay = data['is_off_day'] == true;
    }
    return ResponseBody.fromString(jsonEncode({'can_edit': true, 'off_day_available': true, 'is_off_day': offDay}), 200,
        headers: {Headers.contentTypeHeader: [Headers.jsonContentType]});
  }
}

void main() {
  testWidgets('off-day switch saves and refreshes the server state', (tester) async {
    final adapter = _Adapter();
    final api = ApiClient(customDio: Dio()..httpClientAdapter = adapter, customStorage: _Storage());
    await tester.pumpWidget(ProviderScope(
      overrides: [apiClientProvider.overrideWithValue(api)],
      child: const MaterialApp(home: CreateWorkItemScreen(isEc: true)),
    ));
    await tester.pumpAndSettle();
    expect(find.text('Create'), findsOneWidget);
    await tester.tap(find.byType(SwitchListTile));
    await tester.pumpAndSettle();
    expect(find.text('Today is marked as an off day.'), findsOneWidget);
    expect(find.text('Create'), findsNothing);
    final post = adapter.requests.where((request) => request.method == 'POST').single;
    expect(post.uri.path, '/workhub/api/v1/ec/off-day');
    expect(adapter.offDay, isTrue);
  });
}
