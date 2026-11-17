import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/realtime/reverb_service.dart';
import '../../../core/services/fcm_notification_service.dart';
import '../../../core/theme/orbit_theme.dart';
import '../../../core/widgets/workhub_navigation_bar.dart';
import '../../auth/screens/profile_screen.dart';
import 'global_search_screen.dart';
import '../../chat/screens/chat_list_screen.dart';
import '../../chat/screens/employee_chat_screen.dart';
import '../../inbox/providers/inbox_provider.dart';
import '../../inbox/screens/inbox_screen.dart';
import '../../projects/screens/projects_screen.dart';
import '../../tasks/providers/ec_progress_provider.dart';
import '../../tasks/providers/task_provider.dart';
import '../../tasks/screens/create_work_item_screen.dart';
import '../../tasks/screens/task_screen.dart';
import '../../mail/screens/mail_screen.dart';
import '../providers/dashboard_provider.dart';
import 'orbit_dashboard_view.dart';

class OrbitMainShell extends ConsumerStatefulWidget {
  const OrbitMainShell({super.key});

  @override
  ConsumerState<OrbitMainShell> createState() => _OrbitMainShellState();
}

class _OrbitMainShellState extends ConsumerState<OrbitMainShell> {
  int _currentIndex = 0;
  @visibleForTesting
  int get currentIndex => _currentIndex;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(reverbServiceProvider).connect();
      ref.read(fcmNotificationServiceProvider).initialize();
    });
  }

  void _onBottomNavTapped(int index) {
    setState(() => _currentIndex = index);
  }

  void _openGlobalSearch() {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const GlobalSearchScreen()),
    );
  }

  void _openProfilePage() {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const ProfileScreen()),
    );
  }

  void _showQuickActionSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: OrbitColors.cardBorder,
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'Quick Actions',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: OrbitColors.textNavy,
                ),
              ),
              const SizedBox(height: 16),
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: OrbitColors.coralIconBg,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.location_on_outlined,
                      color: OrbitColors.coralIcon),
                ),
                title: const Text('GPS Check-In Itinerary',
                    style: TextStyle(fontWeight: FontWeight.w700)),
                subtitle: const Text(
                    'Take visit proof photo & clock GPS location',
                    style: TextStyle(fontSize: 12)),
                onTap: () {
                  Navigator.pop(ctx);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                        content: Text('Opening GPS Visit Check-in...'),
                        duration: Duration(seconds: 1)),
                  );
                },
              ),
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: OrbitColors.bubbleBlue,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.add_task_rounded,
                      color: OrbitColors.primaryNavy),
                ),
                title: const Text('New Task / Delegation',
                    style: TextStyle(fontWeight: FontWeight.w700)),
                subtitle: const Text('Assign task or review request to team',
                    style: TextStyle(fontSize: 12)),
                onTap: () {
                  Navigator.pop(ctx);
                  Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const TaskScreen()));
                },
              ),
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFFD1FAE5),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.chat_bubble_outline_rounded,
                      color: Color(0xFF059669)),
                ),
                title: const Text('Customer Discussion',
                    style: TextStyle(fontWeight: FontWeight.w700)),
                subtitle: const Text('Open WhatsApp discussion thread',
                    style: TextStyle(fontSize: 12)),
                onTap: () {
                  Navigator.pop(ctx);
                  Navigator.of(context).push(MaterialPageRoute(
                      builder: (_) => const ChatListScreen()));
                },
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _createWorkItem({required bool isEc}) async {
    final created = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => CreateWorkItemScreen(isEc: isEc)),
    );
    if (created != true || !mounted) return;
    ref.read(inboxNotifierProvider.notifier).loadInbox();
    if (isEc) {
      ref.invalidate(ecProgressProvider);
    } else {
      ref.read(taskNotifierProvider.notifier).loadTasks();
      ref.invalidate(dashboardTasksProvider);
      ref.invalidate(dashboardTaskStatsProvider);
    }
  }

  Future<void> _startEmployeeChat() async {
    final employee = await Navigator.of(context).push<Map<String, dynamic>>(
      MaterialPageRoute(builder: (_) => const EmployeePickerScreen()),
    );
    if (employee == null || !mounted) return;
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => EmployeeMessagesScreen(
          id: (employee['id'] as num).toInt(),
          name: employee['name'].toString(),
        ),
      ),
    );
    if (mounted) {
      ref.read(inboxNotifierProvider.notifier).loadInbox();
    }
  }

  void _showAddActionSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: OrbitColors.cardBorder,
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'Create New',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: OrbitColors.textNavy,
                ),
              ),
              const SizedBox(height: 12),
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFFE8F0FE),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.add_task_rounded,
                      color: Color(0xFF1967D2)),
                ),
                title: const Text('Create task',
                    style: TextStyle(fontWeight: FontWeight.w700)),
                subtitle: const Text('Assign task or review request to team',
                    style: TextStyle(fontSize: 12)),
                onTap: () {
                  Navigator.pop(ctx);
                  _createWorkItem(isEc: false);
                },
              ),
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFEF7E0),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.description_outlined,
                      color: Color(0xFFE37400)),
                ),
                title: const Text('Create EC',
                    style: TextStyle(fontWeight: FontWeight.w700)),
                subtitle: const Text('Submit an Energy of Creation entry',
                    style: TextStyle(fontSize: 12)),
                onTap: () {
                  Navigator.pop(ctx);
                  _createWorkItem(isEc: true);
                },
              ),
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFFE6F4EA),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.chat_bubble_outline_rounded,
                      color: Color(0xFF137333)),
                ),
                title: const Text('New chat / DM',
                    style: TextStyle(fontWeight: FontWeight.w700)),
                subtitle: const Text('Start direct message with a colleague',
                    style: TextStyle(fontSize: 12)),
                onTap: () {
                  Navigator.pop(ctx);
                  _startEmployeeChat();
                },
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }

  void _showMoreMenuSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: OrbitColors.cardBorder,
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'More Modules',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: OrbitColors.textNavy,
                ),
              ),
              const SizedBox(height: 12),
              ListTile(
                selected: _currentIndex == 3,
                leading: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: OrbitColors.bubbleBlue,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.folder_outlined,
                      color: OrbitColors.primaryNavy),
                ),
                title: const Text('Projects',
                    style: TextStyle(fontWeight: FontWeight.w700)),
                subtitle: const Text('Strategic projects & milestones',
                    style: TextStyle(fontSize: 12)),
                trailing: _currentIndex == 3
                    ? const Icon(Icons.check_circle_rounded,
                        color: OrbitColors.primaryNavy)
                    : const Icon(Icons.chevron_right_rounded),
                onTap: () {
                  Navigator.pop(ctx);
                  setState(() => _currentIndex = 3);
                },
              ),
              ListTile(
                selected: _currentIndex == 4,
                leading: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFFE0F2FE),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.mail_outline_rounded,
                      color: Color(0xFF0284C7)),
                ),
                title: const Text('Mail',
                    style: TextStyle(fontWeight: FontWeight.w700)),
                subtitle: const Text('Company webmail & messages',
                    style: TextStyle(fontSize: 12)),
                trailing: _currentIndex == 4
                    ? const Icon(Icons.check_circle_rounded,
                        color: OrbitColors.primaryNavy)
                    : const Icon(Icons.chevron_right_rounded),
                onTap: () {
                  Navigator.pop(ctx);
                  setState(() => _currentIndex = 4);
                },
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final inboxCount = ref.watch(inboxNotifierProvider).items.length;

    final pages = [
      OrbitDashboardView(
        onOpenSearch: _openGlobalSearch,
        onOpenNotifications: () => setState(() => _currentIndex = 1),
        onOpenTasks: () => setState(() => _currentIndex = 2),
        onOpenProjects: () => setState(() => _currentIndex = 3),
        onOpenErp: () => setState(() => _currentIndex = 4),
        onOpenCheckIn: _showQuickActionSheet,
        onOpenProfile: _openProfilePage,
      ),
      const InboxScreen(showFloatingActionButton: false),
      const TaskScreen(showFloatingActionButton: false),
      const ProjectsScreen(),
      const MailScreen(),
    ];

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        if (_currentIndex != 0) {
          setState(() => _currentIndex = 0);
          return;
        }
        final shouldQuit = await showDialog<bool>(
          context: context,
          builder: (dialogCtx) => AlertDialog(
            title: const Text('Keluar dari Aplikasi?'),
            content: const Text(
                'Apakah Anda yakin ingin keluar dari aplikasi WorkHub?'),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(dialogCtx).pop(false),
                child: const Text('Batal'),
              ),
              FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: OrbitColors.accentCoral,
                ),
                onPressed: () => Navigator.of(dialogCtx).pop(true),
                child: const Text('Keluar'),
              ),
            ],
          ),
        );
        if (shouldQuit == true) {
          await SystemNavigator.pop();
        }
      },
      child: Scaffold(
        extendBody: true,
        backgroundColor: OrbitColors.scaffoldBackground,
        body: IndexedStack(
          index: _currentIndex,
          children: pages,
        ),
        bottomNavigationBar: WorkHubNavigationBar(
          selectedIndex: _currentIndex,
          inboxCount: inboxCount,
          onSelected: _onBottomNavTapped,
          onAddTap: _showAddActionSheet,
          onMoreTap: _showMoreMenuSheet,
        ),
      ),
    );
  }
}
