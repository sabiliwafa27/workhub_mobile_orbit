import 'dart:convert';
import 'dart:typed_data';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:workhub_mobile/core/network/api_client.dart';
import 'package:workhub_mobile/core/storage/secure_storage_service.dart';
import 'package:workhub_mobile/features/auth/providers/auth_provider.dart';
import 'package:workhub_mobile/features/inbox/screens/logistic_in_detail_screen.dart';
import 'package:workhub_mobile/features/inbox/screens/logistic_in_officer_form.dart';

class _Storage extends SecureStorageService {
  @override
  Future<String> getBaseUrl() async => 'https://example.test';
  @override
  Future<String?> getToken() async => null;
}

class _Adapter implements HttpClientAdapter {
  final requests = <RequestOptions>[];
  final bool eligible;
  final bool canViewResults;
  _Adapter({this.eligible = false, this.canViewResults = false});
  @override
  void close({bool force = false}) {}
  @override
  Future<ResponseBody> fetch(RequestOptions options, Stream<Uint8List>? requestStream, Future<void>? cancelFuture) async {
    requests.add(options);
    return ResponseBody.fromString(jsonEncode({'data': {
      'selectedLine': {'item_name': 'Material', 'supplier_name': 'Supplier', 'status': eligible ? 'confirmed' : 'completed'},
      'inboxOfficerAssignment': {'logistic_in_item_assignment_id': 91, 'role_name': eligible ? 'Warehouse' : 'Quality Control', 'role_code': eligible ? 'WH' : 'QC', 'employee_name': 'Employee', 'assignment_status': eligible ? 'assigned' : 'completed'},
      'inboxOfficerSubmission': eligible ? null : {'submitted_at': '2026-11-12'},
      'inboxOfficerForm': {'packagingOptions': ['Baik'], 'yesNoOptions': ['ya', 'tidak'], 'standardOptions': ['sesuai_standart']},
      'canViewOfficerResults': canViewResults,
      'assignmentResults': [{'role_code': 'QC', 'role_name': 'Quality Control', 'employee_name': 'Result Officer',
        'assignment_status': 'completed', 'answers': [{'key': 'aroma', 'label': 'Aroma', 'value': 'Sesuai Standart'}]}],
    }}), 200,
        headers: {Headers.contentTypeHeader: [Headers.jsonContentType]});
  }
}

void main() {
  testWidgets('Logistic In detail forwards the exact assignment context', (tester) async {
    final adapter = _Adapter();
    final api = ApiClient(customDio: Dio()..httpClientAdapter = adapter, customStorage: _Storage());
    await tester.pumpWidget(ProviderScope(overrides: [apiClientProvider.overrideWithValue(api)],
      child: const MaterialApp(home: LogisticInDetailScreen(line: '23', assignment: 91))));
    await tester.pumpAndSettle();
    expect(find.text('Material'), findsOneWidget);
    expect(find.text('Supplier'), findsWidgets);
    expect(find.text('Quality Control'), findsOneWidget);
    expect(find.text('Employee'), findsOneWidget);
    expect(adapter.requests.single.uri.path, '/api/v1/inbox/module-detail/wms.logistic-in/23');
    expect(adapter.requests.single.queryParameters['assignment'], 91);
  });

  testWidgets('mention detail does not forward an officer assignment', (tester) async {
    final adapter = _Adapter();
    final api = ApiClient(customDio: Dio()..httpClientAdapter = adapter, customStorage: _Storage());
    await tester.pumpWidget(ProviderScope(overrides: [apiClientProvider.overrideWithValue(api)],
      child: const MaterialApp(home: LogisticInDetailScreen(line: '23', assignment: 91, mention: true))));
    await tester.pumpAndSettle();
    expect(adapter.requests.single.queryParameters['context'], 'mention');
    expect(adapter.requests.single.queryParameters.containsKey('assignment'), isFalse);
  });

  testWidgets('officer form is available only for the exact active assignment', (tester) async {
    final adapter = _Adapter(eligible: true);
    final api = ApiClient(customDio: Dio()..httpClientAdapter = adapter, customStorage: _Storage());
    await tester.pumpWidget(ProviderScope(overrides: [apiClientProvider.overrideWithValue(api)],
      child: const MaterialApp(home: LogisticInDetailScreen(line: '23', assignment: 91))));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.text('WH officer input'), 200, scrollable: find.byType(Scrollable).first);
    expect(find.byType(LogisticInOfficerForm), findsOneWidget);
  });

  testWidgets('mismatched officer assignment does not show the form', (tester) async {
    final adapter = _Adapter(eligible: true);
    final api = ApiClient(customDio: Dio()..httpClientAdapter = adapter, customStorage: _Storage());
    await tester.pumpWidget(ProviderScope(overrides: [apiClientProvider.overrideWithValue(api)],
      child: const MaterialApp(home: LogisticInDetailScreen(line: '23', assignment: 92))));
    await tester.pumpAndSettle();
    await tester.drag(find.byType(ListView).first, const Offset(0, -600));
    await tester.pumpAndSettle();
    expect(find.byType(LogisticInOfficerForm), findsNothing);
  });

  testWidgets('authorized officer results show the returned answers', (tester) async {
    final adapter = _Adapter(canViewResults: true);
    final api = ApiClient(customDio: Dio()..httpClientAdapter = adapter, customStorage: _Storage());
    await tester.pumpWidget(ProviderScope(overrides: [apiClientProvider.overrideWithValue(api)],
      child: const MaterialApp(home: LogisticInDetailScreen(line: '23', mention: true))));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.text('Result Officer'), 200, scrollable: find.byType(Scrollable).first);
    await tester.tap(find.text('Result Officer'));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.text('Sesuai Standart'), 200, scrollable: find.byType(Scrollable).first);
    expect(find.text('Aroma'), findsOneWidget);
    expect(find.text('Sesuai Standart'), findsOneWidget);
  });

  testWidgets('officer results stay hidden when the response denies access', (tester) async {
    final api = ApiClient(customDio: Dio()..httpClientAdapter = _Adapter(), customStorage: _Storage());
    await tester.pumpWidget(ProviderScope(overrides: [apiClientProvider.overrideWithValue(api)],
      child: const MaterialApp(home: LogisticInDetailScreen(line: '23'))));
    await tester.pumpAndSettle();
    await tester.drag(find.byType(ListView).first, const Offset(0, -1000));
    await tester.pumpAndSettle();
    expect(find.text('Result Officer'), findsNothing);
    expect(find.text('Sesuai Standart'), findsNothing);
  });
}
