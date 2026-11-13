import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../../core/widgets/orbit_workspace.dart';
import '../../../core/theme/orbit_theme.dart';
import '../../../core/theme/orbit_motion.dart';
import '../providers/dashboard_provider.dart';

class DashboardSurface extends OrbitSurface {
  const DashboardSurface(
      {super.key,
      required super.child,
      super.padding = const EdgeInsets.all(12)});
}

class DashboardMetric extends StatelessWidget {
  final String title, value, caption;
  final IconData icon;
  final Color accent, tint;
  final Color? waveColor;
  final double? progress;
  final bool wave;
  final VoidCallback? onTap;
  const DashboardMetric(
      {super.key,
      required this.title,
      required this.value,
      required this.caption,
      required this.icon,
      required this.accent,
      required this.tint,
      this.waveColor,
      this.progress,
      this.wave = false,
      this.onTap});
  @override
  Widget build(BuildContext context) => Semantics(
        button: onTap != null,
        child: OrbitScaleTap(
          onTap: onTap,
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: tint,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.78),
                width: 1,
              ),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x0D06244D),
                  blurRadius: 12,
                  offset: Offset(0, 4),
                ),
              ],
            ),
            child: Material(
              color: Colors.transparent,
              borderRadius: BorderRadius.circular(18),
              clipBehavior: Clip.antiAlias,
              child: InkWell(
                  onTap: onTap,
                  borderRadius: BorderRadius.circular(18),
                  child: Stack(children: [
                    if (wave)
                      Positioned.fill(
                          child: CustomPaint(
                              painter: _MetricWave(waveColor ?? accent))),
                    Padding(
                        padding: const EdgeInsets.all(8),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Container(
                                      padding: const EdgeInsets.all(7),
                                      decoration: BoxDecoration(
                                          color: accent.withValues(alpha: .14),
                                          borderRadius:
                                              BorderRadius.circular(12)),
                                      child:
                                          Icon(icon, color: accent, size: 20)),
                                  const SizedBox(width: 8),
                                  Expanded(
                                      child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                        Text(title,
                                            maxLines: 2,
                                            style: const TextStyle(
                                                fontSize: 11,
                                                height: 1.15,
                                                fontWeight: FontWeight.w700,
                                                color:
                                                    OrbitColors.textPrimary)),
                                        const SizedBox(height: 4),
                                        Row(children: [
                                          Expanded(
                                              child: FittedBox(
                                                  fit: BoxFit.scaleDown,
                                                  alignment:
                                                      Alignment.centerLeft,
                                                  child: Text(value,
                                                      style: const TextStyle(
                                                          fontSize: 24,
                                                          height: 1.05,
                                                          fontWeight:
                                                              FontWeight.w800,
                                                          color: OrbitColors
                                                              .textPrimary)))),
                                          if (progress != null)
                                            SizedBox(
                                                width: 30,
                                                height: 30,
                                                child: TweenAnimationBuilder<
                                                    double>(
                                                  duration: MediaQuery
                                                          .disableAnimationsOf(
                                                              context)
                                                      ? Duration.zero
                                                      : const Duration(
                                                          milliseconds: 650),
                                                  curve: Curves.easeOutCubic,
                                                  tween: Tween<double>(
                                                      begin: 0,
                                                      end: progress!
                                                          .clamp(0.0, 1.0)),
                                                  builder: (context, animVal,
                                                          _) =>
                                                      CircularProgressIndicator(
                                                          value: animVal,
                                                          strokeWidth: 5,
                                                          color: accent,
                                                          backgroundColor:
                                                              accent.withValues(
                                                                  alpha: .18),
                                                          strokeCap:
                                                              StrokeCap.round),
                                                )),
                                        ]),
                                      ])),
                                ]),
                            const SizedBox(height: 5),
                            Text(caption,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                    fontSize: 10,
                                    height: 1.2,
                                    color: OrbitColors.textSecondary)),
                          ],
                        )),
                  ])),
            ),
          ),
        ),
      );
}

class _MetricWave extends CustomPainter {
  final Color color;
  const _MetricWave(this.color);
  @override
  void paint(Canvas canvas, Size size) {
    final path = Path()
      ..moveTo(size.width * .36, size.height)
      ..cubicTo(size.width * .45, size.height * .42, size.width * .6,
          size.height * .85, size.width * .72, size.height * .62)
      ..cubicTo(size.width * .88, size.height * .28, size.width * .94,
          size.height * .52, size.width, size.height * .40)
      ..lineTo(size.width, size.height)
      ..close();
    canvas.drawPath(
        path,
        Paint()
          ..shader = LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                color.withValues(alpha: .26),
                color.withValues(alpha: .04)
              ]).createShader(Offset.zero & size));
    final strokePath = Path()
      ..moveTo(size.width * .36, size.height * .95)
      ..cubicTo(size.width * .45, size.height * .42, size.width * .6,
          size.height * .85, size.width * .72, size.height * .62)
      ..cubicTo(size.width * .88, size.height * .28, size.width * .94,
          size.height * .52, size.width, size.height * .40);
    canvas.drawPath(
        strokePath,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.6
          ..color = color.withValues(alpha: .42));
  }

  @override
  bool shouldRepaint(_MetricWave oldDelegate) => oldDelegate.color != color;
}

class DashboardProgress extends StatelessWidget {
  final DashboardTaskStats? stats;
  final bool loading;
  final VoidCallback onViewAll;
  const DashboardProgress(
      {super.key,
      required this.stats,
      required this.loading,
      required this.onViewAll});
  @override
  Widget build(BuildContext context) {
    final values = [
      stats?.open ?? 0,
      stats?.inProgress ?? 0,
      stats?.completed ?? 0
    ];
    final total = stats?.total ?? 0;
    final valid = stats != null &&
        values.every((v) => v >= 0) &&
        values.fold(0, (a, b) => a + b) <= total;
    const colors = [
      OrbitColors.royalBlue,
      OrbitColors.skyBlue,
      OrbitColors.kpiGreen
    ];
    final openPercent =
        total > 0 ? ((stats?.open ?? 0) * 100 / total).round() : 0;
    return DashboardSurface(
        padding: const EdgeInsets.all(10),
        child: Column(children: [
          Row(children: [
            const Expanded(
                child: Text('Task Progress',
                    style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: OrbitColors.textPrimary))),
            TextButton.icon(
                onPressed: onViewAll,
                style: TextButton.styleFrom(
                    minimumSize: const Size(0, 24),
                    padding: EdgeInsets.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap),
                label: const Text('View All', style: TextStyle(fontSize: 11)),
                icon: const Icon(Icons.arrow_forward, size: 15),
                iconAlignment: IconAlignment.end),
          ]),
          LayoutBuilder(builder: (context, constraints) {
            final chartSize = math.min(94.0, constraints.maxWidth * .36);
            return Row(children: [
              Semantics(
                  label: valid
                      ? 'Open tasks: $openPercent percent'
                      : 'Task progress unavailable',
                  child: SizedBox(
                      width: chartSize,
                      height: chartSize,
                      child: Stack(alignment: Alignment.center, children: [
                        TweenAnimationBuilder<double>(
                          duration: MediaQuery.disableAnimationsOf(context)
                              ? Duration.zero
                              : const Duration(milliseconds: 700),
                          curve: Curves.easeOutCubic,
                          tween: Tween(begin: 0, end: 1),
                          builder: (context, value, child) => CustomPaint(
                              size: Size.square(chartSize),
                              painter: _ProgressRing(
                                  values: valid ? values : const [0, 0, 0],
                                  total: total,
                                  colors: colors,
                                  progress: value)),
                        ),
                        SizedBox(
                            width: chartSize * .65,
                            height: chartSize * .65,
                            child: FittedBox(
                                fit: BoxFit.scaleDown,
                                child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text(valid ? '$openPercent%' : '—',
                                          style: const TextStyle(
                                              fontSize: 23,
                                              height: 1.1,
                                              fontWeight: FontWeight.w800,
                                              color: OrbitColors.textPrimary)),
                                      Text(loading ? 'Loading' : 'Open',
                                          style: const TextStyle(
                                              fontSize: 12,
                                              color: OrbitColors.textPrimary)),
                                    ]))),
                      ]))),
              const SizedBox(width: 16),
              Expanded(
                  child: Column(children: [
                for (var i = 0; i < 3; i++) ...[
                  Padding(
                      padding: const EdgeInsets.symmetric(vertical: 5),
                      child: Row(children: [
                        Container(
                            width: 10,
                            height: 10,
                            decoration: BoxDecoration(
                                color: colors[i], shape: BoxShape.circle)),
                        const SizedBox(width: 8),
                        Expanded(
                            child: Text(['Open', 'In Progress', 'Completed'][i],
                                style: const TextStyle(
                                    fontSize: 11,
                                    color: OrbitColors.textPrimary))),
                        Text(
                            valid
                                ? '${values[i]} (${total == 0 ? 0 : (values[i] * 100 / total).round()}%)'
                                : '—',
                            style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: OrbitColors.textPrimary)),
                      ])),
                  if (i < 2) const Divider(height: 1),
                ],
              ])),
            ]);
          }),
        ]));
  }
}

class _ProgressRing extends CustomPainter {
  final List<int> values;
  final int total;
  final List<Color> colors;
  final double progress;
  const _ProgressRing(
      {required this.values,
      required this.total,
      required this.colors,
      required this.progress});
  @override
  void paint(Canvas canvas, Size size) {
    final stroke = size.width * .14;
    final bounds = (Offset.zero & size).deflate(stroke / 2);
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round;
    canvas.drawOval(bounds, paint..color = OrbitColors.cardBorder);
    if (total <= 0) return;
    var start = -math.pi / 2;
    for (var i = 0; i < values.length; i++) {
      final sweep = values[i] / total * 2 * math.pi;
      if (sweep > .05)
        canvas.drawArc(
            bounds,
            start + .025,
            math.max(0, sweep * progress - .05),
            false,
            paint..color = colors[i]);
      start += sweep;
    }
  }

  @override
  bool shouldRepaint(_ProgressRing oldDelegate) =>
      oldDelegate.total != total ||
      oldDelegate.progress != progress ||
      oldDelegate.values.toString() != values.toString();
}

class DashboardShortcuts extends StatelessWidget {
  final VoidCallback onTasks, onInbox, onProjects, onErp;
  final int? unread;
  const DashboardShortcuts(
      {super.key,
      required this.onTasks,
      required this.onInbox,
      required this.onProjects,
      required this.onErp,
      required this.unread});
  @override
  Widget build(BuildContext context) => DashboardSurface(
      padding: const EdgeInsets.all(3),
      child: Row(children: [
        for (final item in [
          (Icons.check_circle, 'My Tasks', onTasks),
          (Icons.mail_outline_rounded, 'Inbox', onInbox),
          (Icons.layers_outlined, 'Projects', onProjects),
          (Icons.grid_view_rounded, 'ERP', onErp),
        ])
          Expanded(
              child: Material(
                  color: item.$2 == 'My Tasks'
                      ? OrbitColors.bubbleBlue
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(15),
                  child: InkWell(
                    onTap: item.$3,
                    borderRadius: BorderRadius.circular(15),
                    child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 5),
                        child: Column(children: [
                          Badge(
                              isLabelVisible:
                                  item.$2 == 'Inbox' && (unread ?? 0) > 0,
                              label: Text('${unread ?? 0}'),
                              backgroundColor: OrbitColors.kpiRed,
                              child: Icon(item.$1,
                                  size: 22, color: OrbitColors.primaryNavy)),
                          const SizedBox(height: 3),
                          Text(item.$2,
                              style: const TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: OrbitColors.textPrimary)),
                        ])),
                  ))),
      ]));
}
