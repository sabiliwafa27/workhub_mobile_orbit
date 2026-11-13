import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/whatsapp_colors.dart';
import '../../../core/theme/orbit_theme.dart';
import '../providers/project_provider.dart';
import '../../tasks/screens/create_work_item_screen.dart';
import '../../tasks/screens/task_detail_screen.dart';

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
      backgroundColor: Colors.transparent,
      body: RefreshIndicator(
        color: WhatsAppColors.tealGreen,
        onRefresh: () async {
          await ref.read(projectNotifierProvider.notifier).loadProjects();
        },
        child: ListView(
          padding: EdgeInsets.only(top: MediaQuery.paddingOf(context).top + 12, bottom: 24),
          children: [
            // Header Banner
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 24, 24, 18),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 30,
                    backgroundColor: WhatsAppColors.navIndicatorBg,
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
                            fontSize: 22,
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

            const SizedBox(height: 30),

            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                decoration: BoxDecoration(color: const Color(0xFFD6DFFF), borderRadius: BorderRadius.circular(999)),
                child: Text(
                'COMPANY INITIATIVES (${displayProjects.length})',
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.3,
                  color: OrbitColors.textNavy,
                ),
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
                  indent: 24,
                  endIndent: 24,
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
    final isMom = project.name.toLowerCase().contains('mom');
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        CircleAvatar(
          radius: 23,
          backgroundColor: isMom ? const Color(0xFFF7DEED) : OrbitColors.bubbleBlue,
          child: Icon(isMom ? Icons.layers_outlined : Icons.code_rounded,
              color: OrbitColors.textNavy, size: 26),
        ),
        const SizedBox(width: 14),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(project.name, style: const TextStyle(fontSize: 17,
              fontWeight: FontWeight.w800, color: OrbitColors.textNavy)),
          if (project.description.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(project.description, style: const TextStyle(fontSize: 14,
                color: OrbitColors.textSecondary)),
          ],
          const SizedBox(height: 12),
          Wrap(spacing: 12, runSpacing: 6, children: [
            Row(mainAxisSize: MainAxisSize.min, children: [
              const Icon(Icons.check_circle_outline, size: 16, color: Color(0xFF009688)),
              const SizedBox(width: 6),
              Text('${project.completedTasks} completed', style: const TextStyle(
                  fontSize: 12, color: OrbitColors.textSecondary)),
            ]),
            Row(mainAxisSize: MainAxisSize.min, children: [
              const Icon(Icons.pending_actions, size: 16, color: OrbitColors.textSecondary),
              const SizedBox(width: 6),
              Text('${project.activeTasks} active', style: const TextStyle(
                  fontSize: 12, color: OrbitColors.textSecondary)),
            ]),
          ]),
        ])),
        const SizedBox(width: 10),
        Column(children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: BoxDecoration(color: const Color(0xFFD1FACB),
                borderRadius: BorderRadius.circular(999)),
            child: Text('${project.progress}%', style: const TextStyle(
                fontWeight: FontWeight.w800, color: Color(0xFF14820B))),
          ),
          const SizedBox(height: 10),
          SizedBox(width: 66, child: ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(value: project.progress.clamp(0, 100) / 100,
                minHeight: 6, backgroundColor: const Color(0xFFD9DEED),
                color: const Color(0xFF14820B)),
          )),
        ]),
      ]),
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
      floatingActionButton: FloatingActionButton.large(
        tooltip: 'Create project task',
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
            : Column(children: [
              Container(
                width: double.infinity,
                margin: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: OrbitColors.cardSurface,
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: OrbitColors.cardBorder),
                ),
                child: Row(children: [
                  const CircleAvatar(
                    radius: 24,
                    backgroundColor: OrbitColors.bubbleBlue,
                    child: Icon(Icons.folder_outlined,
                        color: OrbitColors.primaryNavy),
                  ),
                  const SizedBox(width: 14),
                  Expanded(child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(project.name,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 17,
                              fontWeight: FontWeight.w800,
                              color: OrbitColors.textNavy)),
                      Text('${items.length} tasks in this project',
                          style: const TextStyle(
                              color: OrbitColors.textSecondary)),
                    ],
                  )),
                ]),
              ),
              Expanded(child: ListView.builder(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
                itemCount: items.length,
                itemBuilder: (context, index) {
                  final task = items[index];
                  final complete = task.progressPercent >= 100;
                  return Card(
                    margin: const EdgeInsets.only(bottom: 10),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(24),
                      onTap: () => Navigator.of(context).push(MaterialPageRoute(
                          builder: (_) => TaskDetailScreen(taskId: task.id))),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Row(children: [
                          Container(
                            width: 32,
                            height: 32,
                            decoration: BoxDecoration(
                              color: complete ? OrbitColors.primaryNavy : Colors.transparent,
                              border: Border.all(color: complete
                                  ? OrbitColors.primaryNavy : OrbitColors.textMuted),
                              borderRadius: BorderRadius.circular(9),
                            ),
                            child: complete
                                ? const Icon(Icons.check, size: 20, color: Colors.white)
                                : null,
                          ),
                          const SizedBox(width: 14),
                          Expanded(child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(task.title, style: TextStyle(
                                fontWeight: FontWeight.w700,
                                color: OrbitColors.textNavy,
                                decoration: complete ? TextDecoration.lineThrough : null,
                              )),
                              const SizedBox(height: 4),
                              Text(task.status.replaceAll('_', ' '),
                                  style: const TextStyle(
                                      fontSize: 12,
                                      color: OrbitColors.textSecondary)),
                            ],
                          )),
                          const SizedBox(width: 8),
                          Text('${task.progressPercent}%',
                              style: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                  color: OrbitColors.primaryNavy)),
                        ]),
                      ),
                    ),
                  );
                },
              )),
            ]),
      ),
    );
  }
}
