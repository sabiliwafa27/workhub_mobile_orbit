import 'package:flutter/material.dart';

class ExpandingFabAction {
  const ExpandingFabAction(
      {required this.label, required this.icon, required this.onPressed});
  final String label;
  final IconData icon;
  final VoidCallback onPressed;
}

class GoogleKeepPlusPainter extends CustomPainter {
  final double strokeWidth;
  final double length;
  final double cornerRadius;

  const GoogleKeepPlusPainter({
    this.strokeWidth = 4.6,
    this.length = 11.5,
    this.cornerRadius = 2.3,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final halfStroke = strokeWidth / 2;

    // Google Brand Colors (Blue, Red, Yellow, Green)
    const blue = Color(0xFF4285F4);
    const red = Color(0xFFEA4335);
    const yellow = Color(0xFFFBBC05);
    const green = Color(0xFF34A853);

    final paint = Paint()..style = PaintingStyle.fill;

    // Top arm (Blue)
    paint.color = blue;
    canvas.drawRRect(
      RRect.fromRectAndCorners(
        Rect.fromLTRB(center.dx - halfStroke, center.dy - length,
            center.dx + halfStroke, center.dy + halfStroke),
        topLeft: Radius.circular(cornerRadius),
        topRight: Radius.circular(cornerRadius),
      ),
      paint,
    );

    // Left arm (Red)
    paint.color = red;
    canvas.drawRRect(
      RRect.fromRectAndCorners(
        Rect.fromLTRB(center.dx - length, center.dy - halfStroke,
            center.dx + halfStroke, center.dy + halfStroke),
        topLeft: Radius.circular(cornerRadius),
        bottomLeft: Radius.circular(cornerRadius),
      ),
      paint,
    );

    // Bottom arm (Yellow)
    paint.color = yellow;
    canvas.drawRRect(
      RRect.fromRectAndCorners(
        Rect.fromLTRB(center.dx - halfStroke, center.dy - halfStroke,
            center.dx + halfStroke, center.dy + length),
        bottomLeft: Radius.circular(cornerRadius),
        bottomRight: Radius.circular(cornerRadius),
      ),
      paint,
    );

    // Right arm (Green)
    paint.color = green;
    canvas.drawRRect(
      RRect.fromRectAndCorners(
        Rect.fromLTRB(center.dx - halfStroke, center.dy - halfStroke,
            center.dx + length, center.dy + halfStroke),
        topRight: Radius.circular(cornerRadius),
        bottomRight: Radius.circular(cornerRadius),
      ),
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant GoogleKeepPlusPainter oldDelegate) =>
      strokeWidth != oldDelegate.strokeWidth ||
      length != oldDelegate.length ||
      cornerRadius != oldDelegate.cornerRadius;
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
          FloatingActionButton(
            heroTag: 'inbox-fab',
            elevation: 5,
            highlightElevation: 8,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(18),
            ),
            backgroundColor: Colors.white,
            tooltip: _expanded ? 'Close actions' : 'Create task, EC or chat',
            onPressed: () =>
                _expanded ? _controller.reverse() : _controller.forward(),
            child: AnimatedRotation(
              turns: _expanded ? 0.125 : 0.0,
              duration: const Duration(milliseconds: 260),
              curve: Curves.fastOutSlowIn,
              child: SizedBox(
                width: 26,
                height: 26,
                child: CustomPaint(
                  painter: const GoogleKeepPlusPainter(
                    strokeWidth: 4.6,
                    length: 11.5,
                    cornerRadius: 2.3,
                  ),
                ),
              ),
            ),
          ),
        ],
      );
}
