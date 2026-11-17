import 'package:flutter/material.dart';
import '../../../core/widgets/orbit_workspace.dart';
import '../../../core/utils/created_date_format.dart';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../../../core/theme/orbit_theme.dart';
import '../../auth/providers/auth_provider.dart';
import '../../tasks/providers/ec_progress_provider.dart';
import '../providers/inbox_provider.dart';
import 'discussion_panel.dart';

final _ecDetailProvider =
    FutureProvider.family<Map<String, dynamic>, String>((ref, id) async {
  final cleanId = id.replaceFirst(RegExp(r'^ec:'), '');
  final response = await ref
      .watch(apiClientProvider)
      .dio
      .get('/inbox/api/workhub-tasks/ec/$cleanId/detail');
  if (response.data is! Map)
    throw const FormatException('Unexpected EC detail response');
  return Map<String, dynamic>.from(response.data as Map);
});

class EcInboxDetailScreen extends ConsumerStatefulWidget {
  final String entryId;
  final String? title;
  final String? createdAt;
  const EcInboxDetailScreen({
    super.key,
    required this.entryId,
    this.title,
    this.createdAt,
  });
  @override
  ConsumerState<EcInboxDetailScreen> createState() =>
      _EcInboxDetailScreenState();
}

class _EcInboxDetailScreenState extends ConsumerState<EcInboxDetailScreen> {
  final note = TextEditingController();
  final percent = TextEditingController();
  Map<String, dynamic>? attempt;
  bool saving = false;
  String? error;
  bool initializedProgress = false;
  bool uncertain = false;

  String get _cleanEntryId => widget.entryId.replaceFirst(RegExp(r'^ec:'), '');

  Future<void> _completeEc() async {
    setState(() {
      saving = true;
      error = null;
    });
    try {
      await ref.read(apiClientProvider).dio.post(
        '/inbox/api/workhub-tasks/ec/$_cleanEntryId/progress',
        data: {
          'percentage': 100,
          'note': 'Status diubah menjadi Selesai.',
          'submission_key': const Uuid().v4(),
        },
      );
      if (!mounted) return;
      percent.text = '100';
      note.clear();
      ref.invalidate(_ecDetailProvider(widget.entryId));
      ref.invalidate(ecProgressProvider);
      ref.read(inboxNotifierProvider.notifier).loadInbox();
    } catch (_) {
      if (mounted) {
        setState(() {
          error = 'Unable to complete EC. Tap refresh or try again.';
        });
      }
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  @override
  void initState() {
    super.initState();
    ref.listenManual(_ecDetailProvider(widget.entryId), (_, next) {
      if (initializedProgress || !next.hasValue) return;
      final current = next.valueOrNull?['current_progress'];
      percent.text =
          (current is Map ? (current['percentage'] as num? ?? 0).toInt() : 0)
              .toString();
      initializedProgress = true;
    }, fireImmediately: true);
  }

  @override
  void dispose() {
    note.dispose();
    percent.dispose();
    super.dispose();
  }

  Future<void> save() async {
    final value = int.tryParse(percent.text);
    if (value == null || value < 0 || value > 100 || note.text.trim().isEmpty) {
      setState(() =>
          error = 'Enter a percentage from 0 to 100 and a progress note.');
      return;
    }
    final message = note.text.trim();
    if (uncertain &&
        attempt != null &&
        (attempt!['percentage'] != value || attempt!['note'] != message)) {
      setState(() => error =
          'Restore the same percentage and note to retry, or refresh the EC before making another update.');
      return;
    }
    if (attempt == null ||
        attempt!['percentage'] != value ||
        attempt!['note'] != message) {
      attempt = {
        'percentage': value,
        'note': message,
        'submission_key': const Uuid().v4()
      };
    }
    setState(() {
      saving = true;
      error = null;
    });
    try {
      await ref.read(apiClientProvider).dio.post(
          '/inbox/api/workhub-tasks/ec/$_cleanEntryId/progress',
          data: attempt);
      if (!mounted) return;
      attempt = null;
      uncertain = false;
      note.clear();
      ref.invalidate(_ecDetailProvider(widget.entryId));
      ref.invalidate(ecProgressProvider);
      ref.read(inboxNotifierProvider.notifier).loadInbox();
    } on DioException catch (exception) {
      final status = exception.response?.statusCode;
      if (mounted)
        setState(() {
          uncertain = status == null || status >= 500;
          if (!uncertain) attempt = null;
          error = uncertain
              ? 'Unable to confirm progress. Retry with the same details.'
              : 'The update was rejected. Refresh the EC and check your access.';
        });
    } catch (_) {
      if (mounted)
        setState(() {
          uncertain = true;
          error = 'Unable to confirm progress. Retry with the same details.';
        });
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final detailState = ref.watch(_ecDetailProvider(widget.entryId));
    final title = detailState.when(
      data: (detail) => (detail['title'] ?? widget.title ?? 'EC').toString(),
      loading: () => widget.title ?? 'EC details',
      error: (_, __) => widget.title ?? 'EC details',
    );
    final createdDate = detailState.when(
      data: (detail) => formatCreatedDate(
          detail['created_at'] ?? detail['submitted_at'] ?? widget.createdAt),
      loading: () => formatCreatedDate(widget.createdAt),
      error: (_, __) => formatCreatedDate(widget.createdAt),
    );
    final ecCompleteFab = MediaQuery.viewInsetsOf(context).bottom > 0
        ? null
        : detailState.when<Widget?>(
            data: (detail) {
              final current = detail['current_progress'];
              final pct = current is Map
                  ? (current['percentage'] as num? ?? 0).toInt()
                  : 0;
              if (pct >= 100) return null;
              return _EcDetailCompleteAction(
                entryId: _cleanEntryId,
                onCompleted: () {
                  percent.text = '100';
                  note.clear();
                },
              );
            },
            loading: () => null,
            error: (_, __) => null,
          );
    return OrbitWorkspaceScaffold(
      subtitle: createdDate,
      floatingActionButton: ecCompleteFab,
      appBar: AppBar(
        title: Text(title),
        actions: [
          IconButton(
            tooltip: 'Refresh EC',
            icon: const Icon(Icons.refresh_rounded, color: Colors.white),
            onPressed: () async {
              try {
                await ref.refresh(_ecDetailProvider(widget.entryId).future);
                if (mounted) {
                  setState(() {
                    uncertain = false;
                    attempt = null;
                    error = null;
                  });
                }
              } catch (_) {
                ref.invalidate(_ecDetailProvider(widget.entryId));
              }
            },
          ),
        ],
      ),
      body: detailState.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, __) => Center(
            child: TextButton(
                onPressed: () =>
                    ref.invalidate(_ecDetailProvider(widget.entryId)),
                child: const Text('Unable to load EC. Tap to retry.'))),
        data: (detail) {
          final history = detail['progress_history'] is List
              ? detail['progress_history'] as List
              : const [];
          final current = detail['current_progress'];
          final progress = current is Map
              ? (current['percentage'] as num? ?? 0).toDouble()
              : 0.0;
          return OrbitDetailList(
            children: [
              // Header Card
              Container(
                width: double.infinity,
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
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: OrbitColors.bubbleBlue,
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: const Text(
                            'EC',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: OrbitColors.primaryNavy,
                            ),
                          ),
                        ),
                        const Spacer(),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: OrbitColors.kpiGreenBg,
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Text(
                            '${progress.toStringAsFixed(0)}% DONE',
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF15803D),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    const Divider(height: 1, color: OrbitColors.cardBorder),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        const Icon(
                          Icons.person_outline_rounded,
                          size: 16,
                          color: OrbitColors.textMuted,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Owner: ${detail['employee_name'] ?? '—'}',
                            style: const TextStyle(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w500,
                              color: OrbitColors.textSecondary,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
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
                            'EC date: ${detail['date'] ?? '—'}',
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
                ),
              ),

              // Intended Benefit Card
              if ((detail['intended_benefit'] ?? '').toString().isNotEmpty) ...[
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
                        Icons.lightbulb_outline_rounded,
                        size: 17,
                        color: OrbitColors.primaryNavy,
                      ),
                    ),
                    const SizedBox(width: 10),
                    const Expanded(
                      child: Text(
                        'Intended benefit',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          color: OrbitColors.textNavy,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color:
                        OrbitColors.scaffoldBackground.withValues(alpha: 0.5),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: OrbitColors.cardBorder),
                  ),
                  child: Text(
                    detail['intended_benefit'].toString(),
                    style: const TextStyle(
                      fontSize: 13.5,
                      color: OrbitColors.textNavy,
                      height: 1.4,
                    ),
                  ),
                ),
              ],

              // Current Progress Card
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
                      Icons.trending_up_rounded,
                      size: 17,
                      color: OrbitColors.primaryNavy,
                    ),
                  ),
                  const SizedBox(width: 10),
                  const Expanded(
                    child: Text(
                      'Current progress',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: OrbitColors.textNavy,
                      ),
                    ),
                  ),
                  Text(
                    '${progress.toStringAsFixed(0)}%',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: OrbitColors.primaryNavy,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: LinearProgressIndicator(
                  value: (progress / 100).clamp(0.0, 1.0).toDouble(),
                  minHeight: 8,
                  backgroundColor: OrbitColors.cardBorder,
                  valueColor: const AlwaysStoppedAnimation<Color>(
                      OrbitColors.primaryNavy),
                ),
              ),
              if (progress < 100) ...[
                const SizedBox(height: 14),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFF15803D),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    icon: saving
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(Icons.check_circle_outline, size: 20),
                    label: Text(
                      saving ? 'Completing…' : 'Complete EC (100%)',
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    onPressed: saving ? null : _completeEc,
                  ),
                ),
              ],
              if (detail['can_update_progress'] == true) ...[
                const SizedBox(height: 16),
                const Divider(height: 1, color: OrbitColors.cardBorder),
                const SizedBox(height: 14),
                const Text(
                  'Update progress',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: OrbitColors.textNavy,
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: percent,
                  keyboardType: TextInputType.number,
                  enabled: !saving,
                  decoration: const InputDecoration(
                    labelText: 'Progress (%)',
                    prefixIcon: Icon(Icons.percent_rounded, size: 18),
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: note,
                  maxLines: 3,
                  maxLength: 2000,
                  enabled: !saving,
                  decoration: const InputDecoration(
                    labelText: 'Progress note',
                    prefixIcon: Icon(Icons.note_alt_outlined, size: 20),
                  ),
                ),
                if (error != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    error!,
                    style: const TextStyle(
                      color: Colors.red,
                      fontSize: 12.5,
                    ),
                  ),
                ],
                const SizedBox(height: 8),
                Align(
                  alignment: Alignment.centerLeft,
                  child: FilledButton(
                    onPressed: saving ? null : save,
                    child: Text(saving ? 'Updating…' : 'Update progress'),
                  ),
                ),
              ],

              // Progress History Card
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
                      Icons.history_rounded,
                      size: 17,
                      color: OrbitColors.primaryNavy,
                    ),
                  ),
                  const SizedBox(width: 10),
                  const Expanded(
                    child: Text(
                      'Progress history',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: OrbitColors.textNavy,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              if (history.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 8),
                  child: Text(
                    'No progress updates yet.',
                    style: TextStyle(
                      fontSize: 13,
                      color: OrbitColors.textMuted,
                    ),
                  ),
                ),
              for (final entry in history)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  visualDensity: VisualDensity.compact,
                  title: Text(
                    '${entry['percentage']}% · ${entry['employee_name'] ?? ''}',
                    style: const TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w700,
                      color: OrbitColors.textNavy,
                    ),
                  ),
                  subtitle: Text(
                    '${entry['note'] ?? ''}\n${entry['at'] ?? ''}',
                    style: const TextStyle(
                      fontSize: 12.5,
                      color: OrbitColors.textSecondary,
                    ),
                  ),
                ),

              // Discussion Card
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
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
                            color: OrbitColors.textNavy,
                          ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              InboxDiscussion(
                module: 'workhub_ec',
                subjectKey: widget.entryId,
              ),
            ],
          );
        },
      ),
    );
  }
}

class _EcDetailCompleteAction extends ConsumerStatefulWidget {
  final String entryId;
  final VoidCallback? onCompleted;

  const _EcDetailCompleteAction({
    required this.entryId,
    this.onCompleted,
  });

  @override
  ConsumerState<_EcDetailCompleteAction> createState() =>
      _EcDetailCompleteActionState();
}

class _EcDetailCompleteActionState
    extends ConsumerState<_EcDetailCompleteAction> {
  bool busy = false;
  bool uncertain = false;
  String? submissionKey;

  Future<void> perform() async {
    if (busy || uncertain) return;
    submissionKey ??= const Uuid().v4();
    setState(() => busy = true);
    try {
      final cleanId = widget.entryId.replaceFirst(RegExp(r'^ec:'), '');
      final response = await ref.read(apiClientProvider).dio.post(
        '/inbox/api/workhub-tasks/ec/$cleanId/progress',
        data: {
          'percentage': 100,
          'note': 'Status diubah menjadi Selesai.',
          'submission_key': submissionKey,
        },
      );
      final code = response.statusCode ?? 0;
      if (!mounted) return;
      if (code >= 200 && code < 300) {
        submissionKey = null;
        widget.onCompleted?.call();
        ref.invalidate(_ecDetailProvider(widget.entryId));
        ref.invalidate(ecProgressProvider);
        ref.read(inboxNotifierProvider.notifier).loadInbox();
        setState(() => busy = false);
      } else {
        setState(() {
          busy = false;
          uncertain = true;
        });
      }
    } catch (_) {
      if (!mounted) return;
      setState(() {
        busy = false;
        uncertain = true;
      });
    }
  }

  Future<void> refresh() async {
    setState(() => busy = true);
    try {
      final updated =
          await ref.refresh(_ecDetailProvider(widget.entryId).future);
      if (updated['title'] == null && updated['current_progress'] == null) {
        throw const FormatException('EC state is unavailable');
      }
      if (mounted) {
        setState(() => uncertain = false);
      }
    } catch (_) {
      // Keep the action disabled until EC state can be verified.
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (uncertain) {
      return Material(
        elevation: 6,
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 10, 8, 10),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(
                width: 190,
                child: Text(
                  'The EC update could not be confirmed. Refresh before retrying.',
                  style: TextStyle(fontSize: 12, color: OrbitColors.textNavy),
                ),
              ),
              TextButton(
                onPressed: busy ? null : refresh,
                child: const Text('Refresh'),
              ),
            ],
          ),
        ),
      );
    }
    return Container(
      decoration: const BoxDecoration(
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: Color(0x3306244D),
            blurRadius: 16,
            offset: Offset(0, 6),
          ),
        ],
      ),
      child: FloatingActionButton(
        heroTag: 'ec-complete-${widget.entryId}',
        tooltip: 'Complete EC',
        backgroundColor: OrbitColors.primaryNavy,
        foregroundColor: Colors.white,
        elevation: 0,
        highlightElevation: 0,
        onPressed: busy ? null : perform,
        child: busy
            ? const SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(
                  strokeWidth: 2.5,
                  color: Colors.white,
                ),
              )
            : const Icon(
                Icons.check_rounded,
                size: 28,
              ),
      ),
    );
  }
}
