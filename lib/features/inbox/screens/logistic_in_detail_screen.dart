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
                          title: Text(label),
                          subtitle: Text(value.toString()));
              return OrbitDetailList(children: [
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: OrbitColors.cardSurface,
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(color: OrbitColors.cardBorder),
                  ),
                  child: Row(children: [
                    const CircleAvatar(
                        radius: 26,
                        backgroundColor: OrbitColors.bubbleBlue,
                        child: Icon(Icons.inventory_2_outlined,
                            color: OrbitColors.primaryNavy)),
                    const SizedBox(width: 14),
                    Expanded(
                        child: Text(
                      (selected['item_name'] ??
                              selected['description'] ??
                              'Logistic In')
                          .toString(),
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w800,
                          color: OrbitColors.textNavy),
                    )),
                  ]),
                ),
                const SizedBox(height: 12),
                field('Arrival', selected['arrival_number']),
                field('Status', selected['line_status'] ?? selected['status']),
                field('Supplier', selected['supplier_name']),
                field('Check in', selected['check_in_at']),
                field('License plate', selected['license_plate']),
                field('Driver', selected['driver_name']),
                field('Vehicle type', selected['vehicle_type']),
                field('WhatsApp', selected['whatsapp_number']),
                field('People count', selected['people_count']),
                field('Quantity arrived', selected['qty_arrived']),
                field('Quantity good', selected['qty_good']),
                field('Quantity rejected', selected['qty_reject']),
                field('Verification status', selected['verification_status']),
                if (officer is Map) ...[
                  const Divider(),
                  Text('Officer assignment',
                      style: Theme.of(context).textTheme.titleMedium),
                  field('Role', officer['role_name'] ?? officer['role_code']),
                  field('Officer', officer['employee_name']),
                  field('Assignment status', officer['assignment_status']),
                  if (officer['is_reassigned_historical'] == true)
                    field('Reassigned to',
                        officer['reassigned_to_employee_name']),
                  if (submission is Map)
                    field('Submitted', submission['submitted_at']),
                ],
                if (canSubmit) ...[
                  const Divider(height: 32),
                  LogisticInOfficerForm(
                    line: line,
                    assignmentId: assignment!,
                    role: role,
                    packagingOptions: (formOptions['packagingOptions'] as List)
                        .whereType<String>()
                        .toList(),
                    yesNoOptions: (formOptions['yesNoOptions'] as List)
                        .whereType<String>()
                        .toList(),
                    standardOptions: (formOptions['standardOptions'] as List)
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
                if (assignments.isNotEmpty) ...[
                  const Divider(),
                  Text('Officer assignments',
                      style: Theme.of(context).textTheme.titleMedium),
                  for (final assignment in assignments.whereType<Map>())
                    ListTile(
                        contentPadding: EdgeInsets.zero,
                        title: Text((assignment['role_name'] ??
                                assignment['role_code'] ??
                                'Officer')
                            .toString()),
                        subtitle: Text(
                            (assignment['employee_name'] ?? 'Unassigned')
                                .toString()),
                        trailing:
                            Text((assignment['status'] ?? '').toString())),
                ],
                if (data['canViewOfficerResults'] == true) ...[
                  const Divider(height: 32),
                  Text('Officer results',
                      style: Theme.of(context).textTheme.titleMedium),
                  if (results.isEmpty)
                    const Text('No officer results are available.'),
                  for (final result in results)
                    ExpansionTile(
                      tilePadding: EdgeInsets.zero,
                      title: Text((result['employee_name'] ?? '—').toString()),
                      subtitle: Text(
                          '${result['role_name'] ?? result['role_code']} · ${(result['assignment_status'] ?? 'assigned').toString().replaceAll('_', ' ')}'),
                      children: [
                        field('Submitted', result['submission_submitted_at']),
                        field('Result', result['submission_result']),
                        if (result['answers'] is List &&
                            (result['answers'] as List).isNotEmpty)
                          for (final answer
                              in (result['answers'] as List).whereType<Map>())
                            field(
                                (answer['label'] ?? answer['key'] ?? 'Answer')
                                    .toString(),
                                answer['value'])
                        else
                          const ListTile(
                              contentPadding: EdgeInsets.zero,
                              title: Text(
                                  'No submitted form answers are available.')),
                        field('Notes', result['submission_result_notes']),
                      ],
                    ),
                ],
              ]);
            },
          ),
    );
  }
}
