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

class _InboxRepository extends InboxRepository {
  _InboxRepository(ApiClient client) : super(client);
  final requests = <({String status, String search})>[];
  final reads =
      <({String module, String key, String? type, String? identity})>[];
  final notificationReads = <int>[];
  bool emptySearch = false;
  bool fail = false;

  @override
  Future<void> markMentionNotificationsRead(List<int> ids) async =>
      notificationReads.addAll(ids);

  @override
  Future<bool> markRead(String module, String subjectKey,
      {String? readSubjectType, String? readSubjectKey}) async {
    reads.add((
      module: module,
      key: subjectKey,
      type: readSubjectType,
      identity: readSubjectKey
    ));
    return true;
  }

  @override
  Future<InboxFetchResult> fetchTodos(
      {String status = 'pending', String search = ''}) async {
    requests.add((status: status, search: search));
    if (fail) throw Exception('Network unavailable');
    return InboxFetchResult(
      incompleteCount: 1,
      completeCount: 1,
      sourceCounts: emptySearch && search.isNotEmpty
          ? const {}
          : const {
              'guest-book': [3, 2, 1, 0]
            },
      sourceCountsComplete: true,
      items: emptySearch && search.isNotEmpty
          ? []
          : [
              InboxItemModel.fromJson({
                'id': status == 'complete' ? '2' : '1',
                'title':
                    status == 'complete' ? 'Finished item' : 'Pending item',
                'module_code': 'guest-book',
                'subject_key': '42',
                'has_unread': true,
                'mention_unread_count': 2,
                'mention_notification_ids': [7, 8],
              })
            ],
    );
  }
}

void main() {
  testWidgets('Inbox error hides stale counts and retry reloads',
      (tester) async {
    final api = ApiClient(customDio: Dio(), customStorage: _Storage());
    final repository = _InboxRepository(api);
    await tester.pumpWidget(ProviderScope(
      overrides: [
        inboxNotifierProvider.overrideWith((ref) =>
            InboxNotifier(repository, ReverbRealtimeService(api), null))
      ],
      child: const MaterialApp(home: InboxScreen()),
    ));
    await tester.pumpAndSettle();
    expect(find.text('Incomplete (1)'), findsOneWidget);
    repository.fail = true;
    await tester.tap(find.byIcon(Icons.refresh_rounded));
    await tester.pumpAndSettle();
    expect(find.text('Incomplete (1)'), findsNothing);
    expect(
        find.text('Unable to load Inbox. Please try again.'), findsOneWidget);
    repository.fail = false;
    await tester.tap(find.text('Retry'));
    await tester.pumpAndSettle();
    expect(find.text('Pending item'), findsOneWidget);
    expect(find.text('Incomplete (1)'), findsOneWidget);
  });

  testWidgets('Inbox filters fit a phone viewport', (tester) async {
    await tester.binding.setSurfaceSize(const Size(360, 640));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final api = ApiClient(customDio: Dio(), customStorage: _Storage());
    final repository = _InboxRepository(api);
    await tester.pumpWidget(ProviderScope(
      overrides: [
        inboxNotifierProvider.overrideWith((ref) =>
            InboxNotifier(repository, ReverbRealtimeService(api), null))
      ],
      child: const MaterialApp(home: InboxScreen()),
    ));
    await tester.pumpAndSettle();
    expect(find.text('Pending item'), findsOneWidget);
    expect(find.byType(DropdownButtonFormField<String>), findsNothing);
    expect(find.byType(SwitchListTile), findsNothing);
    expect(find.byKey(const ValueKey('status-pending')), findsOneWidget);
    expect(find.byKey(const ValueKey('status-complete')), findsOneWidget);
    expect(find.byKey(const ValueKey('filter-unread')), findsOneWidget);
    expect(find.byKey(const ValueKey('source-All')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('selected source keeps its label when search has no results',
      (tester) async {
    final api = ApiClient(customDio: Dio(), customStorage: _Storage());
    final repository = _InboxRepository(api)..emptySearch = true;
    await tester.pumpWidget(ProviderScope(
      overrides: [
        inboxNotifierProvider.overrideWith((ref) =>
            InboxNotifier(repository, ReverbRealtimeService(api), null))
      ],
      child: const MaterialApp(home: InboxScreen()),
    ));
    await tester.pumpAndSettle();
    await tester.tap(find.text('All Sources'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Guests').last);
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'nothing');
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pumpAndSettle();
    expect(find.text('Guests'), findsOneWidget);
    expect(find.text('No items found'), findsOneWidget);
    expect(find.text('Incomplete (0)'), findsOneWidget);
    final previousLoads = repository.requests.length;
    await tester.drag(find.byType(ListView).first, const Offset(0, 300));
    await tester.pumpAndSettle();
    expect(repository.requests.length, greaterThan(previousLoads));
  });

  testWidgets('source and unread filters update status counts', (tester) async {
    final api = ApiClient(customDio: Dio(), customStorage: _Storage());
    final repository = _InboxRepository(api);
    await tester.pumpWidget(ProviderScope(
      overrides: [
        inboxNotifierProvider.overrideWith((ref) =>
            InboxNotifier(repository, ReverbRealtimeService(api), null))
      ],
      child: const MaterialApp(home: InboxScreen()),
    ));
    await tester.pumpAndSettle();
    await tester.tap(find.text('All Sources'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Guests').last);
    await tester.pumpAndSettle();
    expect(find.text('Incomplete (3)'), findsOneWidget);
    await tester.tap(find.text('Unread only'));
    await tester.pumpAndSettle();
    expect(find.text('Incomplete (1)'), findsOneWidget);
  });

  testWidgets('status selection and search use the same Inbox view',
      (tester) async {
    final api = ApiClient(customDio: Dio(), customStorage: _Storage());
    final repository = _InboxRepository(api);
    await tester.pumpWidget(ProviderScope(
      overrides: [
        inboxNotifierProvider.overrideWith((ref) =>
            InboxNotifier(repository, ReverbRealtimeService(api), null))
      ],
      child: const MaterialApp(home: InboxScreen()),
    ));
    await tester.pumpAndSettle();
    expect(find.text('Pending item'), findsOneWidget);

    await tester.tap(find.text('Incomplete (1)'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Complete (1)').last);
    await tester.pumpAndSettle();
    expect(find.text('Finished item'), findsOneWidget);
    expect(repository.requests.last.status, 'complete');

    await tester.enterText(find.byType(TextField), 'visitor');
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pumpAndSettle();
    expect(repository.requests.last.status, 'complete');
    expect(repository.requests.last.search, 'visitor');
    await tester.tap(find.text('Reset filters'));
    await tester.pumpAndSettle();
    expect(repository.requests.last, (status: 'pending', search: ''));
    expect(tester.widget<TextField>(find.byType(TextField)).controller!.text,
        isEmpty);
  });

  testWidgets('switching status applies the search before debounce expires',
      (tester) async {
    final api = ApiClient(customDio: Dio(), customStorage: _Storage());
    final repository = _InboxRepository(api);
    await tester.pumpWidget(ProviderScope(
      overrides: [
        inboxNotifierProvider.overrideWith((ref) =>
            InboxNotifier(repository, ReverbRealtimeService(api), null))
      ],
      child: const MaterialApp(home: InboxScreen()),
    ));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'visitor');
    await tester.tap(find.text('Incomplete (1)'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    await tester.tap(find.text('Complete (1)').last);
    await tester.pumpAndSettle();
    expect(repository.requests.last, (status: 'complete', search: 'visitor'));
  });

  testWidgets('reset cancels a pending search', (tester) async {
    final api = ApiClient(customDio: Dio(), customStorage: _Storage());
    final repository = _InboxRepository(api);
    await tester.pumpWidget(ProviderScope(
      overrides: [
        inboxNotifierProvider.overrideWith((ref) =>
            InboxNotifier(repository, ReverbRealtimeService(api), null))
      ],
      child: const MaterialApp(home: InboxScreen()),
    ));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'visitor');
    await tester.pump();
    await tester.tap(find.text('Reset filters'));
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pumpAndSettle();
    expect(repository.requests.last, (status: 'pending', search: ''));
    expect(repository.requests.where((request) => request.search == 'visitor'),
        isEmpty);
  });

  testWidgets('reopened Inbox restores the active status and search',
      (tester) async {
    final api = ApiClient(customDio: Dio(), customStorage: _Storage());
    final repository = _InboxRepository(api);
    final container = ProviderContainer(overrides: [
      inboxNotifierProvider.overrideWith(
          (ref) => InboxNotifier(repository, ReverbRealtimeService(api), null))
    ]);
    addTearDown(container.dispose);
    await container
        .read(inboxNotifierProvider.notifier)
        .loadInbox(status: 'complete', search: 'visitor');
    await tester.pumpWidget(UncontrolledProviderScope(
        container: container, child: const MaterialApp(home: InboxScreen())));
    await tester.pumpAndSettle();
    expect(find.text('Complete (1)'), findsOneWidget);
    expect(tester.widget<TextField>(find.byType(TextField)).controller!.text,
        'visitor');
    expect(find.text('Finished item'), findsOneWidget);
  });

  testWidgets('opening an unread row sends its read identity', (tester) async {
    final api = ApiClient(customDio: Dio(), customStorage: _Storage());
    final repository = _InboxRepository(api);
    await tester.pumpWidget(ProviderScope(
      overrides: [
        inboxRepositoryProvider.overrideWithValue(repository),
        inboxNotifierProvider.overrideWith((ref) =>
            InboxNotifier(repository, ReverbRealtimeService(api), null))
      ],
      child: const MaterialApp(home: InboxScreen()),
    ));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Pending item'));
    await tester.pumpAndSettle();
    expect(repository.reads.single,
        (module: 'guest-book', key: '42', type: 'guest', identity: '42'));
    expect(repository.notificationReads, [7, 8]);
    expect(repository.requests.length, greaterThan(1));
    await tester.ensureVisible(find.text('Mark as read'));
    await tester.tap(find.text('Mark as read'));
    await tester.pumpAndSettle();
    expect(repository.reads.last,
        (module: 'guest-book', key: '42', type: 'guest', identity: '42'));
    expect(repository.notificationReads, [7, 8, 7, 8]);
  });
}
