import 'dart:ui';
import 'package:flutter/material.dart';
import '../theme/orbit_theme.dart';

class WorkHubNavigationBar extends StatelessWidget {
  final int selectedIndex;
  final int inboxCount;
  final ValueChanged<int> onSelected;
  final VoidCallback? onAddTap;
  final VoidCallback? onMoreTap;

  const WorkHubNavigationBar({
    super.key,
    required this.selectedIndex,
    required this.inboxCount,
    required this.onSelected,
    this.onAddTap,
    this.onMoreTap,
  });

  /// Maps page index (`0`: Home, `1`: Inbox, `2`: Tasks, `3`: Projects, `4`: Mail)
  /// to the 5-slot navigation bar (`0`: Home, `1`: Inbox, `2`: (+), `3`: Tasks, `4`: More).
  int get _navSelectedIndex {
    if (selectedIndex == 0) return 0;
    if (selectedIndex == 1) return 1;
    if (selectedIndex == 2) return 3;
    return 4; // Projects (3) & Mail (4) live inside More
  }

  void _handleDestinationSelected(int navIndex) {
    if (navIndex == 0) {
      onSelected(0);
    } else if (navIndex == 1) {
      onSelected(1);
    } else if (navIndex == 2) {
      if (onAddTap != null) {
        onAddTap!();
      } else {
        onSelected(2);
      }
    } else if (navIndex == 3) {
      onSelected(2);
    } else if (navIndex == 4) {
      if (onMoreTap != null) {
        onMoreTap!();
      } else {
        onSelected(3);
      }
    }
  }

  Widget _buildCenterAddButton() {
    return Container(
      key: const ValueKey('orbit-nav-add-button'),
      width: 44,
      height: 44,
      decoration: const BoxDecoration(
        color: OrbitColors.primaryNavy,
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: Color(0x3306244D),
            blurRadius: 10,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: const Icon(
        Icons.add_rounded,
        color: Colors.white,
        size: 26,
      ),
    );
  }

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
                  selectedIndex: _navSelectedIndex,
                  onDestinationSelected: _handleDestinationSelected,
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
                    NavigationDestination(
                      tooltip: 'Create task, EC or chat',
                      icon: _buildCenterAddButton(),
                      selectedIcon: _buildCenterAddButton(),
                      label: '',
                    ),
                    const NavigationDestination(
                        icon: Icon(Icons.task_alt_outlined),
                        selectedIcon: Icon(Icons.task_alt),
                        label: 'Tasks'),
                    const NavigationDestination(
                        icon: Icon(Icons.more_horiz_rounded),
                        selectedIcon: Icon(Icons.more_horiz_rounded),
                        label: 'More'),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
}
