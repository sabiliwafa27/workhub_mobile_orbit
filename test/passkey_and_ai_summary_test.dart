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
import 'package:workhub_mobile/features/tasks/screens/task_detail_screen.dart';

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
            'profile_photo_url': null,
            'passkeys': passkeys,
            'employee': {
              'id': 101,
              'full_name': 'Budi Santosa',
              'preferred_name': 'Budi',
              'photo_url':
                  'https://orbit.kecapsawi.net/storage/employees/photos/budi.webp',
              'primary_role': {'name': 'Field Sales Supervisor'},
              'department': {'name': 'Commercial Operations'},
            },
          },
        },
      };
    } else if (options.path == '/api/v1/auth/my-profile') {
      payload = {
        'data': {
          'has_linked_employee': true,
          'employee_id': 101,
          'user': {
            'id': 42,
            'name': 'Budi Santosa',
            'preferred_name': 'Budi',
            'email': 'budi@kecapsawi.net',
            'profile_photo_url':
                'https://orbit.kecapsawi.net/storage/employees/photos/budi.webp',
            'passkeys': passkeys,
          },
          'employee': {
            'id': 101,
            'full_name': 'Budi Santosa',
            'preferred_name': 'Budi',
            'employee_code': 'EMP-0101',
            'photo_url':
                'https://orbit.kecapsawi.net/storage/employees/photos/budi.webp',
            'organization': {'name': 'PT Kecap Sawi'},
            'department': {'name': 'Commercial Operations'},
            'branch': {'name': 'Kediri HQ'},
            'bank': {'name': 'BCA'},
            'bank_account_number': '1234567890',
            'status': {'name': 'Active'},
            'manager': {'full_name': 'Hendra Wijaya'},
            'primaryRole': {'name': 'Field Sales Supervisor'},
            'responsibleHr': {'full_name': 'Siti Rahma'},
            'timeOffApprover': {'full_name': 'Hendra Wijaya'},
            'attendanceApprover': {'full_name': 'Siti Rahma'},
            'directReports': [
              {'full_name': 'Andi Pratama'},
              {'full_name': 'Rina Sari'},
            ],
            'skills': [
              {'name': 'Key Account Management', 'level': 'Advanced'},
            ],
            'certifications': [
              {'name': 'FMCG Sales Excellence', 'issuer': 'Orbit Academy'},
            ],
            'educations': [
              {'institution': 'Universitas Brawijaya', 'degree': 'S1 Manajemen'},
            ],
            'assignmentHistories': [
              {'role_name': 'Area Sales Executive', 'department': 'East Java'},
            ],
            'documents': [
              {'document_name': 'Employment Contract 2026'},
            ],
            'resumes': [
              {'title': 'Budi Santosa CV'},
            ],
            'testResults': [
              {'name': 'Leadership Assessment', 'score': '92'},
            ],
            'notesHistory': [
              {'note': 'Promoted to supervisor Q3'},
            ],
            'salesSchedule': [
              {'day': 'Monday', 'status': 'Kediri North Route'},
            ],
          },
        },
      };
    } else if (options.path == '/api/v1/auth/login-background') {
      payload = {
        'data': {
          'webp_url':
              'https://orbit.kecapsawi.net/login-desktop.webp?v=1793582708',
          'jpg_url':
              'https://orbit.kecapsawi.net/login-desktop.jpg?v=1793582708',
          'direct_webp_url':
              'https://orbit.kecapsawi.net/images/auth/login-desktop.webp?v=1793582708',
          'version': '1793582708',
          'updated_at': '2026-11-02T01:25:08+00:00',
        },
      };
    } else if (options.path == '/workhub/api/v1/tasks/79/payload') {
      payload = {
        'task': {
          'id': 79,
          'title': 'Prepare Monthly Orbit Report',
          'status': 'in_progress',
          'description': 'Compile field sales metrics.',
          'assignees': [],
        },
      };
    } else if (options.path.contains('/collaboration/') ||
        options.path.contains('/comments')) {
      payload = {
        'data': {
          'subject': {'can_comment': false},
          'comments': [],
          'pagination': {'has_older': false},
        },
      };
    } else if (options.path == '/workhub/api/v1/tasks/80/payload') {
      payload = {
        'task': {
          'id': 80,
          'title': 'Audit East Java Warehouse',
          'status': 'in_progress',
          'progress_percent': 65,
          'priority': 'high',
          'due_date': '2026-11-20',
          'description': 'Verify stock levels in East Java warehouse.',
          'assignees': [
            {
              'unassigned_at': null,
              'employee': {'full_name': 'Budi Santosa'},
            },
          ],
        },
      };
    } else if (options.path == '/workhub/api/v1/tasks/80/ai-summary' ||
        options.path == '/workhub/api/v1/tasks/80/ai-summary/status' ||
        options.path == '/workhub/tasks/80/ai-summary/status') {
      statusCode = options.method == 'POST' ? 202 : 200;
      payload = {
        'task_id': 80,
        'generation_id': 'gen-uuid-80',
        'state': 'queued',
        'pending': true,
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

    await tester.scrollUntilVisible(
      find.text('Add'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
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

  testWidgets(
      'LoginScreen fetches /auth/login-background and ProfileScreen renders full /auth/my-profile employee data and photo fallback',
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
          home: const LoginScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      adapter.requests.any((r) => r.path == '/api/v1/auth/login-background'),
      isTrue,
    );
    expect(
      find.byKey(const ValueKey(
        'login-bg-https://orbit.kecapsawi.net/login-desktop.webp?v=1793582708',
      )),
      findsOneWidget,
    );

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

    expect(
      adapter.requests.any((r) => r.path == '/api/v1/auth/my-profile'),
      isTrue,
    );
    expect(find.text('Field Sales Supervisor'), findsWidgets);
    expect(find.text('Commercial Operations'), findsWidgets);
    expect(find.text('PT Kecap Sawi'), findsOneWidget);
    expect(find.text('Kediri HQ'), findsOneWidget);
    expect(find.text('Hendra Wijaya'), findsWidgets);
    expect(find.text('Siti Rahma'), findsWidgets);
    expect(find.text('Andi Pratama, Rina Sari'), findsOneWidget);
    expect(find.text('Key Account Management • Advanced'), findsOneWidget);
    expect(
      find.text('FMCG Sales Excellence • Orbit Academy'),
      findsOneWidget,
    );
    expect(
      find.text('Universitas Brawijaya • S1 Manajemen'),
      findsOneWidget,
    );
    expect(
      find.text('Area Sales Executive • East Java'),
      findsOneWidget,
    );
    expect(find.text('Employment Contract 2026'), findsOneWidget);
    expect(find.text('Budi Santosa CV'), findsOneWidget);
    expect(find.text('Leadership Assessment • 92'), findsOneWidget);
    expect(find.text('Promoted to supervisor Q3'), findsOneWidget);
    expect(find.text('Monday • Kediri North Route'), findsOneWidget);
  });

  testWidgets('TaskDetailScreen renders Jarvis AI summary sections when ready',
      (tester) async {
    final adapter = _PasskeyAndSummaryAdapter();
    final storage = _FakeStorage()..savedToken = '2|sanctum-passkey-token';
    final api = ApiClient(
      customDio: Dio()..httpClientAdapter = adapter,
      customStorage: storage,
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          storageServiceProvider.overrideWithValue(storage),
          apiClientProvider.overrideWithValue(api),
        ],
        child: MaterialApp(
          theme: OrbitTheme.lightTheme,
          home: const TaskDetailScreen(taskId: 79),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Jarvis AI Summary'), findsOneWidget);
    expect(find.text('Overview'), findsOneWidget);
    expect(find.text('Task #79 is on track.'), findsOneWidget);
  });

  testWidgets(
      'TaskDetailScreen synthesizes structured Jarvis summary when backend stays queued',
      (tester) async {
    final adapter = _PasskeyAndSummaryAdapter();
    final storage = _FakeStorage()..savedToken = '2|sanctum-passkey-token';
    final api = ApiClient(
      customDio: Dio()..httpClientAdapter = adapter,
      customStorage: storage,
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          storageServiceProvider.overrideWithValue(storage),
          apiClientProvider.overrideWithValue(api),
        ],
        child: MaterialApp(
          theme: OrbitTheme.lightTheme,
          home: const TaskDetailScreen(taskId: 80),
        ),
      ),
    );
    for (var i = 0; i < 8; i++) {
      await tester.pump(const Duration(seconds: 2));
    }
    await tester.pumpAndSettle();

    expect(find.text('Jarvis AI Summary'), findsOneWidget);
    expect(find.text('Overview'), findsOneWidget);
    expect(find.text('Progress'), findsOneWidget);
    expect(find.text('Comments Summary'), findsOneWidget);
    expect(
      find.textContaining('Verify stock levels in East Java warehouse.'),
      findsWidgets,
    );
  });
}
