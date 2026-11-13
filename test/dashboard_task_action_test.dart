import 'dart:convert';
import 'dart:typed_data';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:workhub_mobile/core/network/api_client.dart';
import 'package:workhub_mobile/core/storage/secure_storage_service.dart';
import 'package:workhub_mobile/features/auth/providers/auth_provider.dart';
import 'package:workhub_mobile/features/home/screens/orbit_dashboard_view.dart';
import 'package:workhub_mobile/features/tasks/screens/create_work_item_screen.dart';
import 'package:workhub_mobile/core/theme/orbit_theme.dart';

class _Storage extends SecureStorageService {
  @override
  Future<String> getBaseUrl() async => 'https://example.test';
  @override
  Future<String?> getToken() async => null;
}

class _Adapter implements HttpClientAdapter {
  int actions = 0;
  final paths = <String>[];
  bool failTaskLoad = false;
  bool shrinkingEcPages = false;
  bool customEcProgress = false;
  bool ecEditable = true;
  int postStatus = 503;
  bool pendingReview = false;
  bool pagedTasks = false;
  bool emptyTaskPage = false;
  int inboxTotal = 0;
  @override
  void close({bool force = false}) {}
  @override
  Future<ResponseBody> fetch(RequestOptions options,
      Stream<Uint8List>? requestStream, Future<void>? cancelFuture) async {
    paths.add(options.path);
    if (options.method == 'POST') actions++;
    final body = options.path.endsWith('/ec/today/current') && customEcProgress
        ? {
            'data': [
              {
                'id': 1,
                'title': 'EC idea',
                'current_progress': {'percentage': 25}
              }
            ],
            'can_edit': ecEditable,
            'meta': {'last_page': 1}
          }
        : options.path.endsWith('/ec/today/current') && shrinkingEcPages
            ? {
                'data': [],
                'meta': {
                  'last_page': options.queryParameters['page'] == 1 ? 2 : 1
                }
              }
            : options.path.endsWith('/tasks')
                ? {
                    'data': emptyTaskPage
                        ? []
                        : [
                            {
                              'task_id': options.queryParameters['page'] == 2
                                  ? 13
                                  : 12,
                              'title': options.queryParameters['page'] == 2
                                  ? 'Second task'
                                  : 'Dashboard task',
                              'status': 'open',
                              'row_action': pendingReview ? null : 'complete',
                              'has_pending_review': pendingReview
                            }
                          ],
                    'meta': {
                      'total': pagedTasks ? 30 : 1,
                      'current_page': options.queryParameters['page'] ?? 1,
                      'last_page': pagedTasks ? 2 : 1
                    }
                  }
                : options.path.endsWith('/inbox/todos')
                    ? {
                        'tasks': [],
                        'incomplete': [],
                        'complete': [],
                        'incomplete_count': inboxTotal,
                        'complete_count': 0
                      }
                    : {'data': []};
    return ResponseBody.fromString(
        jsonEncode(body),
        options.method == 'POST'
            ? postStatus
            : (failTaskLoad && options.path.endsWith('/tasks'))
                ? 503
                : 200,
        headers: {
          Headers.contentTypeHeader: [Headers.jsonContentType]
        });
  }
}

void main() {
  testWidgets('empty task page with a nonzero total prompts refresh',
      (tester) async {
    final adapter = _Adapter()..emptyTaskPage = true;
    final api = ApiClient(
        customDio: Dio()..httpClientAdapter = adapter,
        customStorage: _Storage());
    await tester.pumpWidget(ProviderScope(
        overrides: [apiClientProvider.overrideWithValue(api)],
        child: MaterialApp(
            home: OrbitDashboardView(
                onOpenSearch: () {},
                onOpenNotifications: () {},
                onOpenCheckIn: () {}))));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.text('No tasks loaded'), 250,
        scrollable: find.byType(Scrollable).first);
    expect(find.text('Refresh to load assigned tasks.'), findsOneWidget);
  });

  testWidgets('dashboard Inbox summary uses the server total', (tester) async {
    final adapter = _Adapter()..inboxTotal = 8;
    final api = ApiClient(
        customDio: Dio()..httpClientAdapter = adapter,
        customStorage: _Storage());
    await tester.pumpWidget(ProviderScope(
        overrides: [apiClientProvider.overrideWithValue(api)],
        child: MaterialApp(
            home: OrbitDashboardView(
                onOpenSearch: () {},
                onOpenNotifications: () {},
                onOpenCheckIn: () {}))));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.text('Unified Inbox & Approvals'), 250,
        scrollable: find.byType(Scrollable).first);
    expect(find.text('8'), findsWidgets);
  });

  testWidgets('dashboard shows the API task total and loads the next page',
      (tester) async {
    final adapter = _Adapter()..pagedTasks = true;
    final api = ApiClient(
        customDio: Dio()..httpClientAdapter = adapter,
        customStorage: _Storage());
    await tester.pumpWidget(ProviderScope(
        overrides: [apiClientProvider.overrideWithValue(api)],
        child: MaterialApp(
            home: OrbitDashboardView(
                onOpenSearch: () {},
                onOpenNotifications: () {},
                onOpenCheckIn: () {}))));
    await tester.pumpAndSettle();
    expect(find.text('30 assigned tasks'), findsOneWidget);
    await tester.scrollUntilVisible(find.text('Load more tasks'), 250,
        scrollable: find.byType(Scrollable).first);
    await tester.tap(find.text('Load more tasks'));
    await tester.pumpAndSettle();
    expect(find.text('Second task'), findsOneWidget);
  });

  testWidgets('dashboard fits a phone viewport', (tester) async {
    await tester.binding.setSurfaceSize(const Size(360, 640));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final api = ApiClient(
        customDio: Dio()..httpClientAdapter = _Adapter(),
        customStorage: _Storage());
    await tester.pumpWidget(ProviderScope(
        overrides: [apiClientProvider.overrideWithValue(api)],
        child: MaterialApp(
            home: OrbitDashboardView(
                onOpenSearch: () {},
                onOpenNotifications: () {},
                onOpenCheckIn: () {}))));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.text('Dashboard task'), 250,
        scrollable: find.byType(Scrollable).first);
    expect(tester.takeException(), isNull);
  });

  testWidgets('dashboard shows review requested even when task status is open',
      (tester) async {
    final adapter = _Adapter()..pendingReview = true;
    final api = ApiClient(
        customDio: Dio()..httpClientAdapter = adapter,
        customStorage: _Storage());
    await tester.pumpWidget(ProviderScope(
        overrides: [apiClientProvider.overrideWithValue(api)],
        child: MaterialApp(
            home: OrbitDashboardView(
                onOpenSearch: () {},
                onOpenNotifications: () {},
                onOpenCheckIn: () {}))));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.text('Dashboard task'), 300,
        scrollable: find.byType(Scrollable).first);
    expect(find.text('Pending review'), findsOneWidget);
    expect(
        tester.widget<Checkbox>(find.byType(Checkbox).first).onChanged, isNull);
  });

  testWidgets('failed task load does not present zero as a live count',
      (tester) async {
    final adapter = _Adapter()..failTaskLoad = true;
    final api = ApiClient(
        customDio: Dio()..httpClientAdapter = adapter,
        customStorage: _Storage());
    await tester.pumpWidget(ProviderScope(
        overrides: [apiClientProvider.overrideWithValue(api)],
        child: MaterialApp(
            home: OrbitDashboardView(
                onOpenSearch: () {},
                onOpenNotifications: () {},
                onOpenCheckIn: () {}))));
    await tester.pumpAndSettle();
    expect(find.text('Unable to load tasks'), findsOneWidget);
    expect(find.text('No assigned tasks'), findsNothing);
  });

  testWidgets('large tonal dashboard button opens EC and task creation choices',
      (tester) async {
    final api = ApiClient(
        customDio: Dio()..httpClientAdapter = _Adapter(),
        customStorage: _Storage());
    await tester.pumpWidget(ProviderScope(
        overrides: [apiClientProvider.overrideWithValue(api)],
        child: MaterialApp(
            theme: OrbitTheme.lightTheme,
            home: OrbitDashboardView(
                onOpenSearch: () {},
                onOpenNotifications: () {},
                onOpenCheckIn: () {}))));
    await tester.pumpAndSettle();
    final createButton = find.byType(FloatingActionButton);
    final buttonSurface = find.descendant(
        of: createButton, matching: find.byType(Material));
    expect(tester.widget<Material>(buttonSurface).color, OrbitColors.bubbleBlue);
    expect(tester.getSize(createButton), const Size(96, 96));
    await tester.tap(find.byType(FloatingActionButton));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Create EC'));
    await tester.pumpAndSettle();
    expect(
        tester
            .widget<CreateWorkItemScreen>(find.byType(CreateWorkItemScreen))
            .isEc,
        isTrue);
    await tester.pageBack();
    await tester.pumpAndSettle();
    await tester.tap(find.byType(FloatingActionButton));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Create task'));
    await tester.pumpAndSettle();
    expect(
        tester
            .widget<CreateWorkItemScreen>(find.byType(CreateWorkItemScreen))
            .isEc,
        isFalse);
  });

  testWidgets('dashboard requires a refresh after an uncertain task action',
      (tester) async {
    final adapter = _Adapter();
    final api = ApiClient(
        customDio: Dio()..httpClientAdapter = adapter,
        customStorage: _Storage());
    await tester.pumpWidget(ProviderScope(
        overrides: [apiClientProvider.overrideWithValue(api)],
        child: MaterialApp(
            home: OrbitDashboardView(
                onOpenSearch: () {},
                onOpenNotifications: () {},
                onOpenCheckIn: () {}))));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.text('Dashboard task'), 300,
        scrollable: find.byType(Scrollable).first);
    await tester.tap(find.byType(Checkbox).first);
    await tester.pumpAndSettle();
    expect(adapter.actions, 1);
    expect(
        tester.widget<Checkbox>(find.byType(Checkbox).first).onChanged, isNull);
    expect(
        find.text(
            'The update could not be confirmed. Refresh My Tasks before trying again.'),
        findsOneWidget);
    adapter.failTaskLoad = true;
    final failedRefresh = tester
        .state<RefreshIndicatorState>(find.byType(RefreshIndicator))
        .show();
    await tester.pumpAndSettle();
    await failedRefresh;
    expect(find.text('Unable to load tasks. Tap to retry.'), findsOneWidget);
    adapter.failTaskLoad = false;
    await tester.tap(find.text('Unable to load tasks. Tap to retry.'));
    await tester.pumpAndSettle();
    expect(tester.widget<Checkbox>(find.byType(Checkbox).first).onChanged,
        isNotNull);
  });

  testWidgets('successful dashboard task action refreshes Inbox',
      (tester) async {
    final adapter = _Adapter()..postStatus = 200;
    final api = ApiClient(
        customDio: Dio()..httpClientAdapter = adapter,
        customStorage: _Storage());
    await tester.pumpWidget(ProviderScope(
        overrides: [apiClientProvider.overrideWithValue(api)],
        child: MaterialApp(
            home: OrbitDashboardView(
                onOpenSearch: () {},
                onOpenNotifications: () {},
                onOpenCheckIn: () {}))));
    await tester.pumpAndSettle();
    final before =
        adapter.paths.where((path) => path.endsWith('/inbox/todos')).length;
    await tester.scrollUntilVisible(find.text('Dashboard task'), 300,
        scrollable: find.byType(Scrollable).first);
    await tester.tap(find.byType(Checkbox).first);
    await tester.pumpAndSettle();
    expect(adapter.paths.where((path) => path.endsWith('/inbox/todos')).length,
        greaterThan(before));
  });

  testWidgets('EC pagination can return from a page that no longer exists',
      (tester) async {
    final adapter = _Adapter()..shrinkingEcPages = true;
    final api = ApiClient(
        customDio: Dio()..httpClientAdapter = adapter,
        customStorage: _Storage());
    await tester.pumpWidget(ProviderScope(
        overrides: [apiClientProvider.overrideWithValue(api)],
        child: MaterialApp(
            home: OrbitDashboardView(
                onOpenSearch: () {},
                onOpenNotifications: () {},
                onOpenCheckIn: () {}))));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.text('EC'), 300,
        scrollable: find.byType(Scrollable).first);
    await tester.tap(find.text('EC'));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.text('Next'), 300,
        scrollable: find.byType(Scrollable).first);
    await tester.tap(find.text('Next'));
    await tester.pumpAndSettle();
    expect(find.text('Previous'), findsOneWidget);
    await tester.tap(find.text('Previous'));
    await tester.pumpAndSettle();
    expect(find.text('1 / 2'), findsOneWidget);
  });

  testWidgets('custom EC progress is not labeled as a different preset',
      (tester) async {
    final adapter = _Adapter()..customEcProgress = true;
    final api = ApiClient(
        customDio: Dio()..httpClientAdapter = adapter,
        customStorage: _Storage());
    await tester.pumpWidget(ProviderScope(
        overrides: [apiClientProvider.overrideWithValue(api)],
        child: MaterialApp(
            home: OrbitDashboardView(
                onOpenSearch: () {},
                onOpenNotifications: () {},
                onOpenCheckIn: () {}))));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.text('EC'), 300,
        scrollable: find.byType(Scrollable).first);
    await tester.tap(find.text('EC'));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.text('EC idea'), 300,
        scrollable: find.byType(Scrollable).first);
    expect(find.text('25%'), findsOneWidget);
    expect(find.text('Change status'), findsOneWidget);
  });

  testWidgets(
      'dashboard EC progress is read only when the edit window is closed',
      (tester) async {
    final adapter = _Adapter()
      ..customEcProgress = true
      ..ecEditable = false;
    final api = ApiClient(
        customDio: Dio()..httpClientAdapter = adapter,
        customStorage: _Storage());
    await tester.pumpWidget(ProviderScope(
        overrides: [apiClientProvider.overrideWithValue(api)],
        child: MaterialApp(
            home: OrbitDashboardView(
                onOpenSearch: () {},
                onOpenNotifications: () {},
                onOpenCheckIn: () {}))));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.text('EC'), 300,
        scrollable: find.byType(Scrollable).first);
    await tester.tap(find.text('EC'));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.text('EC idea'), 300,
        scrollable: find.byType(Scrollable).first);
    expect(find.text('25%'), findsOneWidget);
    expect(find.text('Change status'), findsNothing);
  });

  testWidgets('a rejected EC update asks for a refresh instead of retrying',
      (tester) async {
    final adapter = _Adapter()
      ..customEcProgress = true
      ..postStatus = 403;
    final api = ApiClient(
        customDio: Dio()..httpClientAdapter = adapter,
        customStorage: _Storage());
    await tester.pumpWidget(ProviderScope(
        overrides: [apiClientProvider.overrideWithValue(api)],
        child: MaterialApp(
            home: OrbitDashboardView(
                onOpenSearch: () {},
                onOpenNotifications: () {},
                onOpenCheckIn: () {}))));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.text('EC'), 300,
        scrollable: find.byType(Scrollable).first);
    await tester.tap(find.text('EC'));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.text('Change status'), 300,
        scrollable: find.byType(Scrollable).first);
    await tester.tap(find.byType(DropdownButton<int>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('In progress').last);
    await tester.pumpAndSettle();
    expect(
        find.text(
            'This update was rejected. Refresh EC progress and check your access.'),
        findsOneWidget);
    expect(find.text('Retry'), findsNothing);
  });

  testWidgets('a successful EC update refreshes Inbox and EC progress',
      (tester) async {
    final adapter = _Adapter()
      ..customEcProgress = true
      ..postStatus = 200;
    final api = ApiClient(
        customDio: Dio()..httpClientAdapter = adapter,
        customStorage: _Storage());
    await tester.pumpWidget(ProviderScope(
        overrides: [apiClientProvider.overrideWithValue(api)],
        child: MaterialApp(
            home: OrbitDashboardView(
                onOpenSearch: () {},
                onOpenNotifications: () {},
                onOpenCheckIn: () {}))));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.text('EC'), 300,
        scrollable: find.byType(Scrollable).first);
    await tester.tap(find.text('EC'));
    await tester.pumpAndSettle();
    final inboxLoads =
        adapter.paths.where((path) => path.endsWith('/inbox/todos')).length;
    final ecLoads = adapter.paths
        .where((path) => path.endsWith('/ec/today/current'))
        .length;
    await tester.scrollUntilVisible(find.text('Change status'), 300,
        scrollable: find.byType(Scrollable).first);
    await tester.tap(find.byType(DropdownButton<int>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('In progress').last);
    await tester.pumpAndSettle();
    expect(adapter.paths.where((path) => path.endsWith('/inbox/todos')).length,
        greaterThan(inboxLoads));
    expect(
        adapter.paths
            .where((path) => path.endsWith('/ec/today/current'))
            .length,
        greaterThan(ecLoads));
  });
}
