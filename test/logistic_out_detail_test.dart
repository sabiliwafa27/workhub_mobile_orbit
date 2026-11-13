import 'dart:convert';
import 'dart:typed_data';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:workhub_mobile/core/network/api_client.dart';
import 'package:workhub_mobile/core/storage/secure_storage_service.dart';
import 'package:workhub_mobile/features/auth/providers/auth_provider.dart';
import 'package:workhub_mobile/features/inbox/screens/logistic_out_detail_screen.dart';

class _Storage extends SecureStorageService {
  @override
  Future<String> getBaseUrl() async => 'https://example.test';
  @override
  Future<String?> getToken() async => null;
}

class _Adapter implements HttpClientAdapter {
  final requests = <RequestOptions>[];
  @override
  void close({bool force = false}) {}
  @override
  Future<ResponseBody> fetch(RequestOptions options, Stream<Uint8List>? requestStream, Future<void>? cancelFuture) async {
    requests.add(options);
    return ResponseBody.fromString(jsonEncode({'kind': 'warehouse', 'detail': {
      'header': {'display_reference': 'PO-12', 'supplier': {'branch_name': 'Surabaya'}},
      'items': [{'item_name': 'Product A', 'quantity': 5}],
    }}), 200, headers: {Headers.contentTypeHeader: [Headers.jsonContentType]});
  }
}

void main() {
  testWidgets('Logistic Out detail requests the scoped Core endpoint', (tester) async {
    final adapter = _Adapter();
    final api = ApiClient(customDio: Dio()..httpClientAdapter = adapter, customStorage: _Storage());
    await tester.pumpWidget(ProviderScope(
      overrides: [apiClientProvider.overrideWithValue(api)],
      child: const MaterialApp(home: LogisticOutDetailScreen(stage: 'warehouse', subjectId: 12)),
    ));
    await tester.pumpAndSettle();
    expect(adapter.requests.single.uri.path, '/api/v1/inbox/logistic-out/warehouse/12');
    expect(find.text('PO-12'), findsOneWidget);
    expect(find.text('Surabaya'), findsOneWidget);
    expect(find.text('Product A'), findsOneWidget);
  });
}
