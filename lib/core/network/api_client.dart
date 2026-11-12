import 'package:dio/dio.dart';
import 'package:uuid/uuid.dart';
import '../storage/secure_storage_service.dart';

class ApiClient {
  final Dio dio;
  final SecureStorageService storage;

  ApiClient({Dio? customDio, SecureStorageService? customStorage})
      : dio = customDio ?? Dio(),
        storage = customStorage ?? SecureStorageService() {
    _initDio();
  }

  void _initDio() {
    dio.options.connectTimeout = const Duration(seconds: 15);
    dio.options.receiveTimeout = const Duration(seconds: 20);
    dio.options.headers = {
      'Accept': 'application/json',
      'Content-Type': 'application/json',
    };

    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) async {
          // Dynamic baseUrl resolution
          if (options.baseUrl.isEmpty) {
            options.baseUrl = await storage.getBaseUrl();
          }

          // Ensure proper path prefixing for standard API routes
          var path = options.path;
          if (!path.startsWith('/')) {
            path = '/$path';
          }
          if (!path.startsWith('/api/') && !path.startsWith('/inbox/')) {
            if (path.startsWith('/auth') ||
                path.startsWith('/conversations') ||
                path.startsWith('/visit') ||
                path.startsWith('/check-ins') ||
                path.startsWith('/sales-orders') ||
                path.startsWith('/realtime') ||
                path.startsWith('/fcm-device-tokens')) {
              path = '/api/v1$path';
            }
          }
          options.path = path;

          // Attach Bearer Token
          final token = await storage.getToken();
          if (token != null && token.isNotEmpty) {
            options.headers['Authorization'] = 'Bearer $token';
          }

          // Idempotency-Key header for sensitive POST mutations
          if (options.method.toUpperCase() == 'POST') {
            if (path.contains('/check-ins') || path.contains('/sales-orders')) {
              options.headers.putIfAbsent(
                'Idempotency-Key',
                () => const Uuid().v4(),
              );
            }
          }

          return handler.next(options);
        },
        onError: (DioException error, handler) async {
          if (error.response?.statusCode == 401) {
            // Unauthorized - clear token
            await storage.clearToken();
          }
          return handler.next(error);
        },
      ),
    );
  }
}
