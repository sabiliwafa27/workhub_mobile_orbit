import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/network/api_client.dart';
import '../../../core/theme/orbit_theme.dart';
import '../../../core/realtime/reverb_service.dart';
import '../../auth/providers/auth_provider.dart';
import '../providers/inbox_provider.dart';

typedef _DiscussionKey = ({String module, String subjectKey});

String _path(_DiscussionKey key) {
  final module = Uri.encodeComponent(key.module);
  final subject = Uri.encodeComponent(key.subjectKey);
  if (key.module == 'workhub_ec') return '/inbox/api/workhub-tasks/ec/$subject/comments';
  if (key.module == 'task') return '/collaboration/task/$subject/comments';
  return '/inbox/api/$module/$subject/comments';
}

final _commentsProvider = FutureProvider.autoDispose.family<_DiscussionData, _DiscussionKey>((ref, key) =>
    _fetchDiscussion(ref.watch(apiClientProvider), key));

Future<_DiscussionData> _fetchDiscussion(ApiClient api, _DiscussionKey key, {int? beforeId}) async {
  final response = await api.dio.get(_path(key), queryParameters: {'paginated': 1, 'page_size': 30, if (beforeId != null) 'before_id': beforeId});
  final data = response.data;
  if (data is! Map || data['data'] is! Map || data['data']['comments'] is! List) {
    throw const FormatException('Unexpected comments response');
  }
  final payload = data['data'] as Map;
  final subject = payload['subject'];
  final pagination = payload['pagination'];
  return _DiscussionData(payload['comments'] as List, subject is Map && subject['can_comment'] == true,
      pagination is Map ? (pagination['first_id'] as num?)?.toInt() : null,
      pagination is Map && pagination['has_older'] == true);
}

class _DiscussionData {
  final List<dynamic> comments;
  final bool canComment;
  final int? firstId;
  final bool hasOlder;
  const _DiscussionData(this.comments, this.canComment, this.firstId, this.hasOlder);
}

class InboxDiscussion extends ConsumerStatefulWidget {
  final String module;
  final String subjectKey;
  const InboxDiscussion({super.key, required this.module, required this.subjectKey});
  @override
  ConsumerState<InboxDiscussion> createState() => _InboxDiscussionState();
}

class _InboxDiscussionState extends ConsumerState<InboxDiscussion> {
  final comment = TextEditingController();
  bool sending = false, uncertain = false, loadingOlder = false, olderFailed = false;
  String? sendError;
  bool? hasMoreOlder;
  int? oldestId;
  int historyGeneration = 0;
  List<dynamic> olderComments = [];
  void Function()? _cancelRealtimeSubscription;
  _DiscussionKey get key => (module: widget.module, subjectKey: widget.subjectKey);

  @override
  void initState() {
    super.initState();
    _subscribeToRealtime();
  }

  void _subscribeToRealtime() {
    _cancelRealtimeSubscription?.call();
    final channel = 'private-collaboration.${widget.module}.${widget.subjectKey}';
    _cancelRealtimeSubscription = ref.read(reverbServiceProvider).subscribe(channel, (_) {
      if (mounted) refreshDiscussion();
    });
  }

  @override
  void didUpdateWidget(covariant InboxDiscussion oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.module != widget.module || oldWidget.subjectKey != widget.subjectKey) {
      _subscribeToRealtime();
    }
  }

  @override
  void dispose() {
    _cancelRealtimeSubscription?.call();
    comment.dispose();
    super.dispose();
  }

  void refreshDiscussion() {
    historyGeneration++;
    setState(() { olderComments = []; oldestId = null; hasMoreOlder = null; olderFailed = false; loadingOlder = false; });
    ref.invalidate(_commentsProvider(key));
  }

  Future<void> confirmDiscussionRefresh() async {
    historyGeneration++;
    setState(() { olderComments = []; oldestId = null; hasMoreOlder = null; olderFailed = false; loadingOlder = false; });
    try {
      await ref.refresh(_commentsProvider(key).future);
      if (mounted) setState(() => uncertain = false);
    } catch (_) {
      // Keep the send lock until a refresh succeeds.
    }
  }

  Future<void> loadOlder(_DiscussionData current) async {
    final before = oldestId ?? current.firstId;
    if (before == null || loadingOlder || !(hasMoreOlder ?? current.hasOlder)) return;
    final generation = historyGeneration;
    setState(() { loadingOlder = true; olderFailed = false; });
    try {
      final page = await _fetchDiscussion(ref.read(apiClientProvider), key, beforeId: before);
      if (!mounted || generation != historyGeneration) return;
      final existing = [...olderComments, ...current.comments].whereType<Map>().map((item) => item['comment_id']?.toString()).whereType<String>().toSet();
      final incoming = page.comments.where((item) => item is Map && item['comment_id'] != null && !existing.contains(item['comment_id'].toString()));
      setState(() {
        olderComments = [...incoming, ...olderComments];
        oldestId = page.firstId;
        hasMoreOlder = page.hasOlder && page.firstId != null && page.firstId! < before;
        loadingOlder = false;
      });
    } catch (_) {
      if (mounted && generation == historyGeneration) setState(() { loadingOlder = false; olderFailed = true; });
    }
  }

  Future<void> send() async {
    final body = comment.text.trim();
    if (body.isEmpty || sending || uncertain) return;
    setState(() { sending = true; sendError = null; });
    try {
      await ref.read(apiClientProvider).dio.post(_path(key), data: {'body': body});
      if (!mounted) return;
      comment.clear();
      refreshDiscussion();
      ref.read(inboxNotifierProvider.notifier).loadInbox();
    } on DioException catch (exception) {
      final status = exception.response?.statusCode;
      if (mounted) setState(() {
        if (status != null && status >= 400 && status < 500) {
          sendError = status == 403 ? 'You do not have permission to add this comment.' : 'The comment was rejected. Check the content and try again.';
        } else {
          uncertain = true;
        }
      });
    } catch (_) {
      if (mounted) setState(() => uncertain = true);
    } finally { if (mounted) setState(() => sending = false); }
  }

  @override
  Widget build(BuildContext context) => ref.watch(_commentsProvider(key)).when(
    loading: () => const Center(child: CircularProgressIndicator()),
    error: (_, __) => TextButton(onPressed: confirmDiscussionRefresh, child: const Text('Unable to load discussion. Tap to retry.')),
    data: (discussion) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      if (hasMoreOlder ?? discussion.hasOlder)
        TextButton(onPressed: loadingOlder ? null : () => loadOlder(discussion), child: Text(loadingOlder ? 'Loading…' : olderFailed ? 'Unable to load older comments. Retry' : 'Load older comments')),
      if (discussion.comments.isEmpty && olderComments.isEmpty) const Text('No comments yet.'),
      for (final item in [...olderComments, ...discussion.comments]) Builder(builder: (context) {
        final author = item['author'];
        final name = author is Map ? (author['name'] ?? '').toString() : '';
        return Card(
          margin: const EdgeInsets.only(bottom: 8),
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: OrbitColors.bubbleBlue,
              child: Text(name.isEmpty ? 'U' : name.substring(0, 1).toUpperCase(), style: const TextStyle(color: OrbitColors.primaryNavy, fontWeight: FontWeight.w700)),
            ),
            title: Text(name.isEmpty ? 'User' : name, style: const TextStyle(fontWeight: FontWeight.w700, color: OrbitColors.textNavy)),
            subtitle: Padding(padding: const EdgeInsets.only(top: 4), child: Text((item['body'] ?? '').toString())),
          ),
        );
      }),
      if (discussion.canComment) ...[
        const SizedBox(height: 10),
        TextField(
          controller: comment,
          maxLength: 5000,
          minLines: 2,
          maxLines: 4,
          enabled: !sending,
          decoration: InputDecoration(
            labelText: 'Write a comment...',
            alignLabelWithHint: true,
            prefixIcon: const Icon(Icons.chat_bubble_outline_rounded),
            filled: true,
            fillColor: OrbitColors.cardSurface,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(24),
              borderSide: const BorderSide(color: OrbitColors.cardBorder),
            ),
          ),
        ),
        if (sendError != null) Text(sendError!, style: const TextStyle(color: Colors.red)),
        if (uncertain) ...[
          const Text('The comment may have been sent. Refresh the discussion before retrying.'),
          TextButton(onPressed: confirmDiscussionRefresh, child: const Text('Refresh discussion')),
        ],
        Align(alignment: Alignment.centerRight, child: FilledButton(onPressed: sending || uncertain ? null : send, child: Text(sending ? 'Sending…' : 'Send'))),
      ] else const Text('You can view this discussion but cannot add comments.'),
    ]),
  );
}
