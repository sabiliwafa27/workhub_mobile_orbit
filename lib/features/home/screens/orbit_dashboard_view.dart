import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/orbit_theme.dart';
import '../../auth/providers/auth_provider.dart';
import '../../inbox/providers/inbox_provider.dart';
import '../../tasks/providers/task_provider.dart';

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

  final List<Map<String, dynamic>> _topStores = [
    {'name': 'Dwi - Ps Wates', 'status': 'Pending', 'address': 'Ps. Wates No. 12'},
    {'name': 'Hariyanti - Ps Wates', 'status': 'Pending', 'address': 'Ps. Wates Blok B-4'},
    {'name': 'Chris - Ps Wates', 'status': 'Pending', 'address': 'Jl. Raya Wates No. 8'},
    {'name': 'Suharni - Ps Wates', 'status': 'Completed', 'address': 'Ps. Wates Timur'},
  ];

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authProvider).user;
    final userName = user?.name.split(' ').first ?? 'Budi';
    final taskState = ref.watch(taskNotifierProvider);
    final inboxState = ref.watch(inboxNotifierProvider);

    return Scaffold(
      backgroundColor: OrbitColors.scaffoldBackground,
      body: SafeArea(
        bottom: false,
        child: RefreshIndicator(
          color: OrbitColors.primaryNavy,
          onRefresh: () async {
            await ref.read(taskNotifierProvider.notifier).loadTasks();
            await ref.read(inboxNotifierProvider.notifier).loadInbox();
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

                // 2. Greeting & Decorative Sun Horizon
                _buildGreetingSection(userName),
                const SizedBox(height: 16),

                // 3. Search & Quick Action Pill
                _buildSearchBar(),
                const SizedBox(height: 16),

                // 4. Primarasa Food Industri Clock-in Card
                _buildAttendanceCard(),
                const SizedBox(height: 16),

                // 5. Date Strip Capsule
                _buildDateStrip(),
                const SizedBox(height: 16),

                // 6. Score & Performance Cards (Side by Side)
                _buildScoreAndPerformanceRow(taskState),
                const SizedBox(height: 16),

                // 7. Today's Visits & Metric Filter Capsules
                _buildTodayVisitsSection(),
                const SizedBox(height: 16),

                // 8. Supervisor Guidance / AI Priority Assistant Card
                _buildSupervisorGuidanceCard(),
                const SizedBox(height: 16),

                // 9. Working Hours Card
                _buildWorkingHoursCard(),
                const SizedBox(height: 16),

                // 10. KPI Performance Radar / Metric Cards
                _buildKpiMetricsGrid(),
                const SizedBox(height: 16),

                // 11. Top Priority Stores / Customers
                _buildTopStoresList(),
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
              decoration: BoxDecoration(
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
                    text: 'Sales',
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
              'Good Morning, $name',
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w800,
                color: OrbitColors.textNavy,
                letterSpacing: -0.4,
              ),
            ),
            const SizedBox(height: 2),
            const Text(
              'Sales Productivity Dashboard',
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
                      hintText: 'Search customer / store',
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
                  _isClockedIn ? 'Clocked in 07:15' : 'Not clocked in',
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
              setState(() => _isClockedIn = !_isClockedIn);
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
              decoration: BoxDecoration(
                color: OrbitColors.scaffoldBackground,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.navigation_rounded,
                color: OrbitColors.textNavy,
                size: 20,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDateStrip() {
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
          const Text(
            'Kamis, 2 Jumadil Akhir 1448',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: OrbitColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildScoreAndPerformanceRow(TaskListState taskState) {
    return Row(
      children: [
        // Left Card: Daily Score (Navy Gradient)
        Expanded(
          child: Container(
            height: 140,
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
                        Icon(Icons.shield_outlined, size: 15, color: Colors.white70),
                        SizedBox(width: 4),
                        Text(
                          'Daily Score',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                    const Spacer(),
                    const Text(
                      '0.0%',
                      style: TextStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.w900,
                        color: Colors.white,
                        letterSpacing: -0.5,
                      ),
                    ),
                    const SizedBox(height: 2),
                    const Text(
                      'Rank #1 of 6',
                      style: TextStyle(
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

        // Right Card: MTD Performance (Cream Tint)
        Expanded(
          child: Container(
            height: 140,
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
                    'MTD Performance',
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
                      width: 64,
                      height: 64,
                      child: CircularProgressIndicator(
                        value: 0.794,
                        strokeWidth: 6,
                        backgroundColor: OrbitColors.creamBorder,
                        valueColor: const AlwaysStoppedAnimation<Color>(OrbitColors.brandOrange),
                      ),
                    ),
                    Column(
                      children: const [
                        Text(
                          '79.4%',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w800,
                            color: OrbitColors.textNavy,
                          ),
                        ),
                        Text(
                          'Realized',
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

  Widget _buildTodayVisitsSection() {
    final filters = [
      {'label': 'All', 'count': '0'},
      {'label': 'Open', 'count': '0'},
      {'label': 'Check in', 'count': '0'},
      {'label': 'Closed', 'count': '0'},
    ];

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
              child: const Text(
                '0% Completed',
                style: TextStyle(
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

  Widget _buildSupervisorGuidanceCard() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: OrbitColors.cardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const CircleAvatar(
                radius: 18,
                backgroundColor: OrbitColors.scaffoldBackground,
                child: Icon(Icons.person, color: OrbitColors.primaryNavy, size: 20),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Text(
                          'Raka',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: OrbitColors.textNavy,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                          decoration: BoxDecoration(
                            color: OrbitColors.coralIconBg,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: const Text(
                            'Prioritas',
                            style: TextStyle(
                              fontSize: 9,
                              fontWeight: FontWeight.w700,
                              color: OrbitColors.coralIcon,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const Text(
                      'Leading Supervisor',
                      style: TextStyle(
                        fontSize: 11,
                        color: OrbitColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.refresh_rounded, size: 18, color: OrbitColors.textMuted),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: OrbitColors.bubbleBlue,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: OrbitColors.bubbleBlueBorder),
            ),
            child: const Text(
              'Anda masih tertinggal Rp 36,7jt dari target harian dengan DPI terlemah di Sales Value. Segera kunjungi PFI - Ps Wates, Hariyanti - Ps Wates, Chris - statusnya pending untuk menyelesaikan kunjungan lainnya bisa dijaga pada jadwal berikutnya.',
              style: TextStyle(
                fontSize: 12,
                height: 1.4,
                color: Color(0xFF0369A1),
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          const SizedBox(height: 6),
          const Align(
            alignment: Alignment.centerLeft,
            child: Text(
              '🕒 Generated at 09:18',
              style: TextStyle(
                fontSize: 10,
                color: OrbitColors.textMuted,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWorkingHoursCard() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: OrbitColors.cardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: const [
              Icon(Icons.calendar_month_outlined, size: 16, color: OrbitColors.textNavy),
              SizedBox(width: 6),
              Text(
                'Working Hours',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: OrbitColors.textNavy,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: const [
              Text(
                '07:12 - 09:20',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: OrbitColors.textNavy,
                ),
              ),
              Text(
                '2h 8m / 6h',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: OrbitColors.textSecondary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              value: 0.35,
              minHeight: 6,
              backgroundColor: OrbitColors.scaffoldBackground,
              valueColor: const AlwaysStoppedAnimation<Color>(OrbitColors.brandOrange),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildKpiMetricsGrid() {
    final kpis = [
      {'title': 'SKU Lines', 'value': '60%', 'target': '60%', 'color': OrbitColors.kpiOrange, 'bg': OrbitColors.kpiOrangeBg},
      {'title': 'Effective Calls', 'value': '0%', 'target': '0%', 'color': OrbitColors.kpiRed, 'bg': OrbitColors.kpiRedBg},
      {'title': 'Stores / Hour', 'value': '70%', 'target': '70%', 'color': OrbitColors.kpiOrange, 'bg': OrbitColors.kpiOrangeBg},
      {'title': 'Productive Hours', 'value': '83%', 'target': '83%', 'color': OrbitColors.kpiGreen, 'bg': OrbitColors.kpiGreenBg},
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'KPI Performance',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w700,
            color: OrbitColors.textNavy,
          ),
        ),
        const SizedBox(height: 10),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            mainAxisSpacing: 10,
            crossAxisSpacing: 10,
            childAspectRatio: 2.1,
          ),
          itemCount: kpis.length,
          itemBuilder: (context, i) {
            final kpi = kpis[i];
            return Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: OrbitColors.cardBorder),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        kpi['title'] as String,
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: OrbitColors.textSecondary,
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                        decoration: BoxDecoration(
                          color: kpi['bg'] as Color,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          kpi['target'] as String,
                          style: TextStyle(
                            fontSize: 9,
                            fontWeight: FontWeight.bold,
                            color: kpi['color'] as Color,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    kpi['value'] as String,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: kpi['color'] as Color,
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ],
    );
  }

  Widget _buildTopStoresList() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Toko Utama Anda (4 dari 15)',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w700,
            color: OrbitColors.textNavy,
          ),
        ),
        const SizedBox(height: 10),
        ListView.separated(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: _topStores.length,
          separatorBuilder: (_, __) => const SizedBox(height: 8),
          itemBuilder: (context, i) {
            final store = _topStores[i];
            return Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: OrbitColors.cardBorder),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.emoji_events_rounded,
                    color: OrbitColors.brandOrange,
                    size: 20,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          store['name'] as String,
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: OrbitColors.textNavy,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          store['address'] as String,
                          style: const TextStyle(
                            fontSize: 11,
                            color: OrbitColors.textSecondary,
                          ),
                        ),
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
