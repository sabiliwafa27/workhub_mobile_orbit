import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:workhub_mobile/core/network/api_client.dart';
import 'package:workhub_mobile/core/realtime/reverb_service.dart';
import 'package:workhub_mobile/core/storage/secure_storage_service.dart';
import 'package:workhub_mobile/core/theme/orbit_theme.dart';
import 'package:workhub_mobile/features/auth/models/user_model.dart';
import 'package:workhub_mobile/features/auth/providers/auth_provider.dart';
import 'package:workhub_mobile/features/home/providers/dashboard_provider.dart';
import 'package:workhub_mobile/features/home/screens/orbit_main_shell.dart';
import 'package:workhub_mobile/features/home/screens/orbit_dashboard_components.dart';
import 'package:workhub_mobile/features/tasks/providers/task_provider.dart';

class ReferenceStorage extends SecureStorageService {
  @override
  Future<String?> getToken() async => null;
  @override
  Future<String> getBaseUrl() async => 'https://example.test';
}

class ReferenceAuth extends AuthNotifier {
  ReferenceAuth(super.api, super.storage);
  @override
  Future<void> checkAuthStatus() async {
    state = AuthState(
        isAuthenticated: true,
        user: UserModel(
            id: 1,
            name: 'Budi Santosa',
            email: 'budi@example.test',
            permissions: [],
            modules: {}));
  }
}

class ReferenceRealtime extends ReverbRealtimeService {
  ReferenceRealtime(super.api);
  @override
  Future<void> connect() async {}
}

class ReferenceAdapter implements HttpClientAdapter {
  final queries = <Map<String, dynamic>>[];
  bool failStatus = false;
  int openCount = 8;
  int postStatus = 200;
  Completer<void>? pendingToday;
  int heldRequests = 0;
  @override
  void close({bool force = false}) {}
  @override
  Future<ResponseBody> fetch(RequestOptions options, Stream<Uint8List>? stream,
      Future<void>? cancel) async {
    final today = DateTime.now().toIso8601String().split('T').first;
    Map<String, dynamic> body = {'data': []};
    if (options.path.endsWith('/tasks')) {
      queries.add(Map.of(options.queryParameters));
      final status = options.queryParameters['status'];
      final pending = pendingToday;
      if (pending != null &&
          status == 'all' &&
          options.queryParameters['from'] == today) {
        heldRequests++;
        await pending.future;
        throw DioException(
            requestOptions: options, type: DioExceptionType.connectionError);
      }
      if (failStatus && status != 'all') {
        throw DioException(
            requestOptions: options, type: DioExceptionType.connectionError);
      }
      body = {
        'data': [
          {
            'id': 1,
            'title': 'Uji Coba Beta Workhub Untuk Memastikan Berfungsi Normal',
            'status': 'open',
            'priority': 'high',
            'row_action': 'complete',
            'due_date': today,
            'assignees': [
              {'full_name': 'Budi Santosa'}
            ]
          },
          {
            'id': 2,
            'title': 'Review & Finalisasi Materi Middle Management',
            'status': 'open',
            'priority': 'medium',
            'row_action': 'complete',
            'due_date': today,
            'assignees': [
              {'full_name': 'Budi Santosa'}
            ]
          },
        ],
        'meta': {
          'total': {
                'open': openCount,
                'in_progress': 12,
                'completed': 22
              }[status] ??
              42,
          'current_page': 1,
          'last_page': 1
        }
      };
    } else if (options.path.endsWith('/tasks/performance')) {
      body = {
        'data': {'earned_points': 320, 'task_points': 240, 'ec_points': 80}
      };
    } else if (options.path.endsWith('/inbox/api/todos') ||
        options.path.endsWith('/inbox/todos')) {
      final items = List.generate(
          7,
          (i) => {
                'id': i + 1,
                'module': 'task',
                'subject_key': '${i + 1}',
                'title': 'Approval ${i + 1}',
                'has_unread': true,
                'unread_count': 1
              });
      body = {
        'data': items,
        'incomplete': items,
        'complete': [],
        'incomplete_count': 7,
        'complete_count': 0
      };
    }
    return ResponseBody.fromString(
        jsonEncode(body), options.method == 'POST' ? postStatus : 200,
        headers: {
          Headers.contentTypeHeader: [Headers.jsonContentType]
        });
  }
}

Widget referenceApp(ReferenceAdapter adapter, {double textScale = 1}) {
  final storage = ReferenceStorage();
  final api = ApiClient(
      customDio: Dio()..httpClientAdapter = adapter, customStorage: storage);
  return ProviderScope(
      overrides: [
        storageServiceProvider.overrideWithValue(storage),
        apiClientProvider.overrideWithValue(api),
        authProvider.overrideWith((ref) => ReferenceAuth(api, storage)),
        reverbServiceProvider.overrideWith((ref) => ReferenceRealtime(api)),
      ],
      child: MaterialApp(
          debugShowCheckedModeBanner: false,
          builder: (context, child) => MediaQuery(
              data: MediaQuery.of(context)
                  .copyWith(textScaler: TextScaler.linear(textScale)),
              child: child!),
          theme: OrbitTheme.lightTheme,
          home: const OrbitMainShell()));
}

void main() {
  testWidgets(
      'reference dashboard fits phone widths and retains original palette',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(referenceApp(ReferenceAdapter()));
    await tester.pumpAndSettle();
    expect(find.text('Orbit\nWorkHub'), findsOneWidget);
    expect(find.text('Total Tasks'), findsOneWidget);
    expect(find.text('42'), findsOneWidget);
    expect(find.text('Task Progress'), findsOneWidget);
    expect(find.text('19%'), findsOneWidget);
    expect(find.text('Chat'), findsOneWidget);
    expect(find.text('ERP'), findsWidgets);
    expect(OrbitColors.primaryNavy, const Color(0xFF06244D));
    expect(OrbitColors.brandOrange, const Color(0xFFD97706));
    expect(tester.takeException(), isNull);
    await tester.binding.setSurfaceSize(const Size(320, 640));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(referenceApp(ReferenceAdapter(), textScale: 1.5));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  testWidgets('Task Board create action stays above floating navigation',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(360, 640));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(referenceApp(ReferenceAdapter()));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Tasks'));
    await tester.pumpAndSettle();
    final action = find.byTooltip('Create task');
    expect(action, findsOneWidget);
    expect(
        tester.getBottomRight(action).dy,
        lessThan(tester
            .getTopLeft(find.byKey(const ValueKey('orbit-bottom-navigation')))
            .dy));
    expect(tester.takeException(), isNull);
  });

  testWidgets(
      'period changes fetch server totals without changing Task Board filters',
      (tester) async {
    final adapter = ReferenceAdapter();
    await tester.pumpWidget(referenceApp(adapter));
    await tester.pumpAndSettle();
    final element = tester.element(find.byType(OrbitMainShell));
    final container = ProviderScope.containerOf(element);
    final taskBoardState = container.read(taskNotifierProvider);
    await tester.tap(find.text('Week'));
    await tester.pumpAndSettle();
    final range = DashboardPeriod.week.range(DateTime.now());
    expect(
        adapter.queries.any((q) =>
            q['from'] == range.$1.toIso8601String().split('T').first &&
            q['to'] == range.$2.toIso8601String().split('T').first),
        isTrue);
    expect(identical(container.read(taskNotifierProvider), taskBoardState),
        isTrue);
    expect(tester.takeException(), isNull);
  });

  testWidgets('switching periods during refresh keeps uncertain actions locked',
      (tester) async {
    final adapter = ReferenceAdapter()..postStatus = 503;
    await tester.pumpWidget(referenceApp(adapter));
    await tester.pumpAndSettle();
    const title = 'Uji Coba Beta Workhub Untuk Memastikan Berfungsi Normal';
    await tester.scrollUntilVisible(find.text(title), 250,
        scrollable: find.byType(Scrollable).first);
    await tester.tap(find.byType(Checkbox).first);
    await tester.pumpAndSettle();
    expect(
        tester.widget<Checkbox>(find.byType(Checkbox).first).onChanged, isNull);
    final gate = Completer<void>();
    adapter.pendingToday = gate;
    final refresh = tester
        .state<RefreshIndicatorState>(find.byType(RefreshIndicator))
        .show();
    for (var i = 0; i < 10 && adapter.heldRequests == 0; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(adapter.heldRequests, greaterThan(0));
    await tester.scrollUntilVisible(find.text('Week'), -250,
        scrollable: find.byType(Scrollable).first);
    await tester.tap(find.text('Week'));
    await tester.pump(const Duration(milliseconds: 350));
    adapter.pendingToday = null;
    await tester.tap(find.text('Today').first);
    await tester.pump(const Duration(milliseconds: 350));
    await tester.pump(const Duration(milliseconds: 350));
    gate.complete();
    await tester.pumpAndSettle();
    await refresh;
    await tester.scrollUntilVisible(find.text(title), 250,
        scrollable: find.byType(Scrollable).first);
    expect(
        tester.widget<Checkbox>(find.byType(Checkbox).first).onChanged, isNull);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Task Board mutations refresh dashboard list and statistics',
      (tester) async {
    final adapter = ReferenceAdapter();
    await tester.pumpWidget(referenceApp(adapter));
    await tester.pumpAndSettle();
    final container =
        ProviderScope.containerOf(tester.element(find.byType(OrbitMainShell)));
    expect(
        container
            .read(dashboardTaskStatsProvider(DashboardPeriod.today))
            .valueOrNull
            ?.open,
        8);
    adapter.openCount = 7;
    final refresh = container.read(taskNotifierProvider.notifier).loadTasks();
    await tester.pumpAndSettle();
    await refresh;
    for (var i = 0;
        i < 20 &&
            container
                    .read(dashboardTaskStatsProvider(DashboardPeriod.today))
                    .valueOrNull
                    ?.open !=
                7;
        i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
    expect(
        container
            .read(dashboardTaskStatsProvider(DashboardPeriod.today))
            .valueOrNull
            ?.open,
        7);
    expect(tester.takeException(), isNull);
  });

  testWidgets('failed status requests show unavailable progress',
      (tester) async {
    final adapter = ReferenceAdapter()..failStatus = true;
    await tester.pumpWidget(referenceApp(adapter));
    await tester.pumpAndSettle();
    final progress =
        tester.widget<DashboardProgress>(find.byType(DashboardProgress));
    expect(progress.stats, isNull);
    expect(find.text('19%'), findsNothing);
    expect(find.text('Loading status totals…'), findsNothing);
    adapter.failStatus = false;
    await tester.tap(find.text('Status totals unavailable. Tap to retry.'));
    await tester.pumpAndSettle();
    expect(
        tester
            .widget<DashboardProgress>(find.byType(DashboardProgress))
            .stats
            ?.open,
        8);
    expect(tester.takeException(), isNull);
  });
}
