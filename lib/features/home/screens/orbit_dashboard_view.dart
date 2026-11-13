import 'dart:math';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';
import '../../../core/theme/orbit_theme.dart';
import '../../../core/theme/orbit_motion.dart';
import '../providers/dashboard_provider.dart';
import 'orbit_dashboard_components.dart';
import '../../projects/screens/projects_screen.dart';
import '../../auth/providers/auth_provider.dart';
import '../../inbox/providers/inbox_provider.dart';
import '../../inbox/screens/inbox_screen.dart';
import '../../tasks/providers/task_provider.dart';
import '../../tasks/providers/ec_progress_provider.dart';
import '../../tasks/screens/create_work_item_screen.dart';
import '../../tasks/screens/task_detail_screen.dart';
import '../../visits/models/visit_target_model.dart';
import '../../visits/services/visit_service.dart';

final _dashboardInboxProvider = FutureProvider<InboxFetchResult>((ref) async {
  // Refresh when the Inbox changes, but fetch its pending, unfiltered view.
  ref.watch(inboxNotifierProvider.select((state) => state.items));
  return ref.watch(inboxRepositoryProvider).fetchTodos();
});

final _performanceProvider = FutureProvider<Map<String, dynamic>>((ref) async {
  ref.watch(taskNotifierProvider.select((state) => state.tasks));
  final response =
      await ref.watch(apiClientProvider).dio.get('/tasks/performance');
  return Map<String, dynamic>.from(response.data['data'] as Map);
});

class OrbitDashboardView extends ConsumerStatefulWidget {
  final VoidCallback onOpenSearch;
  final VoidCallback onOpenNotifications;
  final VoidCallback onOpenCheckIn;
  final VoidCallback? onOpenTasks, onOpenProjects, onOpenErp, onOpenProfile;

  const OrbitDashboardView({
    super.key,
    required this.onOpenSearch,
    required this.onOpenNotifications,
    required this.onOpenCheckIn,
    this.onOpenTasks,
    this.onOpenProjects,
    this.onOpenErp,
    this.onOpenProfile,
  });

  @override
  ConsumerState<OrbitDashboardView> createState() => _OrbitDashboardViewState();
}

class _EcProgressRow extends ConsumerStatefulWidget {
  final Map<String, dynamic> entry;
  final bool canEdit;
  final int page;
  const _EcProgressRow(
      {super.key,
      required this.entry,
      required this.canEdit,
      required this.page});

  @override
  ConsumerState<_EcProgressRow> createState() => _EcProgressRowState();
}

class _EcProgressRowState extends ConsumerState<_EcProgressRow> {
  Map<String, dynamic>? attempt;
  bool saving = false;
  bool failed = false;
  String? rejection;

  Future<void> save(int percentage, {bool retry = false}) async {
    if (saving || !widget.canEdit) return;
    if (!retry) {
      final label = percentage == 100
          ? 'Selesai'
          : percentage == 50
              ? 'Sedang Berjalan'
              : 'Belum Dimulai';
      attempt = {
        'percentage': percentage,
        'note': 'Status diubah menjadi $label.',
        'submission_key': const Uuid().v4()
      };
    }
    setState(() {
      saving = true;
      failed = false;
      rejection = null;
    });
    try {
      await ref
          .read(apiClientProvider)
          .dio
          .post('/ec/entries/${widget.entry['id']}/progress', data: attempt);
      if (mounted) {
        attempt = null;
        ref.invalidate(ecProgressProvider(widget.page));
        ref.invalidate(_dashboardInboxProvider);
        ref.read(inboxNotifierProvider.notifier).loadInbox();
      }
    } on DioException catch (exception) {
      final status = exception.response?.statusCode;
      if (mounted && status != null && status >= 400 && status < 500) {
        setState(() {
          attempt = null;
          rejection =
              'This update was rejected. Refresh EC progress and check your access.';
        });
      } else if (mounted) {
        setState(() => failed = true);
      }
    } catch (_) {
      if (mounted) setState(() => failed = true);
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final progress = widget.entry['current_progress'];
    final percentage =
        progress is Map ? (progress['percentage'] as num? ?? 0).toInt() : 0;
    return Card(
        child: Padding(
      padding: const EdgeInsets.all(12),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text((widget.entry['title'] ?? '').toString(),
            style: const TextStyle(fontWeight: FontWeight.w600)),
        const SizedBox(height: 8),
        LinearProgressIndicator(
            value: (percentage / 100).clamp(0.0, 1.0).toDouble()),
        Row(children: [
          Text('$percentage%'),
          const Spacer(),
          if (widget.canEdit && percentage < 100)
            DropdownButton<int>(
              value: percentage == 0 || percentage == 50 ? percentage : null,
              hint: const Text('Change status'),
              items: const [
                DropdownMenuItem(value: 0, child: Text('Not started')),
                DropdownMenuItem(value: 50, child: Text('In progress')),
                DropdownMenuItem(value: 100, child: Text('Completed'))
              ],
              onChanged: saving || failed || rejection != null
                  ? null
                  : (value) {
                      if (value != null && value != percentage) save(value);
                    },
            ),
          if (saving)
            const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2)),
          if (failed && widget.canEdit)
            TextButton(
                onPressed: () =>
                    save(attempt!['percentage'] as int, retry: true),
                child: const Text('Retry')),
        ]),
        if (rejection != null)
          TextButton(
              onPressed: () => ref.invalidate(ecProgressProvider(widget.page)),
              child: Text(rejection!)),
      ]),
    ));
  }
}

class _OrbitDashboardViewState extends ConsumerState<OrbitDashboardView> {
  int _ecPage = 1;
  bool _showEc = false;
  int _selectedVisitFilter = 0; // 0: All, 1: Open, 2: Check in, 3: Closed
  DashboardPeriod _period = DashboardPeriod.today;

  void _openTasks() => (widget.onOpenTasks ?? widget.onOpenSearch)();
  void _openProjects() {
    if (widget.onOpenProjects != null) {
      widget.onOpenProjects!();
      return;
    }
    Navigator.of(context)
        .push(MaterialPageRoute(builder: (_) => const ProjectsScreen()));
  }

  final Set<int> _pendingTaskActions = {};
  final Set<int> _uncertainTaskActions = {};

  Future<void> _refreshTasks() async {
    final period = _period;
    final notifier = ref.read(dashboardTasksProvider(period).notifier);
    await notifier.loadTasks();
    if (mounted &&
        _period == period &&
        identical(
            ref.read(dashboardTasksProvider(period).notifier), notifier) &&
        !ref.read(dashboardTasksProvider(period)).isLoading &&
        ref.read(dashboardTasksProvider(period)).error == null) {
      setState(() => _uncertainTaskActions.clear());
    }
  }

  Future<void> _performTaskAction(TaskItemModel task) async {
    if (_pendingTaskActions.contains(task.id) ||
        _uncertainTaskActions.contains(task.id) ||
        task.rowAction == null) return;
    setState(() => _pendingTaskActions.add(task.id));
    try {
      final repository = ref.read(taskRepositoryProvider);
      final success = task.rowAction == 'request_review'
          ? await repository.requestReview(task.id)
          : await repository.completeTask(task.id);
      if (!mounted) return;
      if (success) {
        await ref.read(dashboardTasksProvider(_period).notifier).loadTasks();
        if (mounted) {
          ref.read(taskNotifierProvider.notifier).loadTasks();
          ref.invalidate(_dashboardInboxProvider);
          ref.read(inboxNotifierProvider.notifier).loadInbox();
        }
      } else {
        setState(() => _uncertainTaskActions.add(task.id));
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text(
                'The update could not be confirmed. Refresh My Tasks before trying again.')));
      }
    } finally {
      if (mounted) setState(() => _pendingTaskActions.remove(task.id));
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authProvider).user;
    final userName = user?.name.split(' ').first ?? 'User';
    final taskState = ref.watch(dashboardTasksProvider(_period));
    final dashboardInbox = ref.watch(_dashboardInboxProvider);
    final inbox = dashboardInbox.valueOrNull;
    final inboxState = InboxListState(
      items: inbox?.items ?? const [],
      incompleteCount: inbox?.incompleteCount,
      completeCount: inbox?.completeCount,
      isLoading: dashboardInbox.isLoading,
      error: dashboardInbox.hasError
          ? inboxErrorMessage(dashboardInbox.error!)
          : null,
    );
    final ecProgress = ref.watch(ecProgressProvider(_ecPage));
    final visitTargetsAsync = ref.watch(visitTargetsNotifierProvider);
    final visitTargets = visitTargetsAsync.value ?? [];

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Stack(children: [
        const Positioned.fill(
            child: DecoratedBox(
                decoration: BoxDecoration(
          gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                OrbitColors.primaryNavyDark,
                OrbitColors.scaffoldBackground,
                OrbitColors.scaffoldBackground
              ],
              stops: [
                0,
                .48,
                1
              ]),
        ))),
        Positioned(
            top: 0,
            left: 0,
            right: 0,
            height: 260,
            child: ShaderMask(
                blendMode: BlendMode.dstIn,
                shaderCallback: (bounds) => const LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Colors.white, Colors.white, Colors.transparent],
                    stops: [0, .62, 1]).createShader(bounds),
                child: Image.asset('assets/images/dashboard_mountains.png',
                    fit: BoxFit.cover, alignment: Alignment.topCenter))),
        SafeArea(
          bottom: false,
          child: RefreshIndicator(
            color: OrbitColors.primaryNavy,
            onRefresh: () async {
              await _refreshTasks();
              if (!mounted) return;
              await ref.read(inboxNotifierProvider.notifier).loadInbox();
              if (!mounted) return;
              ref.invalidate(_dashboardInboxProvider);
              ref.invalidate(ecProgressProvider(_ecPage));
              ref.invalidate(visitTargetsNotifierProvider);
              ref.invalidate(dashboardTaskStatsProvider(_period));
            },
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.only(
                  left: 12, right: 12, top: 12, bottom: 100),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  OrbitEntrance(child: _buildReferenceHeader(userName)),
                  const SizedBox(height: 10),
                  OrbitEntrance(
                      delay: const Duration(milliseconds: 60),
                      child: _buildPeriodPicker()),
                  const SizedBox(height: 12),
                  OrbitEntrance(
                      delay: const Duration(milliseconds: 110),
                      child: _buildReferenceMetrics(taskState, inbox)),
                  const SizedBox(height: 12),
                  OrbitEntrance(
                      delay: const Duration(milliseconds: 170),
                      child: DashboardProgress(
                        stats: ref
                            .watch(dashboardTaskStatsProvider(_period))
                            .valueOrNull,
                        loading: ref
                            .watch(dashboardTaskStatsProvider(_period))
                            .isLoading,
                        onViewAll: _openTasks,
                      )),
                  const SizedBox(height: 12),
                  OrbitEntrance(
                      delay: const Duration(milliseconds: 210),
                      child: DashboardShortcuts(
                          onTasks: () => setState(() => _showEc = false),
                          onInbox: widget.onOpenNotifications,
                          onProjects: _openProjects,
                          onErp: widget.onOpenErp ?? widget.onOpenNotifications,
                          unread: inbox?.incompleteUnreadCount)),
                  const SizedBox(height: 12),
                  if (!_showEc)
                    OrbitEntrance(
                        delay: const Duration(milliseconds: 250),
                        child: _buildActiveTasksSection(taskState)),
                  if (_showEc) ...[
                    TextButton(
                        onPressed: () => setState(() => _showEc = false),
                        child: const Text('Back to My Tasks')),
                    const Text('Energy of Creation',
                        style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: OrbitColors.textNavy)),
                    const SizedBox(height: 10),
                    ecProgress.when(
                      loading: () =>
                          const Center(child: CircularProgressIndicator()),
                      error: (_, __) => TextButton(
                          onPressed: () =>
                              ref.invalidate(ecProgressProvider(_ecPage)),
                          child: const Text(
                              'Unable to load EC progress. Tap to retry.')),
                      data: (payload) {
                        final items = payload['data'] as List;
                        final meta = payload['meta'];
                        final lastPage = meta is Map
                            ? (meta['last_page'] as num? ?? 1).toInt()
                            : 1;
                        return Column(children: [
                          if (items.isEmpty)
                            const Text('No EC entries on this page.'),
                          for (final item in items)
                            _EcProgressRow(
                              key: ValueKey(item['id']),
                              entry: Map<String, dynamic>.from(item as Map),
                              canEdit: payload['can_edit'] == true,
                              page: _ecPage,
                            ),
                          if (lastPage > 1 || _ecPage > 1)
                            Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  TextButton(
                                      onPressed: _ecPage > 1
                                          ? () => setState(() => _ecPage--)
                                          : null,
                                      child: const Text('Previous')),
                                  Text('$_ecPage / $lastPage'),
                                  TextButton(
                                      onPressed: _ecPage < lastPage
                                          ? () => setState(() => _ecPage++)
                                          : null,
                                      child: const Text('Next')),
                                ]),
                        ]);
                      },
                    ),
                  ],
                  const SizedBox(height: 20),

                  // 8. Live Unified Inbox & Approvals Section
                  _buildPendingInboxSection(inboxState),
                  const SizedBox(height: 20),

                  // 9. Today's Scheduled Visits (only if visit targets exist)
                  if (visitTargets.isNotEmpty) ...[
                    _buildTodayVisitsSection(visitTargets),
                    const SizedBox(height: 16),
                    _buildTopStoresList(visitTargets),
                    const SizedBox(height: 16),
                  ],
                ],
              ),
            ),
          ),
        ),
      ]),
    );
  }

  Future<void> _showCreateMenu() async {
    final isEc = await showModalBottomSheet<bool>(
      context: context,
      builder: (context) => SafeArea(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
        ListTile(
            title: const Text('Create EC'),
            onTap: () => Navigator.pop(context, true)),
        ListTile(
            title: const Text('Create task'),
            onTap: () => Navigator.pop(context, false)),
      ])),
    );
    if (isEc == null || !context.mounted) return;
    final created = await Navigator.push<bool>(context,
        MaterialPageRoute(builder: (_) => CreateWorkItemScreen(isEc: isEc)));
    if (created == true && context.mounted) {
      setState(() => _ecPage = 1);
      ref.invalidate(ecProgressProvider(1));
      ref.invalidate(_dashboardInboxProvider);
      ref.read(taskNotifierProvider.notifier).loadTasks();
      ref.read(dashboardTasksProvider(_period).notifier).loadTasks();
      ref.read(inboxNotifierProvider.notifier).loadInbox();
    }
  }

  Widget _buildReferenceHeader(String name) {
    final hour = DateTime.now().hour;
    final greeting = hour < 11
        ? 'Good Morning'
        : hour < 15
            ? 'Good Afternoon'
            : hour < 18
                ? 'Good Evening'
                : 'Good Night';
    final photo = ref.watch(authProvider).user?.profilePhotoUrl;
    Widget action(IconData icon, String label, VoidCallback onTap,
            {bool badge = false}) =>
        IconButton(
          tooltip: label,
          onPressed: onTap,
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(minWidth: 36, minHeight: 40),
          icon: Container(
              width: 30,
              height: 30,
              decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withValues(alpha: .08),
                  border:
                      Border.all(color: Colors.white.withValues(alpha: .25))),
              child: Badge(
                  isLabelVisible: badge,
                  backgroundColor: OrbitColors.kpiRed,
                  child: Center(
                      child: Icon(icon, size: 18, color: Colors.white)))),
        );
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: const LinearGradient(colors: [
                  OrbitColors.bubbleBlueBorder,
                  OrbitColors.primaryNavy
                ]),
                border: Border.all(
                    color: Colors.white.withValues(alpha: .5), width: 2),
                boxShadow: const [
                  BoxShadow(color: Color(0x3306244D), blurRadius: 8)
                ]),
            child: const Icon(Icons.radio_button_checked,
                size: 24, color: Colors.white)),
        const SizedBox(width: 8),
        const Expanded(
            child: Text('Orbit\nWorkHub',
                style: TextStyle(
                    fontSize: 15,
                    height: 1.05,
                    fontWeight: FontWeight.w700,
                    color: Colors.white))),
        action(Icons.search_rounded, 'Search workspace', widget.onOpenSearch),
        action(Icons.notifications_none_rounded, 'Notifications',
            widget.onOpenNotifications,
            badge: (ref
                        .watch(_dashboardInboxProvider)
                        .valueOrNull
                        ?.incompleteUnreadCount ??
                    0) >
                0),
        action(Icons.grid_view_rounded, 'ERP workspace',
            widget.onOpenErp ?? widget.onOpenNotifications),
        IconButton(
            tooltip: 'My profile',
            onPressed: widget.onOpenProfile ?? widget.onOpenCheckIn,
            padding: const EdgeInsets.only(left: 5),
            constraints: const BoxConstraints(minWidth: 36, minHeight: 40),
            icon: CircleAvatar(
                radius: 16,
                backgroundColor: Colors.white,
                child: ClipOval(
                    child: photo == null || photo.isEmpty
                        ? Text(name.isEmpty ? 'U' : name[0].toUpperCase(),
                            style: const TextStyle(
                                color: OrbitColors.primaryNavy,
                                fontSize: 14,
                                fontWeight: FontWeight.w700))
                        : Image.network(photo,
                            width: 30,
                            height: 30,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => const Icon(
                                Icons.person_outline,
                                color: OrbitColors.primaryNavy))))),
      ]),
      const SizedBox(height: 12),
      Row(children: [
        Flexible(
            child: Text('$greeting, $name',
                style: const TextStyle(
                    fontSize: 20,
                    height: 1.15,
                    fontWeight: FontWeight.w700,
                    color: Colors.white))),
        const SizedBox(width: 5),
        const Icon(Icons.waving_hand_rounded,
            size: 22, color: OrbitColors.brandOrangeLight),
      ]),
      const SizedBox(height: 5),
      const Text('Unified Workspace for Tasks, Chat, Projects & ERP',
          style: TextStyle(fontSize: 11, height: 1.25, color: Colors.white)),
    ]);
  }

  Widget _buildPeriodPicker() => Row(children: [
        Expanded(
            flex: 3,
            child: Container(
                padding: const EdgeInsets.all(3),
                decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(99),
                    color: OrbitColors.primaryNavy.withValues(alpha: .3),
                    border:
                        Border.all(color: Colors.white.withValues(alpha: .35))),
                child: Row(children: [
                  for (final period in DashboardPeriod.values)
                    Expanded(
                        child: Semantics(
                      selected: _period == period,
                      button: true,
                      child: InkWell(
                        onTap: () {
                          if (period == _period) return;
                          setState(() => _period = period);
                        },
                        borderRadius: BorderRadius.circular(99),
                        child: AnimatedContainer(
                            duration: MediaQuery.disableAnimationsOf(context)
                                ? Duration.zero
                                : const Duration(milliseconds: 220),
                            padding: const EdgeInsets.symmetric(vertical: 4),
                            decoration: BoxDecoration(
                                color: _period == period
                                    ? OrbitColors.cardSurface
                                    : Colors.transparent,
                                borderRadius: BorderRadius.circular(99)),
                            child: Text(period.label,
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: _period == period
                                        ? FontWeight.w700
                                        : FontWeight.w400,
                                    color: _period == period
                                        ? OrbitColors.textPrimary
                                        : Colors.white))),
                      ),
                    )),
                ]))),
        const SizedBox(width: 12),
        Expanded(
            flex: 2,
            child: Row(children: [
              const Icon(Icons.calendar_today_outlined,
                  size: 16, color: Colors.white),
              const SizedBox(width: 5),
              Expanded(
                  child: FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerRight,
                      child: Text(
                          DateFormat('EEE, dd MMM yyyy').format(DateTime.now()),
                          style: const TextStyle(
                              fontSize: 11, color: Colors.white)))),
            ])),
      ]);

  Widget _buildReferenceMetrics(
      TaskListState taskState, InboxFetchResult? inbox) {
    final stats = ref.watch(dashboardTaskStatsProvider(_period));
    final performance = ref.watch(_performanceProvider);
    final unavailable = taskState.error != null || !stats.hasValue;
    final total = stats.valueOrNull?.total;
    final open = stats.valueOrNull?.open;
    final unread = inbox?.incompleteUnreadCount;
    final metrics = <Widget>[
      DashboardMetric(
          title: 'Total Tasks',
          value: unavailable ? '—' : '$total',
          caption: taskState.error != null || stats.hasError
              ? 'Unable to load tasks'
              : total == null
                  ? 'Loading tasks…'
                  : '$total assigned tasks',
          icon: Icons.assignment_outlined,
          accent: OrbitColors.royalBlue,
          waveColor: const Color(0xFF6366F1),
          tint: OrbitColors.bubbleBlue,
          wave: true,
          onTap: _openTasks),
      DashboardMetric(
          title: 'Open Tasks',
          value: open == null || total == null ? '—' : '$open / $total',
          caption: stats.hasError
              ? 'Status totals unavailable. Tap to retry.'
              : total == null || open == null
                  ? 'Loading status totals…'
                  : '${total == 0 ? 0 : (open * 100 / total).round()}% of selected period',
          icon: Icons.check_circle_outline,
          accent: OrbitColors.kpiGreen,
          tint: OrbitColors.kpiGreenBg,
          progress: open == null || total == null
              ? null
              : total == 0
                  ? 0
                  : open / total,
          onTap: stats.hasError
              ? () => ref.invalidate(dashboardTaskStatsProvider(_period))
              : _openTasks),
      DashboardMetric(
          title: 'Unread Inbox',
          value: unread == null ? '—' : '$unread',
          caption: unread == null
              ? 'Unread total unavailable'
              : 'Unread pending items',
          icon: Icons.mail_outline,
          accent: OrbitColors.kpiRed,
          waveColor: OrbitColors.pinkWave,
          tint: OrbitColors.pinkCardBg,
          wave: true,
          onTap: widget.onOpenNotifications),
      DashboardMetric(
          title: 'Total Points',
          value: performance.hasValue
              ? '${performance.valueOrNull?['earned_points'] ?? 0} pts'
              : '—',
          caption: performance.hasValue
              ? 'Tasks ${performance.valueOrNull?['task_points'] ?? '—'} · EC ${performance.valueOrNull?['ec_points'] ?? '—'}'
              : 'Points unavailable',
          icon: Icons.toll_outlined,
          accent: OrbitColors.brandOrange,
          tint: OrbitColors.creamCard),
    ];
    return Column(children: [
      for (var row = 0; row < 2; row++) ...[
        if (row > 0) const SizedBox(height: 8),
        IntrinsicHeight(
            child:
                Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Expanded(child: metrics[row * 2]),
          const SizedBox(width: 8),
          Expanded(child: metrics[row * 2 + 1]),
        ])),
      ],
    ]);
  }

  Widget _taskHeader() => Row(children: [
        Expanded(
            child: Text('My Tasks (${_period.label})',
                style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: OrbitColors.textPrimary))),
        TextButton.icon(
            onPressed: _openTasks,
            style: TextButton.styleFrom(
                minimumSize: const Size(0, 28),
                padding: EdgeInsets.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap),
            label: const Text('View All', style: TextStyle(fontSize: 11)),
            icon: const Icon(Icons.arrow_forward, size: 15),
            iconAlignment: IconAlignment.end),
        SizedBox(
            width: 28,
            height: 28,
            child: PopupMenuButton<String>(
              tooltip: 'Task options',
              iconSize: 18,
              padding: EdgeInsets.zero,
              onSelected: (value) {
                if (value == 'field') {
                  widget.onOpenCheckIn();
                } else if (value == 'ec') {
                  setState(() => _showEc = true);
                } else {
                  _showCreateMenu();
                }
              },
              itemBuilder: (_) => const [
                PopupMenuItem(
                    value: 'create', child: Text('Create task or EC')),
                PopupMenuItem(value: 'ec', child: Text('EC')),
                PopupMenuItem(value: 'field', child: Text('Field actions'))
              ],
            )),
      ]);

  String _dueLabel(String value) {
    final date = DateTime.tryParse(value);
    if (date == null) return value;
    final now = DateTime.now();
    return date.year == now.year &&
            date.month == now.month &&
            date.day == now.day
        ? 'Today'
        : DateFormat('dd MMM').format(date);
  }

  Widget _buildActiveTasksSection(TaskListState taskState) {
    final tasks = taskState.tasks;

    return DashboardSurface(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _taskHeader(),
            const SizedBox(height: 6),
            if (taskState.error != null)
              TextButton(
                onPressed: _refreshTasks,
                child: const Text('Unable to load tasks. Tap to retry.'),
              )
            else if (tasks.isEmpty && !taskState.isLoading)
              Container(
                width: double.infinity,
                padding:
                    const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
                decoration: BoxDecoration(
                  color: OrbitColors.cardSurface,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: OrbitColors.cardBorder),
                ),
                child: Column(
                  children: [
                    const Icon(Icons.assignment_outlined,
                        size: 36, color: OrbitColors.textMuted),
                    const SizedBox(height: 8),
                    Text(
                      taskState.total > 0
                          ? 'No tasks loaded'
                          : 'No assigned tasks right now',
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: OrbitColors.textNavy,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      taskState.total > 0
                          ? 'Refresh to load assigned tasks.'
                          : 'Tasks assigned to you will automatically appear here.',
                      style: const TextStyle(
                        fontSize: 11,
                        color: OrbitColors.textSecondary,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              )
            else
              ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: tasks.length,
                separatorBuilder: (_, __) => const Divider(height: 1),
                itemBuilder: (context, index) {
                  final task = tasks[index];
                  final actionLabel = task.rowAction == 'request_review'
                      ? 'Request review'
                      : 'Complete';
                  final unavailableReason = task.status == 'completed'
                      ? 'Completed'
                      : task.status == 'cancelled'
                          ? 'Cancelled'
                          : task.status == 'pending_review' ||
                                  task.hasPendingReview
                              ? 'Review already requested'
                              : 'Completion is unavailable for your role or this task state';
                  return Container(
                    color: OrbitColors.cardSurface,
                    padding:
                        const EdgeInsets.symmetric(horizontal: 0, vertical: 4),
                    child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Tooltip(
                              message: task.rowAction == null
                                  ? unavailableReason
                                  : '$actionLabel ${task.title}',
                              child: Semantics(
                                  label: task.rowAction == null
                                      ? '$unavailableReason: ${task.title}'
                                      : '$actionLabel ${task.title}',
                                  child: Checkbox(
                                    visualDensity: VisualDensity.compact,
                                    value: task.status == 'completed',
                                    onChanged: task.rowAction == null ||
                                            _pendingTaskActions
                                                .contains(task.id) ||
                                            _uncertainTaskActions
                                                .contains(task.id)
                                        ? null
                                        : (value) {
                                            if (value == true)
                                              _performTaskAction(task);
                                          },
                                  ))),
                          Expanded(
                              child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                if (task.projectName != null &&
                                    task.projectName!.isNotEmpty)
                                  Text(task.projectName!,
                                      style: const TextStyle(
                                          fontSize: 11,
                                          color: OrbitColors.textSecondary,
                                          fontWeight: FontWeight.w600)),
                                InkWell(
                                  onTap: () => Navigator.of(context).push(
                                      MaterialPageRoute(
                                          builder: (_) => TaskDetailScreen(
                                              taskId: task.id))),
                                  child: Padding(
                                      padding: const EdgeInsets.symmetric(
                                          vertical: 2),
                                      child: Text(task.title,
                                          style: TextStyle(
                                              fontSize: 12,
                                              height: 1.1,
                                              fontWeight: FontWeight.w500,
                                              color: OrbitColors.textNavy,
                                              decoration: task.status ==
                                                      'completed'
                                                  ? TextDecoration.lineThrough
                                                  : null))),
                                ),
                                Wrap(spacing: 10, runSpacing: 4, children: [
                                  if (task.assignees.isNotEmpty)
                                    Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          const Icon(Icons.person_outline,
                                              size: 13,
                                              color: OrbitColors.textSecondary),
                                          const SizedBox(width: 3),
                                          Flexible(
                                              child: Text(task.assignees.first,
                                                  maxLines: 1,
                                                  overflow:
                                                      TextOverflow.ellipsis,
                                                  style: const TextStyle(
                                                      fontSize: 10,
                                                      color: OrbitColors
                                                          .textSecondary))),
                                        ]),
                                  if (task.dueDate.isNotEmpty)
                                    Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          const Icon(
                                              Icons.calendar_today_outlined,
                                              size: 12,
                                              color: OrbitColors.textSecondary),
                                          const SizedBox(width: 4),
                                          Flexible(
                                              child: Text(
                                                  _dueLabel(task.dueDate),
                                                  maxLines: 1,
                                                  overflow:
                                                      TextOverflow.ellipsis,
                                                  style: const TextStyle(
                                                      fontSize: 10,
                                                      color: OrbitColors
                                                          .textSecondary))),
                                        ]),
                                ]),
                                Wrap(spacing: 4, runSpacing: 4, children: [
                                  if (task.status == 'pending_review' ||
                                      task.hasPendingReview)
                                    const Chip(
                                        label: Text('Pending review'),
                                        visualDensity: VisualDensity.compact),
                                ]),
                              ])),
                          const SizedBox(width: 6),
                          Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 9, vertical: 4),
                              decoration: BoxDecoration(
                                  color: task.priority.toLowerCase() == 'high'
                                      ? OrbitColors.kpiRedBg
                                      : OrbitColors.creamCard,
                                  borderRadius: BorderRadius.circular(99)),
                              child: Text(
                                  task.priority.isEmpty
                                      ? 'Medium'
                                      : task.priority[0].toUpperCase() +
                                          task.priority.substring(1),
                                  style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w600,
                                      color:
                                          task.priority.toLowerCase() == 'high'
                                              ? OrbitColors.kpiRed
                                              : OrbitColors.brandOrange))),
                        ]),
                  );
                },
              ),
            if (taskState.page < taskState.lastPage && taskState.error == null)
              Center(
                  child: TextButton(
                onPressed: taskState.isLoadingMore
                    ? null
                    : () => ref
                        .read(dashboardTasksProvider(_period).notifier)
                        .loadMore(),
                child: Text(taskState.isLoadingMore
                    ? 'Loading…'
                    : taskState.loadMoreError != null
                        ? 'Unable to load more. Retry'
                        : 'Load more tasks'),
              )),
          ],
        ));
  }

  Widget _buildPendingInboxSection(InboxListState inboxState) {
    final items = inboxState.items;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
                child: Row(
              children: [
                const Icon(Icons.mark_email_unread_outlined,
                    size: 17, color: OrbitColors.textNavy),
                const SizedBox(width: 6),
                const Flexible(
                    child: Text(
                  'Unified Inbox & Approvals',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: OrbitColors.textNavy,
                  ),
                )),
                const SizedBox(width: 6),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                  decoration: BoxDecoration(
                    color: OrbitColors.brandOrange.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    inboxState.isLoading ||
                            inboxState.error != null ||
                            inboxState.incompleteCount == null
                        ? '—'
                        : '${inboxState.incompleteCount}',
                    style: const TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: OrbitColors.brandOrange,
                    ),
                  ),
                ),
              ],
            )),
            if (inboxState.isLoading)
              const SizedBox(
                width: 14,
                height: 14,
                child: CircularProgressIndicator(
                    strokeWidth: 2, color: OrbitColors.brandOrange),
              ),
          ],
        ),
        const SizedBox(height: 10),
        if (inboxState.error != null)
          TextButton(
            onPressed: () => ref.invalidate(_dashboardInboxProvider),
            child: Text('${inboxState.error} Tap to retry.'),
          )
        else if (items.isEmpty && !inboxState.isLoading)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
            decoration: BoxDecoration(
              color: OrbitColors.cardSurface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: OrbitColors.cardBorder),
            ),
            child: Column(
              children: [
                const Icon(Icons.inbox_outlined,
                    size: 36, color: OrbitColors.textMuted),
                const SizedBox(height: 8),
                Text(
                  (inboxState.incompleteCount ?? 0) > 0
                      ? 'No items loaded'
                      : 'All caught up!',
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: OrbitColors.textNavy,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  (inboxState.incompleteCount ?? 0) > 0
                      ? 'Refresh to load pending items.'
                      : 'No pending approvals or unread notifications.',
                  style: const TextStyle(
                    fontSize: 11,
                    color: OrbitColors.textSecondary,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          )
        else
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: min(5, items.length),
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemBuilder: (context, index) {
              final item = items[index];
              Color tagBg = OrbitColors.bubbleBlue;
              Color tagColor = OrbitColors.primaryNavy;

              if (item.source.contains('guest')) {
                tagBg = const Color(0xFFFEF3C7);
                tagColor = const Color(0xFFB45309);
              } else if (item.source.contains('logistic')) {
                tagBg = const Color(0xFFDCFCE7);
                tagColor = const Color(0xFF15803D);
              } else if (item.source.contains('fleet')) {
                tagBg = OrbitColors.coralIconBg;
                tagColor = OrbitColors.coralIcon;
              }

              return InkWell(
                onTap: () {
                  final id = int.tryParse(item.subjectKey ?? '');
                  final isTask = item.subjectType == 'task' ||
                      const ['task', 'workhub', 'task-mine', 'task-assigned']
                          .contains(item.moduleCode);
                  Navigator.of(context).push(MaterialPageRoute(
                      builder: (_) => isTask && id != null
                          ? TaskDetailScreen(taskId: id)
                          : InboxItemDetailScreen(item: item)));
                },
                child: Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: OrbitColors.cardSurface,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: OrbitColors.cardBorder),
                    boxShadow: const [
                      BoxShadow(
                        color: Color(0x04000000),
                        blurRadius: 4,
                        offset: Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 7, vertical: 3),
                        decoration: BoxDecoration(
                          color: tagBg,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          item.sourceLabel,
                          style: TextStyle(
                            fontSize: 9,
                            fontWeight: FontWeight.w700,
                            color: tagColor,
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              item.title,
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: OrbitColors.textNavy,
                              ),
                            ),
                            if (item.subtitle != null &&
                                item.subtitle!.isNotEmpty) ...[
                              const SizedBox(height: 2),
                              Text(
                                item.subtitle!,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 11,
                                  color: OrbitColors.textSecondary,
                                  height: 1.3,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        item.createdAt,
                        style: const TextStyle(
                            fontSize: 10, color: OrbitColors.textMuted),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
      ],
    );
  }

  Widget _buildTodayVisitsSection(List<VisitTargetModel> targets) {
    final checkedInCount = targets.where((t) => t.isCheckedIn).length;
    final totalCount = targets.length;
    final openCount = totalCount - checkedInCount;

    final filters = [
      {'label': 'All', 'count': totalCount.toString()},
      {'label': 'Open', 'count': openCount.toString()},
      {'label': 'Check in', 'count': checkedInCount.toString()},
      {'label': 'Closed', 'count': '0'},
    ];

    final percentCompleted =
        totalCount > 0 ? ((checkedInCount / totalCount) * 100).toInt() : 0;

    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: const [
                Icon(Icons.assignment_outlined,
                    size: 16, color: OrbitColors.textNavy),
                SizedBox(width: 6),
                Text(
                  "Today's Visits",
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: OrbitColors.textNavy,
                  ),
                ),
              ],
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: OrbitColors.kpiGreenBg,
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                '$percentCompleted% Completed',
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: OrbitColors.kpiGreen,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          children: List.generate(filters.length, (index) {
            final f = filters[index];
            final isSelected = _selectedVisitFilter == index;
            return Expanded(
              child: Padding(
                padding: EdgeInsets.only(
                    right: index == filters.length - 1 ? 0 : 8.0),
                child: InkWell(
                  onTap: () => setState(() => _selectedVisitFilter = index),
                  borderRadius: BorderRadius.circular(14),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? OrbitColors.pillDark
                          : OrbitColors.cardSurface,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: isSelected
                            ? OrbitColors.pillDark
                            : OrbitColors.cardBorder,
                      ),
                      boxShadow: const [
                        BoxShadow(
                          color: Color(0x04000000),
                          blurRadius: 4,
                          offset: Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Column(
                      children: [
                        Text(
                          f['count']!,
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            color: isSelected
                                ? Colors.white
                                : OrbitColors.textNavy,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          f['label']!,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
                            color: isSelected
                                ? Colors.white70
                                : OrbitColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          }),
        ),
      ],
    );
  }

  Widget _buildTopStoresList(List<VisitTargetModel> targets) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Target Kunjungan Hari Ini (${targets.length})',
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w700,
            color: OrbitColors.textNavy,
          ),
        ),
        const SizedBox(height: 10),
        ListView.separated(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: targets.length,
          separatorBuilder: (_, __) => const SizedBox(height: 8),
          itemBuilder: (context, i) {
            final target = targets[i];
            final name = target.customerName;
            final address = target.address;
            final isDone = target.isCheckedIn;

            return Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: OrbitColors.cardSurface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: OrbitColors.cardBorder),
              ),
              child: Row(
                children: [
                  Icon(
                    isDone
                        ? Icons.check_circle_rounded
                        : Icons.storefront_rounded,
                    color:
                        isDone ? OrbitColors.kpiGreen : OrbitColors.brandOrange,
                    size: 20,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          name,
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: OrbitColors.textNavy,
                          ),
                        ),
                        if (address.isNotEmpty) ...[
                          const SizedBox(height: 2),
                          Text(
                            address,
                            style: const TextStyle(
                              fontSize: 11,
                              color: OrbitColors.textSecondary,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const Icon(Icons.chevron_right_rounded,
                      color: OrbitColors.textMuted, size: 20),
                ],
              ),
            );
          },
        ),
      ],
    );
  }
}
