import 'package:flutter/material.dart';
import '../../../../core/theme/whatsapp_colors.dart';

class TaskItemModel {
  final int id;
  final String title;
  final String description;
  final String status;
  final int progressPercent;
  final String dueDate;
  final String priority;

  TaskItemModel({
    required this.id,
    required this.title,
    required this.description,
    required this.status,
    required this.progressPercent,
    required this.dueDate,
    required this.priority,
  });
}

class TaskScreen extends StatefulWidget {
  const TaskScreen({super.key});

  @override
  State<TaskScreen> createState() => _TaskScreenState();
}

class _TaskScreenState extends State<TaskScreen> {
  final List<TaskItemModel> _tasks = [
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
    return Scaffold(
      backgroundColor: WhatsAppColors.background,
      body: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
        itemCount: _tasks.length,
        separatorBuilder: (_, __) => const SizedBox(height: 12),
        itemBuilder: (context, index) {
          final task = _tasks[index];
          return _buildTaskCard(task);
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {},
        backgroundColor: WhatsAppColors.fabBg,
        elevation: 3,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: const Icon(Icons.add_task_rounded, color: Colors.white, size: 22),
      ),
    );
  }

  Widget _buildTaskCard(TaskItemModel task) {
    Color priorityColor;
    switch (task.priority) {
      case 'urgent':
        priorityColor = Colors.red;
        break;
      case 'high':
        priorityColor = Colors.orange;
        break;
      default:
        priorityColor = Colors.blue;
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x06000000),
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
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: priorityColor.withValues(alpha: 0.1),
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
              Row(
                children: [
                  const Icon(Icons.event_outlined, size: 14, color: WhatsAppColors.timeText),
                  const SizedBox(width: 4),
                  Text(
                    task.dueDate,
                    style: const TextStyle(fontSize: 11, color: WhatsAppColors.timeText),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            task.title,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.bold,
              color: WhatsAppColors.titleText,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            task.description,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 12, color: WhatsAppColors.subtitleText),
          ),
          const SizedBox(height: 12),

          // Progress indicator
          Row(
            children: [
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: task.progressPercent / 100,
                    minHeight: 6,
                    backgroundColor: const Color(0xFFE2E8F0),
                    valueColor: const AlwaysStoppedAnimation(WhatsAppColors.primaryGreen),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Text(
                '${task.progressPercent}%',
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: WhatsAppColors.darkGreen,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
