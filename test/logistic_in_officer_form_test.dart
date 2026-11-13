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
import 'package:workhub_mobile/features/inbox/providers/inbox_provider.dart';
import 'package:workhub_mobile/features/inbox/screens/logistic_in_officer_form.dart';

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
  Future<ResponseBody> fetch(RequestOptions options,
      Stream<Uint8List>? requestStream, Future<void>? cancelFuture) async {
    requests.add(options);
    return ResponseBody.fromString(jsonEncode({'message': 'Submitted'}), 200,
        headers: {
          Headers.contentTypeHeader: [Headers.jsonContentType]
        });
  }
}

class _Inbox extends InboxRepository {
  _Inbox(ApiClient client) : super(client);
  @override
  Future<InboxFetchResult> fetchTodos(
          {String status = 'pending', String search = ''}) async =>
      InboxFetchResult(items: []);
}

void main() {
  testWidgets('Logistic In QC form fits a phone viewport', (tester) async {
    await tester.binding.setSurfaceSize(const Size(360, 640));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(ProviderScope(
        child: MaterialApp(
            home: Scaffold(
                body: SingleChildScrollView(
                    child: LogisticInOfficerForm(
      line: '23',
      assignmentId: 91,
      role: 'QC',
      packagingOptions: const ['Baik'],
      yesNoOptions: const ['ya', 'tidak'],
      standardOptions: const ['sesuai_standart'],
      refreshDetail: () async {},
    ))))));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.text('Submit officer form'), 200,
        scrollable: find.byType(Scrollable).first);
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  testWidgets('QC and BM forms show their role-specific required checks',
      (tester) async {
    Widget form(String role) => ProviderScope(
            child: MaterialApp(
                home: Scaffold(
                    body: SingleChildScrollView(
                        child: LogisticInOfficerForm(
          line: '23',
          assignmentId: 91,
          role: role,
          packagingOptions: const ['Baik'],
          yesNoOptions: const ['ya', 'tidak'],
          standardOptions: const ['sesuai_standart'],
          refreshDetail: () async {},
        )))));
    await tester.pumpWidget(form('QC'));
    expect(find.text('Penampakan Visual'), findsOneWidget);
    expect(find.text('Tes Tekan'), findsOneWidget);
    expect(find.text('Received quantity'), findsNothing);

    await tester.pumpWidget(const SizedBox());
    await tester.pumpWidget(form('BM'));
    expect(find.text('Armada dalam kondisi bersih'), findsOneWidget);
    expect(find.text('Received quantity'), findsOneWidget);
    expect(find.text('Penampakan Visual'), findsNothing);
  });

  testWidgets(
      'warehouse form requires a positive quantity and submits its exact assignment',
      (tester) async {
    final adapter = _Adapter();
    final api = ApiClient(
        customDio: Dio()..httpClientAdapter = adapter,
        customStorage: _Storage());
    var refreshed = 0;
    await tester.pumpWidget(ProviderScope(
      overrides: [
        apiClientProvider.overrideWithValue(api),
        inboxNotifierProvider.overrideWith((ref) =>
            InboxNotifier(_Inbox(api), ReverbRealtimeService(api), null))
      ],
      child: MaterialApp(
          home: Scaffold(
              body: SingleChildScrollView(
                  child: LogisticInOfficerForm(
        line: '23',
        assignmentId: 91,
        role: 'WH',
        packagingOptions: const ['Baik'],
        yesNoOptions: const ['ya', 'tidak'],
        standardOptions: const ['sesuai_standart'],
        refreshDetail: () async {
          refreshed++;
        },
      )))),
    ));
    await tester.tap(find.text('Expiry date'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();
    await tester.tap(find.byType(DropdownButtonFormField<String>).at(0));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Baik').last);
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Terima'));
    await tester.tap(find.byType(DropdownButtonFormField<String>).at(1));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Ya').last);
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Reject'));
    await tester.tap(find.byType(DropdownButtonFormField<String>).at(2));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Tidak').last);
    await tester.pumpAndSettle();
    await tester.enterText(
        find.widgetWithText(TextFormField, 'Received quantity'), '0');
    tester.testTextInput.hide();
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Submit officer form'));
    await tester.tap(find.text('Submit officer form'));
    await tester.pumpAndSettle();
    expect(
        find.text(
            'Enter a quantity greater than zero with up to 3 decimal places.'),
        findsOneWidget);
    expect(adapter.requests, isEmpty);

    await tester.enterText(
        find.widgetWithText(TextFormField, 'Received quantity'), '2.5');
    tester.testTextInput.hide();
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Submit officer form'));
    await tester.tap(find.text('Submit officer form'));
    await tester.pumpAndSettle();
    expect(adapter.requests.single.uri.path,
        '/api/v1/inbox/module-detail/wms.logistic-in/23/assignments/91/submit');
    final payload = adapter.requests.single.data is String
        ? jsonDecode(adapter.requests.single.data as String) as Map
        : adapter.requests.single.data as Map;
    expect(payload['packaging_condition'], 'Baik');
    expect(payload['accept_item'], 'ya');
    expect(payload['accept_item_notes'], '2.5');
    expect(payload['reject_item'], 'tidak');
    expect(refreshed, 1);
  });
}
