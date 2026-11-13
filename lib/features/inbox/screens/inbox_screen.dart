import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/orbit_theme.dart';
import '../models/inbox_item_model.dart';
import '../providers/inbox_provider.dart';
import '../../tasks/screens/create_work_item_screen.dart';
import '../../tasks/screens/task_detail_screen.dart';
import '../../tasks/providers/task_provider.dart';
import '../../tasks/providers/ec_progress_provider.dart';
import '../../auth/providers/auth_provider.dart';
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
      .difference(DateTime.utc(target.year, target.month, target.day)).inDays;
  if (days == 0) return '${target.hour.toString().padLeft(2, '0')}:${target.minute.toString().padLeft(2, '0')}';
  if (days == 1) return 'Yesterday';
  return '${target.day}/${target.month}/${(target.year % 100).toString().padLeft(2, '0')}';
}

final _logisticInMentionCapability = FutureProvider.autoDispose.family<bool, int>((ref, line) async {
  final response = await ref.watch(apiClientProvider).dio.get('/inbox/api/logistic-in/$line/mention/capabilities');
  final data = response.data;
  if (data is! Map || data['can_complete'] is! bool) throw const FormatException('Unexpected mention capability response');
  return data['can_complete'] as bool;
});

class InboxScreen extends ConsumerStatefulWidget {
  const InboxScreen({super.key});

  @override
  ConsumerState<InboxScreen> createState() => _InboxScreenState();
}

class _InboxScreenState extends ConsumerState<InboxScreen> {
  String _selectedSource = 'All';
  String _selectedSourceLabel = 'All Sources';
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
    final sources = <String, String>{'All': 'All Sources', ...inboxState.sources,
      for (final item in rawItems) item.filterSource: item.filterSourceLabel};
    if (!sources.containsKey(_selectedSource)) sources[_selectedSource] = _selectedSourceLabel;
    final counts = _selectedSource == 'All' ? null : inboxState.sourceCounts[_selectedSource] ?? (inboxState.sourceCountsComplete ? const [0, 0, 0, 0] : null);
    final incompleteCount = inboxState.error != null || inboxState.isLoading ? null : _selectedSource == 'All'
        ? (_unreadOnly ? inboxState.incompleteUnreadCount : inboxState.incompleteCount)
        : counts?[_unreadOnly ? 2 : 0];
    final completeCount = inboxState.error != null || inboxState.isLoading ? null : _selectedSource == 'All'
        ? (_unreadOnly ? inboxState.completeUnreadCount : inboxState.completeCount)
        : counts?[_unreadOnly ? 3 : 1];

    final filteredItems = rawItems.where((item) =>
        (_selectedSource == 'All' || item.filterSource == _selectedSource) &&
        (!_unreadOnly || item.isUnread)).toList();
    DateTime timestamp(InboxItemModel item, {bool salesComment = false}) =>
        DateTime.tryParse((salesComment ? item.latestCommentAt : null) ?? item.sortAt ?? item.updatedAt ?? item.createdAt) ?? DateTime.fromMillisecondsSinceEpoch(0);
    filteredItems.sort((left, right) {
      final bothSales = left.moduleCode == 'sales-order' && right.moduleCode == 'sales-order';
      return timestamp(right, salesComment: bothSales).compareTo(timestamp(left, salesComment: bothSales));
    });

    return Scaffold(
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          final isEc = await showModalBottomSheet<bool>(context: context, builder: (context) => SafeArea(child: Column(mainAxisSize: MainAxisSize.min, children: [
            ListTile(title: const Text('Create task'), onTap: () => Navigator.pop(context, false)),
            ListTile(title: const Text('Create EC'), onTap: () => Navigator.pop(context, true)),
          ])));
          if (isEc == null || !context.mounted) return;
          final created = await Navigator.of(context).push<bool>(MaterialPageRoute(builder: (_) => CreateWorkItemScreen(isEc: isEc)));
          if (created == true && context.mounted) {
            ref.read(inboxNotifierProvider.notifier).loadInbox();
            if (isEc) {
              ref.invalidate(ecProgressProvider);
            } else {
              ref.read(taskNotifierProvider.notifier).loadTasks();
            }
          }
        },
        child: const Icon(Icons.add),
      ),
      backgroundColor: OrbitColors.scaffoldBackground,
      appBar: AppBar(
        title: const Text(
          'Unified Inbox',
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
              padding: const EdgeInsets.all(16),
              child: Column(children: [
                TextField(controller: _searchController, onChanged: (value) {
                  setState(() => _search = value.trim());
                  _searchTimer?.cancel();
                  _searchTimer = Timer(const Duration(milliseconds: 350), () {
                    if (mounted) ref.read(inboxNotifierProvider.notifier).loadInbox(search: _search);
                  });
                }, decoration: const InputDecoration(prefixIcon: Icon(Icons.search), hintText: 'Search name, phone, plate…')),
                const SizedBox(height: 8),
                Row(children: [
                  Expanded(child: DropdownButtonFormField<String>(
                    value: _view,
                    isExpanded: true,
                    decoration: const InputDecoration(labelText: 'Status', contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 12)),
                    items: [
                      DropdownMenuItem(value: 'pending', child: Text('Incomplete${incompleteCount == null ? '' : ' ($incompleteCount)'}', overflow: TextOverflow.ellipsis)),
                      DropdownMenuItem(value: 'complete', child: Text('Complete${completeCount == null ? '' : ' ($completeCount)'}', overflow: TextOverflow.ellipsis)),
                    ],
                    onChanged: (value) {
                      if (value == null) return;
                      _searchTimer?.cancel();
                      setState(() => _view = value);
                      ref.read(inboxNotifierProvider.notifier).loadInbox(status: value, search: _search);
                    },
                  )),
                  const SizedBox(width: 8),
                  Expanded(child: DropdownButtonFormField<String>(
                    value: _selectedSource,
                    isExpanded: true,
                    decoration: const InputDecoration(labelText: 'Source', contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 12)),
                    items: sources.entries.map((source) => DropdownMenuItem(value: source.key, child: Text(source.value, overflow: TextOverflow.ellipsis))).toList(),
                    onChanged: (value) { if (value != null) setState(() { _selectedSource = value; _selectedSourceLabel = sources[value] ?? value; }); },
                  )),
                ]),
                SwitchListTile(contentPadding: EdgeInsets.zero, title: const Text('Unread only'), value: _unreadOnly, onChanged: (value) => setState(() => _unreadOnly = value)),
                if (_selectedSource != 'All' || _unreadOnly || _search.isNotEmpty || _view != 'pending')
                  Align(alignment: Alignment.centerRight, child: TextButton.icon(
                    onPressed: () {
                      _searchTimer?.cancel();
                      _searchController.clear();
                      setState(() { _search = ''; _view = 'pending'; _selectedSource = 'All'; _selectedSourceLabel = 'All Sources'; _unreadOnly = false; });
                      ref.read(inboxNotifierProvider.notifier).loadInbox(status: 'pending', search: '');
                    },
                    icon: const Icon(Icons.filter_alt_off_outlined), label: const Text('Reset filters'),
                  )),
              ]),
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
                          Padding(padding: const EdgeInsets.symmetric(horizontal: 24), child: Text(inboxState.error!, textAlign: TextAlign.center)),
                          TextButton(
                            onPressed: () => ref.read(inboxNotifierProvider.notifier).loadInbox(),
                            child: const Text('Retry'),
                          ),
                        ],
                      ),
                    )
                  : filteredItems.isEmpty
                  ? LayoutBuilder(builder: (context, constraints) => ListView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      children: [SizedBox(height: constraints.maxHeight, child: const Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.inbox_outlined, size: 48, color: OrbitColors.textMuted),
                          SizedBox(height: 12),
                          Text('No items found', style: TextStyle(color: OrbitColors.textSecondary)),
                        ],
                      ))],
                    ))
                  : ListView.separated(
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: const EdgeInsets.only(bottom: 90),
                      itemCount: filteredItems.length,
                      separatorBuilder: (_, __) => const Divider(height: 1, indent: 64),
                      itemBuilder: (context, index) {
                        final item = filteredItems[index];
                        return _buildInboxCard(item);
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInboxCard(InboxItemModel item) {
    final isGuest = item.moduleCode == 'guest-book' || item.subjectType == 'guest';
    final name = item.title.replaceFirst(RegExp(r'^Guest:\s*'), '').trim();
    final icon = item.source.contains('logistic') ? Icons.local_shipping_outlined
        : item.source.contains('fleet') ? Icons.directions_car_outlined
        : item.source.contains('sales') ? Icons.receipt_long_outlined
        : item.kind == 'mention' ? Icons.alternate_email : Icons.task_alt_outlined;
    return Material(color: Colors.white, child: InkWell(
      onTap: () {
        final identity = item.readIdentity;
        if (item.isUnread && (identity != null || item.unreadMentionNotificationIds.isNotEmpty)) {
          () async {
            try {
              if (identity != null) await ref.read(inboxRepositoryProvider).markRead(identity.module, identity.routeKey,
                  readSubjectType: identity.type, readSubjectKey: identity.key);
              await ref.read(inboxRepositoryProvider).markMentionNotificationsRead(item.unreadMentionNotificationIds);
            } finally {
              if (mounted) ref.read(inboxNotifierProvider.notifier).loadInbox();
            }
          }().catchError((_) {});
        }
        Navigator.of(context).push(MaterialPageRoute(builder: (_) => InboxItemDetailScreen(item: item)));
      },
      child: Padding(padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14), child: Row(children: [
        CircleAvatar(radius: 18, backgroundColor: OrbitColors.bubbleBlue,
          child: isGuest && name.isNotEmpty
              ? Text(String.fromCharCodes(name.runes.take(1)).toUpperCase(), style: const TextStyle(color: OrbitColors.primaryNavy, fontWeight: FontWeight.bold))
              : Icon(icon, color: OrbitColors.primaryNavy, size: 18)),
        const SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          if (item.moduleCode == 'workhub_ec') const Text('EC', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: OrbitColors.primaryNavy)),
          Text(item.title, maxLines: 1, overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 14, fontWeight: item.isUnread ? FontWeight.w700 : FontWeight.w500, color: _view == 'complete' ? OrbitColors.textSecondary : OrbitColors.textNavy)),
          const SizedBox(height: 2),
          Text(item.subtitle?.isNotEmpty == true ? item.subtitle! : item.moduleCode == 'workhub_ec' ? 'No updates yet' : item.sourceLabel,
              maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 12, fontWeight: item.isUnread ? FontWeight.w600 : FontWeight.normal, color: OrbitColors.textSecondary)),
        ])),
        const SizedBox(width: 8),
        Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
          Text(inboxRowTime(item.displayAt), style: const TextStyle(fontSize: 11, color: OrbitColors.textMuted)),
          const SizedBox(height: 5),
          if (item.unreadCount > 0) Semantics(label: '${item.unreadCount} unread', child: Container(
            constraints: const BoxConstraints(minWidth: 20, minHeight: 20),
            padding: const EdgeInsets.symmetric(horizontal: 5),
            alignment: Alignment.center,
            decoration: const BoxDecoration(color: OrbitColors.primaryNavy, borderRadius: BorderRadius.all(Radius.circular(12))),
            child: Text(item.unreadCount > 99 ? '99+' : '${item.unreadCount}', style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
          )) else const SizedBox(height: 20),
        ]),
      ])),
    ));
  }
}

class InboxItemDetailScreen extends ConsumerWidget {
  final InboxItemModel item;
  const InboxItemDetailScreen({super.key, required this.item});

  @override
  Widget build(BuildContext context, WidgetRef ref) => Scaffold(
    appBar: AppBar(title: Text(item.sourceLabel)),
    body: ListView(padding: const EdgeInsets.all(16), children: [
      Text(item.title, style: Theme.of(context).textTheme.titleLarge),
      const SizedBox(height: 12),
      if (item.subtitle != null && item.subtitle!.isNotEmpty) Text(item.subtitle!),
      const SizedBox(height: 12),
      Text('Status: ${item.status.replaceAll('_', ' ')}'),
      const SizedBox(height: 6),
      Text(item.createdAt),
      if (item.logisticInDetail case final reference?)
        TextButton.icon(
          icon: const Icon(Icons.open_in_new),
          label: const Text('Open Logistic In details'),
          onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => LogisticInDetailScreen(
            line: reference.line, assignment: reference.assignment, mention: reference.mention,
          ))),
        ),
      if (item.logisticOutReference case final reference?)
        TextButton.icon(
          icon: const Icon(Icons.open_in_new),
          label: const Text('Open Logistic Out details'),
          onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => LogisticOutDetailScreen(stage: reference.stage, subjectId: reference.id))),
        ),
      if (item.details.isNotEmpty) ...[
        const Divider(height: 32),
        Text('Guest information', style: Theme.of(context).textTheme.titleMedium),
        for (final field in item.details.entries)
          ListTile(contentPadding: EdgeInsets.zero, title: Text(field.key), subtitle: Text(field.value)),
      ],
      if (item.moduleCode == 'guest-book' && item.subjectKey != null)
        _GuestCompletionAction(item: item),
      if (item.logisticOutMentionId != null)
        _LogisticOutMentionAction(item: item),
      if (item.logisticInMentionId != null)
        _LogisticInMentionAction(item: item),
      if (item.moduleCode == 'workhub_ec' && int.tryParse(item.commentSubjectKey ?? item.subjectKey ?? '') != null)
        TextButton.icon(
          icon: const Icon(Icons.open_in_new),
          label: const Text('Open EC details'),
          onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => EcInboxDetailScreen(entryId: item.commentSubjectKey ?? item.subjectKey!))),
        ),
      if ((item.subjectType == 'task' || const ['task', 'workhub', 'task-mine', 'task-assigned'].contains(item.moduleCode)) && int.tryParse(item.subjectKey ?? '') != null)
        TextButton.icon(
          icon: const Icon(Icons.open_in_new),
          label: const Text('Open task'),
          onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => TaskDetailScreen(taskId: int.parse(item.subjectKey!)))),
        ),
      if (item.isUnread && (item.readIdentity != null || item.unreadMentionNotificationIds.isNotEmpty))
        TextButton.icon(
          icon: const Icon(Icons.mark_email_read_outlined),
          label: const Text('Mark as read'),
          onPressed: () async {
            final identity = item.readIdentity;
            var success = true;
            if (identity != null) {
              success = await ref.read(inboxRepositoryProvider).markRead(identity.module, identity.routeKey,
                  readSubjectType: identity.type, readSubjectKey: identity.key);
            }
            try {
              await ref.read(inboxRepositoryProvider).markMentionNotificationsRead(item.unreadMentionNotificationIds);
            } catch (_) {
              success = false;
            }
            if (!context.mounted) return;
            if (success) {
              await ref.read(inboxNotifierProvider.notifier).loadInbox();
              if (context.mounted) Navigator.pop(context);
            } else {
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Unable to mark this item as read.')));
            }
          },
        ),
      if (item.commentModule != null && item.commentModule!.isNotEmpty && item.commentSubjectKey != null && item.commentSubjectKey!.isNotEmpty) ...[
        const Divider(height: 32),
        Text('Discussion', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        InboxDiscussion(module: item.commentModule!, subjectKey: item.commentSubjectKey!),
      ],
    ]),
  );
}

class _GuestCompletionAction extends ConsumerStatefulWidget {
  final InboxItemModel item;
  const _GuestCompletionAction({required this.item});
  @override
  ConsumerState<_GuestCompletionAction> createState() => _GuestCompletionActionState();
}

class _LogisticOutMentionAction extends ConsumerStatefulWidget {
  final InboxItemModel item;
  const _LogisticOutMentionAction({required this.item});
  @override
  ConsumerState<_LogisticOutMentionAction> createState() => _LogisticOutMentionActionState();
}

class _LogisticInMentionAction extends ConsumerStatefulWidget {
  final InboxItemModel item;
  const _LogisticInMentionAction({required this.item});
  @override
  ConsumerState<_LogisticInMentionAction> createState() => _LogisticInMentionActionState();
}

class _LogisticInMentionActionState extends ConsumerState<_LogisticInMentionAction> {
  bool busy = false;
  bool uncertain = false;

  Future<void> complete() async {
    if (busy || uncertain) return;
    setState(() => busy = true);
    try {
      await ref.read(apiClientProvider).dio.post('/inbox/api/logistic-in/${widget.item.logisticInMentionId}/mention/complete');
      if (!mounted) return;
      await ref.read(inboxNotifierProvider.notifier).loadInbox();
      if (mounted) Navigator.pop(context);
    } catch (_) {
      if (mounted) setState(() { busy = false; uncertain = true; });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.item.mentionWorkStatus == 'complete') return const SizedBox.shrink();
    final id = widget.item.logisticInMentionId!;
    return ref.watch(_logisticInMentionCapability(id)).when(
      loading: () => const SizedBox.shrink(),
      error: (_, __) => TextButton(onPressed: () => ref.invalidate(_logisticInMentionCapability(id)), child: const Text('Unable to check mention access. Retry')),
      data: (allowed) {
        if (!allowed) return const SizedBox.shrink();
        if (uncertain) return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('The action may have completed. Refresh Inbox before trying again.'),
          TextButton(onPressed: () async { await ref.read(inboxNotifierProvider.notifier).loadInbox(); if (mounted) Navigator.pop(context); }, child: const Text('Refresh Inbox')),
        ]);
        return Align(alignment: Alignment.centerLeft, child: FilledButton.icon(
          onPressed: busy ? null : complete,
          icon: const Icon(Icons.check),
          label: Text(busy ? 'Saving…' : 'Complete mention'),
        ));
      },
    );
  }
}

class _LogisticOutMentionActionState extends ConsumerState<_LogisticOutMentionAction> {
  bool busy = false;
  bool uncertain = false;

  Future<void> complete() async {
    if (busy || uncertain) return;
    setState(() => busy = true);
    try {
      await ref.read(apiClientProvider).dio.post('/inbox/api/logistic-out/${widget.item.logisticOutMentionId}/mention/complete');
      if (!mounted) return;
      await ref.read(inboxNotifierProvider.notifier).loadInbox();
      if (mounted) Navigator.pop(context);
    } catch (_) {
      if (mounted) setState(() { busy = false; uncertain = true; });
    }
  }

  @override
  Widget build(BuildContext context) {
    final allowed = ref.watch(inboxNotifierProvider).canCompleteComment;
    if (!allowed || widget.item.mentionWorkStatus == 'complete') return const SizedBox.shrink();
    if (uncertain) return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const Text('The action may have completed. Refresh Inbox before trying again.'),
      TextButton(onPressed: () async { await ref.read(inboxNotifierProvider.notifier).loadInbox(); if (mounted) Navigator.pop(context); }, child: const Text('Refresh Inbox')),
    ]);
    return Align(alignment: Alignment.centerLeft, child: FilledButton.icon(
      onPressed: busy ? null : complete,
      icon: const Icon(Icons.check),
      label: Text(busy ? 'Saving…' : 'Complete mention'),
    ));
  }
}

class _GuestCompletionActionState extends ConsumerState<_GuestCompletionAction> {
  bool busy = false;
  bool uncertain = false;

  Future<void> complete(bool checkout) async {
    if (busy || uncertain) return;
    if (checkout) {
      final confirmed = await showDialog<bool>(context: context, builder: (context) => AlertDialog(
        title: const Text('Check out visitor?'),
        content: const Text('This records the visitor checkout and starts the checkout workflow.'),
        actions: [TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')), FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Check out'))],
      ));
      if (confirmed != true || !mounted) return;
    }
    setState(() => busy = true);
    final success = await ref.read(inboxRepositoryProvider).completeTodo(widget.item.moduleCode!, widget.item.subjectKey!);
    if (!mounted) return;
    if (success) {
      await ref.read(inboxNotifierProvider.notifier).loadInbox();
      if (mounted) Navigator.pop(context);
    } else {
      setState(() { busy = false; uncertain = true; });
    }
  }

  @override
  Widget build(BuildContext context) {
    final permissions = ref.watch(inboxNotifierProvider).guestActions;
    final canCheckout = permissions['can_check_out'] == true &&
        const ['assigned', 'security_approved', 'operator_accepted'].contains(widget.item.status);
    final canCompletePersonally = permissions['can_view'] == true && permissions['can_security'] != true &&
        permissions['can_assign'] != true && permissions['can_check_out'] != true;
    if (widget.item.isComplete || (!canCheckout && !canCompletePersonally)) return const SizedBox.shrink();
    if (uncertain) return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const Text('The action may have completed. Refresh Inbox before trying again.'),
      TextButton(onPressed: () async { await ref.read(inboxNotifierProvider.notifier).loadInbox(); if (mounted) Navigator.pop(context); }, child: const Text('Refresh Inbox')),
    ]);
    return Align(alignment: Alignment.centerLeft, child: FilledButton.icon(
      onPressed: busy ? null : () => complete(canCheckout),
      icon: const Icon(Icons.check),
      label: Text(busy ? 'Saving…' : canCheckout ? 'Check out' : 'Complete'),
    ));
  }
}
