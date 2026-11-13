import 'dart:math';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';
import '../../../core/theme/orbit_theme.dart';
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

  const OrbitDashboardView({
    super.key,
    required this.onOpenSearch,
    required this.onOpenNotifications,
    required this.onOpenCheckIn,
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
  bool _isClockedIn = false;
  DateTime? _clockInTime;
  final Set<int> _pendingTaskActions = {};
  final Set<int> _uncertainTaskActions = {};

  Future<void> _refreshTasks() async {
    await ref.read(taskNotifierProvider.notifier).loadTasks();
    if (mounted && ref.read(taskNotifierProvider).error == null) {
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
        await ref.read(taskNotifierProvider.notifier).loadTasks();
        if (mounted) {
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
    final taskState = ref.watch(taskNotifierProvider);
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
      backgroundColor: OrbitColors.scaffoldBackground,
      floatingActionButton: FloatingActionButton.large(
        tooltip: 'Create task or EC',
        onPressed: () async {
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
          final created = await Navigator.push<bool>(
              context,
              MaterialPageRoute(
                  builder: (_) => CreateWorkItemScreen(isEc: isEc)));
          if (created == true && context.mounted) {
            setState(() => _ecPage = 1);
            ref.invalidate(ecProgressProvider(1));
            ref.invalidate(_dashboardInboxProvider);
            ref.read(taskNotifierProvider.notifier).loadTasks();
            ref.read(inboxNotifierProvider.notifier).loadInbox();
          }
        },
        child: const Icon(Icons.add),
      ),
      body: SafeArea(
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
          },
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.only(
                left: 16, right: 16, top: 12, bottom: 100),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 1. Top Brand Header
                _buildTopBrandHeader(),
                const SizedBox(height: 16),

                // 2. Greeting & Sun Horizon
                _buildGreetingSection(userName),
                const SizedBox(height: 16),

                // 3. Search & Quick Action Pill
                _buildSearchBar(),
                const SizedBox(height: 16),

                // 4. Primarasa Food Industri Clock-in Card
                _buildAttendanceCard(),
                const SizedBox(height: 16),

                // 5. Dynamic Date Strip Capsule
                _buildDateStrip(),
                const SizedBox(height: 16),

                // 6. Live Overview & Progress Row
                _buildScoreAndPerformanceRow(taskState, inboxState),
                const SizedBox(height: 20),

                // 7. Live Assigned Tasks Section
                SegmentedButton<bool>(
                  segments: const [
                    ButtonSegment(value: false, label: Text('Tasks')),
                    ButtonSegment(value: true, label: Text('EC'))
                  ],
                  selected: {_showEc},
                  onSelectionChanged: (selection) =>
                      setState(() => _showEc = selection.first),
                ),
                const SizedBox(height: 12),
                if (!_showEc) _buildActiveTasksSection(taskState),
                if (_showEc) ...[
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
    );
  }

  Widget _buildTopBrandHeader() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(
            child: Row(
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: const BoxDecoration(
                color: OrbitColors.primaryNavy,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.radio_button_checked,
                color: Colors.white,
                size: 20,
              ),
            ),
            const SizedBox(width: 8),
            Flexible(
                child: FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: RichText(
                      text: const TextSpan(
                        children: [
                          TextSpan(
                            text: 'Orbit ',
                            style: TextStyle(
                              fontSize: 19,
                              fontWeight: FontWeight.w800,
                              color: OrbitColors.primaryNavy,
                              letterSpacing: -0.3,
                            ),
                          ),
                          TextSpan(
                            text: 'WorkHub',
                            style: TextStyle(
                              fontSize: 19,
                              fontWeight: FontWeight.w600,
                              color: OrbitColors.brandOrange,
                            ),
                          ),
                        ],
                      ),
                    ))),
          ],
        )),
      ],
    );
  }

  Widget _buildGreetingSection(String name) {
    final hour = DateTime.now().hour;
    final timeGreeting = hour < 11
        ? 'Good Morning'
        : hour < 15
            ? 'Good Afternoon'
            : hour < 18
                ? 'Good Evening'
                : 'Good Night';

    return Stack(
      children: [
        Positioned(
          right: 0,
          top: -4,
          child: SizedBox(
            width: 110,
            height: 60,
            child: Stack(
              children: [
                Positioned(
                  right: 20,
                  top: 0,
                  child: Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: LinearGradient(
                        colors: [
                          OrbitColors.sunAmber.withOpacity(0.9),
                          OrbitColors.brandOrangeLight.withOpacity(0.5),
                        ],
                      ),
                    ),
                  ),
                ),
                Positioned(
                  right: 0,
                  bottom: 0,
                  left: 0,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      height: 30,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            const Color(0xFFE2E8F0).withOpacity(0.4),
                            OrbitColors.scaffoldBackground,
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '$timeGreeting, $name',
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w800,
                color: OrbitColors.textNavy,
                letterSpacing: -0.4,
              ),
            ),
            const SizedBox(height: 2),
            const Text(
              'Operational & Productivity Dashboard',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: OrbitColors.textSecondary,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildSearchBar() {
    return Row(
      children: [
        Expanded(
          child: Container(
            height: 46,
            padding: const EdgeInsets.symmetric(horizontal: 14),
            decoration: BoxDecoration(
              color: OrbitColors.cardSurface,
              borderRadius: BorderRadius.circular(999),
              border: Border.all(color: OrbitColors.cardBorder),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x06000000),
                  blurRadius: 8,
                  offset: Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              children: [
                const Icon(Icons.search,
                    color: OrbitColors.textMuted, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    decoration: const InputDecoration(
                      hintText: 'Search tasks, inbox & records',
                      hintStyle: TextStyle(
                        fontSize: 13,
                        color: OrbitColors.textMuted,
                      ),
                      border: InputBorder.none,
                      isDense: true,
                    ),
                    onSubmitted: (val) {
                      widget.onOpenSearch();
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(width: 8),
        Container(
          width: 46,
          height: 46,
          decoration: BoxDecoration(
            color: OrbitColors.cardSurface,
            shape: BoxShape.circle,
            border: Border.all(color: OrbitColors.cardBorder),
            boxShadow: const [
              BoxShadow(
                color: Color(0x06000000),
                blurRadius: 8,
                offset: Offset(0, 2),
              ),
            ],
          ),
          child: IconButton(
            icon: const Icon(Icons.person_add_alt_1_outlined,
                color: OrbitColors.textNavy, size: 20),
            onPressed: widget.onOpenCheckIn,
          ),
        ),
      ],
    );
  }

  Widget _buildAttendanceCard() {
    final statusText = _isClockedIn && _clockInTime != null
        ? 'Clocked in ${DateFormat('HH:mm').format(_clockInTime!)}'
        : 'Tap navigation arrow to clock in';

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: OrbitColors.cardBorder),
        boxShadow: const [
          BoxShadow(
            color: Color(0x06000000),
            blurRadius: 8,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: OrbitColors.coralIconBg,
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              Icons.storefront_rounded,
              color: OrbitColors.coralIcon,
              size: 24,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Primarasa Food Industri',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: OrbitColors.textNavy,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  statusText,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: _isClockedIn
                        ? OrbitColors.kpiGreen
                        : OrbitColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          InkWell(
            onTap: () {
              setState(() {
                _isClockedIn = !_isClockedIn;
                if (_isClockedIn) {
                  _clockInTime = DateTime.now();
                }
              });
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(_isClockedIn
                      ? 'Clocked in successfully!'
                      : 'Clocked out.'),
                  duration: const Duration(seconds: 1),
                ),
              );
            },
            borderRadius: BorderRadius.circular(999),
            child: Container(
              padding: const EdgeInsets.all(10),
              decoration: const BoxDecoration(
                color: OrbitColors.scaffoldBackground,
                shape: BoxShape.circle,
              ),
              child: Icon(
                _isClockedIn
                    ? Icons.check_circle_rounded
                    : Icons.navigation_rounded,
                color:
                    _isClockedIn ? OrbitColors.kpiGreen : OrbitColors.textNavy,
                size: 20,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDateStrip() {
    final nowFormatted = DateFormat('EEEE, d MMMM yyyy').format(DateTime.now());

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: OrbitColors.cardBorder),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: OrbitColors.primaryNavy,
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(Icons.calendar_today_rounded,
                size: 14, color: Colors.white),
          ),
          const SizedBox(width: 8),
          const Icon(Icons.event_note_rounded,
              size: 16, color: OrbitColors.textMuted),
          const SizedBox(width: 8),
          const Icon(Icons.dashboard_outlined,
              size: 16, color: OrbitColors.textMuted),
          const SizedBox(width: 8),
          const Icon(Icons.tune_rounded,
              size: 16, color: OrbitColors.textMuted),
          const Spacer(),
          Flexible(
              child: Text(
            nowFormatted,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: OrbitColors.textSecondary,
            ),
          )),
        ],
      ),
    );
  }

  Widget _buildScoreAndPerformanceRow(
      TaskListState taskState, InboxListState inboxState) {
    final activeCount = taskState.total;
    final taskCountUnavailable = taskState.error != null ||
        (taskState.isLoading && taskState.tasks.isEmpty);
    final performance = ref.watch(_performanceProvider);
    final inboxCountUnavailable = !performance.hasValue;
    final totalInbox = performance.valueOrNull?['earned_points'] ?? 0;

    return Row(
      children: [
        // Left Card: Assigned Tasks (Navy Gradient)
        Expanded(
          child: Container(
            height: 130,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  OrbitColors.primaryNavy,
                  Color(0xFF0F3A73),
                ],
              ),
              borderRadius: BorderRadius.circular(22),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x1A06244D),
                  blurRadius: 10,
                  offset: Offset(0, 4),
                ),
              ],
            ),
            child: Stack(
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: const [
                        Icon(Icons.assignment_turned_in_outlined,
                            size: 15, color: Colors.white70),
                        SizedBox(width: 4),
                        Expanded(
                            child: Text(
                          'Assigned Tasks',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                          ),
                        )),
                      ],
                    ),
                    const Spacer(),
                    Text(
                      taskCountUnavailable ? '—' : '$activeCount',
                      style: const TextStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.w900,
                        color: Colors.white,
                        letterSpacing: -0.5,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      taskCountUnavailable
                          ? (taskState.error != null
                              ? 'Unable to load tasks'
                              : 'Loading tasks…')
                          : activeCount == 0
                              ? 'No assigned tasks'
                              : '$activeCount assigned tasks',
                      style: const TextStyle(
                        fontSize: 11,
                        color: Colors.white70,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
                Positioned(
                  right: 0,
                  bottom: 0,
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Container(width: 4, height: 16, color: Colors.white24),
                      const SizedBox(width: 2),
                      Container(width: 4, height: 26, color: Colors.white38),
                      const SizedBox(width: 2),
                      Container(width: 4, height: 38, color: Colors.white54),
                      const SizedBox(width: 2),
                      Container(width: 4, height: 48, color: Colors.white),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(width: 12),

        // Right Card: Pending Inbox & Approvals (Cream Tint)
        Expanded(
          child: Container(
            height: 130,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: OrbitColors.creamCard,
              borderRadius: BorderRadius.circular(22),
              border: Border.all(color: OrbitColors.creamBorder),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'Performance',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: OrbitColors.textNavy,
                    ),
                  ),
                ),
                const Spacer(),
                Stack(
                  alignment: Alignment.center,
                  children: [
                    SizedBox(
                      width: 58,
                      height: 58,
                      child: const SizedBox.shrink(),
                    ),
                    Column(
                      children: [
                        Text(
                          inboxCountUnavailable ? '—' : '$totalInbox',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            color: OrbitColors.textNavy,
                          ),
                        ),
                        Text(
                          performance.hasError
                              ? 'Unavailable'
                              : 'Tasks ${performance.valueOrNull?['task_points'] ?? '—'} · EC ${performance.valueOrNull?['ec_points'] ?? '—'}',
                          style: const TextStyle(
                            fontSize: 9,
                            fontWeight: FontWeight.w500,
                            color: OrbitColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                const Spacer(),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildActiveTasksSection(TaskListState taskState) {
    final tasks = taskState.tasks;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
                child: Row(
              children: [
                const Icon(Icons.task_alt_rounded,
                    size: 17, color: OrbitColors.textNavy),
                const SizedBox(width: 6),
                const Text(
                  'My Tasks',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: OrbitColors.textNavy,
                  ),
                ),
                const SizedBox(width: 6),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                  decoration: BoxDecoration(
                    color: OrbitColors.primaryNavy.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    '${taskState.total}',
                    style: const TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: OrbitColors.primaryNavy,
                    ),
                  ),
                ),
              ],
            )),
            if (taskState.isLoading)
              const SizedBox(
                width: 14,
                height: 14,
                child: CircularProgressIndicator(
                    strokeWidth: 2, color: OrbitColors.primaryNavy),
              ),
          ],
        ),
        const SizedBox(height: 10),
        if (taskState.error != null)
          TextButton(
            onPressed: _refreshTasks,
            child: const Text('Unable to load tasks. Tap to retry.'),
          )
        else if (tasks.isEmpty && !taskState.isLoading)
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
                      : task.status == 'pending_review' || task.hasPendingReview
                          ? 'Review already requested'
                          : 'Completion is unavailable for your role or this task state';
              return Container(
                color: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
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
                                value: task.status == 'completed',
                                onChanged: task.rowAction == null ||
                                        _pendingTaskActions.contains(task.id) ||
                                        _uncertainTaskActions.contains(task.id)
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
                                      builder: (_) =>
                                          TaskDetailScreen(taskId: task.id))),
                              child: Padding(
                                  padding:
                                      const EdgeInsets.symmetric(vertical: 4),
                                  child: Text(task.title,
                                      style: TextStyle(
                                          fontSize: 14,
                                          color: OrbitColors.textNavy,
                                          decoration: task.status == 'completed'
                                              ? TextDecoration.lineThrough
                                              : null))),
                            ),
                            Wrap(spacing: 4, runSpacing: 4, children: [
                              if (task.status == 'pending_review' ||
                                  task.hasPendingReview)
                                const Chip(
                                    label: Text('Pending review'),
                                    visualDensity: VisualDensity.compact),
                            ]),
                          ])),
                    ]),
              );
            },
          ),
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
    );
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
                    color: OrbitColors.brandOrange.withOpacity(0.12),
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
