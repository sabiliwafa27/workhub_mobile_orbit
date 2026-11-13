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
          final pendingReview = task['status'] == 'pending_review' ||
              assignments.whereType<Map>().any((assignment) =>
                  assignment['unassigned_at'] == null &&
                  assignment['review_requested_at'] != null);
          final names = assignments
              .whereType<Map>()
              .where((assignment) => assignment['unassigned_at'] == null)
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
          final priority = task['priority_name'] ??
              (task['priority'] is Map
                  ? task['priority']['priority_name']
                  : task['priority']);
          final complexity = task['complexity_name'] ??
              (task['complexity'] is Map
                  ? task['complexity']['complexity_name']
                  : task['complexity']);
          final attachments = task['attachments'] is List
              ? task['attachments'] as List
              : const [];
          return OrbitDetailList(children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: OrbitColors.cardSurface,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: OrbitColors.cardBorder),
              ),
              child: Row(
                children: [
                  Container(
                    width: 52,
                    height: 52,
                    decoration: BoxDecoration(
                      color: OrbitColors.bubbleBlue,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: const Icon(Icons.task_alt_rounded,
                        color: OrbitColors.primaryNavy),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Text((task['title'] ?? 'Task').toString(),
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.w800,
                            color: OrbitColors.textNavy)),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),
            if (status != null)
              Chip(
                  avatar: const Icon(Icons.circle, size: 12),
                  label: Text(status.toString()),
                  visualDensity: VisualDensity.compact),
            if (task['row_action'] == 'complete' ||
                task['row_action'] == 'request_review')
              _TaskDetailAction(
                  taskId: taskId, action: task['row_action'] as String),
            if (pendingReview) const Chip(label: Text('Pending review')),
            const SizedBox(height: 16),
            if ((task['description'] ?? '').toString().isNotEmpty) ...[
              const Text('Description',
                  style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 4),
              Text(task['description'].toString()),
              const SizedBox(height: 16)
            ],
            if (names.isNotEmpty)
              ListTile(
                  leading: const Icon(Icons.people_outline,
                      color: OrbitColors.primaryNavy),
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Assignees'),
                  subtitle: Text(names)),
            if (task['due_date'] != null)
              ListTile(
                  leading: const Icon(Icons.calendar_today_outlined,
                      color: OrbitColors.primaryNavy),
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Due date'),
                  subtitle: Text(task['due_date'].toString().split('T').first)),
            if (project is Map && project['name'] != null)
              ListTile(
                  leading: const Icon(Icons.folder_outlined,
                      color: OrbitColors.primaryNavy),
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Project'),
                  subtitle: Text(project['name'].toString())),
            if (priority != null || complexity != null)
              ListTile(
                  leading: const Icon(Icons.flag_outlined,
                      color: OrbitColors.primaryNavy),
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Priority / complexity'),
                  subtitle: Text(
                      [priority, complexity].whereType<String>().join(' · '))),
            if (attachments.isNotEmpty) ...[
              const Text('Attachments',
                  style: TextStyle(fontWeight: FontWeight.bold)),
              for (final attachment in attachments.whereType<Map>())
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.attach_file),
                  title: Text((attachment['original_name'] ??
                          attachment['file_name'] ??
                          attachment['name'] ??
                          'Attachment')
                      .toString()),
                  subtitle: attachment['size'] != null
                      ? Text('${attachment['size']} bytes')
                      : null,
                ),
            ],
            const Divider(height: 32),
            Row(children: [
              const CircleAvatar(
                radius: 19,
                backgroundColor: OrbitColors.bubbleBlue,
                child: Icon(Icons.chat_bubble_outline_rounded,
                    color: OrbitColors.primaryNavy, size: 19),
              ),
              const SizedBox(width: 10),
              Expanded(
                  child: Text('Discussion',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w800,
                          color: OrbitColors.textNavy))),
            ]),
            const SizedBox(height: 8),
            InboxDiscussion(module: 'task', subjectKey: taskId.toString()),
          ]);
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
