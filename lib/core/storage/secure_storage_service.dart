import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../constants/api_constants.dart';

class SecureStorageService {
  final FlutterSecureStorage _storage = const FlutterSecureStorage();

  Future<void> saveToken(String token) async {
    await _storage.write(key: ApiConstants.tokenKey, value: token);
  }

  Future<String?> getToken() async {
    return await _storage.read(key: ApiConstants.tokenKey);
  }

  Future<void> clearToken() async {
    await _storage.delete(key: ApiConstants.tokenKey);
  }

  Future<void> saveBaseUrl(String url) async {
    await _storage.write(key: ApiConstants.baseUrlKey, value: url);
  }

  Future<String> getBaseUrl() async {
    try {
      final migrated = await _storage.read(
        key: ApiConstants.baseUrlMigrationKey,
      );
      if (migrated != 'true') {
        await _storage.delete(key: ApiConstants.baseUrlKey);
        await _storage.write(
          key: ApiConstants.baseUrlMigrationKey,
          value: 'true',
        );
      }
    } catch (_) {
      // Always use the production host if a legacy URL cannot be migrated.
    }
    return ApiConstants.defaultBaseUrl;
  }
}
