import 'package:flutter/material.dart';

class ExpandingFabAction {
  const ExpandingFabAction(
      {required this.label, required this.icon, required this.onPressed});
  final String label;
  final IconData icon;
  final VoidCallback onPressed;
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
      vsync: this, duration: const Duration(milliseconds: 220));
  bool get _expanded => _controller.value > 0;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          SizeTransition(
            sizeFactor: CurvedAnimation(
                parent: _controller, curve: Curves.easeOutCubic),
            axisAlignment: 1,
            child: FadeTransition(
              opacity: _controller,
              child: Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Material(
                  elevation: 6,
                  color: Theme.of(context).colorScheme.surface,
                  borderRadius: BorderRadius.circular(20),
                  child: Column(mainAxisSize: MainAxisSize.min, children: [
                    for (final action in widget.actions)
                      Semantics(
                        button: true,
                        child: InkWell(
                          borderRadius: BorderRadius.circular(20),
                          onTap: () {
                            _controller.reverse();
                            action.onPressed();
                          },
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 13),
                            child:
                                Row(mainAxisSize: MainAxisSize.min, children: [
                              Icon(action.icon, size: 20),
                              const SizedBox(width: 12),
                              Text(action.label,
                                  style:
                                      Theme.of(context).textTheme.labelLarge),
                            ]),
                          ),
                        ),
                      ),
                  ]),
                ),
              ),
            ),
          ),
          FloatingActionButton.large(
            heroTag: 'inbox-fab',
            tooltip: _expanded ? 'Close actions' : 'Create task, EC or chat',
            onPressed: () =>
                _expanded ? _controller.reverse() : _controller.forward(),
            child: AnimatedRotation(
                turns: _expanded ? .125 : 0,
                duration: const Duration(milliseconds: 220),
                child: Icon(_expanded ? Icons.close : Icons.add)),
          ),
        ],
      );
}
