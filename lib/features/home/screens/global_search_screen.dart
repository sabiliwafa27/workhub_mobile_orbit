import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/orbit_theme.dart';
import '../../../core/widgets/orbit_workspace.dart';
import '../../../core/widgets/workhub_search_bar.dart';
import '../../inbox/models/inbox_item_model.dart';
import '../../inbox/providers/inbox_provider.dart';
import '../../inbox/screens/inbox_screen.dart';
import '../../tasks/providers/task_provider.dart';
import '../../tasks/screens/task_detail_screen.dart';
import '../../projects/providers/project_provider.dart';

enum SearchScope { all, inbox, tasks }

class GlobalSearchScreen extends ConsumerStatefulWidget {
  final SearchScope scope;
  const GlobalSearchScreen({super.key, this.scope = SearchScope.all});

  @override
  ConsumerState<GlobalSearchScreen> createState() => _GlobalSearchScreenState();
}

class _GlobalSearchScreenState extends ConsumerState<GlobalSearchScreen> {
  final _searchController = TextEditingController();
  final _focusNode = FocusNode();
  Timer? _debounce;
  String _query = '';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _focusNode.requestFocus();
    });
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _onSearchChanged(String text) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), () {
      if (mounted) {
        setState(() => _query = text.trim());
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final tasks = ref.watch(taskNotifierProvider).tasks;
    final inboxItems = ref.watch(inboxNotifierProvider).items;
    final projects = ref.watch(projectNotifierProvider).projects;

    final q = _query.toLowerCase();

    final isInboxOnly = widget.scope == SearchScope.inbox;
    final isTasksOnly = widget.scope == SearchScope.tasks;

    final matchedTasks = (q.isEmpty || isInboxOnly)
        ? <TaskItemModel>[]
        : tasks.where((t) {
            return t.title.toLowerCase().contains(q) ||
                t.description.toLowerCase().contains(q) ||
                (t.projectName?.toLowerCase().contains(q) ?? false);
          }).toList();

    final matchedInbox = (q.isEmpty || isTasksOnly)
        ? <InboxItemModel>[]
        : inboxItems.where((i) {
            return i.title.toLowerCase().contains(q) ||
                (i.subtitle?.toLowerCase().contains(q) ?? false) ||
                (i.sourceLabel.toLowerCase().contains(q));
          }).toList();

    final matchedProjects = (q.isEmpty || isInboxOnly || isTasksOnly)
        ? <ProjectItemModel>[]
        : projects.where((p) {
            final name = p.name.toLowerCase();
            final desc = p.description.toLowerCase();
            return name.contains(q) || desc.contains(q);
          }).toList();

    final totalResults =
        matchedTasks.length + matchedInbox.length + matchedProjects.length;

    final title = isInboxOnly
        ? 'Search Inbox'
        : isTasksOnly
            ? 'Search Tasks'
            : 'Global Search';

    final hintText = isInboxOnly
        ? 'Search inbox, messages & approvals...'
        : isTasksOnly
            ? 'Search tasks, priorities & assignments...'
            : 'Search tasks, inbox & projects...';

    return Scaffold(
      backgroundColor: OrbitColors.scaffoldBackground,
      appBar: AppBar(
        title: Text(title),
        elevation: 0,
        backgroundColor: OrbitColors.primaryNavy,
        foregroundColor: Colors.white,
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
            child: WorkHubSearchBar(
              controller: _searchController,
              focusNode: _focusNode,
              autoFocus: true,
              hintText: hintText,
              onChanged: _onSearchChanged,
              onClear: () => setState(() => _query = ''),
            ),
          ),
          Expanded(
            child: _query.isEmpty
                ? _buildEmptyPrompt()
                : totalResults == 0
                    ? _buildNoResults()
                    : ListView(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 8),
                        children: [
                          if (matchedTasks.isNotEmpty) ...[
                            if (!isTasksOnly)
                              _buildCategoryHeader(
                                  'TASKS', matchedTasks.length, Icons.check_circle_outline),
                            ...matchedTasks.map(_buildTaskItem),
                            const SizedBox(height: 16),
                          ],
                          if (matchedInbox.isNotEmpty) ...[
                            if (!isInboxOnly)
                              _buildCategoryHeader(
                                  'INBOX & APPROVALS', matchedInbox.length, Icons.inbox_outlined),
                            ...matchedInbox.map(_buildInboxItem),
                            const SizedBox(height: 16),
                          ],
                          if (matchedProjects.isNotEmpty) ...[
                            _buildCategoryHeader(
                                'PROJECTS', matchedProjects.length, Icons.hub_outlined),
                            ...matchedProjects.map(_buildProjectItem),
                            const SizedBox(height: 16),
                          ],
                        ],
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyPrompt() {
    final promptTitle = widget.scope == SearchScope.inbox
        ? 'Type to search inbox'
        : widget.scope == SearchScope.tasks
            ? 'Type to search tasks'
            : 'Type to search across everything';

    final promptSubtitle = widget.scope == SearchScope.inbox
        ? 'Search across inbox notifications & approvals'
        : widget.scope == SearchScope.tasks
            ? 'Search across your assignments & tasks'
            : 'Tasks, Inbox messages, and Projects';

    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.search_rounded, size: 54, color: OrbitColors.textMuted),
          const SizedBox(height: 12),
          Text(
            promptTitle,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: OrbitColors.textNavy,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            promptSubtitle,
            style: const TextStyle(fontSize: 13, color: OrbitColors.textMuted),
          ),
        ],
      ),
    );
  }

  Widget _buildNoResults() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.search_off_rounded,
              size: 54, color: OrbitColors.textMuted),
          const SizedBox(height: 12),
          Text(
            'No results found for "$_query"',
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: OrbitColors.textNavy,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'Try searching for another title, tag, or name',
            style: TextStyle(fontSize: 13, color: OrbitColors.textMuted),
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryHeader(String title, int count, IconData icon) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8, top: 4),
      child: Row(
        children: [
          Icon(icon, size: 16, color: OrbitColors.primaryNavy),
          const SizedBox(width: 8),
          Text(
            '$title ($count)',
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.5,
              color: OrbitColors.primaryNavy,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTaskItem(TaskItemModel task) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      elevation: 0,
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: OrbitColors.cardBorder),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: OrbitColors.bubbleBlue,
            borderRadius: BorderRadius.circular(8),
          ),
          child: const Icon(Icons.assignment_outlined,
              size: 18, color: OrbitColors.primaryNavy),
        ),
        title: Text(
          task.title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
        ),
        subtitle: task.description.isNotEmpty
            ? Text(
                task.description,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 12, color: OrbitColors.textMuted),
              )
            : null,
        trailing: const Icon(Icons.chevron_right_rounded, size: 20),
        onTap: () {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => TaskDetailScreen(taskId: task.id),
            ),
          );
        },
      ),
    );
  }

  Widget _buildInboxItem(InboxItemModel item) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      elevation: 0,
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: OrbitColors.cardBorder),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: const Color(0xFFF1F5F9),
            borderRadius: BorderRadius.circular(8),
          ),
          child: const Icon(Icons.inbox_rounded,
              size: 18, color: Color(0xFF475569)),
        ),
        title: Text(
          item.title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
        ),
        subtitle: item.subtitle != null && item.subtitle!.isNotEmpty
            ? Text(
                item.subtitle!,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 12, color: OrbitColors.textMuted),
              )
            : null,
        trailing: const Icon(Icons.chevron_right_rounded, size: 20),
        onTap: () {
          final taskId = int.tryParse(item.subjectKey ?? '');
          final isTask = item.subjectType == 'task' ||
              const ['task', 'workhub', 'task-mine', 'task-assigned']
                  .contains(item.moduleCode);
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => isTask && taskId != null
                  ? TaskDetailScreen(taskId: taskId)
                  : InboxItemDetailScreen(item: item),
            ),
          );
        },
      ),
    );
  }

  Widget _buildProjectItem(ProjectItemModel project) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      elevation: 0,
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: OrbitColors.cardBorder),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: const Color(0xFFEDE9FE),
            borderRadius: BorderRadius.circular(8),
          ),
          child: const Icon(Icons.folder_outlined,
              size: 18, color: Color(0xFF7C3AED)),
        ),
        title: Text(
          project.name,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
        ),
        subtitle: project.description.isNotEmpty
            ? Text(
                project.description,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 12, color: OrbitColors.textMuted),
              )
            : null,
      ),
    );
  }
}
