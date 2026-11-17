import 'package:flutter/material.dart';
import '../theme/orbit_theme.dart';

class ExpandingFabAction {
  const ExpandingFabAction(
      {required this.label, required this.icon, required this.onPressed});
  final String label;
  final IconData icon;
  final VoidCallback onPressed;
}

/// Computes responsive bottom offset for FloatingActionButtons on screens
/// displayed inside [OrbitMainShell] (which uses `extendBody: true` and the
/// floating [WorkHubNavigationBar]) so the `+` button always sits comfortably
/// above the bottom navigation pill and system gesture/navigation bar across
/// compact, standard, and tall mobile screens.
double orbitResponsiveFabBottomOffset(BuildContext context) {
  final media = MediaQuery.of(context);
  final systemBottom = media.viewPadding.bottom > media.padding.bottom
      ? media.viewPadding.bottom
      : media.padding.bottom;
  // WorkHubNavigationBar height (68) + bottom margin (16) = 84.
  const navBarclearance = 88.0;
  // Scale extra breathing room mildly with screen height so taller phones lift
  // the FAB slightly higher while compact phones stay within easy thumb reach.
  final extraLift = ((media.size.height - 640.0) * 0.035).clamp(8.0, 24.0);
  return navBarclearance + systemBottom + extraLift;
}

/// Computes responsive bottom list padding so scrollable content can scroll
/// completely past both the floating navigation bar and the `+` FAB.
double orbitResponsiveListBottomPadding(BuildContext context) {
  return orbitResponsiveFabBottomOffset(context) + 76.0;
}

class OrbitPlusFab extends StatelessWidget {
  final VoidCallback onPressed;
  final String? tooltip;
  final String? heroTag;
  final bool isExpanded;

  const OrbitPlusFab({
    super.key,
    required this.onPressed,
    this.tooltip,
    this.heroTag,
    this.isExpanded = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: Color(0x3306244D),
            blurRadius: 16,
            offset: Offset(0, 6),
          ),
        ],
      ),
      child: FloatingActionButton(
        heroTag: heroTag,
        elevation: 0,
        highlightElevation: 0,
        shape: const CircleBorder(),
        backgroundColor: OrbitColors.primaryNavy,
        foregroundColor: Colors.white,
        tooltip: tooltip,
        onPressed: onPressed,
        child: AnimatedRotation(
          turns: isExpanded ? 0.125 : 0.0,
          duration: const Duration(milliseconds: 260),
          curve: Curves.fastOutSlowIn,
          child: const Icon(
            Icons.add,
            size: 32,
            color: Colors.white,
          ),
        ),
      ),
    );
  }
}

class ExpandingActionFab extends StatefulWidget {
  const ExpandingActionFab({super.key, required this.actions});
  final List<ExpandingFabAction> actions;

  @override
  State<ExpandingActionFab> createState() => _ExpandingActionFabState();
}

class _ExpandingActionFabState extends State<ExpandingActionFab>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 260),
    reverseDuration: const Duration(milliseconds: 200),
  );

  bool get _expanded => _controller.value > 0;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Widget _buildKeepActionItem(
    BuildContext context,
    ExpandingFabAction action,
    int index,
    int total,
  ) {
    // Reverse index so items closest to the FAB start animating first
    final reversedIndex = total - 1 - index;
    final startInterval = (reversedIndex * 0.12).clamp(0.0, 0.7);
    final endInterval = (startInterval + 0.55).clamp(0.0, 1.0);

    final itemCurve = CurvedAnimation(
      parent: _controller,
      curve: Interval(startInterval, endInterval, curve: Curves.easeOutBack),
    );

    // Subtle Google-styled tinted icon backgrounds
    Color badgeBg;
    Color iconColor;
    final labelLower = action.label.toLowerCase();
    if (labelLower.contains('task')) {
      badgeBg = const Color(0xFFE8F0FE); // Google Blue tint
      iconColor = const Color(0xFF1967D2);
    } else if (labelLower.contains('ec') || labelLower.contains('doc')) {
      badgeBg = const Color(0xFFFEF7E0); // Google Yellow/Amber tint
      iconColor = const Color(0xFFE37400);
    } else if (labelLower.contains('chat') || labelLower.contains('dm')) {
      badgeBg = const Color(0xFFE6F4EA); // Google Green tint
      iconColor = const Color(0xFF137333);
    } else {
      badgeBg = const Color(0xFFF1F3F4);
      iconColor = const Color(0xFF3C4043);
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: ScaleTransition(
        scale: itemCurve,
        alignment: Alignment.bottomRight,
        child: SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(0.0, 0.25),
            end: Offset.zero,
          ).animate(itemCurve),
          child: Semantics(
            button: true,
            label: action.label,
            child: Material(
              elevation: 4,
              shadowColor: const Color(0x3306244D),
              color: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: const BorderSide(color: Color(0x1406244D), width: 1),
              ),
              child: InkWell(
                borderRadius: BorderRadius.circular(16),
                splashColor: const Color(0x1F4285F4),
                highlightColor: const Color(0x0F4285F4),
                onTap: () {
                  _controller.reverse();
                  action.onPressed();
                },
                child: Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 34,
                        height: 34,
                        decoration: BoxDecoration(
                          color: badgeBg,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(action.icon, size: 18, color: iconColor),
                      ),
                      const SizedBox(width: 12),
                      Text(
                        action.label,
                        style: const TextStyle(
                          fontFamily: 'Google Sans',
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF1F1F1F),
                          letterSpacing: 0.1,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          SizeTransition(
            sizeFactor: CurvedAnimation(
              parent: _controller,
              curve: Curves.fastOutSlowIn,
            ),
            axisAlignment: 1.0,
            child: FadeTransition(
              key: const ValueKey('expanding-action-fab-fade'),
              opacity: _controller,
              child: Align(
                alignment: Alignment.centerRight,
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      for (int i = 0; i < widget.actions.length; i++)
                        _buildKeepActionItem(
                          context,
                          widget.actions[i],
                          i,
                          widget.actions.length,
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          OrbitPlusFab(
            heroTag: 'inbox-fab',
            tooltip: _expanded ? 'Close actions' : 'Create task, EC or chat',
            isExpanded: _expanded,
            onPressed: () =>
                _expanded ? _controller.reverse() : _controller.forward(),
          ),
        ],
      );
}
