import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/realtime/reverb_service.dart';
import '../../../core/theme/orbit_theme.dart';
import '../../../core/widgets/workhub_navigation_bar.dart';
import '../../chat/screens/chat_list_screen.dart';
import '../../inbox/providers/inbox_provider.dart';
import '../../inbox/screens/inbox_screen.dart';
import '../../projects/screens/projects_screen.dart';
import '../../tasks/screens/task_screen.dart';
import '../../erpa/screens/erpa_screen.dart';
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

  @override
  Widget build(BuildContext context) {
    final inboxCount = ref.watch(inboxNotifierProvider).items.length;

    final pages = [
      OrbitDashboardView(
        onOpenSearch: () => setState(() => _currentIndex = 2),
        onOpenNotifications: () => setState(() => _currentIndex = 1),
        onOpenTasks: () => setState(() => _currentIndex = 2),
        onOpenProjects: () => setState(() => _currentIndex = 3),
        onOpenErp: () => setState(() => _currentIndex = 4),
        onOpenCheckIn: _showQuickActionSheet,
      ),
      const InboxScreen(),
      const TaskScreen(),
      const ProjectsScreen(),
      const ErpaScreen(),
    ];

    return Scaffold(
      extendBody: true,
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
