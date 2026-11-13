import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:dio/dio.dart';
import 'package:workhub_mobile/core/network/api_client.dart';
import 'package:workhub_mobile/core/storage/secure_storage_service.dart';
import 'package:workhub_mobile/features/auth/providers/auth_provider.dart';
import 'package:workhub_mobile/features/auth/screens/login_screen.dart';
import 'package:workhub_mobile/main.dart';

class _Storage extends SecureStorageService {
  @override
  Future<String?> getToken() async => null;
}

void main() {
  testWidgets('WorkHub starts at login when there is no authenticated user', (tester) async {
    await tester.pumpWidget(ProviderScope(
      overrides: [
        storageServiceProvider.overrideWithValue(_Storage()),
        apiClientProvider.overrideWithValue(ApiClient(customDio: Dio(), customStorage: _Storage())),
      ],
      child: const WorkHubApp(),
    ));
    await tester.pumpAndSettle();

    expect(find.byType(LoginScreen), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
