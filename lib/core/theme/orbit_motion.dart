import 'package:flutter/material.dart';

/// One-shot entrance; rebuilds preserve progress and tab changes can replay it.
/// No repeating timers, and reduced-motion users see content immediately.
class OrbitEntrance extends StatefulWidget {
  final Widget child;
  final Duration delay;
  final bool active;
  const OrbitEntrance(
      {super.key,
      required this.child,
      this.delay = Duration.zero,
      this.active = true});

  @override
  State<OrbitEntrance> createState() => _OrbitEntranceState();
}

class _OrbitEntranceState extends State<OrbitEntrance>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: widget.delay + const Duration(milliseconds: 420),
  );
  bool _reduceMotion = false;

  Animation<double> get _progress => _controller.drive(CurveTween(
        curve: Interval(
            widget.delay.inMilliseconds / _controller.duration!.inMilliseconds,
            1,
            curve: Curves.easeOutCubic),
      ));

  void _start() {
    if (_reduceMotion) {
      _controller.value = 1;
    } else if (widget.active) {
      _controller.forward(from: 0);
    } else {
      _controller.value = 0;
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    if (reduceMotion != _reduceMotion ||
        !_controller.isAnimating && _controller.value == 0) {
      _reduceMotion = reduceMotion;
      _start();
    }
  }

  @override
  void didUpdateWidget(OrbitEntrance oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.delay != oldWidget.delay) {
      _controller.duration = widget.delay + const Duration(milliseconds: 420);
    }
    if (widget.active != oldWidget.active) _start();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_reduceMotion) return widget.child;
    final progress = _progress;
    return FadeTransition(
        opacity: progress,
        child: SlideTransition(
          position: progress
              .drive(Tween(begin: const Offset(0, .025), end: Offset.zero)),
          child: widget.child,
        ));
  }
}

/// FinFlow-inspired motion with native iOS navigation retained.
class OrbitPageTransitionsBuilder extends PageTransitionsBuilder {
  const OrbitPageTransitionsBuilder();
  @override
  Widget buildTransitions<T>(
      PageRoute<T> route,
      BuildContext context,
      Animation<double> animation,
      Animation<double> secondaryAnimation,
      Widget child) {
    if (MediaQuery.disableAnimationsOf(context)) return child;
    final curved = animation.drive(CurveTween(curve: Curves.easeOutCubic));
    return FadeTransition(
        opacity: curved,
        child: SlideTransition(
          position: curved
              .drive(Tween(begin: const Offset(0, .025), end: Offset.zero)),
          child: child,
        ));
  }
}

/// Subtle interactive press scale animation inspired by FinFlow cards & buttons.
class OrbitScaleTap extends StatefulWidget {
  final Widget child;
  final VoidCallback? onTap;
  final double pressedScale;
  const OrbitScaleTap({
    super.key,
    required this.child,
    this.onTap,
    this.pressedScale = 0.975,
  });

  @override
  State<OrbitScaleTap> createState() => _OrbitScaleTapState();
}

class _OrbitScaleTapState extends State<OrbitScaleTap> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    if (widget.onTap == null || reduceMotion) return widget.child;
    return Listener(
      onPointerDown: (_) => setState(() => _pressed = true),
      onPointerUp: (_) => setState(() => _pressed = false),
      onPointerCancel: (_) => setState(() => _pressed = false),
      child: AnimatedScale(
        scale: _pressed ? widget.pressedScale : 1.0,
        duration: const Duration(milliseconds: 140),
        curve: Curves.easeOutCubic,
        child: widget.child,
      ),
    );
  }
}
