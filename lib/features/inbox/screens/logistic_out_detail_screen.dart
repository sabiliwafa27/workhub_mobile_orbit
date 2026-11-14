import 'package:flutter/material.dart';
import '../../../core/widgets/orbit_workspace.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/orbit_theme.dart';
import '../../auth/providers/auth_provider.dart';

typedef _DetailKey = ({String stage, int id});

final _detailProvider = FutureProvider.autoDispose
    .family<Map<String, dynamic>, _DetailKey>((ref, key) async {
  final response = await ref
      .watch(apiClientProvider)
      .dio
      .get('/inbox/api/logistic-out/${key.stage}/${key.id}');
  final data = response.data;
  if (data is! Map || data['detail'] is! Map)
    throw const FormatException('Unexpected Logistic Out response');
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
  const LogisticOutDetailScreen(
      {super.key, required this.stage, required this.subjectId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final key = (stage: stage, id: subjectId);
    return OrbitWorkspaceScaffold(
      subtitle: 'Dispatch details & transport',
      appBar: AppBar(title: const Text('Logistic Out')),
      body: ref.watch(_detailProvider(key)).when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (_, __) => Center(
                child: TextButton(
                    onPressed: () => ref.invalidate(_detailProvider(key)),
                    child:
                        const Text('Unable to load details. Tap to retry.'))),
            data: (payload) {
              final detail = payload['detail'] as Map;
              final header = detail['header'];
              final trip = detail['trip'];
              final transport =
                  _at(header, ['warehouse_process', 'transport']) ??
                      detail['transport'];
              final members = detail['members'] is List
                  ? detail['members'] as List
                  : const [];
              final items = payload['kind'] == 'trip'
                  ? members
                      .whereType<Map>()
                      .expand((member) => member['items'] is List
                          ? member['items'] as List
                          : const [])
                      .toList()
                  : detail['items'] is List
                      ? detail['items'] as List
                      : const [];
              Widget field(String label, Object? value) =>
                  value == null || value.toString().trim().isEmpty
                      ? const SizedBox.shrink()
                      : ListTile(
                          contentPadding: EdgeInsets.zero,
                          visualDensity: VisualDensity.compact,
                          title: Text(
                            label,
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: OrbitColors.textSecondary,
                            ),
                          ),
                          subtitle: Text(
                            value.toString(),
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: OrbitColors.textNavy,
                            ),
                          ),
                        );

              final statusStr = (_at(header, ['status_name']) ??
                      _at(trip, ['status_name']) ??
                      '')
                  .toString();
              final poRef = _at(header, ['display_reference'])?.toString();
              final hasTransport = _at(header,
                          ['central_approval', 'shipping_method_name']) !=
                      null ||
                  _at(trip, ['transport_method']) != null ||
                  _at(header,
                          ['requested_vehicle_type', 'vehicle_type_code']) !=
                      null ||
                  _at(trip, ['planned_vehicle_type', 'code']) != null ||
                  _at(transport, ['internal', 'license_plate']) != null ||
                  _at(transport, ['expedition', 'license_plate']) != null ||
                  _at(transport, ['internal', 'driver_full_name']) != null ||
                  _at(transport, ['expedition', 'driver_full_name']) != null ||
                  _at(transport, ['internal', 'helper_full_name']) != null ||
                  _at(transport, ['internal', 'seal_number']) != null ||
                  _at(transport, ['expedition', 'seal_number']) != null;

              return OrbitDetailList(
                children: [
                  // Hero Header Card
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: OrbitColors.cardSurface,
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(color: Colors.white),
                      boxShadow: const [
                        BoxShadow(
                          color: Color(0x1606244D),
                          blurRadius: 16,
                          offset: Offset(0, 6),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: OrbitColors.bubbleBlue,
                                borderRadius: BorderRadius.circular(999),
                              ),
                              child: const Text(
                                'LOGISTIC OUT',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  color: OrbitColors.primaryNavy,
                                ),
                              ),
                            ),
                            if (statusStr.isNotEmpty) ...[
                              const Spacer(),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 10, vertical: 4),
                                decoration: BoxDecoration(
                                  color: statusStr.contains('complete') ||
                                          statusStr.contains('delivered') ||
                                          statusStr.contains('loaded')
                                      ? OrbitColors.kpiGreenBg
                                      : OrbitColors.kpiOrangeBg,
                                  borderRadius: BorderRadius.circular(999),
                                ),
                                child: Text(
                                  statusStr.replaceAll('_', ' ').toUpperCase(),
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                    color: statusStr.contains('complete') ||
                                            statusStr.contains('delivered') ||
                                            statusStr.contains('loaded')
                                        ? const Color(0xFF15803D)
                                        : OrbitColors.brandOrange,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                        const SizedBox(height: 14),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const CircleAvatar(
                              radius: 22,
                              backgroundColor: OrbitColors.bubbleBlue,
                              child: Icon(
                                Icons.local_shipping_outlined,
                                color: OrbitColors.primaryNavy,
                                size: 22,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                'Logistic Out Overview',
                                style: Theme.of(context)
                                    .textTheme
                                    .titleLarge
                                    ?.copyWith(
                                      fontSize: 18,
                                      fontWeight: FontWeight.w800,
                                      color: OrbitColors.textNavy,
                                      height: 1.25,
                                    ),
                              ),
                            ),
                          ],
                        ),
                        if (poRef != null && poRef.isNotEmpty) ...[
                          const SizedBox(height: 14),
                          const Divider(
                              height: 1, color: OrbitColors.cardBorder),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              const Icon(
                                Icons.tag_rounded,
                                size: 15,
                                color: OrbitColors.textMuted,
                              ),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Text(
                                  'PO Ref: $poRef',
                                  style: const TextStyle(
                                    fontSize: 12.5,
                                    fontWeight: FontWeight.w600,
                                    color: OrbitColors.primaryNavy,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),

                  // Order & Route Card
                  const Divider(height: 24),
                  Row(
                    children: [
                      Container(
                        width: 30,
                        height: 30,
                        decoration: BoxDecoration(
                          color: OrbitColors.bubbleBlue,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(
                          Icons.receipt_long_outlined,
                          size: 17,
                          color: OrbitColors.primaryNavy,
                        ),
                      ),
                      const SizedBox(width: 10),
                      const Expanded(
                        child: Text(
                          'Order & Route',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: OrbitColors.textNavy,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  field(
                      'Status',
                      _at(header, ['status_name']) ??
                          _at(trip, ['status_name'])),
                  field('Purchase order', _at(header, ['display_reference'])),
                  field('Requester', _at(header, ['requester', 'branch_name'])),
                  field('Supplier', _at(header, ['supplier', 'branch_name'])),
                  field('Request date', _at(header, ['request_date'])),
                  field('Loading date', _at(header, ['loading_date'])),

                  // Transport & Vehicle Card
                  if (hasTransport) ...[
                    const Divider(height: 24),
                    Row(
                      children: [
                        Container(
                          width: 30,
                          height: 30,
                          decoration: BoxDecoration(
                            color: OrbitColors.bubbleBlue,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(
                            Icons.local_shipping_outlined,
                            size: 17,
                            color: OrbitColors.primaryNavy,
                          ),
                        ),
                        const SizedBox(width: 10),
                        const Expanded(
                          child: Text(
                            'Transport & Vehicle',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              color: OrbitColors.textNavy,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    field(
                        'Shipping method',
                        _at(header, [
                              'central_approval',
                              'shipping_method_name'
                            ]) ??
                            _at(trip, ['transport_method'])),
                    field(
                        'Vehicle type',
                        _at(header, [
                              'requested_vehicle_type',
                              'vehicle_type_code'
                            ]) ??
                            _at(trip, ['planned_vehicle_type', 'code'])),
                    field(
                        'License plate',
                        _at(transport, ['internal', 'license_plate']) ??
                            _at(transport, ['expedition', 'license_plate'])),
                    field(
                        'Driver',
                        _at(transport, ['internal', 'driver_full_name']) ??
                            _at(transport, ['expedition', 'driver_full_name'])),
                    field('Helper',
                        _at(transport, ['internal', 'helper_full_name'])),
                    field(
                        'Seal number',
                        _at(transport, ['internal', 'seal_number']) ??
                            _at(transport, ['expedition', 'seal_number'])),
                  ],

                  // Member Purchase Orders Card
                  if (members.isNotEmpty) ...[
                    const Divider(height: 24),
                    Row(
                      children: [
                        Container(
                          width: 30,
                          height: 30,
                          decoration: BoxDecoration(
                            color: OrbitColors.bubbleBlue,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(
                            Icons.folder_shared_outlined,
                            size: 17,
                            color: OrbitColors.primaryNavy,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'Purchase orders',
                            style: Theme.of(context)
                                .textTheme
                                .titleMedium
                                ?.copyWith(
                                  fontWeight: FontWeight.w700,
                                  color: OrbitColors.textNavy,
                                ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    for (final member in members.whereType<Map>())
                      field(
                        'Purchase order',
                        member['display_reference'] ??
                            member['logistic_out_id'],
                      ),
                  ],

                  // Items Card
                  if (items.isNotEmpty) ...[
                    const Divider(height: 24),
                    Row(
                      children: [
                        Container(
                          width: 30,
                          height: 30,
                          decoration: BoxDecoration(
                            color: OrbitColors.bubbleBlue,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(
                            Icons.inventory_2_outlined,
                            size: 17,
                            color: OrbitColors.primaryNavy,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'Items',
                            style: Theme.of(context)
                                .textTheme
                                .titleMedium
                                ?.copyWith(
                                  fontWeight: FontWeight.w700,
                                  color: OrbitColors.textNavy,
                                ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    for (final item in items.whereType<Map>())
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        visualDensity: VisualDensity.compact,
                        leading: Container(
                          width: 34,
                          height: 34,
                          decoration: BoxDecoration(
                            color: OrbitColors.bubbleBlue,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(
                            Icons.inventory_2_outlined,
                            color: OrbitColors.primaryNavy,
                            size: 18,
                          ),
                        ),
                        title: Text(
                          (item['item_name'] ??
                                  item['product_name'] ??
                                  item['name'] ??
                                  'Item')
                              .toString(),
                          style: const TextStyle(
                            fontSize: 13.5,
                            fontWeight: FontWeight.w700,
                            color: OrbitColors.textNavy,
                          ),
                        ),
                        subtitle: Text(
                          (item['quantity'] ?? item['qty'] ?? '').toString(),
                          style: const TextStyle(
                            fontSize: 12.5,
                            color: OrbitColors.textSecondary,
                          ),
                        ),
                      ),
                  ],
                ],
              );
            },
          ),
    );
  }
}
