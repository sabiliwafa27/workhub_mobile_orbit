import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/whatsapp_colors.dart';
import '../providers/task_provider.dart';

class TaskScreen extends ConsumerStatefulWidget {
  const TaskScreen({super.key});

  @override
  ConsumerState<TaskScreen> createState() => _TaskScreenState();
}

class _TaskScreenState extends ConsumerState<TaskScreen> {
  final List<TaskItemModel> _fallbackTasks = [
    TaskItemModel(
      id: 912,
      title: 'Evaluasi Penetrasi Pasar Area Sidoarjo Timur',
      description: 'Lakukan mapping ulang toko retail dan rekap repeat order produk 275ml.',
      status: 'in_progress',
      progressPercent: 75,
      dueDate: '15 Nov 2026',
      priority: 'high',
    ),
    TaskItemModel(
      id: 913,
      title: 'Audit Stok Gudang Waru Minggu ke-2',
      description: 'Verifikasi kesesuaian fisik karton kecap vs core WMS.',
      status: 'pending_review',
      progressPercent: 100,
      dueDate: '12 Nov 2026',
      priority: 'urgent',
    ),
    TaskItemModel(
      id: 914,
      title: 'Penyusunan Jadwal Kunjungan Outlet Baru',
      description: 'Input target rute salesman wilayah Krian & Porong.',
      status: 'assigned',
      progressPercent: 30,
      dueDate: '18 Nov 2026',
      priority: 'medium',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final taskState = ref.watch(taskNotifierProvider);
    final displayTasks = taskState.tasks.isNotEmpty ? taskState.tasks : _fallbackTasks;

    return Scaffold(
      backgroundColor: WhatsAppColors.background,
      body: RefreshIndicator(
        color: WhatsAppColors.tealGreen,
        onRefresh: () async {
          await ref.read(taskNotifierProvider.notifier).loadTasks();
        },
        child: ListView(
          padding: const EdgeInsets.symmetric(vertical: 12),
          children: [
            // Status Header Info
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
              child: Row(
                children: [
                  Stack(
                    children: [
                      CircleAvatar(
                        radius: 26,
                        backgroundColor: WhatsAppColors.navIndicatorBg,
                        child: const Icon(
                          Icons.assignment_outlined,
                          color: WhatsAppColors.darkGreen,
                          size: 26,
                        ),
                      ),
                      Positioned(
                        bottom: 0,
                        right: 0,
                        child: Container(
                          padding: const EdgeInsets.all(2),
                          decoration: const BoxDecoration(
                            color: WhatsAppColors.badgeGreen,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.add, size: 14, color: Colors.white),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: const [
                        Text(
                          'My Task Board',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: WhatsAppColors.titleText,
                          ),
                        ),
                        SizedBox(height: 2),
                        Text(
                          'Tap + to create a new task',
                          style: TextStyle(
                            fontSize: 13,
                            color: WhatsAppColors.subtitleText,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            const Divider(color: WhatsAppColors.divider, height: 24),

            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 4.0),
              child: Text(
                'ACTIVE ASSIGNMENTS (${displayTasks.length})',
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.5,
                  color: WhatsAppColors.subtitleText,
                ),
              ),
            ),

            const SizedBox(height: 8),

            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: displayTasks.length,
              separatorBuilder: (_, __) => const Divider(
                color: WhatsAppColors.divider,
                height: 1,
                indent: 16,
                endIndent: 16,
              ),
              itemBuilder: (context, index) {
                final task = displayTasks[index];
                return _buildTaskCard(task);
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTaskCard(TaskItemModel task) {
    Color priorityColor;
    switch (task.priority.toLowerCase()) {
      case 'urgent':
        priorityColor = Colors.red.shade600;
        break;
      case 'high':
        priorityColor = Colors.orange.shade800;
        break;
      default:
        priorityColor = Colors.blue.shade700;
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: priorityColor.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  task.priority.toUpperCase(),
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: priorityColor,
                  ),
                ),
              ),
              const Spacer(),
              if (task.dueDate.isNotEmpty) ...[
                const Icon(Icons.schedule, size: 14, color: WhatsAppColors.timeText),
                const SizedBox(width: 4),
                Text(
                  task.dueDate,
                  style: const TextStyle(
                    fontSize: 12,
                    color: WhatsAppColors.timeText,
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 6),
          Text(
            task.title,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: WhatsAppColors.titleText,
            ),
          ),
          if (task.description.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              task.description,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 13,
                color: WhatsAppColors.subtitleText,
              ),
            ),
          ],
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: task.progressPercent / 100.0,
                    backgroundColor: WhatsAppColors.chipBorder,
                    valueColor: AlwaysStoppedAnimation<Color>(
                      task.progressPercent == 100
                          ? WhatsAppColors.badgeGreen
                          : WhatsAppColors.tealGreen,
                    ),
                    minHeight: 6,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Text(
                '${task.progressPercent}%',
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: WhatsAppColors.titleText,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
