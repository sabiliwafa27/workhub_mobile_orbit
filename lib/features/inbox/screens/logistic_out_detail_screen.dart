import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/orbit_theme.dart';
import '../../auth/providers/auth_provider.dart';

typedef _DetailKey = ({String stage, int id});

final _detailProvider = FutureProvider.autoDispose.family<Map<String, dynamic>, _DetailKey>((ref, key) async {
  final response = await ref.watch(apiClientProvider).dio.get('/inbox/api/logistic-out/${key.stage}/${key.id}');
  final data = response.data;
  if (data is! Map || data['detail'] is! Map) throw const FormatException('Unexpected Logistic Out response');
  return Map<String, dynamic>.from(data);
});

Object? _at(Object? value, List<String> path) {
  for (final key in path) {
    if (value is! Map) return null;
    value = value[key];
  }
  return value;
}

class LogisticOutDetailScreen extends ConsumerWidget {
  final String stage;
  final int subjectId;
  const LogisticOutDetailScreen({super.key, required this.stage, required this.subjectId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final key = (stage: stage, id: subjectId);
    return Scaffold(
      appBar: AppBar(title: const Text('Logistic Out')),
      body: ref.watch(_detailProvider(key)).when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, __) => Center(child: TextButton(onPressed: () => ref.invalidate(_detailProvider(key)), child: const Text('Unable to load details. Tap to retry.'))),
        data: (payload) {
          final detail = payload['detail'] as Map;
          final header = detail['header'];
          final trip = detail['trip'];
          final transport = _at(header, ['warehouse_process', 'transport']) ?? detail['transport'];
          final members = detail['members'] is List ? detail['members'] as List : const [];
          final items = payload['kind'] == 'trip'
              ? members.whereType<Map>().expand((member) => member['items'] is List ? member['items'] as List : const []).toList()
              : detail['items'] is List ? detail['items'] as List : const [];
          Widget field(String label, Object? value) => value == null || value.toString().trim().isEmpty
              ? const SizedBox.shrink()
              : ListTile(contentPadding: EdgeInsets.zero, title: Text(label), subtitle: Text(value.toString()));
          return ListView(padding: const EdgeInsets.all(16), children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: OrbitColors.cardSurface,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: OrbitColors.cardBorder),
              ),
              child: Row(children: [
                const CircleAvatar(radius: 26, backgroundColor: OrbitColors.bubbleBlue,
                    child: Icon(Icons.local_shipping_outlined, color: OrbitColors.primaryNavy)),
                const SizedBox(width: 14),
                Expanded(child: Text('Logistic Out Overview',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w800, color: OrbitColors.textNavy))),
              ]),
            ),
            const SizedBox(height: 12),
            field('Status', _at(header, ['status_name']) ?? _at(trip, ['status_name'])),
            field('Purchase order', _at(header, ['display_reference'])),
            field('Requester', _at(header, ['requester', 'branch_name'])),
            field('Supplier', _at(header, ['supplier', 'branch_name'])),
            field('Request date', _at(header, ['request_date'])),
            field('Loading date', _at(header, ['loading_date'])),
            field('Shipping method', _at(header, ['central_approval', 'shipping_method_name']) ?? _at(trip, ['transport_method'])),
            field('Vehicle type', _at(header, ['requested_vehicle_type', 'vehicle_type_code']) ?? _at(trip, ['planned_vehicle_type', 'code'])),
            field('License plate', _at(transport, ['internal', 'license_plate']) ?? _at(transport, ['expedition', 'license_plate'])),
            field('Driver', _at(transport, ['internal', 'driver_full_name']) ?? _at(transport, ['expedition', 'driver_full_name'])),
            field('Helper', _at(transport, ['internal', 'helper_full_name'])),
            field('Seal number', _at(transport, ['internal', 'seal_number']) ?? _at(transport, ['expedition', 'seal_number'])),
            if (members.isNotEmpty) ...[
              const Divider(), Text('Purchase orders', style: Theme.of(context).textTheme.titleMedium),
              for (final member in members.whereType<Map>()) field('Purchase order', member['display_reference'] ?? member['logistic_out_id']),
            ],
            if (items.isNotEmpty) ...[
              const Divider(), Text('Items', style: Theme.of(context).textTheme.titleMedium),
              for (final item in items.whereType<Map>()) ListTile(contentPadding: EdgeInsets.zero,
                title: Text((item['item_name'] ?? item['product_name'] ?? item['name'] ?? 'Item').toString()),
                subtitle: Text((item['quantity'] ?? item['qty'] ?? '').toString())),
            ],
          ]);
        },
      ),
    );
  }
}
