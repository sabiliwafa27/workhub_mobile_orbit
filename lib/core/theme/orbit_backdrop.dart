import 'package:flutter/material.dart';

/// The pastel landscape shared by the redesign reference screens.
class OrbitBackdrop extends StatelessWidget {
  final Widget child;
  const OrbitBackdrop({super.key, required this.child});

  @override
  Widget build(BuildContext context) => CustomPaint(
        painter: _LandscapePainter(),
        child: child,
      );
}

class _LandscapePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final bounds = Offset.zero & size;
    canvas.drawRect(bounds, Paint()..shader = const LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [Color(0xFFE8EBFF), Color(0xFFF6F7FF), Color(0xFFE9EDFF)],
    ).createShader(bounds));
    final sun = Rect.fromCircle(center: Offset(size.width * .74, 83), radius: 39);
    canvas.drawOval(sun, Paint()..shader = const LinearGradient(
      begin: Alignment.topCenter, end: Alignment.bottomCenter,
      colors: [Color(0xFFFFC273), Color(0xFFFFE6BC)],
    ).createShader(sun));
    final hill = Path()..moveTo(size.width * .35, 110)
      ..cubicTo(size.width * .61, 35, size.width * .62, 120, size.width * .79, 85)
      ..quadraticBezierTo(size.width * .94, 48, size.width, 105)
      ..lineTo(size.width, 148)..lineTo(size.width * .35, 148)..close();
    canvas.drawPath(hill, Paint()..color = const Color(0xFFCDD8F5));
    final lower = Path()..moveTo(0, size.height - 125)
      ..cubicTo(size.width * .24, size.height - 200, size.width * .4,
          size.height - 75, size.width * .66, size.height - 135)
      ..quadraticBezierTo(size.width * .9, size.height - 205,
          size.width, size.height - 145)
      ..lineTo(size.width, size.height)..lineTo(0, size.height)..close();
    canvas.drawPath(lower, Paint()..color = const Color(0xFFDCE4FF));
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
