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
    return customUrl ?? ApiConstants.defaultBaseUrl;
  }
}
