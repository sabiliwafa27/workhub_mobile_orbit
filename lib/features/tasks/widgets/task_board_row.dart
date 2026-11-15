import 'package:flutter/material.dart';
import '../../../core/theme/orbit_theme.dart';
import '../providers/task_provider.dart';

class TaskBoardRow extends StatelessWidget {
  final TaskItemModel task;
  final bool busy;
  final VoidCallback onOpen;
  final VoidCallback? onAction, onPriority;
  const TaskBoardRow(
      {super.key,
      required this.task,
      required this.busy,
      required this.onOpen,
      this.onAction,
      this.onPriority});

  @override
  Widget build(BuildContext context) {
    final done = task.status == 'completed';
    return Material(
        color: Colors.transparent,
        child: InkWell(
            onTap: onOpen,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(10, 12, 12, 12),
              child:
                  Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
                SizedBox(
                    width: 32,
                    height: 36,
                    child: busy
                        ? const Padding(
                            padding: EdgeInsets.all(8),
                            child: CircularProgressIndicator(strokeWidth: 2))
                        : Tooltip(
                            message: task.rowAction == 'request_review'
                                ? 'Request review'
                                : done
                                    ? 'Completed'
                                    : 'Complete task',
                            child: Checkbox(
                                value: done,
                                onChanged: onAction == null || done
                                    ? null
                                    : (_) => onAction!(),
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(5)),
                                side: const BorderSide(
                                    color: OrbitColors.textMuted, width: 1.5),
                                visualDensity: VisualDensity.compact))),
                const SizedBox(width: 6),
                Expanded(
                    child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Text(
                    task.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 14,
                      height: 1.25,
                      fontWeight: FontWeight.w500,
                      color: OrbitColors.textPrimary,
                      decoration: done ? TextDecoration.lineThrough : null,
                    ),
                  ),
                )),
                if (onPriority != null ||
                    (onAction != null && task.rowAction == 'request_review'))
                  SizedBox(
                      width: 24,
                      height: 24,
                      child: PopupMenuButton<String>(
                          tooltip: 'Task actions',
                          padding: EdgeInsets.zero,
                          iconSize: 18,
                          onSelected: (value) {
                            if (value == 'priority') {
                              onPriority?.call();
                            } else {
                              onAction?.call();
                            }
                          },
                          itemBuilder: (_) => [
                                if (onAction != null)
                                  PopupMenuItem(
                                      value: 'action',
                                      child: Text(task.rowAction ==
                                              'request_review'
                                          ? 'Request Review'
                                          : 'Complete')),
                                if (onPriority != null)
                                  const PopupMenuItem(
                                      value: 'priority',
                                      child: Text('Add to Priority')),
                              ])),
              ]),
            )));
  }
}
