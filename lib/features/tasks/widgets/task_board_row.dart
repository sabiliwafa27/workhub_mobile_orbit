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
    final priority = task.priority.toLowerCase();
    final high = priority == 'high' || priority == 'urgent';
    final label = high
        ? 'High'
        : priority == 'low'
            ? 'Low'
            : 'Medium';
    final priorityTint = high
        ? OrbitColors.kpiRedBg
        : priority == 'low'
            ? OrbitColors.kpiGreenBg
            : OrbitColors.creamCard;
    final priorityInk = high
        ? OrbitColors.kpiRed
        : priority == 'low'
            ? const Color(0xFF15803D)
            : OrbitColors.brandOrange;
    final status = switch (task.status) {
      'completed' => 'Completed',
      'cancelled' => 'Cancelled',
      'pending_review' => 'Pending review',
      'in_progress' => 'In Progress',
      _ => task.progressPercent > 0 ? 'In Progress' : 'Belum Mulai',
    };
    final statusTint = done
        ? OrbitColors.kpiGreenBg
        : task.status == 'pending_review'
            ? OrbitColors.creamCard
            : task.progressPercent > 0 || task.status == 'in_progress'
                ? OrbitColors.skyPillBg
                : OrbitColors.slatePillBg;
    final statusInk = done
        ? const Color(0xFF15803D)
        : task.status == 'pending_review'
            ? OrbitColors.brandOrange
            : task.progressPercent > 0 || task.status == 'in_progress'
                ? OrbitColors.skyPillInk
                : OrbitColors.slatePillInk;
    Widget tag(String text, Color color, Color ink) => Container(
          padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
          decoration: BoxDecoration(
              color: color, borderRadius: BorderRadius.circular(99)),
          child: Text(text,
              style: TextStyle(
                  fontSize: 11,
                  height: 1.1,
                  color: ink,
                  fontWeight: FontWeight.w600)),
        );
    final date = DateTime.tryParse(task.dueDate);
    final now = DateTime.now();
    final dateLabel = date == null
        ? ''
        : date.year == now.year &&
                date.month == now.month &&
                date.day == now.day
            ? 'Today'
            : '${date.day} ${const [
                'Jan',
                'Feb',
                'Mar',
                'Apr',
                'May',
                'Jun',
                'Jul',
                'Aug',
                'Sep',
                'Oct',
                'Nov',
                'Dec'
              ][date.month - 1]} ${date.year}';
    Widget meta(IconData icon, String value) =>
        Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, size: 15, color: OrbitColors.textSecondary),
          const SizedBox(width: 5),
          Flexible(
              child: Text(value,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                      fontSize: 11, color: OrbitColors.textSecondary))),
        ]);
    return Material(
        color: Colors.transparent,
        child: InkWell(
            onTap: onOpen,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(10, 12, 12, 12),
              child:
                  Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
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
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                      LayoutBuilder(builder: (context, constraints) {
                        final title = Text(task.title,
                            maxLines: 3,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                                fontSize: 14,
                                height: 1.2,
                                fontWeight: FontWeight.w500,
                                color: OrbitColors.textPrimary,
                                decoration:
                                    done ? TextDecoration.lineThrough : null));
                        final tags = Wrap(spacing: 4, runSpacing: 4, children: [
                          tag(label, priorityTint, priorityInk),
                          Tooltip(
                              message: '${task.progressPercent}% complete',
                              child: tag(status, statusTint, statusInk))
                        ]);
                        // Keep readable titles on small phones and at larger font settings.
                        if (constraints.maxWidth < 260 ||
                            MediaQuery.textScalerOf(context).scale(14) > 17) {
                          return Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                title,
                                const SizedBox(height: 8),
                                tags
                              ]);
                        }
                        return Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(child: title),
                              const SizedBox(width: 8),
                              SizedBox(width: 146, child: tags)
                            ]);
                      }),
                      const SizedBox(height: 8),
                      Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                                child:
                                    Wrap(spacing: 12, runSpacing: 6, children: [
                              if (task.assignees.isNotEmpty)
                                meta(
                                    Icons.person_outline, task.assignees.first),
                              if (dateLabel.isNotEmpty)
                                meta(Icons.calendar_today_outlined, dateLabel),
                              if (task.attachmentCount > 0)
                                meta(Icons.attach_file,
                                    '${task.attachmentCount} attachment${task.attachmentCount == 1 ? '' : 's'}'),
                            ])),
                            if (onPriority != null ||
                                (onAction != null &&
                                    task.rowAction == 'request_review'))
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
                                                  child:
                                                      Text('Add to Priority')),
                                          ])),
                          ]),
                    ])),
              ]),
            )));
  }
}
