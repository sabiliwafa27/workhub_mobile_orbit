import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/orbit_theme.dart';
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
      backgroundColor: OrbitColors.scaffoldBackground,
      appBar: AppBar(
        title: const Text(
          'Task Board',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w800,
            color: OrbitColors.textNavy,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded, color: OrbitColors.textNavy),
            onPressed: () {
              ref.read(taskNotifierProvider.notifier).loadTasks();
            },
          ),
        ],
      ),
      body: RefreshIndicator(
        color: OrbitColors.primaryNavy,
        onRefresh: () async {
          await ref.read(taskNotifierProvider.notifier).loadTasks();
        },
        child: ListView(
          padding: const EdgeInsets.only(left: 16, right: 16, top: 8, bottom: 90),
          children: [
            // Status Header Info
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: OrbitColors.cardBorder),
              ),
              child: Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: OrbitColors.bubbleBlue,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.assignment_outlined,
                      color: OrbitColors.primaryNavy,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Active Assigned Tasks',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: OrbitColors.textNavy,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${displayTasks.length} task${displayTasks.length == 1 ? '' : 's'} in progress',
                          style: const TextStyle(
                            fontSize: 12,
                            color: OrbitColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),

            // Tasks List
            ...displayTasks.map((task) => Padding(
                  padding: const EdgeInsets.only(bottom: 12.0),
                  child: _buildTaskCard(task),
                )),
          ],
        ),
      ),
    );
  }

  Widget _buildTaskCard(TaskItemModel task) {
    Color priorityColor = OrbitColors.kpiGreen;
    Color priorityBg = OrbitColors.kpiGreenBg;
    if (task.priority.toLowerCase() == 'urgent') {
      priorityColor = OrbitColors.kpiRed;
      priorityBg = OrbitColors.kpiRedBg;
    } else if (task.priority.toLowerCase() == 'high') {
      priorityColor = OrbitColors.kpiOrange;
      priorityBg = OrbitColors.kpiOrangeBg;
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: OrbitColors.cardBorder),
        boxShadow: const [
          BoxShadow(
            color: Color(0x04000000),
            blurRadius: 6,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: priorityBg,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  task.priority.toUpperCase(),
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    color: priorityColor,
                  ),
                ),
              ),
              Row(
                children: [
                  const Icon(Icons.calendar_today_rounded, size: 12, color: OrbitColors.textMuted),
                  const SizedBox(width: 4),
                  Text(
                    task.dueDate,
                    style: const TextStyle(
                      fontSize: 11,
                      color: OrbitColors.textMuted,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            task.title,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: OrbitColors.textNavy,
            ),
          ),
          if (task.description.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              task.description,
              style: const TextStyle(
                fontSize: 12,
                color: OrbitColors.textSecondary,
                height: 1.3,
              ),
            ),
          ],
          const SizedBox(height: 14),

          // Progress Indicator
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Progress',
                style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: OrbitColors.textSecondary),
              ),
              Text(
                '${task.progressPercent}%',
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: OrbitColors.textNavy),
              ),
            ],
          ),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              value: task.progressPercent / 100.0,
              minHeight: 6,
              backgroundColor: OrbitColors.scaffoldBackground,
              valueColor: const AlwaysStoppedAnimation<Color>(OrbitColors.brandOrange),
            ),
          ),
          const SizedBox(height: 14),

          // Actions
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              OutlinedButton(
                onPressed: () {
                  ref.read(taskRepositoryProvider).requestReview(task.id);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Review requested.'), duration: Duration(seconds: 1)),
                  );
                },
                style: OutlinedButton.styleFrom(
                  foregroundColor: OrbitColors.primaryNavy,
                  side: const BorderSide(color: OrbitColors.cardBorder),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                ),
                child: const Text('Request Review', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600)),
              ),
              const SizedBox(width: 8),
              ElevatedButton.icon(
                onPressed: () {
                  ref.read(taskNotifierProvider.notifier).completeTask(task.id);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Task completed.'), duration: Duration(seconds: 1)),
                  );
                },
                icon: const Icon(Icons.check, size: 14),
                label: const Text('Complete', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: OrbitColors.primaryNavy,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
