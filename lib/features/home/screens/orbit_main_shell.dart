import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/realtime/reverb_service.dart';
import '../../../core/theme/orbit_theme.dart';
import '../../../core/widgets/workhub_navigation_bar.dart';
import '../../../core/updater/app_updater_service.dart';
import '../../../core/updater/update_dialog.dart';
import '../../auth/providers/auth_provider.dart';
import '../../chat/screens/chat_list_screen.dart';
import '../../chat/screens/employee_chat_screen.dart';
import '../../inbox/providers/inbox_provider.dart';
import '../../inbox/screens/inbox_screen.dart';
import '../../projects/screens/projects_screen.dart';
import '../../tasks/screens/task_screen.dart';
import 'orbit_dashboard_view.dart';

class OrbitMainShell extends ConsumerStatefulWidget {
  const OrbitMainShell({super.key});

  @override
  ConsumerState<OrbitMainShell> createState() => _OrbitMainShellState();
}

class _OrbitMainShellState extends ConsumerState<OrbitMainShell> {
  int _currentIndex = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(reverbServiceProvider).connect();
    });
  }

  void _onBottomNavTapped(int index) {
    setState(() => _currentIndex = index);
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

  void _checkForUpdates() async {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Checking for updates...'),
        duration: Duration(seconds: 1),
      ),
    );
    final updater = AppUpdaterService();
    final shorebird = await updater.checkForShorebirdUpdate();
    if (!mounted) return;
    if (shorebird != ShorebirdUpdateResult.unavailable) {
      final message = switch (shorebird) {
        ShorebirdUpdateResult.upToDate => 'You are using the latest version.',
        ShorebirdUpdateResult.downloaded =>
          'Update downloaded. Close and reopen WorkHub to use it.',
        ShorebirdUpdateResult.restartRequired =>
          'An update is ready. Close and reopen WorkHub to apply it.',
        ShorebirdUpdateResult.failed =>
          'Unable to check or download the update. Please try again.',
        ShorebirdUpdateResult.unavailable => '',
      };
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(message),
          backgroundColor: shorebird == ShorebirdUpdateResult.failed
              ? null
              : OrbitColors.kpiGreen));
      return;
    }
    final release = await updater.checkForUpdate();
    if (!mounted) return;

    if (release != null && release.hasUpdate) {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (_) => UpdateDialog(releaseInfo: release),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('You are using the latest version.'),
          backgroundColor: OrbitColors.kpiGreen,
        ),
      );
    }
  }

  void _showProfileDialog() {
    final user = ref.read(authProvider).user;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        title: const Text(
          'My Profile',
          style: TextStyle(
              color: OrbitColors.textNavy, fontWeight: FontWeight.bold),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: CircleAvatar(
                radius: 36,
                backgroundColor: OrbitColors.bubbleBlue,
                child: Text(
                  user?.name.isNotEmpty == true
                      ? user!.name[0].toUpperCase()
                      : 'U',
                  style: const TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: OrbitColors.primaryNavy,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
            _buildProfileRow('Full Name', user?.name ?? '-'),
            _buildProfileRow('Username', user?.username ?? '-'),
            _buildProfileRow('Email', user?.email ?? '-'),
            _buildProfileRow('Job Title', user?.title ?? '-'),
            _buildProfileRow('Department', user?.department ?? '-'),
            _buildProfileRow('Employee Code', user?.employeeCode ?? '-'),
            _buildProfileRow(
                'Employee ID', user?.employeeId?.toString() ?? '-'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Close',
                style: TextStyle(color: OrbitColors.textSecondary)),
          ),
          FilledButton(
            onPressed: () {
              Navigator.pop(ctx);
              _handleLogout();
            },
            style: FilledButton.styleFrom(
              backgroundColor: OrbitColors.accentCoral,
              foregroundColor: Colors.white,
            ),
            child: const Text('Logout'),
          ),
        ],
      ),
    );
  }

  Widget _buildProfileRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              '$label:',
              style: const TextStyle(
                  color: OrbitColors.textSecondary,
                  fontSize: 13,
                  fontWeight: FontWeight.w500),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                  color: OrbitColors.textPrimary,
                  fontSize: 13,
                  fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }

  void _handleLogout() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Logout'),
        content: const Text('Are you sure you want to log out from WorkHub?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              ref.read(authProvider.notifier).logout();
            },
            child: const Text('Logout',
                style: TextStyle(color: OrbitColors.accentCoral)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final inboxCount = ref.watch(inboxNotifierProvider).items.length;

    final pages = [
      OrbitDashboardView(
        onOpenSearch: () => setState(() => _currentIndex = 2),
        onOpenNotifications: () => setState(() => _currentIndex = 1),
        onOpenCheckIn: _showQuickActionSheet,
      ),
      const InboxScreen(),
      const EmployeeChatScreen(),
      const ProjectsScreen(),
    ];

    return Scaffold(
      backgroundColor: OrbitColors.scaffoldBackground,
      body: IndexedStack(
        index: _currentIndex,
        children: pages,
      ),
      bottomNavigationBar: WorkHubNavigationBar(
          selectedIndex: _currentIndex,
          inboxCount: inboxCount,
          onSelected: _onBottomNavTapped),
    );
  }
}
