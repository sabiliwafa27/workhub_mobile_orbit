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
              child: Text(
                'COMPANY INITIATIVES (${displayProjects.length})',
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.3,
                  color: WhatsAppColors.primaryGreen,
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
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 62,
                height: 62,
                decoration: BoxDecoration(
                  color: WhatsAppColors.navIndicatorBg,
                  borderRadius: BorderRadius.circular(24),
                ),
                child: Icon(
                  project.name.toLowerCase().contains('mom')
                      ? Icons.layers_outlined
                      : project.name.toLowerCase().contains('test')
                          ? Icons.code_rounded
                          : Icons.hub_outlined,
                  color: WhatsAppColors.primaryGreen,
                  size: 30,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      project.name,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: WhatsAppColors.titleText,
                      ),
                    ),
                    if (project.description.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        project.description,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 14,
                          color: WhatsAppColors.subtitleText,
                        ),
                      ),
                    ],
                    const SizedBox(height: 16),
                    Row(children: [
                      const Icon(Icons.check_circle_outline,
                          size: 18, color: WhatsAppColors.tealGreen),
                      const SizedBox(width: 8),
                      Flexible(child: Text('${project.completedTasks} completed',
                          maxLines: 1, overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 13,
                              color: WhatsAppColors.subtitleText))),
                    ]),
                    const SizedBox(height: 6),
                    Row(children: [
                      const Icon(Icons.pending_actions,
                          size: 18, color: WhatsAppColors.iconMuted),
                      const SizedBox(width: 8),
                      Flexible(child: Text('${project.activeTasks} active',
                          maxLines: 1, overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 13,
                              color: WhatsAppColors.subtitleText))),
                    ]),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    decoration: BoxDecoration(
                      color: WhatsAppColors.navIndicatorBg,
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text('${project.progress}%', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: WhatsAppColors.darkGreen)),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: 86,
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(999),
                      child: LinearProgressIndicator(
                        value: project.progress.clamp(0, 100) / 100,
                        backgroundColor: WhatsAppColors.chipBorder,
                        valueColor: const AlwaysStoppedAnimation<Color>(WhatsAppColors.darkGreen),
                        minHeight: 6,
                      ),
                    ),
                  ),
                ],
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
