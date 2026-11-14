import 'dart:ui';
import 'package:flutter/material.dart';
import '../theme/orbit_theme.dart';

class WorkHubNavigationBar extends StatelessWidget {
  final int selectedIndex;
  final int inboxCount;
  final ValueChanged<int> onSelected;

  const WorkHubNavigationBar({
    super.key,
    required this.selectedIndex,
    required this.inboxCount,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) => SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.80),
              borderRadius: BorderRadius.circular(999),
              border: Border.all(color: OrbitColors.cardBorder, width: 1),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x24102D62),
                  blurRadius: 24,
                  offset: Offset(0, 10),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(999),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
                child: NavigationBar(
                  key: const ValueKey('orbit-bottom-navigation'),
                  height: 68,
                  selectedIndex: selectedIndex,
                  onDestinationSelected: onSelected,
                  backgroundColor: Colors.transparent,
                  surfaceTintColor: Colors.transparent,
                  indicatorColor: OrbitColors.bubbleBlue,
                  indicatorShape: const StadiumBorder(),
                  elevation: 0,
                  destinations: [
                    const NavigationDestination(
                        icon: Icon(Icons.home_outlined),
                        selectedIcon: Icon(Icons.home),
                        label: 'Home'),
                    NavigationDestination(
                      icon: Badge(
                          isLabelVisible: inboxCount > 0,
                          label: Text('$inboxCount'),
                          child: const Icon(Icons.inbox_outlined)),
                      selectedIcon: Badge(
                          isLabelVisible: inboxCount > 0,
                          label: Text('$inboxCount'),
                          child: const Icon(Icons.inbox)),
                      label: 'Inbox',
                    ),
                    const NavigationDestination(
                        icon: Icon(Icons.task_alt_outlined),
                        selectedIcon: Icon(Icons.task_alt),
                        label: 'Tasks'),
                    const NavigationDestination(
                        icon: Icon(Icons.folder_outlined),
                        selectedIcon: Icon(Icons.folder),
                        label: 'Projects'),
                    const NavigationDestination(
                        icon: Icon(Icons.grid_view_outlined),
                        selectedIcon: Icon(Icons.grid_view_rounded),
                        label: 'ERPa'),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
}
