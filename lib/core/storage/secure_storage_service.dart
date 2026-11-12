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
    final customUrl = await _storage.read(key: ApiConstants.baseUrlKey);
    if (customUrl != null && customUrl.isNotEmpty) {
      // Strip trailing /api/v1 or trailing slashes so baseUrl is strictly the root host origin
      var cleaned = customUrl.replaceAll(RegExp(r'/api/v1/?$'), '').replaceAll(RegExp(r'/+$'), '');
      if (cleaned.contains('10.11.2.49') || cleaned.contains('rosyad-erplab')) {
        cleaned = ApiConstants.defaultBaseUrl;
      }
      return cleaned;
    }
    return ApiConstants.defaultBaseUrl;
  }
}
