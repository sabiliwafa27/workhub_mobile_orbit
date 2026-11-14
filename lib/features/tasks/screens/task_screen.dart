import 'dart:async';
import 'package:flutter/material.dart';
import '../../../core/widgets/orbit_workspace.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/orbit_theme.dart';
import '../../auth/providers/auth_provider.dart';
import '../providers/task_provider.dart';
import 'create_work_item_screen.dart';
import 'task_detail_screen.dart';
import '../widgets/task_board_row.dart';
import '../../inbox/screens/inbox_screen.dart';
import '../../inbox/providers/inbox_provider.dart';

enum TaskBoardPeriod { today, week, month, overdue, all }

class TaskScreen extends ConsumerStatefulWidget {
  final VoidCallback? onOpenNotifications, onOpenProfile;
  const TaskScreen({super.key, this.onOpenNotifications, this.onOpenProfile});

  @override
  ConsumerState<TaskScreen> createState() => _TaskScreenState();
}

class _TaskScreenState extends ConsumerState<TaskScreen> {
  final _searchController = TextEditingController();
  final _searchFocus = FocusNode();
  final _scrollController = ScrollController();
  final _busyTasks = <int>{};
  bool _showFilters = false;
  TaskBoardPeriod _period = TaskBoardPeriod.today;
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
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _selectPeriod(TaskBoardPeriod.today);
    });
  }

  Future<Map<String, dynamic>> _loadIdeas(String search) {
    final future = _fetchIdeas(search);
    // The permission-dependent panel may not be mounted when a request fails.
    // Keep the original future so FutureBuilder can still present its retry UI.
    future.ignore();
    return future;
  }

  Future<Map<String, dynamic>> _fetchIdeas(String search) async {
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
    _searchController.dispose();
    _searchFocus.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _selectPeriod(TaskBoardPeriod period) async {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    DateTime? start, end;
    if (period == TaskBoardPeriod.today) {
      start = today;
      end = today;
    }
    if (period == TaskBoardPeriod.week) {
      start = today.subtract(Duration(days: today.weekday - 1));
      end = start.add(const Duration(days: 6));
    }
    if (period == TaskBoardPeriod.month) {
      start = DateTime(now.year, now.month);
      end = DateTime(now.year, now.month + 1, 0);
    }
    setState(() {
      _period = period;
      _status = period == TaskBoardPeriod.overdue ? 'overdue' : 'all';
      _dateRange =
          start == null ? null : DateTimeRange(start: start, end: end!);
    });
    String date(DateTime d) => d.toIso8601String().split('T').first;
    await ref.read(taskNotifierProvider.notifier).loadTasks(
        status: _status,
        search: _searchController.text.trim(),
        priority: _priority,
        from: start == null ? null : date(start),
        to: end == null ? null : date(end),
        clearDateRange: start == null);
  }

  Future<void> _focusSearch() async {
    if (_scrollController.hasClients) {
      await _scrollController.animateTo(0,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOutCubic);
    }
    if (mounted) _searchFocus.requestFocus();
  }

  Future<void> _taskAction(TaskItemModel task) async {
    if (_busyTasks.contains(task.id)) return;
    setState(() => _busyTasks.add(task.id));
    try {
      final repository = ref.read(taskRepositoryProvider);
      final review = task.rowAction == 'request_review';
      final success = review
          ? await repository.requestReview(task.id)
          : await repository.completeTask(task.id);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(success
              ? review
                  ? 'Review requested.'
                  : 'Task completed.'
              : review
                  ? 'Could not request review. Refresh and try again.'
                  : 'Could not complete task. Refresh and try again.')));
      if (success) ref.read(taskNotifierProvider.notifier).loadTasks();
    } finally {
      if (mounted) setState(() => _busyTasks.remove(task.id));
    }
  }

  Future<void> _addPriority(TaskItemModel task) async {
    if (_busyTasks.contains(task.id)) return;
    setState(() => _busyTasks.add(task.id));
    try {
      await ref.read(taskRepositoryProvider).addPriority(task.id);
      if (!mounted) return;
      _reloadPriorities();
      ref.read(taskNotifierProvider.notifier).loadTasks();
    } catch (_) {
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Unable to add priority. Please try again.')));
    } finally {
      if (mounted) setState(() => _busyTasks.remove(task.id));
    }
  }

  void _profile() {
    if (widget.onOpenProfile != null) {
      widget.onOpenProfile!();
      return;
    }
    final user = ref.read(authProvider).user;
    showDialog<void>(
        context: context,
        builder: (context) => AlertDialog(
                title: Text(user?.name ?? 'My profile'),
                content: Text(user?.email ?? ''),
                actions: [
                  TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Close'))
                ]));
  }

  Widget _headerAction(IconData icon, String label, VoidCallback action,
          {bool badge = false}) =>
      IconButton(
          tooltip: label,
          onPressed: action,
          padding: const EdgeInsets.all(3),
          constraints: const BoxConstraints(minWidth: 34, minHeight: 40),
          icon: Container(
              width: 30,
              height: 30,
              decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withValues(alpha: .08),
                  border:
                      Border.all(color: Colors.white.withValues(alpha: .3))),
              child: Badge(
                  isLabelVisible: badge,
                  backgroundColor: OrbitColors.kpiRed,
                  child: Center(
                      child: Icon(icon, color: Colors.white, size: 19)))));

  @override
  Widget build(BuildContext context) {
    final taskState = ref.watch(taskNotifierProvider);
    final user = ref.watch(authProvider).user;
    final canManageEc = user?.can('task.ec.manage') == true;
    final showAll = _period == TaskBoardPeriod.all || _status != 'all';
    final tasks = showAll
        ? taskState.tasks
        : taskState.tasks
            .where((task) =>
                task.status != 'completed' && task.status != 'cancelled')
            .toList();
    final unread =
        ref.watch(inboxNotifierProvider).items.any((item) => item.isUnread);
    final photo = user?.profilePhotoUrl;
    return OrbitWorkspaceScaffold(
      subtitle: 'Your priorities, progress & assignments',
      floatingActionButtonColor: OrbitColors.royalBlue,
      appBar: AppBar(
          leadingWidth: 42,
          leading: const Icon(Icons.assignment_turned_in_outlined,
              color: Colors.white, size: 27),
          title: const Text('Task Board'),
          actions: [
            _headerAction(Icons.search_rounded, 'Search tasks', _focusSearch),
            _headerAction(
                Icons.notifications_none_rounded,
                'Task notifications',
                widget.onOpenNotifications ??
                    () => Navigator.of(context).push(
                        MaterialPageRoute(builder: (_) => const InboxScreen())),
                badge: unread),
            IconButton(
                tooltip: 'My profile',
                onPressed: _profile,
                padding: const EdgeInsets.fromLTRB(4, 0, 10, 0),
                constraints: const BoxConstraints(minWidth: 38, minHeight: 40),
                icon: CircleAvatar(
                    radius: 17,
                    backgroundColor: Colors.white,
                    child: ClipOval(
                        child: photo == null || photo.isEmpty
                            ? Text(
                                user?.name.isNotEmpty == true
                                    ? user!.name[0].toUpperCase()
                                    : 'U',
                                style: const TextStyle(
                                    color: OrbitColors.primaryNavy,
                                    fontSize: 13))
                            : Image.network(photo,
                                width: 32,
                                height: 32,
                                fit: BoxFit.cover,
                                errorBuilder: (_, __, ___) => const Icon(
                                    Icons.person_outline,
                                    color: OrbitColors.primaryNavy)))))
          ]),
      floatingActionButton: Container(
        decoration: const BoxDecoration(
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: Color(0x4D2563EB),
              blurRadius: 16,
              offset: Offset(0, 6),
            ),
          ],
        ),
        child: FloatingActionButton(
            heroTag: 'task-board-fab',
            tooltip: 'Create task',
            shape: const CircleBorder(),
            backgroundColor: OrbitColors.royalBlue,
            foregroundColor: Colors.white,
            elevation: 0,
            onPressed: () async {
              final created = await Navigator.of(context).push<bool>(
                  MaterialPageRoute(
                      builder: (_) => const CreateWorkItemScreen()));
              if (created == true && mounted)
                ref.read(taskNotifierProvider.notifier).loadTasks();
            },
            child: const Icon(Icons.add, size: 34)),
      ),
      body: RefreshIndicator(
          onRefresh: () => ref.read(taskNotifierProvider.notifier).loadTasks(),
          child: ListView(
              controller: _scrollController,
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 96),
              children: [
                Row(children: [
                  Expanded(
                      child: Container(
                          decoration: BoxDecoration(
                              color: OrbitColors.cardSurface
                                  .withValues(alpha: .88),
                              borderRadius: BorderRadius.circular(99),
                              border: Border.all(
                                  color: Colors.white.withValues(alpha: .8))),
                          child: TextField(
                              key: const ValueKey('task-board-search'),
                              controller: _searchController,
                              focusNode: _searchFocus,
                              onChanged: (value) {
                                _searchTimer?.cancel();
                                _searchTimer = Timer(
                                    const Duration(milliseconds: 350), () {
                                  if (mounted)
                                    ref
                                        .read(taskNotifierProvider.notifier)
                                        .loadTasks(search: value.trim());
                                });
                              },
                              decoration: const InputDecoration(
                                  hintText: 'Search, filters & priorities',
                                  prefixIcon: Icon(Icons.search),
                                  filled: false,
                                  isDense: true,
                                  contentPadding: EdgeInsets.symmetric(
                                      horizontal: 12, vertical: 14),
                                  border: InputBorder.none,
                                  enabledBorder: InputBorder.none,
                                  focusedBorder: InputBorder.none)))),
                  const SizedBox(width: 8),
                  Material(
                      color: OrbitColors.cardSurface.withValues(alpha: .88),
                      shape: const CircleBorder(),
                      child: IconButton(
                          key: const ValueKey('task-board-filters-toggle'),
                          tooltip: 'Search, filters & priorities',
                          isSelected: _showFilters,
                          onPressed: () =>
                              setState(() => _showFilters = !_showFilters),
                          icon: const Icon(Icons.tune_rounded,
                              color: OrbitColors.primaryNavy))),
                ]),
                const SizedBox(height: 12),
                Container(
                    padding: const EdgeInsets.all(3),
                    decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: .10),
                        borderRadius: BorderRadius.circular(99),
                        border: Border.all(
                            color: Colors.white.withValues(alpha: .4))),
                    child: Row(children: [
                      for (final entry in const [
                        (TaskBoardPeriod.today, 'Today'),
                        (TaskBoardPeriod.week, 'This Week'),
                        (TaskBoardPeriod.month, 'Month'),
                        (TaskBoardPeriod.overdue, 'Overdue')
                      ])
                        Expanded(
                            child: Semantics(
                                selected: _period == entry.$1,
                                button: true,
                                child: InkWell(
                                    onTap: () => _selectPeriod(entry.$1),
                                    borderRadius: BorderRadius.circular(99),
                                    child: AnimatedContainer(
                                        duration: MediaQuery
                                                .disableAnimationsOf(context)
                                            ? Duration.zero
                                            : const Duration(milliseconds: 220),
                                        padding: const EdgeInsets.symmetric(
                                            vertical: 9),
                                        decoration: BoxDecoration(
                                            color: _period == entry.$1
                                                ? OrbitColors.primaryNavy
                                                : Colors.transparent,
                                            borderRadius:
                                                BorderRadius.circular(99)),
                                        child: Text(entry.$2,
                                            textAlign: TextAlign.center,
                                            style: TextStyle(
                                                fontSize: 11,
                                                fontWeight: _period == entry.$1
                                                    ? FontWeight.w700
                                                    : FontWeight.w400,
                                                color: Colors.white))))))
                    ])),
                const SizedBox(height: 12),
                Offstage(
                    offstage: !_showFilters,
                    child: OrbitSurface(
                        child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                          Row(children: [
                            const Expanded(
                                child: Text('Advanced filters & priorities',
                                    style: TextStyle(
                                        fontWeight: FontWeight.w700))),
                            IconButton(
                                tooltip: 'Close filters',
                                onPressed: () =>
                                    setState(() => _showFilters = false),
                                icon: const Icon(Icons.close, size: 18))
                          ]),
                          const Text('Priority',
                              style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w800,
                                  color: OrbitColors.textNavy)),
                          const SizedBox(height: 6),
                          FutureBuilder<Map<String, dynamic>>(
                            future: _priorityFuture,
                            builder: (context, snapshot) {
                              if (snapshot.connectionState ==
                                  ConnectionState.waiting)
                                return const LinearProgressIndicator();
                              if (snapshot.hasError)
                                return TextButton(
                                    onPressed: _reloadPriorities,
                                    child: const Text(
                                        'Priority is unavailable. Retry'));
                              final payload =
                                  snapshot.data ?? const <String, dynamic>{};
                              final rows = payload['data'] is List
                                  ? payload['data'] as List
                                  : const [];
                              final meta = payload['meta'];
                              return Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    if (rows.isEmpty)
                                      const Padding(
                                          padding:
                                              EdgeInsets.symmetric(vertical: 8),
                                          child:
                                              Text('No priority tasks yet.')),
                                    for (final row in rows.whereType<Map>())
                                      ListTile(
                                        dense: true,
                                        contentPadding: EdgeInsets.zero,
                                        title: Text(
                                            (row['title'] ?? 'Task').toString(),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis),
                                        trailing: IconButton(
                                            tooltip: 'Remove from Priority',
                                            icon: const Icon(
                                                Icons.remove_circle_outline),
                                            onPressed: () async {
                                              await ref
                                                  .read(taskRepositoryProvider)
                                                  .removePriority(
                                                      (row['task_id'] as num)
                                                          .toInt());
                                              if (!mounted) return;
                                              _reloadPriorities();
                                              ref
                                                  .read(taskNotifierProvider
                                                      .notifier)
                                                  .loadTasks();
                                            }),
                                        onTap: () => Navigator.of(context).push(
                                            MaterialPageRoute(
                                                builder: (_) =>
                                                    TaskDetailScreen(
                                                        taskId: (row['task_id']
                                                                as num)
                                                            .toInt()))),
                                      ),
                                    if (meta is Map &&
                                        (meta['last_page'] as num? ?? 1) > 1)
                                      const Text(
                                          'Showing your saved priority tasks'),
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
                                _ideasTimer = Timer(
                                    const Duration(milliseconds: 350), () {
                                  if (mounted)
                                    setState(() => _ideasFuture =
                                        _loadIdeas(_ideasSearch));
                                });
                              },
                            ),
                            FutureBuilder<Map<String, dynamic>>(
                              future: _ideasFuture,
                              builder: (context, snapshot) {
                                if (snapshot.connectionState ==
                                    ConnectionState.waiting)
                                  return const LinearProgressIndicator();
                                if (snapshot.hasError)
                                  return TextButton(
                                      onPressed: () => setState(() =>
                                          _ideasFuture =
                                              _loadIdeas(_ideasSearch)),
                                      child: const Text(
                                          'Unable to load EC ideas. Retry'));
                                final data =
                                    snapshot.data ?? const <String, dynamic>{};
                                final ideas = data['data'] is List
                                    ? data['data'] as List
                                    : const [];
                                return Column(children: [
                                  if (ideas.isEmpty)
                                    const ListTile(
                                        title: Text('No EC ideas for today')),
                                  for (final idea in ideas.whereType<Map>())
                                    ListTile(
                                      contentPadding: EdgeInsets.zero,
                                      leading:
                                          const Icon(Icons.lightbulb_outline),
                                      title: Text((idea['title'] ??
                                              idea['idea'] ??
                                              'EC idea')
                                          .toString()),
                                      subtitle: Text((idea['status_name'] ??
                                              idea['status'] ??
                                              '')
                                          .toString()),
                                    ),
                                ]);
                              },
                            ),
                            const Divider(height: 24),
                          ],
                          DropdownButtonFormField<String>(
                            key: ValueKey('status-$_status'),
                            value: _status,
                            decoration: const InputDecoration(
                                labelText: 'Status', isDense: true),
                            items: const [
                              DropdownMenuItem(
                                  value: 'all', child: Text('All statuses')),
                              DropdownMenuItem(
                                  value: 'open', child: Text('Open')),
                              DropdownMenuItem(
                                  value: 'in_progress',
                                  child: Text('In progress')),
                              DropdownMenuItem(
                                  value: 'pending_review',
                                  child: Text('Pending review')),
                              DropdownMenuItem(
                                  value: 'completed', child: Text('Completed')),
                              DropdownMenuItem(
                                  value: 'cancelled', child: Text('Cancelled')),
                              DropdownMenuItem(
                                  value: 'overdue', child: Text('Overdue')),
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
                            key: ValueKey('priority-$_priority'),
                            value: _priority,
                            decoration: const InputDecoration(
                                labelText: 'Priority', isDense: true),
                            items: const [
                              DropdownMenuItem(
                                  value: '', child: Text('Any priority')),
                              DropdownMenuItem(
                                  value: 'low', child: Text('Low')),
                              DropdownMenuItem(
                                  value: 'normal', child: Text('Normal')),
                              DropdownMenuItem(
                                  value: 'urgent', child: Text('Urgent'))
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
                              setState(() {
                                _dateRange = picked;
                                _period = TaskBoardPeriod.all;
                              });
                              ref.read(taskNotifierProvider.notifier).loadTasks(
                                  from: picked.start
                                      .toIso8601String()
                                      .substring(0, 10),
                                  to: picked.end
                                      .toIso8601String()
                                      .substring(0, 10));
                            },
                          ),
                          const SizedBox(height: 12),
                        ]))),
                if (_showFilters) const SizedBox(height: 12),
                OrbitSurface(
                    padding: EdgeInsets.zero,
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Padding(
                              padding: const EdgeInsets.fromLTRB(14, 10, 12, 6),
                              child: Row(children: [
                                Expanded(
                                    child: Text(
                                        taskState.isLoading
                                            ? 'Loading tasks…'
                                            : showAll
                                                ? 'Tasks (${taskState.total})'
                                                : 'Active Tasks (${tasks.length})',
                                        style: const TextStyle(
                                            fontSize: 18,
                                            fontWeight: FontWeight.w700,
                                            color: OrbitColors.textPrimary))),
                                TextButton.icon(
                                    onPressed: () =>
                                        _selectPeriod(TaskBoardPeriod.all),
                                    label: const Text('View All'),
                                    icon: const Icon(Icons.arrow_forward,
                                        size: 17),
                                    iconAlignment: IconAlignment.end,
                                    style: TextButton.styleFrom(
                                        padding: EdgeInsets.zero,
                                        minimumSize: const Size(0, 32),
                                        tapTargetSize:
                                            MaterialTapTargetSize.shrinkWrap)),
                              ])),
                          if (taskState.isLoading)
                            const Padding(
                                padding: EdgeInsets.all(28),
                                child:
                                    Center(child: CircularProgressIndicator()))
                          else if (taskState.error != null)
                            Center(
                                child: TextButton(
                                    onPressed: () => ref
                                        .read(taskNotifierProvider.notifier)
                                        .loadTasks(),
                                    child: const Text(
                                        'Unable to load tasks. Tap to retry.')))
                          else if (tasks.isEmpty)
                            const Padding(
                                padding: EdgeInsets.all(28),
                                child: Center(child: Text('No tasks assigned')))
                          else
                            for (var i = 0; i < tasks.length; i++) ...[
                              if (i > 0)
                                const Divider(
                                    height: 1, indent: 14, endIndent: 14),
                              TaskBoardRow(
                                  task: tasks[i],
                                  busy: _busyTasks.contains(tasks[i].id),
                                  onOpen: () => Navigator.of(context).push(
                                      MaterialPageRoute(
                                          builder: (_) => TaskDetailScreen(
                                              taskId: tasks[i].id))),
                                  onAction: _busyTasks.contains(tasks[i].id) ||
                                          !const ['complete', 'request_review']
                                              .contains(tasks[i].rowAction)
                                      ? null
                                      : () => _taskAction(tasks[i]),
                                  onPriority: tasks[i].priorityEligible &&
                                          !tasks[i].isPersonalPriority
                                      ? () => _addPriority(tasks[i])
                                      : null),
                            ],
                          if (taskState.page < taskState.lastPage &&
                              taskState.error == null)
                            Center(
                                child: TextButton(
                                    onPressed: taskState.isLoadingMore
                                        ? null
                                        : () => ref
                                            .read(taskNotifierProvider.notifier)
                                            .loadMore(),
                                    child: Text(taskState.isLoadingMore
                                        ? 'Loading…'
                                        : taskState.loadMoreError != null
                                            ? 'Unable to load more. Retry'
                                            : 'Load more tasks'))),
                        ])),
              ])),
    );
  }
}
