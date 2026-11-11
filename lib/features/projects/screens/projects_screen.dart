import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/whatsapp_colors.dart';
import '../providers/project_provider.dart';

class ProjectsScreen extends ConsumerStatefulWidget {
  const ProjectsScreen({super.key});

  @override
  ConsumerState<ProjectsScreen> createState() => _ProjectsScreenState();
}

class _ProjectsScreenState extends ConsumerState<ProjectsScreen> {
  final List<ProjectItemModel> _fallbackProjects = [
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
    final projectState = ref.watch(projectNotifierProvider);
    final displayProjects = projectState.projects.isNotEmpty ? projectState.projects : _fallbackProjects;

    return Scaffold(
      backgroundColor: WhatsAppColors.background,
      body: RefreshIndicator(
        color: WhatsAppColors.tealGreen,
        onRefresh: () async {
          await ref.read(projectNotifierProvider.notifier).loadProjects();
        },
        child: ListView(
          padding: const EdgeInsets.symmetric(vertical: 12),
          children: [
            // Header Banner
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 26,
                    backgroundColor: const Color(0xFFEFF6FF),
                    child: const Icon(
                      Icons.hub_outlined,
                      color: Color(0xFF1D4ED8),
                      size: 26,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: const [
                        Text(
                          'WorkHub Projects',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: WhatsAppColors.titleText,
                          ),
                        ),
                        SizedBox(height: 2),
                        Text(
                          'Energy of Creation & Strategic Milestones',
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
                'COMPANY INITIATIVES (${displayProjects.length})',
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
              itemCount: displayProjects.length,
              separatorBuilder: (_, __) => const Divider(
                color: WhatsAppColors.divider,
                height: 1,
                indent: 16,
                endIndent: 16,
              ),
              itemBuilder: (context, index) {
                final project = displayProjects[index];
                return _buildProjectCard(project);
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProjectCard(ProjectItemModel project) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  project.name,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: WhatsAppColors.titleText,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: WhatsAppColors.navIndicatorBg,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '${project.progress}%',
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: WhatsAppColors.darkGreen,
                  ),
                ),
              ),
            ],
          ),
          if (project.description.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              project.description,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 13,
                color: WhatsAppColors.subtitleText,
              ),
            ),
          ],
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: project.progress / 100.0,
              backgroundColor: WhatsAppColors.chipBorder,
              valueColor: const AlwaysStoppedAnimation<Color>(WhatsAppColors.tealGreen),
              minHeight: 6,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              const Icon(Icons.check_circle_outline, size: 14, color: WhatsAppColors.tealGreen),
              const SizedBox(width: 4),
              Text(
                '${project.completedTasks} completed',
                style: const TextStyle(fontSize: 12, color: WhatsAppColors.subtitleText),
              ),
              const SizedBox(width: 14),
              const Icon(Icons.pending_actions, size: 14, color: WhatsAppColors.iconMuted),
              const SizedBox(width: 4),
              Text(
                '${project.activeTasks} active',
                style: const TextStyle(fontSize: 12, color: WhatsAppColors.subtitleText),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
