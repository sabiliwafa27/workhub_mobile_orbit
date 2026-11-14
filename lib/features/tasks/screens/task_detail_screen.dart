import 'package:flutter/material.dart';
import '../../../core/widgets/orbit_workspace.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../auth/providers/auth_provider.dart';
import '../../inbox/screens/discussion_panel.dart';
import '../../inbox/providers/inbox_provider.dart';
import '../../../core/theme/orbit_theme.dart';
import '../providers/task_provider.dart';

final _taskDetailProvider = FutureProvider.autoDispose
    .family<Map<String, dynamic>, int>((ref, id) async {
  final response =
      await ref.watch(apiClientProvider).dio.get('/tasks/$id/payload');
  final data = response.data;
  if (data is! Map || data['task'] is! Map)
    throw const FormatException('Unexpected task detail response');
  return Map<String, dynamic>.from(data['task'] as Map);
});

class TaskDetailScreen extends ConsumerWidget {
  final int taskId;
  const TaskDetailScreen({super.key, required this.taskId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final detail = ref.watch(_taskDetailProvider(taskId));
    return OrbitWorkspaceScaffold(
      subtitle: 'Overview, assignees & discussion',
      appBar: AppBar(title: const Text('Task details')),
      body: detail.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, __) => Center(
            child: TextButton(
                onPressed: () => ref.invalidate(_taskDetailProvider(taskId)),
                child: const Text('Unable to load task. Tap to retry.'))),
        data: (task) {
          final assignments =
              task['assignees'] is List ? task['assignees'] as List : const [];
          final activeAssignments = assignments
              .whereType<Map>()
              .where((assignment) => assignment['unassigned_at'] == null)
              .toList();
          final pendingReview = task['status'] == 'pending_review' ||
              assignments.whereType<Map>().any((assignment) =>
                  assignment['unassigned_at'] == null &&
                  assignment['review_requested_at'] != null);
          final names = activeAssignments
              .map((assignment) => assignment['employee'])
              .whereType<Map>()
              .map((employee) => (employee['full_name'] ?? '').toString())
              .where((name) => name.isNotEmpty)
              .join(', ');
          final project = task['project'];
          final status = task['status_name'] ??
              (task['status'] is Map
                  ? task['status']['status_name']
                  : task['status']);
          final statusStr = (status ?? '').toString();
          final priority = task['priority_name'] ??
              (task['priority'] is Map
                  ? task['priority']['priority_name']
                  : task['priority']);
          final complexity = task['complexity_name'] ??
              (task['complexity'] is Map
                  ? task['complexity']['complexity_name']
                  : task['complexity']);
          final points = task['points'] as num? ??
              (task['token_points'] as num?) ??
              (task['reward_tokens'] as num?);
          final attachments = task['attachments'] is List
              ? task['attachments'] as List
              : const [];
          final reviews = task['reviews'] is List
              ? (task['reviews'] as List).whereType<Map>().toList()
              : const [];
          final creator = task['creator'] is Map
              ? task['creator'] as Map
              : task['created_by'] is Map
                  ? task['created_by'] as Map
                  : task['employee'] is Map
                      ? task['employee'] as Map
                      : null;
          final creatorName = creator != null
              ? (creator['full_name'] ?? creator['name'] ?? '').toString()
              : null;
          final isPrivate = task['is_private'] == true;
          final hasAction = task['row_action'] == 'complete' ||
              task['row_action'] == 'request_review';

          return OrbitDetailList(
            children: [
              // Hero Overview Card
              Container(
                width: double.infinity,
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
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        if (project is Map && project['name'] != null)
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: OrbitColors.bubbleBlue,
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: Text(
                              project['name'].toString(),
                              style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: OrbitColors.primaryNavy,
                              ),
                            ),
                          )
                        else
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: OrbitColors.bubbleBlue,
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: Text(
                              'TASK #$taskId',
                              style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: OrbitColors.primaryNavy,
                              ),
                            ),
                          ),
                        if (statusStr.isNotEmpty)
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: statusStr.contains('complete') ||
                                      statusStr == 'done'
                                  ? OrbitColors.kpiGreenBg
                                  : statusStr.contains('review')
                                      ? const Color(0xFFEDE9FE)
                                      : OrbitColors.bubbleBlue,
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: Text(
                              statusStr.replaceAll('_', ' ').toUpperCase(),
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: statusStr.contains('complete') ||
                                        statusStr == 'done'
                                    ? const Color(0xFF15803D)
                                    : statusStr.contains('review')
                                        ? const Color(0xFF6D28D9)
                                        : OrbitColors.primaryNavy,
                              ),
                            ),
                          ),
                        if (points != null && points > 0)
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: OrbitColors.kpiOrangeBg,
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(
                                  Icons.stars_rounded,
                                  size: 13,
                                  color: OrbitColors.brandOrange,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  '$points pts',
                                  style: const TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w800,
                                    color: OrbitColors.brandOrange,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        if (isPrivate)
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF1F5F9),
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.lock_outline,
                                    size: 12, color: OrbitColors.textSecondary),
                                SizedBox(width: 4),
                                Text(
                                  'Private',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                    color: OrbitColors.textSecondary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        if (pendingReview)
                          const Chip(
                            visualDensity: VisualDensity.compact,
                            label: Text('Pending review'),
                          ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: 46,
                          height: 46,
                          decoration: BoxDecoration(
                            color: OrbitColors.bubbleBlue,
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: const Icon(
                            Icons.task_alt_rounded,
                            color: OrbitColors.primaryNavy,
                            size: 24,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            (task['title'] ?? 'Task').toString(),
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
                    if (hasAction) ...[
                      const SizedBox(height: 14),
                      _TaskDetailAction(
                        taskId: taskId,
                        action: task['row_action'] as String,
                      ),
                    ],
                    if (creatorName != null || task['created_at'] != null) ...[
                      const SizedBox(height: 14),
                      const Divider(height: 1, color: OrbitColors.cardBorder),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          if (creatorName != null) ...[
                            const Icon(
                              Icons.person_outline_rounded,
                              size: 15,
                              color: OrbitColors.textMuted,
                            ),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                'By $creatorName',
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500,
                                  color: OrbitColors.textSecondary,
                                ),
                              ),
                            ),
                          ],
                          if (task['created_at'] != null) ...[
                            const Icon(
                              Icons.access_time_rounded,
                              size: 14,
                              color: OrbitColors.textMuted,
                            ),
                            const SizedBox(width: 5),
                            Text(
                              task['created_at'].toString().split('T').first,
                              style: const TextStyle(
                                fontSize: 12,
                                color: OrbitColors.textMuted,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ],
                ),
              ),

              // Parameters & Timeline Card
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
                      Icons.tune_rounded,
                      size: 17,
                      color: OrbitColors.primaryNavy,
                    ),
                  ),
                  const SizedBox(width: 10),
                  const Expanded(
                    child: Text(
                      'Parameters & Timeline',
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
              if (priority != null || complexity != null)
                ListTile(
                  leading: const Icon(Icons.flag_outlined,
                      color: OrbitColors.primaryNavy),
                  contentPadding: EdgeInsets.zero,
                  visualDensity: VisualDensity.compact,
                  title: const Text(
                    'Priority / complexity',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: OrbitColors.textSecondary,
                    ),
                  ),
                  subtitle: Text(
                    [priority, complexity].whereType<String>().join(' · '),
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: OrbitColors.textNavy,
                    ),
                  ),
                ),
              if (task['due_date'] != null)
                ListTile(
                  leading: const Icon(Icons.calendar_today_outlined,
                      color: OrbitColors.primaryNavy),
                  contentPadding: EdgeInsets.zero,
                  visualDensity: VisualDensity.compact,
                  title: const Text(
                    'Due date',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: OrbitColors.textSecondary,
                    ),
                  ),
                  subtitle: Text(
                    task['due_date'].toString().split('T').first,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: OrbitColors.textNavy,
                    ),
                  ),
                ),
              if (task['start_date'] != null)
                ListTile(
                  leading: const Icon(Icons.play_circle_outline,
                      color: OrbitColors.primaryNavy),
                  contentPadding: EdgeInsets.zero,
                  visualDensity: VisualDensity.compact,
                  title: const Text(
                    'Start date',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: OrbitColors.textSecondary,
                    ),
                  ),
                  subtitle: Text(
                    task['start_date'].toString().split('T').first,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: OrbitColors.textNavy,
                    ),
                  ),
                ),
              if (points != null && points > 0)
                ListTile(
                  leading: const Icon(Icons.stars_outlined,
                      color: OrbitColors.brandOrange),
                  contentPadding: EdgeInsets.zero,
                  visualDensity: VisualDensity.compact,
                  title: const Text(
                    'Reward points',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: OrbitColors.textSecondary,
                    ),
                  ),
                  subtitle: Text(
                    '$points pts',
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: OrbitColors.textNavy,
                    ),
                  ),
                ),
              if (task['repeat_frequency'] != null)
                ListTile(
                  leading: const Icon(Icons.repeat_rounded,
                      color: OrbitColors.primaryNavy),
                  contentPadding: EdgeInsets.zero,
                  visualDensity: VisualDensity.compact,
                  title: const Text(
                    'Recurrence',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: OrbitColors.textSecondary,
                    ),
                  ),
                  subtitle: Text(
                    '${task['repeat_frequency']}${task['repeat_until'] != null ? ' until ' + task['repeat_until'].toString().split('T').first : ''}',
                    style: const TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w600,
                      color: OrbitColors.textNavy,
                    ),
                  ),
                ),

              // Description Card
              if ((task['description'] ?? '').toString().isNotEmpty) ...[
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
                        Icons.description_outlined,
                        size: 17,
                        color: OrbitColors.primaryNavy,
                      ),
                    ),
                    const SizedBox(width: 10),
                    const Expanded(
                      child: Text(
                        'Description',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          color: OrbitColors.textNavy,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color:
                        OrbitColors.scaffoldBackground.withValues(alpha: 0.5),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: OrbitColors.cardBorder),
                  ),
                  child: Text(
                    task['description'].toString(),
                    style: const TextStyle(
                      fontSize: 13.5,
                      color: OrbitColors.textNavy,
                      height: 1.45,
                    ),
                  ),
                ),
              ],

              // Project Association Card
              if (project is Map && project['name'] != null) ...[
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
                        Icons.folder_outlined,
                        size: 17,
                        color: OrbitColors.primaryNavy,
                      ),
                    ),
                    const SizedBox(width: 10),
                    const Expanded(
                      child: Text(
                        'Project',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          color: OrbitColors.textNavy,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                ListTile(
                  leading: const Icon(Icons.folder_outlined,
                      color: OrbitColors.primaryNavy),
                  contentPadding: EdgeInsets.zero,
                  visualDensity: VisualDensity.compact,
                  title: const Text(
                    'Project',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: OrbitColors.textSecondary,
                    ),
                  ),
                  subtitle: Text(
                    project['name'].toString(),
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: OrbitColors.textNavy,
                    ),
                  ),
                ),
              ],

              // Assignees Card
              if (activeAssignments.isNotEmpty || names.isNotEmpty) ...[
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
                        Icons.people_outline_rounded,
                        size: 17,
                        color: OrbitColors.primaryNavy,
                      ),
                    ),
                    const SizedBox(width: 10),
                    const Expanded(
                      child: Text(
                        'Assignees',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          color: OrbitColors.textNavy,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                if (activeAssignments.isNotEmpty)
                  for (final assignment in activeAssignments) ...[
                    Builder(builder: (context) {
                      final emp = assignment['employee'] is Map
                          ? assignment['employee'] as Map
                          : const {};
                      final empName =
                          (emp['full_name'] ?? emp['name'] ?? 'Assignee')
                              .toString();
                      final dept = emp['department'] ?? emp['job_title'];
                      final isReq = assignment['review_requested_at'] != null;
                      return ListTile(
                        contentPadding: EdgeInsets.zero,
                        visualDensity: VisualDensity.compact,
                        leading: CircleAvatar(
                          radius: 17,
                          backgroundColor: OrbitColors.bubbleBlue,
                          child: Text(
                            empName.isNotEmpty ? empName[0].toUpperCase() : 'U',
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                              color: OrbitColors.primaryNavy,
                            ),
                          ),
                        ),
                        title: Text(
                          empName,
                          style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 13.5,
                            color: OrbitColors.textNavy,
                          ),
                        ),
                        subtitle: dept != null
                            ? Text(
                                dept.toString(),
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: OrbitColors.textSecondary,
                                ),
                              )
                            : null,
                        trailing: isReq
                            ? Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFEDE9FE),
                                  borderRadius: BorderRadius.circular(999),
                                ),
                                child: const Text(
                                  'Review Requested',
                                  style: TextStyle(
                                    fontSize: 10.5,
                                    fontWeight: FontWeight.w700,
                                    color: Color(0xFF6D28D9),
                                  ),
                                ),
                              )
                            : null,
                      );
                    }),
                  ]
                else if (names.isNotEmpty)
                  ListTile(
                    leading: const Icon(Icons.people_outline,
                        color: OrbitColors.primaryNavy),
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Assignees'),
                    subtitle: Text(names),
                  ),
              ],

              // Reviews & Approvals Card
              if (reviews.isNotEmpty) ...[
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
                        Icons.rate_review_outlined,
                        size: 17,
                        color: OrbitColors.primaryNavy,
                      ),
                    ),
                    const SizedBox(width: 10),
                    const Expanded(
                      child: Text(
                        'Reviews & Feedback',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          color: OrbitColors.textNavy,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                for (final rev in reviews) ...[
                  Builder(builder: (context) {
                    final reviewerName = rev['reviewer']?['full_name'] ??
                        rev['employee']?['full_name'] ??
                        'Reviewer';
                    final revStatus = (rev['status'] ?? 'reviewed').toString();
                    final feedback =
                        rev['feedback'] ?? rev['notes'] ?? rev['comment'];
                    final reviewedAt = rev['reviewed_at'] ?? rev['created_at'];
                    return Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: OrbitColors.scaffoldBackground
                            .withValues(alpha: 0.5),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: OrbitColors.cardBorder),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text(
                                reviewerName.toString(),
                                style: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                  color: OrbitColors.textNavy,
                                ),
                              ),
                              const Spacer(),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 2),
                                decoration: BoxDecoration(
                                  color: revStatus.contains('approve')
                                      ? OrbitColors.kpiGreenBg
                                      : OrbitColors.kpiOrangeBg,
                                  borderRadius: BorderRadius.circular(999),
                                ),
                                child: Text(
                                  revStatus.replaceAll('_', ' ').toUpperCase(),
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w700,
                                    color: revStatus.contains('approve')
                                        ? const Color(0xFF15803D)
                                        : OrbitColors.brandOrange,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          if (feedback != null &&
                              feedback.toString().isNotEmpty) ...[
                            const SizedBox(height: 6),
                            Text(
                              feedback.toString(),
                              style: const TextStyle(
                                fontSize: 12.5,
                                color: OrbitColors.textNavy,
                              ),
                            ),
                          ],
                          if (reviewedAt != null) ...[
                            const SizedBox(height: 4),
                            Text(
                              reviewedAt.toString().split('T').first,
                              style: const TextStyle(
                                fontSize: 11,
                                color: OrbitColors.textMuted,
                              ),
                            ),
                          ],
                        ],
                      ),
                    );
                  }),
                ],
              ],

              // Attachments Card
              if (attachments.isNotEmpty) ...[
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
                        Icons.attach_file_rounded,
                        size: 17,
                        color: OrbitColors.primaryNavy,
                      ),
                    ),
                    const SizedBox(width: 10),
                    const Expanded(
                      child: Text(
                        'Attachments',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          color: OrbitColors.textNavy,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                for (final attachment in attachments.whereType<Map>())
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    visualDensity: VisualDensity.compact,
                    leading: Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: OrbitColors.bubbleBlue,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(
                        Icons.attach_file,
                        color: OrbitColors.primaryNavy,
                        size: 20,
                      ),
                    ),
                    title: Text(
                      (attachment['original_name'] ??
                              attachment['file_name'] ??
                              attachment['name'] ??
                              'Attachment')
                          .toString(),
                      style: const TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w700,
                        color: OrbitColors.textNavy,
                      ),
                    ),
                    subtitle: attachment['size'] != null
                        ? Text(
                            '${attachment['size']} bytes',
                            style: const TextStyle(
                              fontSize: 12,
                              color: OrbitColors.textSecondary,
                            ),
                          )
                        : null,
                  ),
              ],

              // Scoped Discussion Card
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
                      Icons.chat_bubble_outline_rounded,
                      size: 17,
                      color: OrbitColors.primaryNavy,
                    ),
                  ),
                  const SizedBox(width: 10),
                  const Expanded(
                    child: Text(
                      'Discussion',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        color: OrbitColors.textNavy,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              InboxDiscussion(module: 'task', subjectKey: taskId.toString()),
            ],
          );
        },
      ),
    );
  }
}

class _TaskDetailAction extends ConsumerStatefulWidget {
  final int taskId;
  final String action;
  const _TaskDetailAction({required this.taskId, required this.action});

  @override
  ConsumerState<_TaskDetailAction> createState() => _TaskDetailActionState();
}

class _TaskDetailActionState extends ConsumerState<_TaskDetailAction> {
  bool busy = false;
  bool uncertain = false;

  Future<void> perform() async {
    if (busy || uncertain) return;
    setState(() => busy = true);
    final repository = ref.read(taskRepositoryProvider);
    final success = widget.action == 'request_review'
        ? await repository.requestReview(widget.taskId)
        : await repository.completeTask(widget.taskId);
    if (!mounted) return;
    if (success) {
      ref.invalidate(_taskDetailProvider(widget.taskId));
      ref.read(taskNotifierProvider.notifier).loadTasks();
      ref.read(inboxNotifierProvider.notifier).loadInbox();
      setState(() => busy = false);
    } else {
      setState(() {
        busy = false;
        uncertain = true;
      });
    }
  }

  Future<void> refresh() async {
    setState(() => busy = true);
    try {
      final updated =
          await ref.refresh(_taskDetailProvider(widget.taskId).future);
      if (updated['title'] == null)
        throw const FormatException('Task state is unavailable');
      if (mounted) setState(() => uncertain = false);
    } catch (_) {
      // Keep the action disabled until the current task state can be checked.
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (uncertain)
      return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text(
            'The task update could not be confirmed. Refresh before retrying.'),
        TextButton(
            onPressed: busy ? null : refresh,
            child: const Text('Refresh task')),
      ]);
    return Align(
        alignment: Alignment.centerLeft,
        child: FilledButton.icon(
          onPressed: busy ? null : perform,
          icon: const Icon(Icons.check),
          label: Text(busy
              ? 'Saving…'
              : widget.action == 'request_review'
                  ? 'Request review'
                  : 'Complete task'),
        ));
  }
}
