import 'dart:convert';
import 'dart:typed_data';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:workhub_mobile/core/network/api_client.dart';
import 'package:workhub_mobile/core/services/fcm_notification_service.dart';
import 'package:workhub_mobile/core/storage/secure_storage_service.dart';

class _FakeStorage extends SecureStorageService {
  String? token;

  _FakeStorage({this.token});

  @override
  Future<String?> getToken() async => token;

  @override
  Future<String> getBaseUrl() async => 'https://orbit.kecapsawi.net';
}

class _MockHttpAdapter implements HttpClientAdapter {
  final List<RequestOptions> recordedRequests = [];
  int responseStatusCode = 200;
  Map<String, dynamic> responseBody = {'success': true};

  @override
  void close({bool force = false}) {}

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    recordedRequests.add(options);

    final encoded = utf8.encode(jsonEncode(responseBody));
    return ResponseBody.fromBytes(
      encoded,
      responseStatusCode,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('FcmNotificationService Tests', () {
    late _MockHttpAdapter mockAdapter;
    late _FakeStorage storage;
    late ApiClient apiClient;
    late FcmNotificationService fcmService;

    setUp(() {
      mockAdapter = _MockHttpAdapter();
      storage = _FakeStorage(token: 'test-auth-token-123');
      apiClient = ApiClient(
        customDio: Dio()..httpClientAdapter = mockAdapter,
        customStorage: storage,
      );
      fcmService = FcmNotificationService(apiClient, storage: storage);
    });

    test('Defers registration when user is not authenticated', () async {
      storage.token = null;
      final result = await fcmService.registerTokenWithBackend('mock-fcm-token');

      expect(result, isFalse);
      expect(mockAdapter.recordedRequests, isEmpty);
    });

    test('Defers registration when user token is empty string', () async {
      storage.token = '';
      final result = await fcmService.registerTokenWithBackend('mock-fcm-token');

      expect(result, isFalse);
      expect(mockAdapter.recordedRequests, isEmpty);
    });

    test('Rejects invalid token (empty or too long)', () async {
      final resultEmpty = await fcmService.registerTokenWithBackend('');
      expect(resultEmpty, isFalse);

      final tooLongToken = 'a' * 4097;
      final resultTooLong = await fcmService.registerTokenWithBackend(tooLongToken);
      expect(resultTooLong, isFalse);
      expect(mockAdapter.recordedRequests, isEmpty);
    });

    test('Registers FCM token with platform: "android" when authenticated', () async {
      final sampleToken = 'eXampleFcmToken_1234567890';
      final result = await fcmService.registerTokenWithBackend(sampleToken);

      expect(result, isTrue);
      expect(mockAdapter.recordedRequests.length, 1);

      final req = mockAdapter.recordedRequests.first;
      // ApiClient transforms /fcm-device-tokens to /api/v1/fcm-device-tokens
      expect(req.path, '/api/v1/fcm-device-tokens');
      expect(req.method, 'POST');

      // Verify payload
      expect(req.data, isA<Map<String, dynamic>>());
      final data = req.data as Map<String, dynamic>;
      expect(data['token'], sampleToken);
      expect(data['platform'], 'android');
      // Ensure 'device_type' is not sent
      expect(data.containsKey('device_type'), isFalse);

      // Verify Authorization header
      expect(req.headers['Authorization'], 'Bearer test-auth-token-123');
    });

    test('Handles HTTP 422 Unprocessable Entity and logs validation errors safely', () async {
      mockAdapter.responseStatusCode = 422;
      mockAdapter.responseBody = {
        'message': 'The platform field is required.',
        'errors': {
          'platform': ['The platform field is required.'],
        },
      };

      final logs = <String>[];
      final originalDebugPrint = debugPrint;
      debugPrint = (String? message, {int? wrapWidth}) {
        if (message != null) logs.add(message);
      };

      final sampleToken = 'super_secret_fcm_token_value';
      final result = await fcmService.registerTokenWithBackend(sampleToken);

      debugPrint = originalDebugPrint;

      expect(result, isFalse);
      expect(mockAdapter.recordedRequests.length, 1);

      // Check log output
      final allLogs = logs.join('\n');
      expect(allLogs, contains('HTTP 422'));
      expect(allLogs, contains('The platform field is required.'));
      expect(allLogs, contains('Validation errors:'));

      // Crucial security requirement: NEVER print the token or Authorization header
      expect(allLogs.contains(sampleToken), isFalse);
      expect(allLogs.toLowerCase().contains('bearer'), isFalse);
      expect(allLogs.contains('test-auth-token-123'), isFalse);
    });
  });
}
