import 'package:flutter/material.dart';

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
  Widget build(BuildContext context) => NavigationBar(
        selectedIndex: selectedIndex,
        onDestinationSelected: onSelected,
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
              icon: Icon(Icons.chat_bubble_outline),
              selectedIcon: Icon(Icons.chat_bubble),
              label: 'Chat'),
          const NavigationDestination(
              icon: Icon(Icons.folder_outlined),
              selectedIcon: Icon(Icons.folder),
              label: 'Projects'),
        ],
      );
}
