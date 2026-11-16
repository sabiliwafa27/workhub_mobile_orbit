import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:flutter/services.dart';
import '../../../core/network/api_client.dart';
import '../models/user_model.dart';

class PasskeyCancelledException implements Exception {
  final String message;
  const PasskeyCancelledException([this.message = 'Passkey prompt cancelled']);

  @override
  String toString() => message;
}

class PasskeyException implements Exception {
  final String message;
  const PasskeyException(this.message);

  @override
  String toString() => message;
}

abstract class PasskeyPlatformBridge {
  Future<String> createPasskey(String optionsJson);
  Future<String> getPasskey(String optionsJson);
}

class MethodChannelPasskeyBridge implements PasskeyPlatformBridge {
  static const MethodChannel _channel =
      MethodChannel('net.kecapsawi.workhub_mobile/passkeys');

  const MethodChannelPasskeyBridge();

  @override
  Future<String> createPasskey(String optionsJson) async {
    try {
      final result = await _channel.invokeMethod<String>(
        'createPasskey',
        {'optionsJson': optionsJson},
      );
      if (result == null || result.isEmpty) {
        throw const PasskeyException('Empty passkey registration response.');
      }
      return result;
    } on PlatformException catch (e) {
      if (e.code == 'CANCELLED') {
        throw PasskeyCancelledException(e.message ?? 'Cancelled');
      }
      throw PasskeyException(
        e.message ?? 'Unable to create passkey on this device.',
      );
    }
  }

  @override
  Future<String> getPasskey(String optionsJson) async {
    try {
      final result = await _channel.invokeMethod<String>(
        'getPasskey',
        {'optionsJson': optionsJson},
      );
      if (result == null || result.isEmpty) {
        throw const PasskeyException('Empty passkey assertion response.');
      }
      return result;
    } on PlatformException catch (e) {
      if (e.code == 'CANCELLED') {
        throw PasskeyCancelledException(e.message ?? 'Cancelled');
      }
      throw PasskeyException(
        e.message ?? 'Unable to sign in with passkey on this device.',
      );
    }
  }
}

class PasskeyService {
  final ApiClient _apiClient;
  final PasskeyPlatformBridge _bridge;

  PasskeyService(
    this._apiClient, {
    PasskeyPlatformBridge? bridge,
  }) : _bridge = bridge ?? const MethodChannelPasskeyBridge();

  static String _toBase64Url(String input) {
    return input
        .trim()
        .replaceAll('+', '-')
        .replaceAll('/', '_')
        .replaceAll(RegExp(r'=+$'), '');
  }

  static Map<String, dynamic> normalizeCreationOptions(
      Map<String, dynamic> raw) {
    final normalized = Map<String, dynamic>.from(raw);
    if (normalized['challenge'] is String) {
      normalized['challenge'] = _toBase64Url(normalized['challenge'] as String);
    }
    if (normalized['user'] is Map) {
      final user = Map<String, dynamic>.from(normalized['user'] as Map);
      if (user['id'] is String) {
        user['id'] = _toBase64Url(user['id'] as String);
      } else if (user['id'] != null) {
        user['id'] =
            _toBase64Url(base64UrlEncode(utf8.encode(user['id'].toString())));
      }
      normalized['user'] = user;
    }
    if (normalized['excludeCredentials'] is List) {
      normalized['excludeCredentials'] =
          (normalized['excludeCredentials'] as List)
              .whereType<Map>()
              .map((item) {
        final copy = Map<String, dynamic>.from(item);
        if (copy['id'] is String) {
          copy['id'] = _toBase64Url(copy['id'] as String);
        }
        return copy;
      }).toList();
    }
    return normalized;
  }

  static Map<String, dynamic> normalizeRequestOptions(
      Map<String, dynamic> raw) {
    final normalized = Map<String, dynamic>.from(raw);
    if (normalized['challenge'] is String) {
      normalized['challenge'] = _toBase64Url(normalized['challenge'] as String);
    }
    if (normalized['allowCredentials'] is List) {
      normalized['allowCredentials'] = (normalized['allowCredentials'] as List)
          .whereType<Map>()
          .map((item) {
        final copy = Map<String, dynamic>.from(item);
        if (copy['id'] is String) {
          copy['id'] = _toBase64Url(copy['id'] as String);
        }
        return copy;
      }).toList();
    }
    return normalized;
  }

  Future<({String token, UserModel user})> loginWithPasskey({
    bool rememberMe = true,
    String deviceName = 'WorkHub Flutter App',
  }) async {
    try {
      final optionsRes =
          await _apiClient.dio.post('/auth/passkeys/login/options');
      final body = optionsRes.data;
      final data = body is Map && body['data'] is Map
          ? Map<String, dynamic>.from(body['data'] as Map)
          : body is Map
              ? Map<String, dynamic>.from(body)
              : <String, dynamic>{};

      final challengeId = data['challenge_id']?.toString();
      final rawOptions = data['options'];
      if (challengeId == null ||
          challengeId.isEmpty ||
          rawOptions is! Map) {
        throw const PasskeyException(
            'Server returned invalid passkey login options.');
      }

      final options =
          normalizeRequestOptions(Map<String, dynamic>.from(rawOptions));
      final credentialJson = await _bridge.getPasskey(jsonEncode(options));
      final decoded = jsonDecode(credentialJson);
      if (decoded is! Map) {
        throw const PasskeyException('Invalid credential assertion format.');
      }
      final cred = Map<String, dynamic>.from(decoded);
      final responseMap = cred['response'] is Map
          ? Map<String, dynamic>.from(cred['response'] as Map)
          : <String, dynamic>{};

      final verifyRes = await _apiClient.dio.post(
        '/auth/passkeys/login/verify',
        data: {
          'challenge_id': challengeId,
          'credential': {
            'id': cred['id'],
            'rawId': cred['rawId'] ?? cred['id'],
            'type': cred['type'] ?? 'public-key',
            'response': {
              'clientDataJSON': responseMap['clientDataJSON'],
              'authenticatorData': responseMap['authenticatorData'],
              'signature': responseMap['signature'],
              if (responseMap['userHandle'] != null)
                'userHandle': responseMap['userHandle'],
            },
          },
          'remember_me': rememberMe,
          'device_name': deviceName,
        },
      );

      final verifyBody = verifyRes.data;
      final verifyData = verifyBody is Map && verifyBody['data'] is Map
          ? Map<String, dynamic>.from(verifyBody['data'] as Map)
          : verifyBody is Map
              ? Map<String, dynamic>.from(verifyBody)
              : <String, dynamic>{};

      final token = verifyData['token']?.toString();
      final userMap = verifyData['user'];
      if (token == null || token.isEmpty || userMap is! Map) {
        throw const PasskeyException(
            'Passkey verification succeeded but no session token was returned.');
      }

      return (
        token: token,
        user: UserModel.fromJson(Map<String, dynamic>.from(userMap)),
      );
    } on PasskeyCancelledException {
      rethrow;
    } on PasskeyException {
      rethrow;
    } on DioException catch (e) {
      final msg = e.response?.data is Map
          ? (e.response?.data['message']?.toString())
          : null;
      throw PasskeyException(
        msg != null && msg.isNotEmpty
            ? msg
            : 'Passkey sign-in failed. Please try again or use your password.',
      );
    }
  }

  Future<PasskeyCredentialModel> registerPasskey({
    required String name,
  }) async {
    try {
      final optionsRes =
          await _apiClient.dio.post('/auth/passkeys/register/options');
      final body = optionsRes.data;
      final data = body is Map && body['data'] is Map
          ? Map<String, dynamic>.from(body['data'] as Map)
          : body is Map
              ? Map<String, dynamic>.from(body)
              : <String, dynamic>{};

      final challengeId = data['challenge_id']?.toString();
      final rawOptions = data['options'];
      if (challengeId == null ||
          challengeId.isEmpty ||
          rawOptions is! Map) {
        throw const PasskeyException(
            'Server returned invalid passkey registration options.');
      }

      final options =
          normalizeCreationOptions(Map<String, dynamic>.from(rawOptions));
      final registrationJson = await _bridge.createPasskey(jsonEncode(options));
      final decoded = jsonDecode(registrationJson);
      if (decoded is! Map) {
        throw const PasskeyException('Invalid credential attestation format.');
      }
      final cred = Map<String, dynamic>.from(decoded);
      final responseMap = cred['response'] is Map
          ? Map<String, dynamic>.from(cred['response'] as Map)
          : <String, dynamic>{};

      final label = name.trim().isEmpty ? 'WorkHub Mobile' : name.trim();
      final verifyRes = await _apiClient.dio.post(
        '/auth/passkeys/register/verify',
        data: {
          'challenge_id': challengeId,
          'name': label,
          'credential': {
            'id': cred['id'],
            'rawId': cred['rawId'] ?? cred['id'],
            'type': cred['type'] ?? 'public-key',
            'response': {
              'clientDataJSON': responseMap['clientDataJSON'],
              'attestationObject': responseMap['attestationObject'],
              if (responseMap['transports'] != null)
                'transports': responseMap['transports'],
            },
          },
        },
      );

      final verifyBody = verifyRes.data;
      final verifyData = verifyBody is Map && verifyBody['data'] is Map
          ? Map<String, dynamic>.from(verifyBody['data'] as Map)
          : verifyBody is Map
              ? Map<String, dynamic>.from(verifyBody)
              : <String, dynamic>{};
      final passkeyMap = verifyData['passkey'] is Map
          ? Map<String, dynamic>.from(verifyData['passkey'] as Map)
          : verifyData;

      return PasskeyCredentialModel.fromJson(passkeyMap);
    } on PasskeyCancelledException {
      rethrow;
    } on PasskeyException {
      rethrow;
    } on DioException catch (e) {
      final msg = e.response?.data is Map
          ? (e.response?.data['message']?.toString())
          : null;
      throw PasskeyException(
        msg != null && msg.isNotEmpty
            ? msg
            : 'Unable to register passkey. Please try again.',
      );
    }
  }

  Future<List<PasskeyCredentialModel>> fetchPasskeys() async {
    final response = await _apiClient.dio.get('/auth/passkeys');
    final body = response.data;
    final dynamic list = body is Map && body['data'] is Map
        ? (body['data']['passkeys'] ?? body['data']['items'])
        : body is Map
            ? (body['data'] ?? body['passkeys'])
            : body;
    if (list is List) {
      return list
          .whereType<Map>()
          .map((e) =>
              PasskeyCredentialModel.fromJson(Map<String, dynamic>.from(e)))
          .toList();
    }
    return const [];
  }

  Future<void> deletePasskey(int passkeyId) async {
    try {
      await _apiClient.dio.delete('/auth/passkeys/$passkeyId');
    } on DioException catch (e) {
      final msg = e.response?.data is Map
          ? (e.response?.data['message']?.toString())
          : null;
      throw PasskeyException(
        msg != null && msg.isNotEmpty
            ? msg
            : 'Unable to remove passkey.',
      );
    }
  }
}
