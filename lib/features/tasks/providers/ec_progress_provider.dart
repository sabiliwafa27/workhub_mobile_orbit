import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../auth/providers/auth_provider.dart';

final ecProgressProvider = FutureProvider.family<Map<String, dynamic>, int>((ref, page) async {
  final response = await ref.watch(apiClientProvider).dio.get('/ec/today/current', queryParameters: {'page': page});
  if (response.data is! Map || response.data['data'] is! List) {
    throw const FormatException('Unexpected EC response');
  }
  return Map<String, dynamic>.from(response.data as Map);
});
