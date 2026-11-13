import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/orbit_theme.dart';
import '../../auth/providers/auth_provider.dart';
import '../providers/task_provider.dart';
import 'create_work_item_screen.dart';
import 'task_detail_screen.dart';

class TaskScreen extends ConsumerStatefulWidget {
  const TaskScreen({super.key});

  @override
  ConsumerState<TaskScreen> createState() => _TaskScreenState();
}

class _TaskScreenState extends ConsumerState<TaskScreen> {
  String _status = 'all';
  String _priority = '';
  DateTimeRange? _dateRange;
  Timer? _searchTimer;
  late Future<Map<String, dynamic>> _priorityFuture;
  late Future<Map<String, dynamic>> _ideasFuture;
  String _ideasSearch = '';
  Timer? _ideasTimer;

  @override
  void initState() {
    super.initState();
    _priorityFuture = ref.read(taskRepositoryProvider).fetchPriorities();
    _ideasFuture = _loadIdeas('');
  }

  Future<Map<String, dynamic>> _loadIdeas(String search) async {
    final response = await ref
        .read(apiClientProvider)
        .dio
        .get('/ec/today', queryParameters: {'search': search, 'page': 1});
    if (response.data is! Map)
      throw const FormatException('Unexpected EC ideas response');
    return Map<String, dynamic>.from(response.data as Map);
  }

  void _reloadPriorities() => setState(() =>
      _priorityFuture = ref.read(taskRepositoryProvider).fetchPriorities());

  @override
  void dispose() {
    _searchTimer?.cancel();
    _ideasTimer?.cancel();
    super.dispose();
  }

  String _group(TaskItemModel task) {
    final due = DateTime.tryParse(task.dueDate);
    if (due == null) return 'No Due Date';
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final day = DateTime(due.year, due.month, due.day);
    if (day.isBefore(today)) {
      return const ['completed', 'cancelled']
              .contains(task.status.toLowerCase())
          ? 'Past Dates'
          : 'Overdue';
    }
    return day == today ? 'Today' : 'Upcoming';
  }

  @override
  Widget build(BuildContext context) {
    final taskState = ref.watch(taskNotifierProvider);
    final canManageEc =
        ref.watch(authProvider).user?.can('task.ec.manage') == true;
    final displayTasks = taskState.tasks;

    return Scaffold(
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          final created = await Navigator.of(context).push<bool>(
              MaterialPageRoute(builder: (_) => const CreateWorkItemScreen()));
          if (created == true && context.mounted)
            ref.read(taskNotifierProvider.notifier).loadTasks();
        },
        child: const Icon(Icons.add),
      ),
      backgroundColor: OrbitColors.scaffoldBackground,
      appBar: AppBar(
        title: const Text('Task Board'),
        actions: [
          IconButton(
            icon:
                const Icon(Icons.refresh_rounded, color: OrbitColors.textNavy),
            onPressed: () {
              ref.read(taskNotifierProvider.notifier).loadTasks();
            },
          ),
        ],
      ),
      body: RefreshIndicator(
        color: OrbitColors.primaryNavy,
        onRefresh: () async {
          await ref.read(taskNotifierProvider.notifier).loadTasks();
        },
        child: ListView(
          padding:
              const EdgeInsets.only(left: 16, right: 16, top: 8, bottom: 90),
          children: [
            const Text('Priority',
                style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: OrbitColors.textNavy)),
            const SizedBox(height: 6),
            FutureBuilder<Map<String, dynamic>>(
              future: _priorityFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting)
                  return const LinearProgressIndicator();
                if (snapshot.hasError)
                  return TextButton(
                      onPressed: _reloadPriorities,
                      child: const Text('Priority is unavailable. Retry'));
                final payload = snapshot.data ?? const <String, dynamic>{};
                final rows = payload['data'] is List
                    ? payload['data'] as List
                    : const [];
                final meta = payload['meta'];
                return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (rows.isEmpty)
                        const Padding(
                            padding: EdgeInsets.symmetric(vertical: 8),
                            child: Text('No priority tasks yet.')),
                      for (final row in rows.whereType<Map>())
                        ListTile(
                          dense: true,
                          contentPadding: EdgeInsets.zero,
                          title: Text((row['title'] ?? 'Task').toString(),
                              maxLines: 1, overflow: TextOverflow.ellipsis),
                          trailing: IconButton(
                              tooltip: 'Remove from Priority',
                              icon: const Icon(Icons.remove_circle_outline),
                              onPressed: () async {
                                await ref
                                    .read(taskRepositoryProvider)
                                    .removePriority(
                                        (row['task_id'] as num).toInt());
                                _reloadPriorities();
                                ref
                                    .read(taskNotifierProvider.notifier)
                                    .loadTasks();
                              }),
                          onTap: () => Navigator.of(context).push(
                              MaterialPageRoute(
                                  builder: (_) => TaskDetailScreen(
                                      taskId:
                                          (row['task_id'] as num).toInt()))),
                        ),
                      if (meta is Map && (meta['last_page'] as num? ?? 1) > 1)
                        const Text('Showing your saved priority tasks'),
                    ]);
              },
            ),
            const Divider(height: 24),
            if (canManageEc) ...[
              const Text('EC Today Ideas',
                  style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: OrbitColors.textNavy)),
              TextField(
                decoration: const InputDecoration(
                    prefixIcon: Icon(Icons.lightbulb_outline),
                    hintText: 'Search today ideas',
                    isDense: true),
                onChanged: (value) {
                  _ideasSearch = value.trim();
                  _ideasTimer?.cancel();
                  _ideasTimer = Timer(const Duration(milliseconds: 350), () {
                    if (mounted)
                      setState(() => _ideasFuture = _loadIdeas(_ideasSearch));
                  });
                },
              ),
              FutureBuilder<Map<String, dynamic>>(
                future: _ideasFuture,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting)
                    return const LinearProgressIndicator();
                  if (snapshot.hasError)
                    return TextButton(
                        onPressed: () => setState(
                            () => _ideasFuture = _loadIdeas(_ideasSearch)),
                        child: const Text('Unable to load EC ideas. Retry'));
                  final data = snapshot.data ?? const <String, dynamic>{};
                  final ideas =
                      data['data'] is List ? data['data'] as List : const [];
                  return Column(children: [
                    if (ideas.isEmpty)
                      const ListTile(title: Text('No EC ideas for today')),
                    for (final idea in ideas.whereType<Map>())
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: const Icon(Icons.lightbulb_outline),
                        title: Text((idea['title'] ?? idea['idea'] ?? 'EC idea')
                            .toString()),
                        subtitle: Text(
                            (idea['status_name'] ?? idea['status'] ?? '')
                                .toString()),
                      ),
                  ]);
                },
              ),
              const Divider(height: 24),
            ],
            TextField(
              decoration: const InputDecoration(
                  prefixIcon: Icon(Icons.search),
                  hintText: 'Search tasks',
                  isDense: true),
              onChanged: (value) {
                _searchTimer?.cancel();
                _searchTimer = Timer(const Duration(milliseconds: 350), () {
                  if (mounted)
                    ref
                        .read(taskNotifierProvider.notifier)
                        .loadTasks(search: value.trim());
                });
              },
            ),
            const SizedBox(height: 8),
            DropdownButtonFormField<String>(
              value: _status,
              decoration:
                  const InputDecoration(labelText: 'Status', isDense: true),
              items: const [
                DropdownMenuItem(value: 'all', child: Text('All statuses')),
                DropdownMenuItem(value: 'open', child: Text('Open')),
                DropdownMenuItem(
                    value: 'in_progress', child: Text('In progress')),
                DropdownMenuItem(
                    value: 'pending_review', child: Text('Pending review')),
                DropdownMenuItem(value: 'completed', child: Text('Completed')),
                DropdownMenuItem(value: 'cancelled', child: Text('Cancelled')),
                DropdownMenuItem(value: 'overdue', child: Text('Overdue')),
              ],
              onChanged: (value) {
                if (value == null) return;
                setState(() => _status = value);
                ref
                    .read(taskNotifierProvider.notifier)
                    .loadTasks(status: value);
              },
            ),
            DropdownButtonFormField<String>(
              value: _priority,
              decoration:
                  const InputDecoration(labelText: 'Priority', isDense: true),
              items: const [
                DropdownMenuItem(value: '', child: Text('Any priority')),
                DropdownMenuItem(value: 'low', child: Text('Low')),
                DropdownMenuItem(value: 'normal', child: Text('Normal')),
                DropdownMenuItem(value: 'urgent', child: Text('Urgent'))
              ],
              onChanged: (value) {
                if (value == null) return;
                setState(() => _priority = value);
                ref
                    .read(taskNotifierProvider.notifier)
                    .loadTasks(priority: value);
              },
            ),
            TextButton.icon(
              icon: const Icon(Icons.date_range),
              label: Text(_dateRange == null
                  ? 'Filter by due date'
                  : '${_dateRange!.start.toIso8601String().substring(0, 10)} – ${_dateRange!.end.toIso8601String().substring(0, 10)}'),
              onPressed: () async {
                final picked = await showDateRangePicker(
                    context: context,
                    firstDate: DateTime(2020),
                    lastDate: DateTime(2100),
                    initialDateRange: _dateRange);
                if (picked == null || !mounted) return;
                setState(() => _dateRange = picked);
                ref.read(taskNotifierProvider.notifier).loadTasks(
                    from: picked.start.toIso8601String().substring(0, 10),
                    to: picked.end.toIso8601String().substring(0, 10));
              },
            ),
            const SizedBox(height: 12),
            // Status Header Info
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: OrbitColors.cardSurface,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: OrbitColors.cardBorder),
              ),
              child: Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: OrbitColors.bubbleBlue,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.assignment_outlined,
                      color: OrbitColors.primaryNavy,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Active Assigned Tasks',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: OrbitColors.textNavy,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${displayTasks.length} task${displayTasks.length == 1 ? '' : 's'} in progress',
                          style: const TextStyle(
                            fontSize: 12,
                            color: OrbitColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),

            // Tasks List
            if (taskState.isLoading)
              const Center(
                child: Padding(
                  padding: EdgeInsets.symmetric(vertical: 40),
                  child:
                      CircularProgressIndicator(color: OrbitColors.primaryNavy),
                ),
              )
            else if (taskState.error != null)
              Center(
                child: TextButton(
                  onPressed: () =>
                      ref.read(taskNotifierProvider.notifier).loadTasks(),
                  child: const Text('Unable to load tasks. Tap to retry.'),
                ),
              )
            else if (displayTasks.isEmpty)
              Container(
                padding:
                    const EdgeInsets.symmetric(vertical: 36, horizontal: 20),
                decoration: BoxDecoration(
                  color: OrbitColors.cardSurface,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: OrbitColors.cardBorder),
                ),
                child: Column(
                  children: const [
                    Icon(Icons.task_alt_rounded,
                        size: 48, color: OrbitColors.textMuted),
                    SizedBox(height: 12),
                    Text(
                      'No tasks assigned',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: OrbitColors.textNavy,
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      'All your tasks will be listed here when assigned.',
                      style: TextStyle(
                          fontSize: 12, color: OrbitColors.textSecondary),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              )
            else
              for (final group in [
                'Overdue',
                'Past Dates',
                'Today',
                'Upcoming',
                'No Due Date'
              ]) ...[
                if (displayTasks.any((task) => _group(task) == group)) ...[
                  Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: Text(group,
                          style: const TextStyle(fontWeight: FontWeight.bold))),
                  for (final task
                      in displayTasks.where((task) => _group(task) == group))
                    Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: _buildTaskCard(task)),
                ],
              ],
            if (taskState.page < taskState.lastPage && taskState.error == null)
              Center(
                  child: TextButton(
                onPressed: taskState.isLoadingMore
                    ? null
                    : () => ref.read(taskNotifierProvider.notifier).loadMore(),
                child: Text(taskState.isLoadingMore
                    ? 'Loading…'
                    : taskState.loadMoreError != null
                        ? 'Unable to load more. Retry'
                        : 'Load more tasks'),
              )),
          ],
        ),
      ),
    );
  }

  Widget _buildTaskCard(TaskItemModel task) {
    Color priorityColor = OrbitColors.kpiGreen;
    Color priorityBg = OrbitColors.kpiGreenBg;
    if (task.priority.toLowerCase() == 'urgent') {
      priorityColor = OrbitColors.kpiRed;
      priorityBg = OrbitColors.kpiRedBg;
    } else if (task.priority.toLowerCase() == 'high') {
      priorityColor = OrbitColors.kpiOrange;
      priorityBg = OrbitColors.kpiOrangeBg;
    }

    return InkWell(
      onTap: () => Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => TaskDetailScreen(taskId: task.id))),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: OrbitColors.cardSurface,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: OrbitColors.cardBorder),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    color: task.progressPercent >= 100
                        ? OrbitColors.primaryNavy
                        : Colors.transparent,
                    border: Border.all(
                      color: task.progressPercent >= 100
                          ? OrbitColors.primaryNavy
                          : OrbitColors.textMuted,
                      width: 1.5,
                    ),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: task.progressPercent >= 100
                      ? const Icon(Icons.check, size: 19, color: Colors.white)
                      : null,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(task.title, style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: OrbitColors.textNavy,
                        decoration: task.progressPercent >= 100
                            ? TextDecoration.lineThrough
                            : null,
                      )),
                      if (task.description.isNotEmpty) ...[
                        const SizedBox(height: 3),
                        Text(task.description, maxLines: 1, overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontSize: 12, color: OrbitColors.textSecondary)),
                      ],
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                        decoration: BoxDecoration(color: OrbitColors.bubbleBlue, borderRadius: BorderRadius.circular(999)),
                        child: Text('${task.progressPercent}% · ${task.progressPercent >= 100 ? 'Complete' : 'In progress'}',
                            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: OrbitColors.textSecondary)),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: priorityBg,
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(task.priority.toUpperCase(),
                          style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                              color: priorityColor)),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.calendar_today_rounded,
                            size: 12, color: OrbitColors.textMuted),
                        const SizedBox(width: 4),
                        Text(task.dueDate,
                            style: const TextStyle(
                                fontSize: 11,
                                color: OrbitColors.textMuted,
                                fontWeight: FontWeight.w500)),
                      ],
                    ),
                  ],
                ),
              ],
            ),
            if (task.attachmentCount > 0)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Row(children: [
                  const Icon(Icons.attach_file, size: 14),
                  Text(
                      '${task.attachmentCount} attachment${task.attachmentCount == 1 ? '' : 's'}')
                ]),
              ),
            const SizedBox(height: 14),

            // Progress Indicator
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                if (task.priorityEligible && !task.isPersonalPriority)
                  IconButton(
                    tooltip: 'Add to Priority',
                    icon: const Icon(Icons.push_pin_outlined),
                    onPressed: () async {
                      await ref
                          .read(taskRepositoryProvider)
                          .addPriority(task.id);
                      _reloadPriorities();
                      ref.read(taskNotifierProvider.notifier).loadTasks();
                    },
                  ),
                const Text(
                  'Progress',
                  style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: OrbitColors.textSecondary),
                ),
                Text(
                  '${task.progressPercent}%',
                  style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      color: OrbitColors.textNavy),
                ),
              ],
            ),
            const SizedBox(height: 6),
            ClipRRect(
              borderRadius: BorderRadius.circular(999),
              child: LinearProgressIndicator(
                value: task.progressPercent / 100.0,
                minHeight: 6,
                backgroundColor: OrbitColors.scaffoldBackground,
                valueColor: const AlwaysStoppedAnimation<Color>(
                    OrbitColors.brandOrange),
              ),
            ),
            const SizedBox(height: 14),

            if (task.projectName != null)
              Text(task.projectName!,
                  style: const TextStyle(color: OrbitColors.textSecondary)),
            if (task.assignees.isNotEmpty)
              Text(task.assignees.join(', '),
                  style: const TextStyle(color: OrbitColors.textSecondary)),
            // Actions
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                if (task.rowAction == 'request_review')
                  OutlinedButton(
                    onPressed: () async {
                      final success = await ref
                          .read(taskRepositoryProvider)
                          .requestReview(task.id);
                      if (!mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                          content: Text(success
                              ? 'Review requested.'
                              : 'Could not request review. Refresh and try again.')));
                      if (success)
                        ref.read(taskNotifierProvider.notifier).loadTasks();
                    },
                    style: OutlinedButton.styleFrom(
                      foregroundColor: OrbitColors.primaryNavy,
                      side: const BorderSide(color: OrbitColors.cardBorder),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(999)),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 6),
                    ),
                    child: const Text('Request Review',
                        style: TextStyle(
                            fontSize: 11, fontWeight: FontWeight.w600)),
                  ),
                if (task.rowAction == 'complete')
                  FilledButton.icon(
                    onPressed: () async {
                      final success = await ref
                          .read(taskRepositoryProvider)
                          .completeTask(task.id);
                      if (!mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                          content: Text(success
                              ? 'Task completed.'
                              : 'Could not complete task. Refresh and try again.')));
                      if (success)
                        ref.read(taskNotifierProvider.notifier).loadTasks();
                    },
                    icon: const Icon(Icons.check, size: 14),
                    label: const Text('Complete',
                        style: TextStyle(
                            fontSize: 11, fontWeight: FontWeight.bold)),
                    style: FilledButton.styleFrom(
                      backgroundColor: OrbitColors.primaryNavy,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 6),
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
