import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:workhub_mobile/core/network/api_client.dart';
import 'package:workhub_mobile/core/realtime/reverb_service.dart';
import 'package:workhub_mobile/core/storage/secure_storage_service.dart';
import 'package:workhub_mobile/features/inbox/models/inbox_item_model.dart';
import 'package:workhub_mobile/features/inbox/providers/inbox_provider.dart';
import 'package:workhub_mobile/features/inbox/screens/inbox_screen.dart';

class _Storage extends SecureStorageService {
  @override
  Future<String> getBaseUrl() async => 'https://example.test';
  @override
  Future<String?> getToken() async => null;
}

class _Repository extends InboxRepository {
  final Map<String, dynamic> permissions;
  final actions = <String>[];
  _Repository(ApiClient client, this.permissions) : super(client);
  @override
  Future<InboxFetchResult> fetchTodos(
          {String status = 'pending', String search = ''}) async =>
      InboxFetchResult(items: [], guestActions: permissions);
  @override
  Future<bool> completeTodo(String module, String subjectKey) async {
    actions.add('$module:$subjectKey');
    return true;
  }
}

Future<void> _open(WidgetTester tester, _Repository repository, ApiClient api,
    String status) async {
  final item = InboxItemModel.fromJson({
    'module_code': 'guest-book',
    'subject_type': 'guest',
    'subject_key': '984',
    'full_name': 'Visitor',
    'status': status
  });
  await tester.pumpWidget(ProviderScope(
    overrides: [
      inboxRepositoryProvider.overrideWithValue(repository),
      inboxNotifierProvider.overrideWith(
          (ref) => InboxNotifier(repository, ReverbRealtimeService(api), null))
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
}

void main() {
  testWidgets('guest Inbox detail fits a phone viewport', (tester) async {
    await tester.binding.setSurfaceSize(const Size(360, 640));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final api = ApiClient(customDio: Dio(), customStorage: _Storage());
    await _open(
        tester,
        _Repository(api, {'can_view': true, 'can_check_out': true}),
        api,
        'assigned');
    await tester.scrollUntilVisible(find.text('Check out'), 200,
        scrollable: find.byType(Scrollable).first);
    expect(tester.takeException(), isNull);
  });

  testWidgets('guest recipient sees personal completion', (tester) async {
    final api = ApiClient(customDio: Dio(), customStorage: _Storage());
    final repository = _Repository(api, {'can_view': true});
    await _open(tester, repository, api, 'pending');
    expect(find.text('Check out'), findsNothing);
    await tester.tap(find.text('Complete'));
    await tester.pumpAndSettle();
    expect(repository.actions, ['guest-book:984']);
  });

  testWidgets('checkout requires the eligible state and confirmation',
      (tester) async {
    final api = ApiClient(customDio: Dio(), customStorage: _Storage());
    final repository =
        _Repository(api, {'can_view': true, 'can_check_out': true});
    await _open(tester, repository, api, 'assigned');
    await tester.tap(find.text('Check out'));
    await tester.pumpAndSettle();
    expect(find.text('Check out visitor?'), findsOneWidget);
    expect(repository.actions, isEmpty);
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(repository.actions, isEmpty);
    await tester.tap(find.text('Check out'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Check out').last);
    await tester.pumpAndSettle();
    expect(repository.actions, ['guest-book:984']);
  });

  testWidgets('checkout is hidden for a pending visitor', (tester) async {
    final api = ApiClient(customDio: Dio(), customStorage: _Storage());
    final repository =
        _Repository(api, {'can_view': true, 'can_check_out': true});
    await _open(tester, repository, api, 'pending');
    expect(find.text('Check out'), findsNothing);
    expect(find.text('Complete'), findsNothing);
  });
}
