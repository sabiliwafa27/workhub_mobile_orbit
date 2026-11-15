import 'package:flutter/material.dart';

class WhatsAppMenuItem<T> {
  final T value;
  final String title;
  final IconData? icon;
  final IconData? trailingIcon;
  final Color? textColor;
  final Color? iconColor;
  final FontWeight? fontWeight;

  const WhatsAppMenuItem({
    required this.value,
    required this.title,
    this.icon,
    this.trailingIcon,
    this.textColor,
    this.iconColor,
    this.fontWeight,
  });
}

/// Displays a sleek, animated dropdown popup strictly styled after WhatsApp Android:
/// - Smooth scale + fade transition originating from the anchor (top-right)
/// - WhatsApp elevation, subtle shadow, and clean white card with 8px radius
/// - Authentic typography (15px, Roboto/default, Color(0xFF111B21) or custom)
/// - 48px height menu items with native ink ripple
Future<T?> showWhatsAppMenu<T>({
  required BuildContext context,
  required RelativeRect position,
  required List<WhatsAppMenuItem<T>> items,
  double minWidth = 180,
  Alignment transformAlignment = Alignment.topRight,
}) {
  return Navigator.of(context, rootNavigator: true).push<T>(
    _WhatsAppMenuRoute<T>(
      position: position,
      items: items,
      minWidth: minWidth,
      transformAlignment: transformAlignment,
    ),
  );
}

class _WhatsAppMenuRoute<T> extends PopupRoute<T> {
  final RelativeRect position;
  final List<WhatsAppMenuItem<T>> items;
  final double minWidth;
  final Alignment transformAlignment;

  _WhatsAppMenuRoute({
    required this.position,
    required this.items,
    this.minWidth = 180,
    this.transformAlignment = Alignment.topRight,
  });

  @override
  Duration get transitionDuration => const Duration(milliseconds: 180);

  @override
  Duration get reverseTransitionDuration => const Duration(milliseconds: 140);

  @override
  bool get barrierDismissible => true;

  @override
  Color? get barrierColor => Colors.transparent;

  @override
  String? get barrierLabel => 'Dismiss menu';

  @override
  Widget buildPage(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
  ) {
    return CustomSingleChildLayout(
      delegate: _WhatsAppMenuLayoutDelegate(position: position),
      child: _WhatsAppMenuWidget<T>(
        route: this,
        items: items,
        minWidth: minWidth,
      ),
    );
  }

  @override
  Widget buildTransitions(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    // WhatsApp menu animation: Snappy scale-out from anchor corner + fast fade
    final curvedAnimation = CurvedAnimation(
      parent: animation,
      curve: Curves.easeOutCubic,
      reverseCurve: Curves.easeInCubic,
    );

    return ScaleTransition(
      scale: Tween<double>(begin: 0.75, end: 1.0).animate(curvedAnimation),
      alignment: transformAlignment,
      child: FadeTransition(
        opacity: Tween<double>(begin: 0.0, end: 1.0).animate(curvedAnimation),
        child: child,
      ),
    );
  }
}

class _WhatsAppMenuLayoutDelegate extends SingleChildLayoutDelegate {
  final RelativeRect position;
  _WhatsAppMenuLayoutDelegate({required this.position});

  @override
  BoxConstraints getConstraintsForChild(BoxConstraints constraints) {
    return BoxConstraints.loose(constraints.biggest);
  }

  @override
  Offset getPositionForChild(Size size, Size childSize) {
    // Position menu exactly below anchor, shifted slightly for WhatsApp look
    double x = size.width - childSize.width - position.right;
    if (x < 12) x = 12;
    if (x + childSize.width > size.width - 12) {
      x = size.width - childSize.width - 12;
    }

    double y = position.top;
    if (y + childSize.height > size.height - 16) {
      y = size.height - childSize.height - 16;
    }
    if (y < 16) y = 16;

    return Offset(x, y);
  }

  @override
  bool shouldRelayout(_WhatsAppMenuLayoutDelegate oldDelegate) {
    return position != oldDelegate.position;
  }
}

class _WhatsAppMenuWidget<T> extends StatelessWidget {
  final _WhatsAppMenuRoute<T> route;
  final List<WhatsAppMenuItem<T>> items;
  final double minWidth;

  const _WhatsAppMenuWidget({
    required this.route,
    required this.items,
    required this.minWidth,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: Container(
        constraints: BoxConstraints(minWidth: minWidth),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(8),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.15),
              blurRadius: 16,
              spreadRadius: 0,
              offset: const Offset(0, 4),
            ),
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.08),
              blurRadius: 4,
              spreadRadius: 0,
              offset: const Offset(0, 1),
            ),
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: IntrinsicWidth(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 6),
              for (int i = 0; i < items.length; i++) ...[
                _buildMenuItem(context, items[i]),
              ],
              const SizedBox(height: 6),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMenuItem(BuildContext context, WhatsAppMenuItem<T> item) {
    const defaultTextColor = Color(0xFF111B21); // WhatsApp standard dark text
    final textColor = item.textColor ?? defaultTextColor;
    final iconColor = item.iconColor ?? const Color(0xFF54656F); // WhatsApp icon color

    return InkWell(
      splashColor: const Color(0x1A000000),
      highlightColor: const Color(0x0D000000),
      onTap: () {
        Navigator.of(context).pop(item.value);
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (item.icon != null) ...[
              Icon(item.icon, size: 20, color: iconColor),
              const SizedBox(width: 14),
            ],
            Flexible(
              child: Text(
                item.title,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: item.fontWeight ?? FontWeight.w400,
                  color: textColor,
                  letterSpacing: 0.1,
                ),
              ),
            ),
            if (item.trailingIcon != null) ...[
              const SizedBox(width: 14),
              Icon(item.trailingIcon, size: 20, color: iconColor),
            ],
          ],
        ),
      ),
    );
  }
}
