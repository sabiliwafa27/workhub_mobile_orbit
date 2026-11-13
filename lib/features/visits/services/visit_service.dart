import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../../../core/network/api_client.dart';
import '../../auth/providers/auth_provider.dart';
import '../models/visit_target_model.dart';

final visitServiceProvider = Provider<VisitService>((ref) {
  final apiClient = ref.watch(apiClientProvider);
  return VisitService(apiClient);
});

final visitTargetsNotifierProvider =
    FutureProvider<List<VisitTargetModel>>((ref) async {
  final service = ref.watch(visitServiceProvider);
  return await service.getVisitTargets();
});

class VisitService {
  final ApiClient _apiClient;

  VisitService(this._apiClient);

  Future<Map<String, dynamic>?> getVisitContext() async {
    try {
      final response = await _apiClient.dio.get('/visit-context');
      if (response.data is Map && response.data['data'] is Map) {
        return response.data['data'] as Map<String, dynamic>;
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  Future<List<VisitTargetModel>> getVisitTargets(
      {String? date, String status = 'all'}) async {
    try {
      final queryParams = <String, dynamic>{'status': status};
      if (date != null && date.isNotEmpty) {
        queryParams['date'] = date;
      }

      final response = await _apiClient.dio
          .get('/visit-targets', queryParameters: queryParams);
      if (response.data is Map && response.data['data'] is List) {
        final list = response.data['data'] as List;
        return list
            .map((json) =>
                VisitTargetModel.fromJson(json as Map<String, dynamic>))
            .toList();
      }
      return [];
    } catch (_) {
      return [];
    }
  }

  Future<bool> checkIn({
    required String visitTargetUuid,
    required double latitude,
    required double longitude,
    required String photoPath,
    String? note,
  }) async {
    try {
      final formData = FormData.fromMap({
        'visit_target_uuid': visitTargetUuid,
        'request_uuid': const Uuid().v4(),
        'latitude': latitude,
        'longitude': longitude,
        'client_captured_at': DateTime.now().toIso8601String(),
        if (note != null && note.isNotEmpty) 'note': note,
        'photo': await MultipartFile.fromFile(photoPath,
            filename: 'checkin_evidence.jpg'),
      });

      final response = await _apiClient.dio.post('/check-ins', data: formData);
      return response.statusCode == 200 || response.statusCode == 201;
    } catch (_) {
      return false;
    }
  }
}
