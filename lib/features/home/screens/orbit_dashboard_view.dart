import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../core/theme/orbit_theme.dart';
import '../../auth/providers/auth_provider.dart';
import '../../inbox/models/inbox_item_model.dart';
import '../../inbox/providers/inbox_provider.dart';
import '../../tasks/providers/task_provider.dart';
import '../../visits/models/visit_target_model.dart';
import '../../visits/services/visit_service.dart';

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

class _OrbitDashboardViewState extends ConsumerState<OrbitDashboardView> {
  int _selectedVisitFilter = 0; // 0: All, 1: Open, 2: Check in, 3: Closed
  bool _isClockedIn = false;
  DateTime? _clockInTime;

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authProvider).user;
    final userName = user?.name.split(' ').first ?? 'User';
    final taskState = ref.watch(taskNotifierProvider);
    final inboxState = ref.watch(inboxNotifierProvider);
    final visitTargetsAsync = ref.watch(visitTargetsNotifierProvider);
    final visitTargets = visitTargetsAsync.value ?? [];

    return Scaffold(
      backgroundColor: OrbitColors.scaffoldBackground,
      body: SafeArea(
        bottom: false,
        child: RefreshIndicator(
          color: OrbitColors.primaryNavy,
          onRefresh: () async {
            await ref.read(taskNotifierProvider.notifier).loadTasks();
            await ref.read(inboxNotifierProvider.notifier).loadInbox();
            ref.invalidate(visitTargetsNotifierProvider);
          },
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.only(left: 16, right: 16, top: 12, bottom: 100),
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
                _buildActiveTasksSection(taskState),
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
        Row(
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
            RichText(
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
            ),
          ],
        ),
        Row(
          children: [
            Stack(
              children: [
                IconButton(
                  onPressed: widget.onOpenNotifications,
                  icon: const Icon(Icons.notifications_none_rounded, color: OrbitColors.textPrimary, size: 24),
                  style: IconButton.styleFrom(
                    backgroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                      side: const BorderSide(color: OrbitColors.cardBorder),
                    ),
                  ),
                ),
                Positioned(
                  top: 8,
                  right: 8,
                  child: Container(
                    width: 8,
                    height: 8,
                    decoration: const BoxDecoration(
                      color: OrbitColors.accentCoral,
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(width: 8),
            IconButton(
              onPressed: widget.onOpenSearch,
              icon: const Icon(Icons.dashboard_customize_outlined, color: OrbitColors.textPrimary, size: 22),
              style: IconButton.styleFrom(
                backgroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: const BorderSide(color: OrbitColors.cardBorder),
                ),
              ),
            ),
          ],
        ),
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
              color: Colors.white,
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
                const Icon(Icons.search, color: OrbitColors.textMuted, size: 20),
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
            color: Colors.white,
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
            icon: const Icon(Icons.person_add_alt_1_outlined, color: OrbitColors.textNavy, size: 20),
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
                    color: _isClockedIn ? OrbitColors.kpiGreen : OrbitColors.textSecondary,
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
                  content: Text(_isClockedIn ? 'Clocked in successfully!' : 'Clocked out.'),
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
                _isClockedIn ? Icons.check_circle_rounded : Icons.navigation_rounded,
                color: _isClockedIn ? OrbitColors.kpiGreen : OrbitColors.textNavy,
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
            child: const Icon(Icons.calendar_today_rounded, size: 14, color: Colors.white),
          ),
          const SizedBox(width: 8),
          const Icon(Icons.event_note_rounded, size: 16, color: OrbitColors.textMuted),
          const SizedBox(width: 8),
          const Icon(Icons.dashboard_outlined, size: 16, color: OrbitColors.textMuted),
          const SizedBox(width: 8),
          const Icon(Icons.tune_rounded, size: 16, color: OrbitColors.textMuted),
          const Spacer(),
          Text(
            nowFormatted,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: OrbitColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildScoreAndPerformanceRow(TaskListState taskState, InboxListState inboxState) {
    final activeCount = taskState.tasks.length;
    final totalInbox = inboxState.items.length;
    final completedCount = taskState.tasks.where((t) => t.status == 'completed' || t.status == 'done').length;
    final progressPercent = activeCount > 0 ? ((completedCount / activeCount) * 100).toInt() : 0;
    final progressRatio = activeCount > 0 ? (completedCount / activeCount) : 0.0;

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
                        Icon(Icons.assignment_turned_in_outlined, size: 15, color: Colors.white70),
                        SizedBox(width: 4),
                        Text(
                          'Assigned Tasks',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                    const Spacer(),
                    Text(
                      '$activeCount',
                      style: const TextStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.w900,
                        color: Colors.white,
                        letterSpacing: -0.5,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      activeCount == 0 ? 'No pending tasks' : '$activeCount tasks in queue',
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
                    'Inbox Todos',
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
                      child: CircularProgressIndicator(
                        value: progressRatio > 0 ? progressRatio : 0.0,
                        strokeWidth: 5.5,
                        backgroundColor: OrbitColors.creamBorder,
                        valueColor: const AlwaysStoppedAnimation<Color>(OrbitColors.brandOrange),
                      ),
                    ),
                    Column(
                      children: [
                        Text(
                          '$totalInbox',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            color: OrbitColors.textNavy,
                          ),
                        ),
                        const Text(
                          'Pending',
                          style: TextStyle(
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
            Row(
              children: [
                const Icon(Icons.task_alt_rounded, size: 17, color: OrbitColors.textNavy),
                const SizedBox(width: 6),
                const Text(
                  'Active Assigned Tasks',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: OrbitColors.textNavy,
                  ),
                ),
                const SizedBox(width: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                  decoration: BoxDecoration(
                    color: OrbitColors.primaryNavy.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    '${tasks.length}',
                    style: const TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: OrbitColors.primaryNavy,
                    ),
                  ),
                ),
              ],
            ),
            if (taskState.isLoading)
              const SizedBox(
                width: 14,
                height: 14,
                child: CircularProgressIndicator(strokeWidth: 2, color: OrbitColors.primaryNavy),
              ),
          ],
        ),
        const SizedBox(height: 10),
        if (tasks.isEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: OrbitColors.cardBorder),
            ),
            child: Column(
              children: const [
                Icon(Icons.assignment_outlined, size: 36, color: OrbitColors.textMuted),
                SizedBox(height: 8),
                Text(
                  'No assigned tasks right now',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: OrbitColors.textNavy,
                  ),
                ),
                SizedBox(height: 2),
                Text(
                  'Tasks assigned to you will automatically appear here.',
                  style: TextStyle(
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
            itemCount: min(5, tasks.length),
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemBuilder: (context, index) {
              final task = tasks[index];
              Color priorityColor = OrbitColors.kpiGreen;
              Color priorityBg = OrbitColors.kpiGreenBg;
              if (task.priority.toLowerCase() == 'urgent') {
                priorityColor = OrbitColors.kpiRed;
                priorityBg = OrbitColors.kpiRedBg;
              } else if (task.priority.toLowerCase() == 'high') {
                priorityColor = OrbitColors.kpiOrange;
                priorityBg = OrbitColors.kpiOrangeBg;
              }

              return Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.white,
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
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                          decoration: BoxDecoration(
                            color: priorityBg,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            task.priority.toUpperCase(),
                            style: TextStyle(
                              fontSize: 9,
                              fontWeight: FontWeight.w800,
                              color: priorityColor,
                            ),
                          ),
                        ),
                        if (task.dueDate.isNotEmpty)
                          Row(
                            children: [
                              const Icon(Icons.calendar_today_rounded, size: 11, color: OrbitColors.textMuted),
                              const SizedBox(width: 4),
                              Text(
                                task.dueDate,
                                style: const TextStyle(fontSize: 11, color: OrbitColors.textMuted),
                              ),
                            ],
                          ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      task.title,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: OrbitColors.textNavy,
                      ),
                    ),
                    if (task.description.isNotEmpty) ...[
                      const SizedBox(height: 3),
                      Text(
                        task.description,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 11,
                          color: OrbitColors.textSecondary,
                          height: 1.3,
                        ),
                      ),
                    ],
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(999),
                            child: LinearProgressIndicator(
                              value: (task.progressPercent / 100.0).clamp(0.0, 1.0),
                              minHeight: 5,
                              backgroundColor: OrbitColors.scaffoldBackground,
                              valueColor: const AlwaysStoppedAnimation<Color>(OrbitColors.brandOrange),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          '${task.progressPercent}%',
                          style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: OrbitColors.textNavy),
                        ),
                      ],
                    ),
                  ],
                ),
              );
            },
          ),
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
            Row(
              children: [
                const Icon(Icons.mark_email_unread_outlined, size: 17, color: OrbitColors.textNavy),
                const SizedBox(width: 6),
                const Text(
                  'Unified Inbox & Approvals',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: OrbitColors.textNavy,
                  ),
                ),
                const SizedBox(width: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                  decoration: BoxDecoration(
                    color: OrbitColors.brandOrange.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    '${items.length}',
                    style: const TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: OrbitColors.brandOrange,
                    ),
                  ),
                ),
              ],
            ),
            if (inboxState.isLoading)
              const SizedBox(
                width: 14,
                height: 14,
                child: CircularProgressIndicator(strokeWidth: 2, color: OrbitColors.brandOrange),
              ),
          ],
        ),
        const SizedBox(height: 10),
        if (items.isEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: OrbitColors.cardBorder),
            ),
            child: Column(
              children: const [
                Icon(Icons.inbox_outlined, size: 36, color: OrbitColors.textMuted),
                SizedBox(height: 8),
                Text(
                  'All caught up!',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: OrbitColors.textNavy,
                  ),
                ),
                SizedBox(height: 2),
                Text(
                  'No pending approvals or unread notifications.',
                  style: TextStyle(
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

              return Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.white,
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
                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
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
                          if (item.subtitle != null && item.subtitle!.isNotEmpty) ...[
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
                      style: const TextStyle(fontSize: 10, color: OrbitColors.textMuted),
                    ),
                  ],
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

    final percentCompleted = totalCount > 0 ? ((checkedInCount / totalCount) * 100).toInt() : 0;

    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: const [
                Icon(Icons.assignment_outlined, size: 16, color: OrbitColors.textNavy),
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
                padding: EdgeInsets.only(right: index == filters.length - 1 ? 0 : 8.0),
                child: InkWell(
                  onTap: () => setState(() => _selectedVisitFilter = index),
                  borderRadius: BorderRadius.circular(14),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    decoration: BoxDecoration(
                      color: isSelected ? OrbitColors.pillDark : Colors.white,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: isSelected ? OrbitColors.pillDark : OrbitColors.cardBorder,
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
                            color: isSelected ? Colors.white : OrbitColors.textNavy,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          f['label']!,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
                            color: isSelected ? Colors.white70 : OrbitColors.textSecondary,
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
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: OrbitColors.cardBorder),
              ),
              child: Row(
                children: [
                  Icon(
                    isDone ? Icons.check_circle_rounded : Icons.storefront_rounded,
                    color: isDone ? OrbitColors.kpiGreen : OrbitColors.brandOrange,
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
                  const Icon(Icons.chevron_right_rounded, color: OrbitColors.textMuted, size: 20),
                ],
              ),
            );
          },
        ),
      ],
    );
  }
}
