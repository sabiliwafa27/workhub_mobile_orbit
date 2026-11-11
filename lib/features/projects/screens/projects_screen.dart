import 'package:flutter/material.dart';
import '../../../../core/theme/whatsapp_colors.dart';

class ProjectItemModel {
  final int id;
  final String name;
  final String description;
  final int progress;
  final int activeTasks;
  final int completedTasks;
  final String status;

  ProjectItemModel({
    required this.id,
    required this.name,
    required this.description,
    required this.progress,
    required this.activeTasks,
    required this.completedTasks,
    required this.status,
  });
}

class ProjectsScreen extends StatefulWidget {
  const ProjectsScreen({super.key});

  @override
  State<ProjectsScreen> createState() => _ProjectsScreenState();
}

class _ProjectsScreenState extends State<ProjectsScreen> {
  final List<ProjectItemModel> _projects = [
    ProjectItemModel(
      id: 1,
      name: 'Ekspansi Distribusi Area Jawa Timur 2026',
      description: 'Program peningkatan penetrasi produk kecap botol dan jerigen di retail tradisional.',
      progress: 68,
      activeTasks: 8,
      completedTasks: 16,
      status: 'active',
    ),
    ProjectItemModel(
      id: 2,
      name: 'Modernisasi Modul Armada & FMS',
      description: 'Integrasi OCR struk BBM dan rekonsiliasi MyPertamina otomatis.',
      progress: 92,
      activeTasks: 2,
      completedTasks: 24,
      status: 'active',
    ),
    ProjectItemModel(
      id: 3,
      name: 'Implementasi WMS Logistic In Rev',
      description: 'Sistem intake barcode dan routing penerimaan barang mentah.',
      progress: 80,
      activeTasks: 5,
      completedTasks: 20,
      status: 'active',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: WhatsAppColors.background,
      body: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
        itemCount: _projects.length,
        separatorBuilder: (_, __) => const SizedBox(height: 12),
        itemBuilder: (context, index) {
          final project = _projects[index];
          return _buildProjectCard(project);
        },
      ),
    );
  }

  Widget _buildProjectCard(ProjectItemModel project) {
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
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFFEFF6FF),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.folder_shared_rounded, color: Color(0xFF2563EB), size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  project.name,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: WhatsAppColors.titleText,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            project.description,
            style: const TextStyle(fontSize: 12, color: WhatsAppColors.subtitleText),
          ),
          const SizedBox(height: 14),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Tasks: ${project.completedTasks}/${project.completedTasks + project.activeTasks}',
                style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: WhatsAppColors.subtitleText),
              ),
              Text(
                '${project.progress}% Complete',
                style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: WhatsAppColors.darkGreen),
              ),
            ],
          ),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: project.progress / 100,
              minHeight: 6,
              backgroundColor: const Color(0xFFE2E8F0),
              valueColor: const AlwaysStoppedAnimation(WhatsAppColors.primaryGreen),
            ),
          ),
        ],
      ),
    );
  }
}
