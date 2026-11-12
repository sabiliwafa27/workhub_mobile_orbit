import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/whatsapp_colors.dart';
import '../providers/project_provider.dart';
import '../../tasks/screens/create_work_item_screen.dart';

class ProjectsScreen extends ConsumerStatefulWidget {
  const ProjectsScreen({super.key});

  @override
  ConsumerState<ProjectsScreen> createState() => _ProjectsScreenState();
}

class _ProjectsScreenState extends ConsumerState<ProjectsScreen> {
  @override
  Widget build(BuildContext context) {
    final projectState = ref.watch(projectNotifierProvider);
    final displayProjects = projectState.projects;

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

            if (projectState.isLoading)
              const Center(
                child: Padding(
                  padding: EdgeInsets.symmetric(vertical: 40),
                  child: CircularProgressIndicator(color: WhatsAppColors.tealGreen),
                ),
              )
            else if (projectState.error != null)
              Center(
                child: TextButton(
                  onPressed: () => ref.read(projectNotifierProvider.notifier).loadProjects(),
                  child: const Text('Unable to load projects. Tap to retry.'),
                ),
              )
            else if (displayProjects.isEmpty)
              const Center(
                child: Padding(
                  padding: EdgeInsets.symmetric(vertical: 40, horizontal: 20),
                  child: Column(
                    children: [
                      Icon(Icons.hub_outlined, size: 48, color: WhatsAppColors.subtitleText),
                      SizedBox(height: 12),
                      Text(
                        'No company initiatives found',
                        style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: WhatsAppColors.titleText),
                      ),
                      SizedBox(height: 4),
                      Text(
                        'Strategic projects and milestones will appear here.',
                        style: TextStyle(fontSize: 12, color: WhatsAppColors.subtitleText),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              )
            else
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
                  return InkWell(
                    onTap: () => Navigator.of(context).push(MaterialPageRoute(
                      builder: (_) => ProjectTasksScreen(project: project),
                    )),
                    child: _buildProjectCard(project),
                  );
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

class ProjectTasksScreen extends ConsumerWidget {
  final ProjectItemModel project;

  const ProjectTasksScreen({super.key, required this.project});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tasks = ref.watch(projectTasksProvider(project.id));
    return Scaffold(
      appBar: AppBar(title: Text(project.name)),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          final created = await Navigator.of(context).push<bool>(MaterialPageRoute(builder: (_) => CreateWorkItemScreen(projectId: project.id)));
          if (created == true && context.mounted) ref.invalidate(projectTasksProvider(project.id));
        },
        child: const Icon(Icons.add),
      ),
      body: tasks.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, __) => Center(
          child: TextButton(
            onPressed: () => ref.invalidate(projectTasksProvider(project.id)),
            child: const Text('Unable to load project tasks. Tap to retry.'),
          ),
        ),
        data: (items) => items.isEmpty
            ? const Center(child: Text('No tasks in this project.'))
            : ListView.builder(
                itemCount: items.length,
                itemBuilder: (context, index) {
                  final task = items[index];
                  return ListTile(title: Text(task.title), subtitle: Text(task.status));
                },
              ),
      ),
    );
  }
}
