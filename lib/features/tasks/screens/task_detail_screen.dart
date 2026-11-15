import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import '../../../core/widgets/orbit_workspace.dart';
import '../../../core/utils/created_date_format.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/widgets/attachment_preview_tile.dart';
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

class _TaskAiSummaryState {
  final String status;
  final String? summary;

  const _TaskAiSummaryState({required this.status, this.summary});
}

final _taskAiSummaryProvider = FutureProvider.autoDispose
    .family<_TaskAiSummaryState, int>((ref, id) async {
  final api = ref.watch(apiClientProvider).dio;

  Future<Map<String, dynamic>> readStatus(String? generationId) async {
    final path = '/tasks/$id/ai-summary/status';
    final response = await api.get(
      path,
      queryParameters:
          generationId == null ? null : {'generation_id': generationId},
    );
    final body = response.data;
    final data =
        body is Map && body['data'] is Map ? body['data'] as Map : body;
    return data is Map ? Map<String, dynamic>.from(data) : <String, dynamic>{};
  }

  String? summaryFrom(Map<String, dynamic> data) {
    final summary = data['summary'];
    return summary is String && summary.trim().isNotEmpty
        ? summary.trim()
        : null;
  }

  final dispatchResponse = await api.post('/tasks/$id/ai-summary');
  final dispatchBody = dispatchResponse.data;
  final dispatchData = dispatchBody is Map && dispatchBody['data'] is Map
      ? Map<String, dynamic>.from(dispatchBody['data'] as Map)
      : dispatchBody is Map
          ? Map<String, dynamic>.from(dispatchBody)
          : <String, dynamic>{};
  final generationValue = dispatchData['generation_id'] ??
      dispatchData['generationId'] ??
      dispatchData['generation'] ??
      dispatchData['id'];
  final generationId = generationValue?.toString();
  var statusData = dispatchData;
  var summary = summaryFrom(statusData);
  var status = (statusData['status'] ?? 'processing').toString().toLowerCase();
  if (summary != null) {
    return _TaskAiSummaryState(status: 'ready', summary: summary);
  }

  for (var attempt = 0; attempt < 15; attempt++) {
    await Future<void>.delayed(const Duration(seconds: 2));
    statusData = await readStatus(generationId);
    summary = summaryFrom(statusData);
    status = (statusData['status'] ?? status).toString().toLowerCase();
    if (summary != null) {
      return _TaskAiSummaryState(status: 'ready', summary: summary);
    }
    if (status == 'failed' || status == 'error') {
      return _TaskAiSummaryState(status: status);
    }
  }

  return _TaskAiSummaryState(status: status);
});

List<({String title, String body})> _taskSummarySections(String summary) {
  const headings = {
    'overview': 'Overview',
    'progress': 'Progress',
    'comments summary': 'Comments Summary',
  };
  final sections = <String, StringBuffer>{};
  String? current;

  for (final line in summary.split('\n')) {
    final heading =
        line.trim().replaceAll(RegExp(r'^[#*\s]+|[#*\s:]+$'), '').toLowerCase();
    final matched = headings[heading];
    if (matched != null) {
      current = matched;
      sections.putIfAbsent(current, StringBuffer.new);
    } else if (current != null) {
      if (sections[current]!.isNotEmpty) sections[current]!.write('\n');
      sections[current]!.write(line.trimRight());
    }
  }

  if (sections.isEmpty) {
    return [(title: 'Overview', body: summary)];
  }
  return [
    for (final title in headings.values)
      if (sections[title]?.toString().trim().isNotEmpty == true)
        (title: title, body: sections[title]!.toString().trim()),
  ];
}

class _TaskAiSummaryCard extends ConsumerWidget {
  final int taskId;
  const _TaskAiSummaryCard({required this.taskId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final summary = ref.watch(_taskAiSummaryProvider(taskId));
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: OrbitColors.cardBorder),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0C06244D),
            blurRadius: 14,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.auto_awesome_rounded,
                  size: 18, color: OrbitColors.primaryNavy),
              const SizedBox(width: 8),
              const Text(
                'Jarvis AI Summary',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  color: OrbitColors.textNavy,
                ),
              ),
              const Spacer(),
              if (summary.isLoading)
                const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: OrbitColors.primaryNavy),
                ),
            ],
          ),
          const SizedBox(height: 12),
          summary.when(
            loading: () => const Text(
              'Jarvis is preparing an overview of progress and comments…',
              style: TextStyle(
                  fontSize: 13, color: OrbitColors.textSecondary, height: 1.4),
            ),
            error: (_, __) => const Text(
              'Jarvis summary is unavailable right now.',
              style: TextStyle(
                  fontSize: 13, color: OrbitColors.textSecondary, height: 1.4),
            ),
            data: (result) {
              if (result.summary == null) {
                return Text(
                  result.status == 'processing' || result.status == 'pending'
                      ? 'Jarvis is still preparing the summary.'
                      : 'No Jarvis summary is available for this task yet.',
                  style: const TextStyle(
                      fontSize: 13,
                      color: OrbitColors.textSecondary,
                      height: 1.4),
                );
              }
              final sections = _taskSummarySections(result.summary!);
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (var index = 0; index < sections.length; index++) ...[
                    if (index > 0) const SizedBox(height: 12),
                    Text(
                      sections[index].title,
                      style: const TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w800,
                        color: OrbitColors.primaryNavy,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      sections[index].body,
                      style: const TextStyle(
                        fontSize: 13,
                        height: 1.45,
                        color: OrbitColors.textNavy,
                      ),
                    ),
                  ],
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

class TaskDetailScreen extends ConsumerWidget {
  final int taskId;
  const TaskDetailScreen({super.key, required this.taskId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final detail = ref.watch(_taskDetailProvider(taskId));
    final taskTitle = detail.when(
      data: (task) => (task['title'] ?? 'Task').toString(),
      loading: () => 'Task details',
      error: (_, __) => 'Task details',
    );
    final createdDate = detail.when(
      data: (task) => formatCreatedDate(task['created_at']),
      loading: () => '',
      error: (_, __) => '',
    );
    final taskActionFab = MediaQuery.viewInsetsOf(context).bottom > 0
        ? null
        : detail.when<Widget?>(
            data: (task) {
              final action = task['row_action']?.toString();
              if (action != 'complete' && action != 'request_review') {
                return null;
              }
              return _TaskDetailAction(taskId: taskId, action: action!);
            },
            loading: () => null,
            error: (_, __) => null,
          );
    return OrbitWorkspaceScaffold(
      subtitle: createdDate,
      floatingActionButton: taskActionFab,
      appBar: AppBar(
        title: Text(
          taskTitle,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ),
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
          return RefreshIndicator(
            color: OrbitColors.primaryNavy,
            onRefresh: () async {
              ref.invalidate(_taskDetailProvider(taskId));
              await ref.read(_taskDetailProvider(taskId).future);
            },
            child: ListView(
              padding: const EdgeInsets.fromLTRB(14, 10, 14, 96),
              children: [
                _TaskAiSummaryCard(taskId: taskId),
                const SizedBox(height: 12),
                // 1. Unified Clean Header & Overview Card
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: OrbitColors.cardBorder, width: 1),
                    boxShadow: const [
                      BoxShadow(
                        color: Color(0x0C06244D),
                        blurRadius: 16,
                        offset: Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Badges row
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
                                      size: 12,
                                      color: OrbitColors.textSecondary),
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

                      if (creatorName != null) ...[
                        const SizedBox(height: 2),
                        Row(
                          children: [
                            const Icon(
                              Icons.person_outline_rounded,
                              size: 14,
                              color: OrbitColors.textMuted,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              'By $creatorName',
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                                color: OrbitColors.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ],

                      // Description directly integrated
                      if ((task['description'] ?? '')
                          .toString()
                          .isNotEmpty) ...[
                        const SizedBox(height: 16),
                        const Divider(height: 1, color: OrbitColors.cardBorder),
                        const SizedBox(height: 14),
                        const Text(
                          'Description',
                          style: TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w700,
                            color: OrbitColors.textSecondary,
                            letterSpacing: 0.2,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          task['description'].toString(),
                          style: const TextStyle(
                            fontSize: 14,
                            color: OrbitColors.textNavy,
                            height: 1.45,
                          ),
                        ),
                      ],

                      // Parameters & Key Attributes Table inside the container
                      const SizedBox(height: 16),
                      const Divider(height: 1, color: OrbitColors.cardBorder),
                      const SizedBox(height: 12),

                      _buildDetailRow(
                        icon: Icons.flag_outlined,
                        label: 'Priority / Complexity',
                        value: [priority, complexity]
                            .whereType<String>()
                            .join(' · '),
                        show: priority != null || complexity != null,
                      ),
                      _buildDetailRow(
                        icon: Icons.calendar_today_outlined,
                        label: 'Due date',
                        value:
                            task['due_date']?.toString().split('T').first ?? '',
                        show: task['due_date'] != null,
                      ),
                      _buildDetailRow(
                        icon: Icons.play_circle_outline,
                        label: 'Start date',
                        value:
                            task['start_date']?.toString().split('T').first ??
                                '',
                        show: task['start_date'] != null,
                      ),
                      _buildDetailRow(
                        icon: Icons.repeat_rounded,
                        label: 'Recurrence',
                        value:
                            '${task['repeat_frequency']}${task['repeat_until'] != null ? ' until ' + task['repeat_until'].toString().split('T').first : ''}',
                        show: task['repeat_frequency'] != null,
                      ),
                      _buildDetailRow(
                        icon: Icons.stars_outlined,
                        label: 'Reward points',
                        value: '$points pts',
                        show: points != null && points > 0,
                      ),
                      _buildDetailRow(
                        icon: Icons.folder_outlined,
                        label: 'Project',
                        value: project is Map
                            ? (project['name'] ?? '').toString()
                            : '',
                        show: project is Map && project['name'] != null,
                      ),

                      // Assignees section inside the unified card
                      if (activeAssignments.isNotEmpty || names.isNotEmpty) ...[
                        const SizedBox(height: 6),
                        const Divider(height: 1, color: OrbitColors.cardBorder),
                        const SizedBox(height: 12),
                        const Text(
                          'Assignees',
                          style: TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w700,
                            color: OrbitColors.textSecondary,
                            letterSpacing: 0.2,
                          ),
                        ),
                        const SizedBox(height: 8),
                        if (activeAssignments.isNotEmpty)
                          for (final assignment in activeAssignments) ...[
                            Builder(builder: (context) {
                              final emp = assignment['employee'] is Map
                                  ? assignment['employee'] as Map
                                  : const {};
                              final empName = (emp['full_name'] ??
                                      emp['name'] ??
                                      'Assignee')
                                  .toString();
                              final dept =
                                  emp['department'] ?? emp['job_title'];
                              final isReq =
                                  assignment['review_requested_at'] != null;
                              return Padding(
                                padding:
                                    const EdgeInsets.symmetric(vertical: 4),
                                child: Row(
                                  children: [
                                    CircleAvatar(
                                      radius: 14,
                                      backgroundColor: OrbitColors.bubbleBlue,
                                      child: Text(
                                        empName.isNotEmpty
                                            ? empName[0].toUpperCase()
                                            : 'U',
                                        style: const TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.bold,
                                          color: OrbitColors.primaryNavy,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            empName,
                                            style: const TextStyle(
                                              fontWeight: FontWeight.w700,
                                              fontSize: 13.5,
                                              color: OrbitColors.textNavy,
                                            ),
                                          ),
                                          if (dept != null)
                                            Text(
                                              dept.toString(),
                                              style: const TextStyle(
                                                fontSize: 11.5,
                                                color:
                                                    OrbitColors.textSecondary,
                                              ),
                                            ),
                                        ],
                                      ),
                                    ),
                                    if (isReq)
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 8, vertical: 3),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFFEDE9FE),
                                          borderRadius:
                                              BorderRadius.circular(999),
                                        ),
                                        child: const Text(
                                          'Review Requested',
                                          style: TextStyle(
                                            fontSize: 10.5,
                                            fontWeight: FontWeight.w700,
                                            color: Color(0xFF6D28D9),
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                              );
                            }),
                          ]
                        else if (names.isNotEmpty)
                          Text(
                            names,
                            style: const TextStyle(
                              fontSize: 13.5,
                              fontWeight: FontWeight.w600,
                              color: OrbitColors.textNavy,
                            ),
                          ),
                      ],

                      // Attachments inside the unified card
                      if (attachments.isNotEmpty) ...[
                        const SizedBox(height: 6),
                        const Divider(height: 1, color: OrbitColors.cardBorder),
                        const SizedBox(height: 12),
                        const Text(
                          'Attachments',
                          style: TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w700,
                            color: OrbitColors.textSecondary,
                            letterSpacing: 0.2,
                          ),
                        ),
                        const SizedBox(height: 8),
                        for (final attachment in attachments.whereType<Map>())
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 4),
                            child: AttachmentPreviewTile.fromMap(attachment),
                          ),
                      ],

                      // Reviews inside the unified card
                      if (reviews.isNotEmpty) ...[
                        const SizedBox(height: 6),
                        const Divider(height: 1, color: OrbitColors.cardBorder),
                        const SizedBox(height: 12),
                        const Text(
                          'Reviews & Feedback',
                          style: TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w700,
                            color: OrbitColors.textSecondary,
                            letterSpacing: 0.2,
                          ),
                        ),
                        const SizedBox(height: 8),
                        for (final rev in reviews) ...[
                          Builder(builder: (context) {
                            final reviewerName = rev['reviewer']
                                    ?['full_name'] ??
                                rev['employee']?['full_name'] ??
                                'Reviewer';
                            final revStatus =
                                (rev['status'] ?? 'reviewed').toString();
                            final feedback = rev['feedback'] ??
                                rev['notes'] ??
                                rev['comment'];
                            final reviewedAt =
                                rev['reviewed_at'] ?? rev['created_at'];
                            return Container(
                              margin: const EdgeInsets.only(bottom: 8),
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: OrbitColors.scaffoldBackground
                                    .withValues(alpha: 0.5),
                                borderRadius: BorderRadius.circular(12),
                                border:
                                    Border.all(color: OrbitColors.cardBorder),
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
                                          borderRadius:
                                              BorderRadius.circular(999),
                                        ),
                                        child: Text(
                                          revStatus
                                              .replaceAll('_', ' ')
                                              .toUpperCase(),
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
                    ],
                  ),
                ),

                const SizedBox(height: 16),

                // 2. Scoped Discussion Panel (Independent clean card)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: OrbitColors.cardBorder, width: 1),
                    boxShadow: const [
                      BoxShadow(
                        color: Color(0x0C06244D),
                        blurRadius: 16,
                        offset: Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            width: 32,
                            height: 32,
                            decoration: BoxDecoration(
                              color: OrbitColors.bubbleBlue,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Icon(
                              Icons.chat_bubble_outline_rounded,
                              size: 18,
                              color: OrbitColors.primaryNavy,
                            ),
                          ),
                          const SizedBox(width: 10),
                          const Text(
                            'Discussion',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                              color: OrbitColors.textNavy,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      InboxDiscussion(
                          module: 'task', subjectKey: taskId.toString()),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildDetailRow({
    required IconData icon,
    required String label,
    required String value,
    required bool show,
  }) {
    if (!show || value.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 17, color: OrbitColors.primaryNavy),
          const SizedBox(width: 10),
          SizedBox(
            width: 140,
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: OrbitColors.textSecondary,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              textAlign: TextAlign.end,
              style: const TextStyle(
                fontSize: 13.5,
                fontWeight: FontWeight.w700,
                color: OrbitColors.textNavy,
              ),
            ),
          ),
        ],
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
      return Material(
        elevation: 6,
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 10, 8, 10),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(
                width: 190,
                child: Text(
                  'The task update could not be confirmed. Refresh before retrying.',
                  style: TextStyle(fontSize: 12, color: OrbitColors.textNavy),
                ),
              ),
              TextButton(
                onPressed: busy ? null : refresh,
                child: const Text('Refresh'),
              ),
            ],
          ),
        ),
      );
    return Container(
      decoration: const BoxDecoration(
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: Color(0x3306244D),
            blurRadius: 16,
            offset: Offset(0, 6),
          ),
        ],
      ),
      child: FloatingActionButton(
        heroTag: 'task-action-${widget.taskId}',
        tooltip: widget.action == 'request_review'
            ? 'Request review'
            : 'Complete task',
        backgroundColor: OrbitColors.primaryNavy,
        foregroundColor: Colors.white,
        elevation: 0,
        highlightElevation: 0,
        onPressed: busy ? null : perform,
        child: busy
            ? const SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(
                  strokeWidth: 2.5,
                  color: Colors.white,
                ),
              )
            : Icon(
                widget.action == 'request_review'
                    ? Icons.rate_review_outlined
                    : Icons.check_rounded,
                size: 28,
              ),
      ),
    );
  }
}
