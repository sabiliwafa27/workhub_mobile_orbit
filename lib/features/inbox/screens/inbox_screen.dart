import 'dart:async';
import 'package:flutter/material.dart';
import '../../../core/widgets/orbit_workspace.dart';
import '../../../core/widgets/expanding_action_fab.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/orbit_theme.dart';
import '../models/inbox_item_model.dart';
import '../providers/inbox_provider.dart';
import '../../tasks/screens/create_work_item_screen.dart';
import '../../tasks/screens/task_detail_screen.dart';
import '../../tasks/providers/task_provider.dart';
import '../../tasks/providers/ec_progress_provider.dart';
import '../../home/providers/dashboard_provider.dart';
import '../../auth/providers/auth_provider.dart';
import '../../chat/screens/employee_chat_screen.dart';

import 'ec_inbox_detail_screen.dart';
import 'discussion_panel.dart';
import 'logistic_out_detail_screen.dart';
import 'logistic_in_detail_screen.dart';

String inboxRowTime(String value, {DateTime? now}) {
  if (value.isEmpty) return '–';
  final parsed = DateTime.tryParse(value);
  if (parsed == null) return value;
  final target = parsed.toUtc().add(const Duration(hours: 7));
  final current = (now ?? DateTime.now()).toUtc().add(const Duration(hours: 7));
  final days = DateTime.utc(current.year, current.month, current.day)
      .difference(DateTime.utc(target.year, target.month, target.day))
      .inDays;
  if (days == 0)
    return '${target.hour.toString().padLeft(2, '0')}:${target.minute.toString().padLeft(2, '0')}';
  if (days == 1) return 'Yesterday';
  return '${target.day}/${target.month}/${(target.year % 100).toString().padLeft(2, '0')}';
}

final _logisticInMentionCapability =
    FutureProvider.autoDispose.family<bool, int>((ref, line) async {
  final response = await ref
      .watch(apiClientProvider)
      .dio
      .get('/inbox/api/logistic-in/$line/mention/capabilities');
  final data = response.data;
  if (data is! Map || data['can_complete'] is! bool)
    throw const FormatException('Unexpected mention capability response');
  return data['can_complete'] as bool;
});

class InboxScreen extends ConsumerStatefulWidget {
  final bool isActive;
  final String initialSource;
  const InboxScreen(
      {super.key, this.isActive = true, this.initialSource = 'All'});

  @override
  ConsumerState<InboxScreen> createState() => _InboxScreenState();
}

class _InboxScreenState extends ConsumerState<InboxScreen> {
  late String _selectedSource = widget.initialSource;
  late String _selectedSourceLabel =
      widget.initialSource == 'employee-chat' ? 'Chats' : 'All Sources';
  String _view = 'pending';
  String _search = '';
  bool _unreadOnly = false;
  Timer? _searchTimer;
  late final TextEditingController _searchController;

  @override
  void initState() {
    super.initState();
    final state = ref.read(inboxNotifierProvider);
    _view = state.status;
    _search = state.search;
    _searchController = TextEditingController(text: _search);
  }

  Future<void> _startChat(BuildContext context) async {
    final employee = await Navigator.of(context).push<Map<String, dynamic>>(
        MaterialPageRoute(builder: (_) => const EmployeePickerScreen()));
    if (employee == null || !context.mounted) return;
    await Navigator.of(context).push(MaterialPageRoute(
        builder: (_) => EmployeeMessagesScreen(
            id: (employee['id'] as num).toInt(),
            name: employee['name'].toString())));
    if (context.mounted) ref.read(inboxNotifierProvider.notifier).loadInbox();
  }

  Future<void> _createWorkItem(BuildContext context,
      {required bool isEc}) async {
    final created = await Navigator.of(context).push<bool>(
        MaterialPageRoute(builder: (_) => CreateWorkItemScreen(isEc: isEc)));
    if (created != true || !context.mounted) return;
    ref.read(inboxNotifierProvider.notifier).loadInbox();
    if (isEc) {
      ref.invalidate(ecProgressProvider);
    } else {
      ref.read(taskNotifierProvider.notifier).loadTasks();
      ref.invalidate(dashboardTasksProvider);
      ref.invalidate(dashboardTaskStatsProvider);
    }
  }

  @override
  void dispose() {
    _searchTimer?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final inboxState = ref.watch(inboxNotifierProvider);
    final rawItems = inboxState.items;
    final sources = <String, String>{
      'All': 'All Sources',
      ...inboxState.sources,
      for (final item in rawItems) item.filterSource: item.filterSourceLabel
    };
    // Ensure _selectedSource is a valid key in sources before building DropdownButtonFormField
    if (!sources.containsKey(_selectedSource)) {
      sources[_selectedSource] = _selectedSourceLabel;
    }
    final counts = _selectedSource == 'All'
        ? null
        : inboxState.sourceCounts[_selectedSource] ??
            (inboxState.sourceCountsComplete ? const [0, 0, 0, 0] : null);
    final incompleteCount = inboxState.error != null || inboxState.isLoading
        ? null
        : _selectedSource == 'All'
            ? (_unreadOnly
                ? inboxState.incompleteUnreadCount
                : inboxState.incompleteCount)
            : counts?[_unreadOnly ? 2 : 0];
    final completeCount = inboxState.error != null || inboxState.isLoading
        ? null
        : _selectedSource == 'All'
            ? (_unreadOnly
                ? inboxState.completeUnreadCount
                : inboxState.completeCount)
            : counts?[_unreadOnly ? 3 : 1];

    final filteredItems = rawItems
        .where((item) =>
            (_selectedSource == 'All' ||
                item.filterSource == _selectedSource) &&
            (!_unreadOnly || item.isUnread))
        .toList();
    DateTime timestamp(InboxItemModel item, {bool salesComment = false}) =>
        DateTime.tryParse((salesComment ? item.latestCommentAt : null) ??
            item.sortAt ??
            item.updatedAt ??
            item.createdAt) ??
        DateTime.fromMillisecondsSinceEpoch(0);
    filteredItems.sort((left, right) {
      final bothSales =
          left.moduleCode == 'sales-order' && right.moduleCode == 'sales-order';
      return timestamp(right, salesComment: bothSales)
          .compareTo(timestamp(left, salesComment: bothSales));
    });

    return OrbitWorkspaceScaffold(
      subtitle: 'Tasks, conversations & approvals',
      floatingActionButton: Padding(
        padding: EdgeInsets.only(
          bottom: 16 +
              (MediaQuery.paddingOf(context).bottom -
                      MediaQuery.viewPaddingOf(context).bottom)
                  .clamp(0.0, double.infinity),
        ),
        child: ExpandingActionFab(actions: [
          ExpandingFabAction(
              label: 'Create task',
              icon: Icons.add_task_rounded,
              onPressed: () => _createWorkItem(context, isEc: false)),
          ExpandingFabAction(
              label: 'Create EC',
              icon: Icons.description_outlined,
              onPressed: () => _createWorkItem(context, isEc: true)),
          ExpandingFabAction(
              label: 'New chat / DM',
              icon: Icons.chat_bubble_outline_rounded,
              onPressed: () => _startChat(context)),
        ]),
      ),
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        leadingWidth: 64,
        leading: Padding(
          padding: const EdgeInsets.only(left: 16, top: 5, bottom: 5),
          child: Container(
            decoration: BoxDecoration(
              color: OrbitColors.primaryNavy,
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Icon(Icons.chat_bubble_outline_rounded,
                color: Colors.white, size: 24),
          ),
        ),
        title: const Text(
          'Unified Inbox',
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w800,
            color: Colors.white,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded, color: Colors.white),
            onPressed: () {
              ref.read(inboxNotifierProvider.notifier).loadInbox();
            },
          ),
        ],
      ),
      body: RefreshIndicator(
        color: OrbitColors.primaryNavy,
        onRefresh: () async {
          await ref.read(inboxNotifierProvider.notifier).loadInbox();
        },
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 6),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Container(
                    constraints: const BoxConstraints(minHeight: 46),
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    decoration: BoxDecoration(
                      color: OrbitColors.cardSurface,
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(color: OrbitColors.cardBorder),
                      boxShadow: const [
                        BoxShadow(
                          color: Color(0x0A06244D),
                          blurRadius: 10,
                          offset: Offset(0, 3),
                        ),
                      ],
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.search_rounded,
                          color: OrbitColors.textMuted,
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: TextField(
                            controller: _searchController,
                            onChanged: (value) {
                              setState(() => _search = value.trim());
                              _searchTimer?.cancel();
                              _searchTimer = Timer(
                                const Duration(milliseconds: 350),
                                () {
                                  if (mounted) {
                                    ref
                                        .read(inboxNotifierProvider.notifier)
                                        .loadInbox(search: _search);
                                  }
                                },
                              );
                            },
                            style: const TextStyle(
                              color: OrbitColors.textPrimary,
                              fontSize: 14,
                            ),
                            decoration: const InputDecoration(
                              hintText: 'Search name, phone, plate...',
                              hintStyle: TextStyle(
                                color: OrbitColors.textMuted,
                                fontSize: 14,
                              ),
                              border: InputBorder.none,
                              enabledBorder: InputBorder.none,
                              focusedBorder: InputBorder.none,
                              filled: false,
                              isDense: true,
                              contentPadding:
                                  EdgeInsets.symmetric(vertical: 12),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 10),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        _buildFilterChip(
                          key: const ValueKey('status-pending'),
                          label:
                              'Incomplete${incompleteCount == null ? '' : ' ($incompleteCount)'}',
                          selected: _view == 'pending',
                          onTap: () => _selectStatus('pending'),
                        ),
                        const SizedBox(width: 8),
                        _buildFilterChip(
                          key: const ValueKey('status-complete'),
                          label:
                              'Complete${completeCount == null ? '' : ' ($completeCount)'}',
                          selected: _view == 'complete',
                          onTap: () => _selectStatus('complete'),
                        ),
                        const SizedBox(width: 8),
                        _buildFilterChip(
                          key: const ValueKey('filter-unread'),
                          label: 'Unread only',
                          selected: _unreadOnly,
                          onTap: () =>
                              setState(() => _unreadOnly = !_unreadOnly),
                        ),
                        const SizedBox(width: 8),
                        if (_selectedSource != 'All' ||
                            _unreadOnly ||
                            _search.isNotEmpty ||
                            _view != 'pending') ...[
                          _buildFilterChip(
                            key: const ValueKey('filter-reset'),
                            label: 'Reset filters',
                            selected: false,
                            leadingIcon: Icons.filter_alt_off_outlined,
                            onTap: _resetFilters,
                          ),
                          const SizedBox(width: 8),
                        ],
                        _buildFilterChip(
                          key: ValueKey('source-$_selectedSource'),
                          label:
                              sources[_selectedSource] ?? _selectedSourceLabel,
                          selected: _selectedSource != 'All',
                          trailingIcon: Icons.keyboard_arrow_down_rounded,
                          onTap: () => _showSourceFilterSheet(context, sources),
                        ),
                      ],
                    ),
                  ),
                  if (inboxState.chatError != null &&
                      _selectedSource != 'employee-chat')
                    Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: Text(
                        'Chats are unavailable. Select Chats to retry.',
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.error,
                          fontSize: 12,
                        ),
                      ),
                    ),
                ],
              ),
            ),

            // Items List
            Expanded(
              child: inboxState.isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : inboxState.error != null
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Padding(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 24),
                                  child: Text(inboxState.error!,
                                      textAlign: TextAlign.center)),
                              TextButton(
                                onPressed: () => ref
                                    .read(inboxNotifierProvider.notifier)
                                    .loadInbox(),
                                child: const Text('Retry'),
                              ),
                            ],
                          ),
                        )
                      : _selectedSource == 'employee-chat' &&
                              inboxState.chatError != null
                          ? Center(
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(inboxState.chatError!,
                                      textAlign: TextAlign.center),
                                  const SizedBox(height: 8),
                                  TextButton.icon(
                                    onPressed: () => ref
                                        .read(inboxNotifierProvider.notifier)
                                        .loadInbox(),
                                    icon: const Icon(Icons.refresh_rounded),
                                    label: const Text('Retry'),
                                  ),
                                ],
                              ),
                            )
                          : filteredItems.isEmpty
                              ? LayoutBuilder(
                                  builder: (context, constraints) => ListView(
                                        physics:
                                            const AlwaysScrollableScrollPhysics(),
                                        children: [
                                          SizedBox(
                                              height: constraints.maxHeight,
                                              child: const Column(
                                                mainAxisAlignment:
                                                    MainAxisAlignment.center,
                                                children: [
                                                  Icon(Icons.inbox_outlined,
                                                      size: 48,
                                                      color: OrbitColors
                                                          .textMuted),
                                                  SizedBox(height: 12),
                                                  Text('No items found',
                                                      style: TextStyle(
                                                          color: OrbitColors
                                                              .textSecondary)),
                                                ],
                                              ))
                                        ],
                                      ))
                              : ListView.separated(
                                  physics:
                                      const AlwaysScrollableScrollPhysics(),
                                  padding:
                                      const EdgeInsets.fromLTRB(12, 6, 12, 96),
                                  itemCount: filteredItems.length,
                                  separatorBuilder: (_, __) => const ColoredBox(
                                    color: OrbitColors.cardSurface,
                                    child: Divider(
                                      height: 1,
                                      thickness: 1,
                                      indent: 76,
                                      endIndent: 16,
                                      color: OrbitColors.cardBorder,
                                    ),
                                  ),
                                  itemBuilder: (context, index) {
                                    final item = filteredItems[index];
                                    return _buildInboxRow(
                                      item,
                                      isFirst: index == 0,
                                      isLast: index == filteredItems.length - 1,
                                    );
                                  },
                                ),
            ),
          ],
        ),
      ),
    );
  }

  void _selectStatus(String value) {
    if (_view == value) return;
    _searchTimer?.cancel();
    setState(() => _view = value);
    ref
        .read(inboxNotifierProvider.notifier)
        .loadInbox(status: value, search: _search);
  }

  void _resetFilters() {
    _searchTimer?.cancel();
    _searchController.clear();
    setState(() {
      _search = '';
      _view = 'pending';
      _selectedSource = 'All';
      _selectedSourceLabel = 'All Sources';
      _unreadOnly = false;
    });
    ref
        .read(inboxNotifierProvider.notifier)
        .loadInbox(status: 'pending', search: '');
  }

  Future<void> _showSourceFilterSheet(
    BuildContext context,
    Map<String, String> sources,
  ) async {
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: OrbitColors.cardSurface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: 10),
            Center(
              child: Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: OrbitColors.cardBorder,
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
            ),
            const Padding(
              padding: EdgeInsets.fromLTRB(20, 14, 20, 8),
              child: Text(
                'Filter by source',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: OrbitColors.textNavy,
                ),
              ),
            ),
            Flexible(
              child: ListView(
                shrinkWrap: true,
                children: [
                  for (final source in sources.entries)
                    ListTile(
                      title: Text(
                        source.value,
                        style: TextStyle(
                          fontWeight: _selectedSource == source.key
                              ? FontWeight.w700
                              : FontWeight.w500,
                          color: OrbitColors.textNavy,
                        ),
                      ),
                      trailing: _selectedSource == source.key
                          ? const Icon(
                              Icons.check_rounded,
                              color: OrbitColors.primaryNavy,
                            )
                          : null,
                      onTap: () {
                        setState(() {
                          _selectedSource = source.key;
                          _selectedSourceLabel = source.value;
                        });
                        Navigator.of(sheetContext).pop();
                      },
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterChip({
    Key? key,
    required String label,
    required bool selected,
    required VoidCallback onTap,
    IconData? leadingIcon,
    IconData? trailingIcon,
  }) {
    final fg = selected ? Colors.white : OrbitColors.textSecondary;
    return Material(
      key: key,
      color: selected ? OrbitColors.primaryNavy : OrbitColors.cardSurface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(999),
        side: BorderSide(
          color: selected ? OrbitColors.primaryNavy : OrbitColors.cardBorder,
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        borderRadius: BorderRadius.circular(999),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (leadingIcon != null) ...[
                Icon(leadingIcon, size: 16, color: fg),
                const SizedBox(width: 6),
              ],
              Text(
                label,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w600,
                  color: fg,
                ),
              ),
              if (trailingIcon != null) ...[
                const SizedBox(width: 4),
                Icon(trailingIcon, size: 16, color: fg),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInboxRow(
    InboxItemModel item, {
    required bool isFirst,
    required bool isLast,
  }) {
    final isGuest =
        item.moduleCode == 'guest-book' || item.subjectType == 'guest';
    final name = item.title.replaceFirst(RegExp(r'^Guest:\s*'), '').trim();
    final icon = item.moduleCode == 'employee-chat'
        ? Icons.chat_bubble_outline_rounded
        : item.source.contains('logistic')
            ? Icons.local_shipping_outlined
            : item.source.contains('fleet')
                ? Icons.directions_car_outlined
                : item.source.contains('sales')
                    ? Icons.receipt_long_outlined
                    : item.kind == 'mention'
                        ? Icons.alternate_email
                        : Icons.task_alt_outlined;
    final (avatarBg, avatarFg) = item.source.contains('logistic')
        ? (OrbitColors.kpiOrangeBg, OrbitColors.brandOrange)
        : item.source.contains('sales')
            ? (OrbitColors.kpiGreenBg, OrbitColors.kpiGreen)
            : item.kind == 'mention'
                ? (const Color(0xFFFFDFED), const Color(0xFFA64F86))
                : (OrbitColors.bubbleBlue, OrbitColors.primaryNavy);
    final borderRadius = BorderRadius.vertical(
      top: isFirst ? const Radius.circular(24) : Radius.zero,
      bottom: isLast ? const Radius.circular(24) : Radius.zero,
    );
    return Material(
      color: OrbitColors.cardSurface.withValues(alpha: 0.96),
      shape: RoundedRectangleBorder(borderRadius: borderRadius),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        borderRadius: borderRadius,
        onTap: () {
          if (item.moduleCode == 'employee-chat') {
            final conversationId = int.tryParse(item.subjectKey ?? '');
            if (conversationId == null) return;
            Navigator.of(context)
                .push(MaterialPageRoute(
                    builder: (_) => EmployeeMessagesScreen(
                          id: conversationId,
                          name: item.title,
                        )))
                .then((_) {
              if (mounted) ref.read(inboxNotifierProvider.notifier).loadInbox();
            });
            return;
          }
          final identity = item.readIdentity;
          if (item.isUnread &&
              (identity != null ||
                  item.unreadMentionNotificationIds.isNotEmpty)) {
            () async {
              try {
                if (identity != null)
                  await ref.read(inboxRepositoryProvider).markRead(
                      identity.module, identity.routeKey,
                      readSubjectType: identity.type,
                      readSubjectKey: identity.key);
                await ref
                    .read(inboxRepositoryProvider)
                    .markMentionNotificationsRead(
                        item.unreadMentionNotificationIds);
              } finally {
                if (mounted)
                  ref.read(inboxNotifierProvider.notifier).loadInbox();
              }
            }()
                .catchError((_) {});
          }
          final taskId = int.tryParse(item.subjectKey ?? '');
          final isTask = item.subjectType == 'task' ||
              const ['task', 'workhub', 'task-mine', 'task-assigned']
                  .contains(item.moduleCode);
          Navigator.of(context).push(MaterialPageRoute(
              builder: (_) => isTask && taskId != null
                  ? TaskDetailScreen(taskId: taskId)
                  : InboxItemDetailScreen(item: item)));
        },
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              CircleAvatar(
                radius: 24,
                backgroundColor: avatarBg,
                child: isGuest && name.isNotEmpty
                    ? Text(
                        String.fromCharCodes(name.runes.take(1)).toUpperCase(),
                        style: TextStyle(
                          color: avatarFg,
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                        ),
                      )
                    : Icon(icon, color: avatarFg, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (item.moduleCode == 'workhub_ec')
                      Padding(
                        padding: const EdgeInsets.only(bottom: 3),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 7,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: OrbitColors.bubbleBlue,
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: const Text(
                            'EC',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                              color: OrbitColors.primaryNavy,
                            ),
                          ),
                        ),
                      ),
                    Text(
                      item.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight:
                            item.isUnread ? FontWeight.w700 : FontWeight.w600,
                        color: _view == 'complete'
                            ? OrbitColors.textSecondary
                            : OrbitColors.textNavy,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      item.subtitle?.isNotEmpty == true
                          ? item.subtitle!
                          : item.moduleCode == 'workhub_ec'
                              ? 'No updates yet'
                              : item.sourceLabel,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight:
                            item.isUnread ? FontWeight.w600 : FontWeight.normal,
                        color: OrbitColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    inboxRowTime(item.displayAt),
                    style: TextStyle(
                      fontSize: 11.5,
                      fontWeight: item.unreadCount > 0
                          ? FontWeight.w700
                          : FontWeight.w500,
                      color: item.unreadCount > 0
                          ? OrbitColors.primaryNavy
                          : OrbitColors.textMuted,
                    ),
                  ),
                  const SizedBox(height: 6),
                  if (item.unreadCount > 0)
                    Semantics(
                      label: '${item.unreadCount} unread',
                      child: Container(
                        constraints:
                            const BoxConstraints(minWidth: 21, minHeight: 21),
                        padding: const EdgeInsets.symmetric(horizontal: 6),
                        alignment: Alignment.center,
                        decoration: const BoxDecoration(
                          color: OrbitColors.primaryNavy,
                          borderRadius: BorderRadius.all(Radius.circular(999)),
                        ),
                        child: Text(
                          item.unreadCount > 99 ? '99+' : '${item.unreadCount}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    )
                  else
                    const SizedBox(height: 21),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class InboxItemDetailScreen extends ConsumerWidget {
  final InboxItemModel item;
  const InboxItemDetailScreen({super.key, required this.item});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isGuest =
        item.moduleCode == 'guest-book' || item.subjectType == 'guest';
    final isTask = (item.subjectType == 'task' ||
            const ['task', 'workhub', 'task-mine', 'task-assigned']
                .contains(item.moduleCode)) &&
        int.tryParse(item.subjectKey ?? '') != null;
    final isEc = item.moduleCode == 'workhub_ec' &&
        int.tryParse(item.commentSubjectKey ?? item.subjectKey ?? '') != null;
    final hasLinkedRecords = item.logisticInDetail != null ||
        item.logisticOutReference != null ||
        isEc ||
        isTask;
    final canMarkRead = item.isUnread &&
        (item.readIdentity != null ||
            item.unreadMentionNotificationIds.isNotEmpty);
    final hasActions =
        (item.moduleCode == 'guest-book' && item.subjectKey != null) ||
            item.logisticOutMentionId != null ||
            item.logisticInMentionId != null ||
            canMarkRead;
    final hasDiscussion = item.commentModule != null &&
        item.commentModule!.isNotEmpty &&
        item.commentSubjectKey != null &&
        item.commentSubjectKey!.isNotEmpty;

    return OrbitWorkspaceScaffold(
      subtitle: 'Record details & discussion',
      appBar: AppBar(title: Text(item.sourceLabel)),
      body: OrbitDetailList(
        children: [
          // Header Hero Card
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: OrbitColors.cardSurface,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: Colors.white),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x1606244D),
                  blurRadius: 16,
                  offset: Offset(0, 6),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  alignment: WrapAlignment.spaceBetween,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: OrbitColors.bubbleBlue,
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        item.sourceLabel,
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: OrbitColors.primaryNavy,
                        ),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: item.status.contains('complete') ||
                                item.status.contains('approved') ||
                                item.status == 'done'
                            ? OrbitColors.kpiGreenBg
                            : OrbitColors.kpiOrangeBg,
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        item.status.replaceAll('_', ' ').toUpperCase(),
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: item.status.contains('complete') ||
                                  item.status.contains('approved') ||
                                  item.status == 'done'
                              ? const Color(0xFF15803D)
                              : OrbitColors.brandOrange,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    CircleAvatar(
                      radius: 22,
                      backgroundColor: OrbitColors.bubbleBlue,
                      child: Icon(
                        isGuest
                            ? Icons.badge_outlined
                            : item.source.contains('logistic')
                                ? Icons.local_shipping_outlined
                                : isTask
                                    ? Icons.task_alt_outlined
                                    : Icons.layers_outlined,
                        color: OrbitColors.primaryNavy,
                        size: 22,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            item.title,
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                              color: OrbitColors.textNavy,
                              height: 1.25,
                            ),
                          ),
                          if (item.subtitle != null &&
                              item.subtitle!.isNotEmpty) ...[
                            const SizedBox(height: 6),
                            Text(
                              item.subtitle!,
                              style: const TextStyle(
                                fontSize: 13.5,
                                color: OrbitColors.textSecondary,
                                height: 1.3,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
                if (item.createdAt.isNotEmpty) ...[
                  const SizedBox(height: 14),
                  const Divider(height: 1, color: OrbitColors.cardBorder),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      const Icon(
                        Icons.calendar_today_outlined,
                        size: 15,
                        color: OrbitColors.textMuted,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          item.createdAt,
                          style: const TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w500,
                            color: OrbitColors.textSecondary,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),

          // Linked Records Card
          if (hasLinkedRecords) ...[
            const Divider(height: 24),
            Row(
              children: [
                Container(
                  width: 30,
                  height: 30,
                  decoration: BoxDecoration(
                    color: OrbitColors.bubbleBlue,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(
                    Icons.hub_outlined,
                    size: 17,
                    color: OrbitColors.primaryNavy,
                  ),
                ),
                const SizedBox(width: 10),
                const Expanded(
                  child: Text(
                    'Linked Records',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: OrbitColors.textNavy,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            if (item.logisticInDetail case final reference?)
              _buildLinkedRecordTile(
                icon: Icons.inventory_2_outlined,
                title: 'Logistic In details',
                buttonLabel: 'Open Logistic In details',
                onTap: () => Navigator.of(context).push(MaterialPageRoute(
                  builder: (_) => LogisticInDetailScreen(
                    line: reference.line,
                    assignment: reference.assignment,
                    mention: reference.mention,
                  ),
                )),
              ),
            if (item.logisticOutReference case final reference?)
              _buildLinkedRecordTile(
                icon: Icons.local_shipping_outlined,
                title: 'Logistic Out details',
                buttonLabel: 'Open Logistic Out details',
                onTap: () => Navigator.of(context).push(MaterialPageRoute(
                  builder: (_) => LogisticOutDetailScreen(
                    stage: reference.stage,
                    subjectId: reference.id,
                  ),
                )),
              ),
            if (isEc)
              _buildLinkedRecordTile(
                icon: Icons.emoji_events_outlined,
                title: 'EC contest details',
                buttonLabel: 'Open EC details',
                onTap: () => Navigator.of(context).push(MaterialPageRoute(
                  builder: (_) => EcInboxDetailScreen(
                    entryId: item.commentSubjectKey ?? item.subjectKey!,
                  ),
                )),
              ),
            if (isTask)
              _buildLinkedRecordTile(
                icon: Icons.task_alt_outlined,
                title: 'Task record',
                buttonLabel: 'Open task',
                onTap: () => Navigator.of(context).push(MaterialPageRoute(
                  builder: (_) =>
                      TaskDetailScreen(taskId: int.parse(item.subjectKey!)),
                )),
              ),
          ],

          // Guest / Record details Card
          if (item.details.isNotEmpty) ...[
            const Divider(height: 24),
            Row(
              children: [
                Container(
                  width: 30,
                  height: 30,
                  decoration: BoxDecoration(
                    color: OrbitColors.bubbleBlue,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(
                    Icons.badge_outlined,
                    size: 17,
                    color: OrbitColors.primaryNavy,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Guest information',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                          color: OrbitColors.textNavy,
                        ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            for (final field in item.details.entries)
              ListTile(
                contentPadding: EdgeInsets.zero,
                visualDensity: VisualDensity.compact,
                title: Text(
                  field.key,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: OrbitColors.textSecondary,
                  ),
                ),
                subtitle: Text(
                  field.value,
                  style: const TextStyle(
                    fontSize: 14.5,
                    fontWeight: FontWeight.w600,
                    color: OrbitColors.textNavy,
                  ),
                ),
              ),
          ],

          // Actions Card
          if (hasActions) ...[
            const Divider(height: 24),
            Row(
              children: [
                Container(
                  width: 30,
                  height: 30,
                  decoration: BoxDecoration(
                    color: OrbitColors.bubbleBlue,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(
                    Icons.touch_app_outlined,
                    size: 17,
                    color: OrbitColors.primaryNavy,
                  ),
                ),
                const SizedBox(width: 10),
                const Expanded(
                  child: Text(
                    'Actions',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: OrbitColors.textNavy,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            if (item.moduleCode == 'guest-book' && item.subjectKey != null)
              _GuestCompletionAction(item: item),
            if (item.logisticOutMentionId != null)
              _LogisticOutMentionAction(item: item),
            if (item.logisticInMentionId != null)
              _LogisticInMentionAction(item: item),
            if (canMarkRead) ...[
              const SizedBox(height: 6),
              Align(
                alignment: Alignment.centerLeft,
                child: FilledButton.tonalIcon(
                  icon: const Icon(Icons.mark_email_read_outlined, size: 18),
                  label: const Text('Mark as read'),
                  onPressed: () async {
                    final identity = item.readIdentity;
                    var success = true;
                    if (identity != null) {
                      success = await ref.read(inboxRepositoryProvider).markRead(
                            identity.module,
                            identity.routeKey,
                            readSubjectType: identity.type,
                            readSubjectKey: identity.key,
                          );
                    }
                    try {
                      await ref
                          .read(inboxRepositoryProvider)
                          .markMentionNotificationsRead(
                              item.unreadMentionNotificationIds);
                    } catch (_) {
                      success = false;
                    }
                    if (!context.mounted) return;
                    if (success) {
                      await ref
                          .read(inboxNotifierProvider.notifier)
                          .loadInbox();
                      if (context.mounted) Navigator.pop(context);
                    } else {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content:
                              Text('Unable to mark this item as read.'),
                        ),
                      );
                    }
                  },
                ),
              ),
            ],
          ],

          // Discussion Card
          if (hasDiscussion) ...[
            const Divider(height: 24),
            Row(
              children: [
                Container(
                  width: 30,
                  height: 30,
                  decoration: BoxDecoration(
                    color: OrbitColors.bubbleBlue,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(
                    Icons.chat_bubble_outline_rounded,
                    size: 17,
                    color: OrbitColors.primaryNavy,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Discussion',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                          color: OrbitColors.textNavy,
                        ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            InboxDiscussion(
              module: item.commentModule!,
              subjectKey: item.commentSubjectKey!,
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildLinkedRecordTile({
    required IconData icon,
    required String title,
    required String buttonLabel,
    required VoidCallback onTap,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Container(
        decoration: BoxDecoration(
          color: OrbitColors.scaffoldBackground.withValues(alpha: 0.5),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: OrbitColors.cardBorder),
        ),
        child: ListTile(
          dense: true,
          leading: Icon(icon, color: OrbitColors.primaryNavy, size: 20),
          title: Text(
            title,
            style: const TextStyle(
              fontSize: 13.5,
              fontWeight: FontWeight.w600,
              color: OrbitColors.textNavy,
            ),
          ),
          trailing: TextButton.icon(
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            icon: const Icon(Icons.open_in_new, size: 15),
            label: Text(
              buttonLabel,
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
            ),
            onPressed: onTap,
          ),
        ),
      ),
    );
  }
}

class _GuestCompletionAction extends ConsumerStatefulWidget {
  final InboxItemModel item;
  const _GuestCompletionAction({required this.item});
  @override
  ConsumerState<_GuestCompletionAction> createState() =>
      _GuestCompletionActionState();
}

class _LogisticOutMentionAction extends ConsumerStatefulWidget {
  final InboxItemModel item;
  const _LogisticOutMentionAction({required this.item});
  @override
  ConsumerState<_LogisticOutMentionAction> createState() =>
      _LogisticOutMentionActionState();
}

class _LogisticInMentionAction extends ConsumerStatefulWidget {
  final InboxItemModel item;
  const _LogisticInMentionAction({required this.item});
  @override
  ConsumerState<_LogisticInMentionAction> createState() =>
      _LogisticInMentionActionState();
}

class _LogisticInMentionActionState
    extends ConsumerState<_LogisticInMentionAction> {
  bool busy = false;
  bool uncertain = false;

  Future<void> complete() async {
    if (busy || uncertain) return;
    setState(() => busy = true);
    try {
      await ref.read(apiClientProvider).dio.post(
          '/inbox/api/logistic-in/${widget.item.logisticInMentionId}/mention/complete');
      if (!mounted) return;
      await ref.read(inboxNotifierProvider.notifier).loadInbox();
      if (mounted) Navigator.pop(context);
    } catch (_) {
      if (mounted)
        setState(() {
          busy = false;
          uncertain = true;
        });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.item.mentionWorkStatus == 'complete')
      return const SizedBox.shrink();
    final id = widget.item.logisticInMentionId!;
    return ref.watch(_logisticInMentionCapability(id)).when(
          loading: () => const SizedBox.shrink(),
          error: (_, __) => TextButton(
              onPressed: () => ref.invalidate(_logisticInMentionCapability(id)),
              child: const Text('Unable to check mention access. Retry')),
          data: (allowed) {
            if (!allowed) return const SizedBox.shrink();
            if (uncertain)
              return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                        'The action may have completed. Refresh Inbox before trying again.'),
                    TextButton(
                        onPressed: () async {
                          await ref
                              .read(inboxNotifierProvider.notifier)
                              .loadInbox();
                          if (mounted) Navigator.pop(context);
                        },
                        child: const Text('Refresh Inbox')),
                  ]);
            return Align(
                alignment: Alignment.centerLeft,
                child: FilledButton.icon(
                  onPressed: busy ? null : complete,
                  icon: const Icon(Icons.check),
                  label: Text(busy ? 'Saving…' : 'Complete mention'),
                ));
          },
        );
  }
}

class _LogisticOutMentionActionState
    extends ConsumerState<_LogisticOutMentionAction> {
  bool busy = false;
  bool uncertain = false;

  Future<void> complete() async {
    if (busy || uncertain) return;
    setState(() => busy = true);
    try {
      await ref.read(apiClientProvider).dio.post(
          '/inbox/api/logistic-out/${widget.item.logisticOutMentionId}/mention/complete');
      if (!mounted) return;
      await ref.read(inboxNotifierProvider.notifier).loadInbox();
      if (mounted) Navigator.pop(context);
    } catch (_) {
      if (mounted)
        setState(() {
          busy = false;
          uncertain = true;
        });
    }
  }

  @override
  Widget build(BuildContext context) {
    final allowed = ref.watch(inboxNotifierProvider).canCompleteComment;
    if (!allowed || widget.item.mentionWorkStatus == 'complete')
      return const SizedBox.shrink();
    if (uncertain)
      return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text(
            'The action may have completed. Refresh Inbox before trying again.'),
        TextButton(
            onPressed: () async {
              await ref.read(inboxNotifierProvider.notifier).loadInbox();
              if (mounted) Navigator.pop(context);
            },
            child: const Text('Refresh Inbox')),
      ]);
    return Align(
        alignment: Alignment.centerLeft,
        child: FilledButton.icon(
          onPressed: busy ? null : complete,
          icon: const Icon(Icons.check),
          label: Text(busy ? 'Saving…' : 'Complete mention'),
        ));
  }
}

class _GuestCompletionActionState
    extends ConsumerState<_GuestCompletionAction> {
  bool busy = false;
  bool uncertain = false;

  Future<void> complete(bool checkout) async {
    if (busy || uncertain) return;
    if (checkout) {
      final confirmed = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
                title: const Text('Check out visitor?'),
                content: const Text(
                    'This records the visitor checkout and starts the checkout workflow.'),
                actions: [
                  TextButton(
                      onPressed: () => Navigator.pop(context, false),
                      child: const Text('Cancel')),
                  FilledButton(
                      onPressed: () => Navigator.pop(context, true),
                      child: const Text('Check out'))
                ],
              ));
      if (confirmed != true || !mounted) return;
    }
    setState(() => busy = true);
    final success = await ref
        .read(inboxRepositoryProvider)
        .completeTodo(widget.item.moduleCode!, widget.item.subjectKey!);
    if (!mounted) return;
    if (success) {
      await ref.read(inboxNotifierProvider.notifier).loadInbox();
      if (mounted) Navigator.pop(context);
    } else {
      setState(() {
        busy = false;
        uncertain = true;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final permissions = ref.watch(inboxNotifierProvider).guestActions;
    final canCheckout = permissions['can_check_out'] == true &&
        const ['assigned', 'security_approved', 'operator_accepted']
            .contains(widget.item.status);
    final canCompletePersonally = permissions['can_view'] == true &&
        permissions['can_security'] != true &&
        permissions['can_assign'] != true &&
        permissions['can_check_out'] != true;
    if (widget.item.isComplete || (!canCheckout && !canCompletePersonally))
      return const SizedBox.shrink();
    if (uncertain)
      return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text(
            'The action may have completed. Refresh Inbox before trying again.'),
        TextButton(
            onPressed: () async {
              await ref.read(inboxNotifierProvider.notifier).loadInbox();
              if (mounted) Navigator.pop(context);
            },
            child: const Text('Refresh Inbox')),
      ]);
    return Align(
        alignment: Alignment.centerLeft,
        child: FilledButton.icon(
          onPressed: busy ? null : () => complete(canCheckout),
          icon: const Icon(Icons.check),
          label: Text(busy
              ? 'Saving…'
              : canCheckout
                  ? 'Check out'
                  : 'Complete'),
        ));
  }
}
