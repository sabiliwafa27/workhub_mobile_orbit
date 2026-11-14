import 'package:flutter/material.dart';
import '../../../core/widgets/orbit_workspace.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/orbit_theme.dart';
import '../../auth/providers/auth_provider.dart';
import 'logistic_in_officer_form.dart';

typedef _LineKey = ({String line, int? assignment, bool mention});

final _lineProvider = FutureProvider.autoDispose
    .family<Map<String, dynamic>, _LineKey>((ref, key) async {
  final line = Uri.encodeComponent(key.line);
  final response = await ref
      .watch(apiClientProvider)
      .dio
      .get('/inbox/api/module-detail/wms.logistic-in/$line', queryParameters: {
    'format': 'json',
    if (key.mention) 'context': 'mention',
    if (!key.mention && key.assignment != null) 'assignment': key.assignment,
  });
  final data = response.data;
  if (data is! Map || data['data'] is! Map)
    throw const FormatException('Unexpected Logistic In response');
  return Map<String, dynamic>.from(data['data'] as Map);
});

class LogisticInDetailScreen extends ConsumerWidget {
  final String line;
  final int? assignment;
  final bool mention;
  const LogisticInDetailScreen(
      {super.key, required this.line, this.assignment, this.mention = false});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final key = (line: line, assignment: assignment, mention: mention);
    return OrbitWorkspaceScaffold(
      subtitle: 'Arrival details & officer assignments',
      appBar: AppBar(title: const Text('Logistic In')),
      body: ref.watch(_lineProvider(key)).when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (_, __) => Center(
                child: TextButton(
                    onPressed: () => ref.invalidate(_lineProvider(key)),
                    child:
                        const Text('Unable to load details. Tap to retry.'))),
            data: (data) {
              final selected = data['selectedLine'];
              if (selected is! Map)
                return const Center(child: Text('No item details available.'));
              final officer = data['inboxOfficerAssignment'];
              final submission = data['inboxOfficerSubmission'];
              final assignments = data['activeTabAssignments'] is List
                  ? data['activeTabAssignments'] as List
                  : const [];
              final results = data['canViewOfficerResults'] == true &&
                      data['assignmentResults'] is List
                  ? (data['assignmentResults'] as List)
                      .whereType<Map>()
                      .where((result) => const ['QC', 'BM', 'WH'].contains(
                          (result['role_code'] ?? '').toString().toUpperCase()))
                      .toList()
                  : <Map>[];
              const roleOrder = {'QC': 0, 'BM': 1, 'WH': 2};
              results.sort((a, b) =>
                  roleOrder[(a['role_code'] ?? '').toString().toUpperCase()]!
                      .compareTo(roleOrder[
                          (b['role_code'] ?? '').toString().toUpperCase()]!));
              final formOptions = data['inboxOfficerForm'];
              final officerId = officer is Map
                  ? int.tryParse(
                      '${officer['logistic_in_item_assignment_id'] ?? ''}')
                  : null;
              final role =
                  officer is Map ? (officer['role_code'] ?? '').toString() : '';
              final assignmentStatus = officer is Map
                  ? (officer['assignment_status'] ?? '').toString()
                  : '';
              final canSubmit = !mention &&
                  assignment != null &&
                  officerId == assignment &&
                  submission == null &&
                  officer is Map &&
                  officer['is_reassigned_historical'] != true &&
                  const ['QC', 'BM', 'WH'].contains(role) &&
                  const ['assigned', 'in_progress']
                      .contains(assignmentStatus) &&
                  selected['status'] == 'confirmed' &&
                  formOptions is Map &&
                  formOptions['packagingOptions'] is List &&
                  formOptions['yesNoOptions'] is List &&
                  formOptions['standardOptions'] is List;
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

              final itemName = (selected['item_name'] ??
                      selected['description'] ??
                      'Logistic In')
                  .toString();
              final statusStr =
                  (selected['line_status'] ?? selected['status'] ?? '')
                      .toString();
              final hasTransport = selected['license_plate'] != null ||
                  selected['driver_name'] != null ||
                  selected['vehicle_type'] != null ||
                  selected['whatsapp_number'] != null ||
                  selected['people_count'] != null;
              final hasQuantities = selected['qty_arrived'] != null ||
                  selected['qty_good'] != null ||
                  selected['qty_reject'] != null ||
                  selected['verification_status'] != null;

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
                                'LOGISTIC IN',
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
                                  color: statusStr.contains('confirm') ||
                                          statusStr.contains('complete')
                                      ? OrbitColors.kpiGreenBg
                                      : OrbitColors.kpiOrangeBg,
                                  borderRadius: BorderRadius.circular(999),
                                ),
                                child: Text(
                                  statusStr.replaceAll('_', ' ').toUpperCase(),
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                    color: statusStr.contains('confirm') ||
                                            statusStr.contains('complete')
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
                                Icons.inventory_2_outlined,
                                color: OrbitColors.primaryNavy,
                                size: 22,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                itemName,
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
                        if (selected['arrival_number'] != null) ...[
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
                                  'Arrival #${selected['arrival_number']}',
                                  style: const TextStyle(
                                    fontSize: 12.5,
                                    fontWeight: FontWeight.w500,
                                    color: OrbitColors.textSecondary,
                                  ),
                                ),
                              ),
                              if (selected['check_in_at'] != null) ...[
                                const Icon(
                                  Icons.access_time_rounded,
                                  size: 15,
                                  color: OrbitColors.textMuted,
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  selected['check_in_at'].toString(),
                                  style: const TextStyle(
                                    fontSize: 12.5,
                                    fontWeight: FontWeight.w500,
                                    color: OrbitColors.textSecondary,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),

                  // Arrival & Supplier Card
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
                          'Arrival Details',
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
                  field('Arrival', selected['arrival_number']),
                  field(
                      'Status', selected['line_status'] ?? selected['status']),
                  field('Supplier', selected['supplier_name']),
                  field('Check in', selected['check_in_at']),

                  // Transport & Driver Card
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
                            'Transport & Driver',
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
                    field('License plate', selected['license_plate']),
                    field('Driver', selected['driver_name']),
                    field('Vehicle type', selected['vehicle_type']),
                    field('WhatsApp', selected['whatsapp_number']),
                    field('People count', selected['people_count']),
                  ],

                  // Quantities & Verification Card
                  if (hasQuantities) ...[
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
                            Icons.fact_check_outlined,
                            size: 17,
                            color: OrbitColors.primaryNavy,
                          ),
                        ),
                        const SizedBox(width: 10),
                        const Expanded(
                          child: Text(
                            'Quantities & Verification',
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
                    field('Quantity arrived', selected['qty_arrived']),
                    field('Quantity good', selected['qty_good']),
                    field('Quantity rejected', selected['qty_reject']),
                    field(
                        'Verification status', selected['verification_status']),
                  ],

                  // Officer Assignment Card
                  if (officer is Map) ...[
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
                            Icons.assignment_ind_outlined,
                            size: 17,
                            color: OrbitColors.primaryNavy,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'Officer assignment',
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
                    field('Role', officer['role_name'] ?? officer['role_code']),
                    field('Officer', officer['employee_name']),
                    field('Assignment status', officer['assignment_status']),
                    if (officer['is_reassigned_historical'] == true)
                      field('Reassigned to',
                          officer['reassigned_to_employee_name']),
                    if (submission is Map)
                      field('Submitted', submission['submitted_at']),
                  ],

                  // Officer Input Form Card
                  if (canSubmit) ...[
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
                            Icons.edit_note_rounded,
                            size: 17,
                            color: OrbitColors.primaryNavy,
                          ),
                        ),
                        const SizedBox(width: 10),
                        const Expanded(
                          child: Text(
                            'Officer Input Form',
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
                    LogisticInOfficerForm(
                      line: line,
                      assignmentId: assignment!,
                      role: role,
                      packagingOptions:
                          (formOptions['packagingOptions'] as List)
                              .whereType<String>()
                              .toList(),
                      yesNoOptions: (formOptions['yesNoOptions'] as List)
                          .whereType<String>()
                          .toList(),
                      standardOptions:
                          (formOptions['standardOptions'] as List)
                              .whereType<String>()
                              .toList(),
                      refreshDetail: () async {
                        final updated =
                            await ref.refresh(_lineProvider(key).future);
                        if (updated['selectedLine'] is! Map)
                          throw const FormatException(
                              'Logistic In state is unavailable');
                      },
                    ),
                  ],

                  // Officer Assignments List Card
                  if (assignments.isNotEmpty) ...[
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
                            Icons.group_outlined,
                            size: 17,
                            color: OrbitColors.primaryNavy,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'Officer assignments',
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
                    for (final assignment in assignments.whereType<Map>())
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        visualDensity: VisualDensity.compact,
                        title: Text(
                          (assignment['role_name'] ??
                                  assignment['role_code'] ??
                                  'Officer')
                              .toString(),
                          style: const TextStyle(
                            fontSize: 13.5,
                            fontWeight: FontWeight.w700,
                            color: OrbitColors.textNavy,
                          ),
                        ),
                        subtitle: Text(
                          (assignment['employee_name'] ?? 'Unassigned')
                              .toString(),
                          style: const TextStyle(
                            fontSize: 12.5,
                            color: OrbitColors.textSecondary,
                          ),
                        ),
                        trailing: Text(
                          (assignment['status'] ?? '').toString(),
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: OrbitColors.primaryNavy,
                          ),
                        ),
                      ),
                  ],

                  // Officer Results Card
                  if (data['canViewOfficerResults'] == true) ...[
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
                            Icons.rule_folder_outlined,
                            size: 17,
                            color: OrbitColors.primaryNavy,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'Officer results',
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
                    if (results.isEmpty)
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 8),
                        child: Text(
                          'No officer results are available.',
                          style: TextStyle(
                            fontSize: 13,
                            color: OrbitColors.textMuted,
                          ),
                        ),
                      ),
                    for (final result in results)
                      ExpansionTile(
                        tilePadding: EdgeInsets.zero,
                        title: Text(
                          (result['employee_name'] ?? '—').toString(),
                          style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            color: OrbitColors.textNavy,
                          ),
                        ),
                        subtitle: Text(
                          '${result['role_name'] ?? result['role_code']} · ${(result['assignment_status'] ?? 'assigned').toString().replaceAll('_', ' ')}',
                          style: const TextStyle(
                            fontSize: 12.5,
                            color: OrbitColors.textSecondary,
                          ),
                        ),
                        children: [
                          field('Submitted',
                              result['submission_submitted_at']),
                          field('Result', result['submission_result']),
                          if (result['answers'] is List &&
                              (result['answers'] as List).isNotEmpty)
                            for (final answer
                                in (result['answers'] as List).whereType<Map>())
                              field(
                                  (answer['label'] ??
                                          answer['key'] ??
                                          'Answer')
                                      .toString(),
                                  answer['value'])
                          else
                            const ListTile(
                              contentPadding: EdgeInsets.zero,
                              title: Text(
                                  'No submitted form answers are available.'),
                            ),
                          field('Notes', result['submission_result_notes']),
                        ],
                      ),
                  ],
                ],
              );
            },
          ),
    );
  }
}
