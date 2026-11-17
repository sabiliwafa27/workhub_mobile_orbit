import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:workhub_mobile/core/network/api_client.dart';
import 'package:workhub_mobile/core/realtime/reverb_service.dart';
import 'package:workhub_mobile/core/services/fcm_notification_service.dart';
import 'package:workhub_mobile/core/storage/secure_storage_service.dart';
import 'package:workhub_mobile/core/theme/orbit_theme.dart';
import 'package:workhub_mobile/features/auth/models/user_model.dart';
import 'package:workhub_mobile/features/auth/providers/auth_provider.dart';
import 'package:workhub_mobile/features/home/screens/orbit_main_shell.dart';
import 'package:workhub_mobile/features/inbox/providers/inbox_provider.dart';

class _FakeStorage extends SecureStorageService {
  @override
  Future<String> getBaseUrl() async => 'https://example.test';
  @override
  Future<String?> getToken() async => 'mock-token';
}

class _DummyFcmService extends FcmNotificationService {
  _DummyFcmService() : super(ApiClient(customStorage: _FakeStorage()));
  @override
  Future<void> initialize() async {}
}

class _DummyReverbService extends ReverbRealtimeService {
  _DummyReverbService(ApiClient client) : super(client);
  @override
  Future<void> connect() async {}
  @override
  void Function() subscribe(
          String channelName, void Function(dynamic) onEvent) =>
      () {};
}

void main() {
  testWidgets(
      'OrbitMainShell starts on Home and centralizes back navigation before exit dialog',
      (tester) async {
    final storage = _FakeStorage();
    final api = ApiClient(customDio: Dio(), customStorage: storage);
    final reverb = _DummyReverbService(api);
    final fcm = _DummyFcmService();

    final user = UserModel(
      id: 1,
      name: 'Rosyad',
      email: 'rosyad@example.com',
      permissions: const [],
      modules: const {},
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          apiClientProvider.overrideWithValue(api),
          storageServiceProvider.overrideWithValue(storage),
          reverbServiceProvider.overrideWithValue(reverb),
          fcmNotificationServiceProvider.overrideWithValue(fcm),
          authProvider.overrideWith((ref) {
            final notifier = AuthNotifier(api, storage);
            notifier.state = AuthState(isAuthenticated: true, user: user);
            return notifier;
          }),
        ],
        child: MaterialApp(
          theme: OrbitTheme.lightTheme,
          home: const OrbitMainShell(),
        ),
      ),
    );

    await tester.pumpAndSettle();

    // Default screen is Home (Dashboard)
    final mainShellState =
        tester.state(find.byType(OrbitMainShell)) as dynamic;
    expect(mainShellState.currentIndex, isZero);

    // Switch to Inbox (tab index 1)
    await tester.tap(find.text('Inbox'));
    await tester.pumpAndSettle();
    expect(mainShellState.currentIndex, equals(1));

    // Simulate Android system back button press while on Inbox tab
    final dynamic widgetsAppState = tester.state(find.byType(WidgetsApp));
    await widgetsAppState.didPopRoute();
    await tester.pumpAndSettle();

    // Back from Inbox must centralize to Home (index 0)
    expect(mainShellState.currentIndex, isZero);

    // Press back again from Home (index 0) -> shows quit confirmation dialog
    await widgetsAppState.didPopRoute();
    await tester.pumpAndSettle();

    expect(find.text('Keluar dari Aplikasi?'), findsOneWidget);
    expect(
      find.text('Apakah Anda yakin ingin keluar dari aplikasi WorkHub?'),
      findsOneWidget,
    );
    expect(find.text('Batal'), findsOneWidget);
    expect(find.text('Keluar'), findsOneWidget);

    // Tapping Batal dismisses dialog and stays on Home
    await tester.tap(find.text('Batal'));
    await tester.pumpAndSettle();

    expect(find.text('Keluar dari Aplikasi?'), findsNothing);
    expect(mainShellState.currentIndex, isZero);
  });
}
