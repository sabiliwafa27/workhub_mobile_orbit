import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../../../core/theme/orbit_theme.dart';
import '../../auth/providers/auth_provider.dart';
import '../../tasks/providers/ec_progress_provider.dart';
import '../providers/inbox_provider.dart';
import 'discussion_panel.dart';

final _ecDetailProvider = FutureProvider.family<Map<String, dynamic>, String>((ref, id) async {
  final response = await ref.watch(apiClientProvider).dio.get('/inbox/api/workhub-tasks/ec/$id/detail');
  if (response.data is! Map) throw const FormatException('Unexpected EC detail response');
  return Map<String, dynamic>.from(response.data as Map);
});

class EcInboxDetailScreen extends ConsumerStatefulWidget {
  final String entryId;
  const EcInboxDetailScreen({super.key, required this.entryId});
  @override
  ConsumerState<EcInboxDetailScreen> createState() => _EcInboxDetailScreenState();
}

class _EcInboxDetailScreenState extends ConsumerState<EcInboxDetailScreen> {
  final note = TextEditingController();
  final percent = TextEditingController();
  Map<String, dynamic>? attempt;
  bool saving = false;
  String? error;
  bool initializedProgress = false;
  bool uncertain = false;

  @override
  void initState() {
    super.initState();
    ref.listenManual(_ecDetailProvider(widget.entryId), (_, next) {
      if (initializedProgress || !next.hasValue) return;
      final current = next.valueOrNull?['current_progress'];
      percent.text = (current is Map ? (current['percentage'] as num? ?? 0).toInt() : 0).toString();
      initializedProgress = true;
    }, fireImmediately: true);
  }

  @override
  void dispose() { note.dispose(); percent.dispose(); super.dispose(); }

  Future<void> refresh() async {
    if (saving) return;
    setState(() => saving = true);
    try {
      final detail = await ref.refresh(_ecDetailProvider(widget.entryId).future);
      if (!mounted) return;
      final current = detail['current_progress'];
      percent.text = (current is Map ? (current['percentage'] as num? ?? 0).toInt() : 0).toString();
      setState(() { uncertain = false; attempt = null; error = null; });
    } catch (_) {
      if (mounted) setState(() => error = 'Unable to refresh EC. Please try again.');
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  Future<void> save() async {
    final value = int.tryParse(percent.text);
    if (value == null || value < 0 || value > 100 || note.text.trim().isEmpty) {
      setState(() => error = 'Enter a percentage from 0 to 100 and a progress note.');
      return;
    }
    final message = note.text.trim();
    if (uncertain && attempt != null && (attempt!['percentage'] != value || attempt!['note'] != message)) {
      setState(() => error = 'Restore the same percentage and note to retry, or refresh the EC before making another update.');
      return;
    }
    if (attempt == null || attempt!['percentage'] != value || attempt!['note'] != message) {
      attempt = {'percentage': value, 'note': message, 'submission_key': const Uuid().v4()};
    }
    setState(() { saving = true; error = null; });
    try {
      await ref.read(apiClientProvider).dio.post('/inbox/api/workhub-tasks/ec/${widget.entryId}/progress', data: attempt);
      if (!mounted) return;
      attempt = null; uncertain = false; note.clear();
      ref.invalidate(_ecDetailProvider(widget.entryId));
      ref.invalidate(ecProgressProvider);
      ref.read(inboxNotifierProvider.notifier).loadInbox();
    } on DioException catch (exception) {
      final status = exception.response?.statusCode;
      if (mounted) setState(() {
        uncertain = status == null || status >= 500;
        if (!uncertain) attempt = null;
        error = uncertain ? 'Unable to confirm progress. Retry with the same details.' : 'The update was rejected. Refresh the EC and check your access.';
      });
    } catch (_) {
      if (mounted) setState(() { uncertain = true; error = 'Unable to confirm progress. Retry with the same details.'; });
    } finally { if (mounted) setState(() => saving = false); }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('EC details'), actions: [IconButton(tooltip: 'Refresh EC', onPressed: saving ? null : refresh, icon: const Icon(Icons.refresh))]),
    body: ref.watch(_ecDetailProvider(widget.entryId)).when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (_, __) => Center(child: TextButton(onPressed: () => ref.invalidate(_ecDetailProvider(widget.entryId)), child: const Text('Unable to load EC. Tap to retry.'))),
      data: (detail) {
        final history = detail['progress_history'] is List ? detail['progress_history'] as List : const [];
        final current = detail['current_progress'];
        final progress = current is Map ? (current['percentage'] as num? ?? 0).toDouble() : 0.0;
        return ListView(cacheExtent: 4000, padding: const EdgeInsets.all(16), children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: OrbitColors.cardSurface,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: OrbitColors.cardBorder),
            ),
            child: Row(children: [
              const CircleAvatar(
                radius: 25,
                backgroundColor: OrbitColors.bubbleBlue,
                child: Icon(Icons.layers_outlined, color: OrbitColors.primaryNavy),
              ),
              const SizedBox(width: 14),
              Expanded(child: Text((detail['title'] ?? '').toString(),
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w800, color: OrbitColors.textNavy))),
            ]),
          ),
          const SizedBox(height: 12),
          Text('Owner: ${detail['employee_name'] ?? '—'}'),
          Text('EC date: ${detail['date'] ?? '—'}'),
          if ((detail['intended_benefit'] ?? '').toString().isNotEmpty) ...[const SizedBox(height: 12), const Text('Intended benefit', style: TextStyle(fontWeight: FontWeight.bold)), Text(detail['intended_benefit'].toString())],
          const SizedBox(height: 16), LinearProgressIndicator(value: (progress / 100).clamp(0.0, 1.0).toDouble()), Text('${progress.toStringAsFixed(0)}%'),
          if (detail['can_update_progress'] == true) ...[
            const SizedBox(height: 16), const Text('Update progress', style: TextStyle(fontWeight: FontWeight.bold)),
            TextField(controller: percent, keyboardType: TextInputType.number, enabled: !saving, decoration: const InputDecoration(labelText: 'Progress (%)')),
            TextField(controller: note, maxLines: 3, maxLength: 2000, enabled: !saving, decoration: const InputDecoration(labelText: 'Progress note')),
            if (error != null) Text(error!, style: const TextStyle(color: Colors.red)),
            Align(alignment: Alignment.centerLeft, child: FilledButton(onPressed: saving ? null : save, child: Text(saving ? 'Updating…' : 'Update progress'))),
          ],
          const SizedBox(height: 16), const Text('Progress history', style: TextStyle(fontWeight: FontWeight.bold)),
          if (history.isEmpty) const Text('No progress updates yet.'),
          for (final entry in history) ListTile(contentPadding: EdgeInsets.zero, title: Text('${entry['percentage']}% · ${entry['employee_name'] ?? ''}'), subtitle: Text('${entry['note'] ?? ''}\n${entry['at'] ?? ''}')),
          const Divider(height: 32),
          Row(children: [
            const CircleAvatar(radius: 19, backgroundColor: OrbitColors.bubbleBlue,
                child: Icon(Icons.chat_bubble_outline_rounded,
                    color: OrbitColors.primaryNavy, size: 19)),
            const SizedBox(width: 10),
            Text('Discussion', style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w800, color: OrbitColors.textNavy)),
          ]),
          const SizedBox(height: 8),
          InboxDiscussion(module: 'workhub_ec', subjectKey: widget.entryId),
        ]);
      },
    ),
  );
}
