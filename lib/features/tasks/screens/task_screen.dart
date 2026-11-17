import 'dart:async';
import 'package:flutter/material.dart';
import '../../../core/widgets/orbit_workspace.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/orbit_theme.dart';
import '../../auth/providers/auth_provider.dart';
import '../../auth/screens/profile_screen.dart';
import '../../../core/widgets/whatsapp_popup_menu.dart';
import '../../home/screens/global_search_screen.dart';
import '../providers/task_provider.dart';
import 'create_work_item_screen.dart';
import 'task_detail_screen.dart';
import '../widgets/task_board_row.dart';
import '../../inbox/screens/inbox_screen.dart';
import '../../inbox/providers/inbox_provider.dart';
import '../../home/providers/dashboard_provider.dart';
import '../../../core/widgets/expanding_action_fab.dart';

enum TaskBoardPeriod { today, week, month, overdue, all }

class TaskScreen extends ConsumerStatefulWidget {
  final VoidCallback? onOpenNotifications, onOpenProfile;
  final bool showFloatingActionButton;
  const TaskScreen({
    super.key,
    this.onOpenNotifications,
    this.onOpenProfile,
    this.showFloatingActionButton = true,
  });

  @override
  ConsumerState<TaskScreen> createState() => _TaskScreenState();
}

class _TaskScreenState extends ConsumerState<TaskScreen> {
  final _searchController = TextEditingController();
  final _searchFocus = FocusNode();
  final _scrollController = ScrollController();
  final _busyTasks = <int>{};
  bool _showFilters = false;
  TaskBoardPeriod _period = TaskBoardPeriod.all;
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
      if (mounted) _selectPeriod(TaskBoardPeriod.all);
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

  (DateTime?, DateTime?) _periodRange(TaskBoardPeriod period) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    if (period == TaskBoardPeriod.today) {
      return (today, today);
    }
    if (period == TaskBoardPeriod.week) {
      final start = today.subtract(Duration(days: today.weekday - 1));
      return (start, start.add(const Duration(days: 6)));
    }
    if (period == TaskBoardPeriod.month) {
      return (
        DateTime(now.year, now.month),
        DateTime(now.year, now.month + 1, 0)
      );
    }
    return (null, null);
  }

  Future<void> _selectPeriod(TaskBoardPeriod period) async {
    final (start, end) = _periodRange(period);
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

  Future<void> _selectScope(TaskScope scope) async {
    final (start, end) = _periodRange(_period);
    String date(DateTime d) => d.toIso8601String().split('T').first;
    await ref.read(taskNotifierProvider.notifier).loadTasks(
        scope: scope,
        status: _status,
        search: _searchController.text.trim(),
        priority: _priority,
        from: start == null ? null : date(start),
        to: end == null ? null : date(end),
        clearDateRange: start == null);
  }

  Future<void> _openFilterDialog() async {
    final user = ref.read(authProvider).user;
    final canManageEc = user?.can('task.ec.manage') == true;

    await showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Close filters',
      barrierColor: Colors.black.withValues(alpha: 0.4),
      transitionDuration: const Duration(milliseconds: 240),
      transitionBuilder: (ctx, anim1, anim2, child) {
        final curve = CurvedAnimation(
          parent: anim1,
          curve: Curves.easeOutCubic,
          reverseCurve: Curves.easeInCubic,
        );
        return SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(0, -0.15),
            end: Offset.zero,
          ).animate(curve),
          child: FadeTransition(
            opacity: curve,
            child: child,
          ),
        );
      },
      pageBuilder: (dialogContext, _, __) {
        return StatefulBuilder(
          builder: (modalContext, setModalState) {
            final media = MediaQuery.of(dialogContext);
            final maxHeight = media.size.height * 0.78;

            return SafeArea(
              child: Align(
                alignment: Alignment.topCenter,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                  child: Material(
                    color: Colors.transparent,
                    child: Container(
                      constraints: BoxConstraints(maxHeight: maxHeight),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.20),
                            blurRadius: 24,
                            spreadRadius: 2,
                            offset: const Offset(0, 8),
                          ),
                        ],
                      ),
                      clipBehavior: Clip.antiAlias,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          // Header
                          Padding(
                            padding: const EdgeInsets.fromLTRB(20, 16, 12, 12),
                            child: Row(
                              children: [
                                const Icon(Icons.tune_rounded,
                                    color: OrbitColors.primaryNavy, size: 22),
                                const SizedBox(width: 10),
                                const Expanded(
                                  child: Text(
                                    'Advanced filters & priorities',
                                    style: TextStyle(
                                      fontSize: 17,
                                      fontWeight: FontWeight.w800,
                                      color: OrbitColors.textNavy,
                                    ),
                                  ),
                                ),
                                IconButton(
                                  tooltip: 'Close filters',
                                  icon: const Icon(Icons.close_rounded,
                                      color: OrbitColors.textMuted, size: 22),
                                  onPressed: () => Navigator.of(dialogContext).pop(),
                                ),
                              ],
                            ),
                          ),
                          const Divider(height: 1, thickness: 1, color: OrbitColors.cardBorder),

                          // Scrollable body
                          Flexible(
                            child: SingleChildScrollView(
                              padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  if (canManageEc) ...[
                                    const Text('EC Today Ideas',
                                        style: TextStyle(
                                            fontSize: 16,
                                            fontWeight: FontWeight.w800,
                                            color: OrbitColors.textNavy)),
                                    const SizedBox(height: 6),
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
                                          if (mounted) {
                                            setState(() => _ideasFuture =
                                                _loadIdeas(_ideasSearch));
                                            setModalState(() {});
                                          }
                                        });
                                      },
                                    ),
                                    const SizedBox(height: 8),
                                    FutureBuilder<Map<String, dynamic>>(
                                      future: _ideasFuture,
                                      builder: (context, snapshot) {
                                        if (snapshot.connectionState ==
                                            ConnectionState.waiting) {
                                          return const LinearProgressIndicator();
                                        }
                                        if (snapshot.hasError) {
                                          return TextButton(
                                              onPressed: () {
                                                setState(() => _ideasFuture =
                                                    _loadIdeas(_ideasSearch));
                                                setModalState(() {});
                                              },
                                              child: const Text(
                                                  'Unable to load EC ideas. Retry'));
                                        }
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
                                  Builder(
                                    builder: (fieldCtx) {
                                      const statusOptions = {
                                        'all': 'All statuses',
                                        'open': 'Open',
                                        'in_progress': 'In progress',
                                        'pending_review': 'Pending review',
                                        'completed': 'Completed',
                                        'cancelled': 'Cancelled',
                                        'overdue': 'Overdue',
                                      };
                                      return _buildWhatsAppFieldSelector(
                                        key: ValueKey('status-$_status'),
                                        label: 'Status',
                                        value: statusOptions[_status] ?? 'All statuses',
                                        onTap: () async {
                                          final RenderBox? button =
                                              fieldCtx.findRenderObject() as RenderBox?;
                                          final RenderBox? overlay = Overlay.of(fieldCtx)
                                              .context
                                              .findRenderObject() as RenderBox?;
                                          if (button == null || overlay == null) return;
                                          final position = RelativeRect.fromRect(
                                            Rect.fromPoints(
                                              button.localToGlobal(
                                                  Offset(0, button.size.height + 4),
                                                  ancestor: overlay),
                                              button.localToGlobal(
                                                  button.size.bottomRight(Offset.zero),
                                                  ancestor: overlay),
                                            ),
                                            Offset.zero & overlay.size,
                                          );
                                          final selected = await showWhatsAppMenu<String>(
                                            context: fieldCtx,
                                            position: position,
                                            transformAlignment: Alignment.topLeft,
                                            minWidth: button.size.width,
                                            items: [
                                              for (final entry in statusOptions.entries)
                                                WhatsAppMenuItem<String>(
                                                  value: entry.key,
                                                  title: entry.value,
                                                  fontWeight: _status == entry.key
                                                      ? FontWeight.w700
                                                      : FontWeight.w400,
                                                  textColor: _status == entry.key
                                                      ? OrbitColors.primaryNavy
                                                      : const Color(0xFF111B21),
                                                  trailingIcon: _status == entry.key
                                                      ? Icons.check_rounded
                                                      : null,
                                                  iconColor: OrbitColors.primaryNavy,
                                                ),
                                            ],
                                          );
                                          if (selected != null && mounted) {
                                            setState(() => _status = selected);
                                            setModalState(() {});
                                            ref
                                                .read(taskNotifierProvider.notifier)
                                                .loadTasks(status: selected);
                                          }
                                        },
                                      );
                                    },
                                  ),
                                  const SizedBox(height: 12),
                                  Builder(
                                    builder: (fieldCtx) {
                                      const priorityOptions = {
                                        '': 'Any priority',
                                        'low': 'Low',
                                        'normal': 'Normal',
                                        'urgent': 'Urgent',
                                      };
                                      return _buildWhatsAppFieldSelector(
                                        key: ValueKey('priority-$_priority'),
                                        label: 'Priority',
                                        value: priorityOptions[_priority] ?? 'Any priority',
                                        onTap: () async {
                                          final RenderBox? button =
                                              fieldCtx.findRenderObject() as RenderBox?;
                                          final RenderBox? overlay = Overlay.of(fieldCtx)
                                              .context
                                              .findRenderObject() as RenderBox?;
                                          if (button == null || overlay == null) return;
                                          final position = RelativeRect.fromRect(
                                            Rect.fromPoints(
                                              button.localToGlobal(
                                                  Offset(0, button.size.height + 4),
                                                  ancestor: overlay),
                                              button.localToGlobal(
                                                  button.size.bottomRight(Offset.zero),
                                                  ancestor: overlay),
                                            ),
                                            Offset.zero & overlay.size,
                                          );
                                          final selected = await showWhatsAppMenu<String>(
                                            context: fieldCtx,
                                            position: position,
                                            transformAlignment: Alignment.topLeft,
                                            minWidth: button.size.width,
                                            items: [
                                              for (final entry in priorityOptions.entries)
                                                WhatsAppMenuItem<String>(
                                                  value: entry.key,
                                                  title: entry.value,
                                                  fontWeight: _priority == entry.key
                                                      ? FontWeight.w700
                                                      : FontWeight.w400,
                                                  textColor: _priority == entry.key
                                                      ? OrbitColors.primaryNavy
                                                      : const Color(0xFF111B21),
                                                  trailingIcon: _priority == entry.key
                                                      ? Icons.check_rounded
                                                      : null,
                                                  iconColor: OrbitColors.primaryNavy,
                                                ),
                                            ],
                                          );
                                          if (selected != null && mounted) {
                                            setState(() => _priority = selected);
                                            setModalState(() {});
                                            ref
                                                .read(taskNotifierProvider.notifier)
                                                .loadTasks(priority: selected);
                                          }
                                        },
                                      );
                                    },
                                  ),
                                  const SizedBox(height: 12),
                                  Row(
                                    children: [
                                      Expanded(
                                        child: TextButton.icon(
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
                                            setModalState(() {});
                                            ref.read(taskNotifierProvider.notifier).loadTasks(
                                                from: picked.start
                                                    .toIso8601String()
                                                    .substring(0, 10),
                                                to: picked.end
                                                    .toIso8601String()
                                                    .substring(0, 10));
                                          },
                                        ),
                                      ),
                                      if (_status != 'all' ||
                                          _priority.isNotEmpty ||
                                          _dateRange != null) ...[
                                        TextButton(
                                          onPressed: () {
                                            setState(() {
                                              _status = 'all';
                                              _priority = '';
                                              _dateRange = null;
                                            });
                                            setModalState(() {});
                                            ref
                                                .read(taskNotifierProvider.notifier)
                                                .loadTasks(
                                                    status: 'all',
                                                    priority: '',
                                                    clearDateRange: true);
                                          },
                                          child: const Text('Reset'),
                                        ),
                                      ],
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildWhatsAppFieldSelector({
    Key? key,
    required String label,
    required String value,
    required VoidCallback onTap,
  }) {
    return Material(
      key: key,
      color: const Color(0xFFF7F8FA),
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          child: Row(
            children: [
              Expanded(
                child: Row(
                  children: [
                    Text(
                      '$label:',
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: OrbitColors.textMuted,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        value,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w700,
                          color: OrbitColors.textNavy,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(
                Icons.keyboard_arrow_down_rounded,
                color: Color(0xFF54656F),
                size: 20,
              ),
            ],
          ),
        ),
      ),
    );
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
          {Key? key, bool badge = false}) =>
      IconButton(
          key: key,
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
    final tasks = (showAll || taskState.scope == TaskScope.delegatedByMe)
        ? taskState.tasks
        : taskState.tasks
            .where((task) =>
                task.status != 'completed' && task.status != 'cancelled')
            .toList();
    final String boardTitle;
    if (taskState.isLoading) {
      boardTitle = 'Loading tasks…';
    } else if (taskState.scope == TaskScope.delegatedByMe) {
      boardTitle = 'Assigned to Others (${tasks.length})';
    } else if (showAll) {
      boardTitle = 'Tasks (${taskState.total})';
    } else {
      boardTitle = 'Active Tasks (${tasks.length})';
    }
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
            _headerAction(
              Icons.search_rounded,
              'Search tasks',
              () => Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) =>
                      const GlobalSearchScreen(scope: SearchScope.tasks),
                ),
              ),
            ),
            _headerAction(
              Icons.tune_rounded,
              'Advanced filters & priorities',
              _openFilterDialog,
              key: const ValueKey('task-board-filters-toggle'),
              badge: _status != 'all' || _priority.isNotEmpty || _dateRange != null,
            ),
          ]),
      floatingActionButton: !widget.showFloatingActionButton
          ? null
          : Padding(
              padding: EdgeInsets.only(
                  bottom: orbitResponsiveFabBottomOffset(context)),
              child: OrbitPlusFab(
                heroTag: 'task-board-fab',
                tooltip: 'Create task',
                onPressed: () async {
                  final created = await Navigator.of(context).push<bool>(
                      MaterialPageRoute(
                          builder: (_) => const CreateWorkItemScreen()));
                  if (created == true && mounted) {
                    ref.read(taskNotifierProvider.notifier).loadTasks();
                    ref.invalidate(dashboardTasksProvider);
                    ref.invalidate(dashboardTaskStatsProvider);
                  }
                },
              ),
            ),
      body: RefreshIndicator(
          onRefresh: () => ref.read(taskNotifierProvider.notifier).loadTasks(),
          child: ListView(
              controller: _scrollController,
              padding: EdgeInsets.fromLTRB(
                  12, 12, 12, orbitResponsiveListBottomPadding(context)),
              children: [
                Container(
                    key: const ValueKey('task-scope-toggle'),
                    padding: const EdgeInsets.all(3),
                    decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: .18),
                        borderRadius: BorderRadius.circular(99),
                        border: Border.all(
                            color: Colors.white.withValues(alpha: .45))),
                    child: Row(children: [
                      Expanded(
                          child: Semantics(
                              selected:
                                  taskState.scope == TaskScope.assignedToMe,
                              button: true,
                              child: InkWell(
                                  onTap: () =>
                                      _selectScope(TaskScope.assignedToMe),
                                  borderRadius: BorderRadius.circular(99),
                                  child: AnimatedContainer(
                                      duration: MediaQuery.disableAnimationsOf(
                                              context)
                                          ? Duration.zero
                                          : const Duration(milliseconds: 220),
                                      padding: const EdgeInsets.symmetric(
                                          vertical: 8),
                                      decoration: BoxDecoration(
                                          color: taskState.scope ==
                                                  TaskScope.assignedToMe
                                              ? OrbitColors.primaryNavy
                                              : Colors.transparent,
                                          borderRadius:
                                              BorderRadius.circular(99)),
                                      child: Row(
                                          mainAxisAlignment:
                                              MainAxisAlignment.center,
                                          children: [
                                            const Icon(
                                                Icons.person_outline_rounded,
                                                size: 15,
                                                color: Colors.white),
                                            const SizedBox(width: 5),
                                            Flexible(
                                              child: Text('Assigned to Me',
                                                  maxLines: 1,
                                                  overflow:
                                                      TextOverflow.ellipsis,
                                                  textAlign: TextAlign.center,
                                                  style: TextStyle(
                                                      fontSize: 12,
                                                      fontWeight: taskState
                                                                  .scope ==
                                                              TaskScope
                                                                  .assignedToMe
                                                          ? FontWeight.w700
                                                          : FontWeight.w400,
                                                      color: Colors.white)),
                                            ),
                                          ]))))),
                      Expanded(
                          child: Semantics(
                              selected:
                                  taskState.scope == TaskScope.delegatedByMe,
                              button: true,
                              child: InkWell(
                                  onTap: () =>
                                      _selectScope(TaskScope.delegatedByMe),
                                  borderRadius: BorderRadius.circular(99),
                                  child: AnimatedContainer(
                                      duration: MediaQuery.disableAnimationsOf(
                                              context)
                                          ? Duration.zero
                                          : const Duration(milliseconds: 220),
                                      padding: const EdgeInsets.symmetric(
                                          vertical: 8),
                                      decoration: BoxDecoration(
                                          color: taskState.scope ==
                                                  TaskScope.delegatedByMe
                                              ? OrbitColors.primaryNavy
                                              : Colors.transparent,
                                          borderRadius:
                                              BorderRadius.circular(99)),
                                      child: Row(
                                          mainAxisAlignment:
                                              MainAxisAlignment.center,
                                          children: [
                                            const Icon(
                                                Icons.people_alt_outlined,
                                                size: 15,
                                                color: Colors.white),
                                            const SizedBox(width: 5),
                                            Flexible(
                                              child: Text('Assign to Others',
                                                  maxLines: 1,
                                                  overflow:
                                                      TextOverflow.ellipsis,
                                                  textAlign: TextAlign.center,
                                                  style: TextStyle(
                                                      fontSize: 12,
                                                      fontWeight: taskState
                                                                  .scope ==
                                                              TaskScope
                                                                  .delegatedByMe
                                                          ? FontWeight.w700
                                                          : FontWeight.w400,
                                                      color: Colors.white)),
                                            ),
                                          ]))))),
                    ])),
                const SizedBox(height: 8),
                Container(
                    padding: const EdgeInsets.all(3),
                    decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: .10),
                        borderRadius: BorderRadius.circular(99),
                        border: Border.all(
                            color: Colors.white.withValues(alpha: .4))),
                    child: Row(children: [
                      for (final entry in const [
                        (TaskBoardPeriod.all, 'All'),
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
                FutureBuilder<Map<String, dynamic>>(
                  future: _priorityFuture,
                  builder: (context, snapshot) {
                    if (snapshot.hasError || !snapshot.hasData) {
                      return const SizedBox.shrink();
                    }
                    final payload = snapshot.data!;
                    final rows = payload['data'] is List
                        ? (payload['data'] as List).whereType<Map>().toList()
                        : const <Map>[];
                    if (rows.isEmpty) return const SizedBox.shrink();

                    return Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: OrbitSurface(
                        padding: EdgeInsets.zero,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Padding(
                              padding: EdgeInsets.fromLTRB(14, 12, 14, 4),
                              child: Row(
                                children: [
                                  Icon(Icons.star_rounded,
                                      color: OrbitColors.primaryNavy, size: 20),
                                  SizedBox(width: 7),
                                  Text(
                                    'Priority',
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w800,
                                      color: OrbitColors.textPrimary,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            for (final row in rows)
                              ListTile(
                                dense: true,
                                title: Text(
                                  (row['title'] ?? 'Task').toString(),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                trailing: IconButton(
                                  tooltip: 'Remove from Priority',
                                  icon: const Icon(Icons.remove_circle_outline),
                                  onPressed: () async {
                                    final taskId =
                                        (row['task_id'] as num).toInt();
                                    await ref
                                        .read(taskRepositoryProvider)
                                        .removePriority(taskId);
                                    if (!mounted) return;
                                    _reloadPriorities();
                                    ref
                                        .read(taskNotifierProvider.notifier)
                                        .loadTasks(showLoading: false);
                                  },
                                ),
                                onTap: () => Navigator.of(context).push(
                                  MaterialPageRoute(
                                    builder: (_) => TaskDetailScreen(
                                      taskId: (row['task_id'] as num).toInt(),
                                    ),
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
                const SizedBox(height: 12),
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
                                            : boardTitle,
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
                            Padding(
                                padding: const EdgeInsets.all(28),
                                child: Center(
                                    child: Text(taskState.scope ==
                                            TaskScope.delegatedByMe
                                        ? 'No tasks assigned to others found for this period'
                                        : 'No tasks assigned for this period')))
                          else
                            for (var i = 0; i < tasks.length; i++) ...[
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
