import 'dart:convert';
import 'dart:typed_data';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:workhub_mobile/core/network/api_client.dart';
import 'package:workhub_mobile/core/storage/secure_storage_service.dart';
import 'package:workhub_mobile/core/theme/orbit_theme.dart';
import 'package:workhub_mobile/features/auth/models/user_model.dart';
import 'package:workhub_mobile/features/auth/providers/auth_provider.dart';
import 'package:workhub_mobile/features/auth/screens/login_screen.dart';
import 'package:workhub_mobile/features/auth/screens/profile_screen.dart';
import 'package:workhub_mobile/features/auth/services/passkey_service.dart';

class _FakeStorage extends SecureStorageService {
  String? savedToken;

  @override
  Future<void> saveToken(String token) async {
    savedToken = token;
  }

  @override
  Future<String?> getToken() async => savedToken;

  @override
  Future<void> clearToken() async {
    savedToken = null;
  }

  @override
  Future<String> getBaseUrl() async => 'https://orbit.kecapsawi.net';
}

class _FakePasskeyBridge implements PasskeyPlatformBridge {
  String? lastRequestOptionsJson;
  String? lastCreationOptionsJson;

  @override
  Future<String> getPasskey(String optionsJson) async {
    lastRequestOptionsJson = optionsJson;
    return jsonEncode({
      'id': 'cred-login-1',
      'rawId': 'cred-login-1',
      'type': 'public-key',
      'response': {
        'clientDataJSON': 'eyJ0eXBlIjoid2ViYXV0aG4uZ2V0In0',
        'authenticatorData': 'SZYN5YgOJGh0NBcPZHZgW4_krbk',
        'signature': 'MEQCID6K-kL',
        'userHandle': 'NDI',
      },
    });
  }

  @override
  Future<String> createPasskey(String optionsJson) async {
    lastCreationOptionsJson = optionsJson;
    return jsonEncode({
      'id': 'cred-reg-2',
      'rawId': 'cred-reg-2',
      'type': 'public-key',
      'response': {
        'clientDataJSON': 'eyJ0eXBlIjoid2ViYXV0aG4uY3JlYXRlIn0',
        'attestationObject': 'o2NmbXRkbm9uZQ',
        'transports': ['internal'],
      },
    });
  }
}

class _PasskeyAndSummaryAdapter implements HttpClientAdapter {
  final List<RequestOptions> requests = [];
  final List<Map<String, dynamic>> passkeys = [
    {
      'id': 10,
      'name': 'Pixel 9a Biometric',
      'created_at': '2026-11-16T08:00:00Z',
    },
  ];

  @override
  void close({bool force = false}) {}

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requests.add(options);
    Map<String, dynamic> payload = {'data': {}};
    int statusCode = 200;

    if (options.path == '/api/v1/auth/passkeys/login/options') {
      payload = {
        'data': {
          'challenge_id': 'chal-login-123',
          'expires_in': 120,
          'options': {
            'challenge': 'dGVzdGNoYWxsZW5nZQ==',
            'timeout': 60000,
            'rpId': 'orbit.kecapsawi.net',
            'allowCredentials': [],
            'userVerification': 'required',
          },
        },
      };
    } else if (options.path == '/api/v1/auth/passkeys/login/verify') {
      payload = {
        'data': {
          'token': '2|sanctum-passkey-token',
          'token_type': 'Bearer',
          'user': {
            'id': 42,
            'name': 'Budi Santosa',
            'preferred_name': 'Budi',
            'email': 'budi@kecapsawi.net',
            'passkeys': passkeys,
          },
        },
      };
    } else if (options.path == '/api/v1/auth/passkeys/register/options') {
      payload = {
        'data': {
          'challenge_id': 'chal-reg-456',
          'expires_in': 120,
          'options': {
            'challenge': 'cmVnY2hhbGxlbmdl==',
            'rp': {'name': 'Orbit WorkHub', 'id': 'orbit.kecapsawi.net'},
            'user': {
              'id': 'NDI=',
              'name': 'budi@kecapsawi.net',
              'displayName': 'Budi Santosa',
            },
            'pubKeyCredParams': [
              {'type': 'public-key', 'alg': -7},
            ],
          },
        },
      };
    } else if (options.path == '/api/v1/auth/passkeys/register/verify') {
      final created = {
        'id': 11,
        'name': 'My Work Phone',
        'created_at': '2026-11-16T09:30:00Z',
      };
      passkeys.add(created);
      payload = {
        'data': {'passkey': created},
      };
    } else if (options.path == '/api/v1/auth/passkeys' &&
        options.method == 'GET') {
      payload = {
        'data': {'passkeys': passkeys},
      };
    } else if (options.path.startsWith('/api/v1/auth/passkeys/') &&
        options.method == 'DELETE') {
      final id = int.tryParse(options.path.split('/').last);
      passkeys.removeWhere((p) => p['id'] == id);
      payload = {'message': 'Passkey removed successfully'};
    } else if (options.path == '/api/v1/auth/me') {
      payload = {
        'data': {
          'user': {
            'id': 42,
            'name': 'Budi Santosa',
            'preferred_name': 'Budi',
            'email': 'budi@kecapsawi.net',
            'passkeys': passkeys,
          },
        },
      };
    } else if (options.path == '/workhub/api/v1/tasks/79/ai-summary') {
      statusCode = 202;
      payload = {
        'task_id': 79,
        'generation_id': 'gen-uuid-79',
        'state': 'queued',
        'pending': true,
      };
    } else if (options.path == '/workhub/api/v1/tasks/79/ai-summary/status') {
      payload = {
        'task_id': 79,
        'generation_id': options.queryParameters['generation_id'],
        'state': 'completed',
        'pending': false,
        'summary': 'Overview\nTask #79 is on track.',
      };
    }

    return ResponseBody.fromString(
      jsonEncode(payload),
      statusCode,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }
}

void main() {
  test('ApiClient routes Jarvis AI summary to /workhub/api/v1/tasks/{id}/ai-summary',
      () async {
    final adapter = _PasskeyAndSummaryAdapter();
    final storage = _FakeStorage()..savedToken = 'test-token';
    final api = ApiClient(
      customDio: Dio()..httpClientAdapter = adapter,
      customStorage: storage,
    );

    final dispatch = await api.dio.post('/tasks/79/ai-summary');
    expect(dispatch.statusCode, 202);
    expect(dispatch.data['generation_id'], 'gen-uuid-79');

    final status = await api.dio.get(
      '/tasks/79/ai-summary/status',
      queryParameters: {'generation_id': 'gen-uuid-79'},
    );
    expect(status.statusCode, 200);
    expect(status.data['summary'], contains('Task #79 is on track.'));
    expect(
      adapter.requests.map((r) => r.path).toList(),
      [
        '/workhub/api/v1/tasks/79/ai-summary',
        '/workhub/api/v1/tasks/79/ai-summary/status',
      ],
    );
  });

  test('PasskeyService completes login, registration, list, and delete flows',
      () async {
    final adapter = _PasskeyAndSummaryAdapter();
    final storage = _FakeStorage();
    final api = ApiClient(
      customDio: Dio()..httpClientAdapter = adapter,
      customStorage: storage,
    );
    final bridge = _FakePasskeyBridge();
    final service = PasskeyService(api, bridge: bridge);

    final loginResult = await service.loginWithPasskey(rememberMe: true);
    expect(loginResult.token, '2|sanctum-passkey-token');
    expect(loginResult.user.name, 'Budi Santosa');
    expect(loginResult.user.passkeys.length, 1);
    expect(
      jsonDecode(bridge.lastRequestOptionsJson!)['challenge'],
      'dGVzdGNoYWxsZW5nZQ',
    );

    final created = await service.registerPasskey(name: 'My Work Phone');
    expect(created.id, 11);
    expect(created.name, 'My Work Phone');

    final listed = await service.fetchPasskeys();
    expect(listed.length, 2);

    await service.deletePasskey(10);
    final afterDelete = await service.fetchPasskeys();
    expect(afterDelete.map((p) => p.id).toList(), [11]);
  });

  testWidgets('LoginScreen signs in with passkey button', (tester) async {
    final adapter = _PasskeyAndSummaryAdapter();
    final storage = _FakeStorage();
    final api = ApiClient(
      customDio: Dio()..httpClientAdapter = adapter,
      customStorage: storage,
    );
    final bridge = _FakePasskeyBridge();
    final service = PasskeyService(api, bridge: bridge);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          storageServiceProvider.overrideWithValue(storage),
          apiClientProvider.overrideWithValue(api),
          passkeyServiceProvider.overrideWithValue(service),
        ],
        child: MaterialApp(
          theme: OrbitTheme.lightTheme,
          home: const LoginScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final passkeyButton = find.text('Sign in with Passkey');
    expect(passkeyButton, findsOneWidget);

    await tester.tap(passkeyButton);
    await tester.pumpAndSettle();

    expect(storage.savedToken, '2|sanctum-passkey-token');
  });

  testWidgets('ProfileScreen displays passkeys and registers a new passkey',
      (tester) async {
    final adapter = _PasskeyAndSummaryAdapter();
    final storage = _FakeStorage()..savedToken = '2|sanctum-passkey-token';
    final api = ApiClient(
      customDio: Dio()..httpClientAdapter = adapter,
      customStorage: storage,
    );
    final bridge = _FakePasskeyBridge();
    final service = PasskeyService(api, bridge: bridge);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          storageServiceProvider.overrideWithValue(storage),
          apiClientProvider.overrideWithValue(api),
          passkeyServiceProvider.overrideWithValue(service),
        ],
        child: MaterialApp(
          theme: OrbitTheme.lightTheme,
          home: const ProfileScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('SECURITY & PASSKEYS'), findsOneWidget);
    expect(find.text('Pixel 9a Biometric'), findsOneWidget);

    await tester.ensureVisible(find.text('Add'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Add'));
    await tester.pumpAndSettle();

    expect(find.text('Register Passkey'), findsOneWidget);
    await tester.enterText(find.byType(TextFormField), 'My Work Phone');
    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();

    expect(find.text('My Work Phone'), findsOneWidget);
    expect(find.text('Passkey registered successfully.'), findsOneWidget);
  });
}
