import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/realtime/reverb_service.dart';
import '../../../core/theme/whatsapp_colors.dart';
import '../../../core/updater/app_updater_service.dart';
import '../../../core/updater/update_dialog.dart';
import '../../auth/providers/auth_provider.dart';
import '../../chat/screens/chat_list_screen.dart';
import '../../inbox/screens/inbox_screen.dart';
import '../../tasks/screens/task_screen.dart';
import '../../projects/screens/projects_screen.dart';

class WhatsAppMainScreen extends ConsumerStatefulWidget {
  const WhatsAppMainScreen({super.key});

  @override
  ConsumerState<WhatsAppMainScreen> createState() => _WhatsAppMainScreenState();
}

class _WhatsAppMainScreenState extends ConsumerState<WhatsAppMainScreen> {
  int _currentIndex = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(reverbServiceProvider).connect();
    });
  }

  final List<Widget> _pages = const [
    ChatListScreen(),
    InboxScreen(),
    TaskScreen(),
    ProjectsScreen(),
  ];

  void _onMenuSelected(String value) async {
    switch (value) {
      case 'updates':
        _checkForUpdates();
        break;
      case 'profile':
        _showProfileDialog();
        break;
      case 'logout':
        _handleLogout();
        break;
    }
  }

  void _checkForUpdates() async {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Checking for updates...'),
        duration: Duration(seconds: 1),
      ),
    );
    final updater = AppUpdaterService();
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
          backgroundColor: WhatsAppColors.tealGreen,
        ),
      );
    }
  }

  void _showProfileDialog() {
    final user = ref.read(authProvider).user;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: WhatsAppColors.cardBg,
        title: const Text(
          'My Profile',
          style: TextStyle(color: WhatsAppColors.textPrimary, fontWeight: FontWeight.bold),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: CircleAvatar(
                radius: 36,
                backgroundColor: WhatsAppColors.tealGreen.withOpacity(0.2),
                child: Text(
                  user?.name.isNotEmpty == true ? user!.name[0].toUpperCase() : 'U',
                  style: const TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: WhatsAppColors.tealGreen,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              user?.name ?? 'User',
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: WhatsAppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              user?.email ?? '',
              style: const TextStyle(
                fontSize: 14,
                color: WhatsAppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: WhatsAppColors.searchBarBg,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                'Employee ID: ${user?.employeeCode ?? "EMP-${user?.id ?? 0}"}',
                style: const TextStyle(
                  fontSize: 12,
                  color: WhatsAppColors.textSecondary,
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Close', style: TextStyle(color: WhatsAppColors.tealGreen)),
          ),
        ],
      ),
    );
  }

  void _handleLogout() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Logout'),
        content: const Text('Are you sure you want to log out from WorkHub?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Logout'),
          ),
        ],
      ),
    );

    if (confirm == true && mounted) {
      await ref.read(authProvider.notifier).logout();
    }
  }

  String _getPageTitle() {
    switch (_currentIndex) {
      case 0:
        return 'WhatsApp';
      case 1:
        return 'Inbox';
      case 2:
        return 'Task';
      case 3:
        return 'Projects';
      default:
        return 'WhatsApp';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: WhatsAppColors.background,
      appBar: AppBar(
        backgroundColor: WhatsAppColors.background,
        elevation: 0,
        scrolledUnderElevation: 0,
        title: Text(
          _getPageTitle(),
          style: const TextStyle(
            color: WhatsAppColors.textPrimary,
            fontSize: 22,
            fontWeight: FontWeight.bold,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.search, color: WhatsAppColors.iconMuted),
            onPressed: () {
              // Toggle or focus search
            },
          ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert, color: WhatsAppColors.iconMuted),
            color: WhatsAppColors.cardBg,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            onSelected: _onMenuSelected,
            itemBuilder: (BuildContext context) => <PopupMenuEntry<String>>[
              const PopupMenuItem<String>(
                value: 'updates',
                child: Row(
                  children: [
                    Icon(Icons.system_update_rounded, color: WhatsAppColors.tealGreen, size: 20),
                    SizedBox(width: 12),
                    Text(
                      'Check for App Updates',
                      style: TextStyle(color: WhatsAppColors.textPrimary, fontSize: 14),
                    ),
                  ],
                ),
              ),
              const PopupMenuItem<String>(
                value: 'profile',
                child: Row(
                  children: [
                    Icon(Icons.person_outline, color: WhatsAppColors.textSecondary, size: 20),
                    SizedBox(width: 12),
                    Text(
                      'My Profile',
                      style: TextStyle(color: WhatsAppColors.textPrimary, fontSize: 14),
                    ),
                  ],
                ),
              ),
              const PopupMenuDivider(),
              const PopupMenuItem<String>(
                value: 'logout',
                child: Row(
                  children: [
                    Icon(Icons.logout, color: Colors.redAccent, size: 20),
                    SizedBox(width: 12),
                    Text(
                      'Logout',
                      style: TextStyle(color: Colors.redAccent, fontSize: 14),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      body: IndexedStack(
        index: _currentIndex,
        children: _pages,
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: WhatsAppColors.background,
          border: Border(
            top: BorderSide(
              color: WhatsAppColors.divider.withOpacity(0.5),
              width: 0.5,
            ),
          ),
        ),
        child: NavigationBarTheme(
          data: NavigationBarThemeData(
            indicatorColor: WhatsAppColors.navIndicatorBg,
            labelTextStyle: MaterialStateProperty.resolveWith((states) {
              if (states.contains(MaterialState.selected)) {
                return const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: WhatsAppColors.textPrimary,
                );
              }
              return const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: WhatsAppColors.textSecondary,
              );
            }),
            iconTheme: MaterialStateProperty.resolveWith((states) {
              if (states.contains(MaterialState.selected)) {
                return const IconThemeData(
                  color: WhatsAppColors.navIndicatorIcon,
                  size: 24,
                );
              }
              return const IconThemeData(
                color: WhatsAppColors.iconMuted,
                size: 24,
              );
            }),
          ),
          child: NavigationBar(
            height: 68,
            backgroundColor: WhatsAppColors.background,
            selectedIndex: _currentIndex,
            onDestinationSelected: (index) {
              setState(() {
                _currentIndex = index;
              });
            },
            destinations: const [
              NavigationDestination(
                icon: Icon(Icons.chat_bubble_outline_rounded),
                selectedIcon: Icon(Icons.chat_bubble_rounded),
                label: 'Chats',
              ),
              NavigationDestination(
                icon: Icon(Icons.inbox_outlined),
                selectedIcon: Icon(Icons.inbox_rounded),
                label: 'Inbox',
              ),
              NavigationDestination(
                icon: Badge(
                  backgroundColor: WhatsAppColors.tealGreen,
                  smallSize: 8,
                  child: Icon(Icons.task_alt_outlined),
                ),
                selectedIcon: Badge(
                  backgroundColor: WhatsAppColors.tealGreen,
                  smallSize: 8,
                  child: Icon(Icons.task_alt),
                ),
                label: 'Task',
              ),
              NavigationDestination(
                icon: Icon(Icons.dashboard_outlined),
                selectedIcon: Icon(Icons.dashboard_rounded),
                label: 'Projects',
              ),
            ],
          ),
        ),
      ),
    );
  }
}
