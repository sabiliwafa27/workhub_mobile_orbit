import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dio/dio.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
import 'package:uuid/uuid.dart';
import 'package:intl/intl.dart';
import '../../auth/providers/auth_provider.dart';

DateTime standardTaskDueDate(DateTime now) =>
    DateTime(now.year, now.month, now.day + 2);

class EcCreationPolicy {
  final bool canEdit;
  final bool offDayAvailable;
  final bool isOffDay;
  const EcCreationPolicy(
      {required this.canEdit,
      this.offDayAvailable = false,
      this.isOffDay = false});
}

final ecCreationPolicyProvider =
    FutureProvider.autoDispose<EcCreationPolicy>((ref) async {
  final response =
      await ref.watch(apiClientProvider).dio.get('/ec/today/current');
  final data = response.data;
  if (data is! Map || data['can_edit'] is! bool)
    throw const FormatException('Unexpected EC policy response');
  return EcCreationPolicy(
      canEdit: data['can_edit'] as bool,
      offDayAvailable: data['off_day_available'] == true,
      isOffDay: data['is_off_day'] == true);
});

class CreateWorkItemScreen extends ConsumerStatefulWidget {
  final bool isEc;
  final int? projectId;
  const CreateWorkItemScreen({super.key, this.isEc = false, this.projectId});

  @override
  ConsumerState<CreateWorkItemScreen> createState() =>
      _CreateWorkItemScreenState();
}

class _CreateWorkItemScreenState extends ConsumerState<CreateWorkItemScreen> {
  final title = TextEditingController();
  final description = TextEditingController();
  DateTime dueDate = standardTaskDueDate(DateTime.now());
  DateTime? startDate;
  DateTime? repeatUntil;
  String? repeatFrequency;
  int? repeatDay;
  int? repeatWeekday;
  int? repeatOrdinal;
  int? repeatMonth;
  final repeatInterval = TextEditingController(text: '1');
  bool saving = false;
  bool quickMode = true;
  String? standardDescription;
  String? standardTitle;
  int? standardAssignee;
  List<XFile>? standardAttachments;
  String? quickMentionQuery;
  int quickMentionStart = 0;
  int quickMentionEnd = 0;
  bool taskSubmissionUncertain = false;
  bool ecSubmissionUncertain = false;
  String? uncertainEcSignature;
  bool generating = false;
  bool changingOffDay = false;
  bool taskFormReady = false;
  bool taskCanCreate = false;
  String? error;
  String? generationMessage;
  int? assigneeId;
  String creationKey = const Uuid().v4();
  String? submittedEcTitle;
  String? submittedEcMentions;
  final extraIdeas = <TextEditingController>[];
  final extraIdeaKeys = <TextEditingController, String>{};
  final submittedIdeas = <TextEditingController, String>{};
  final mentions = <TextEditingController, List<Map<String, dynamic>>>{};
  final previousIdeaText = <TextEditingController, String>{};
  TextEditingController? mentionQueryController;
  int mentionQueryStart = 0;
  int mentionQueryEnd = 0;
  List<dynamic> mentionSuggestions = [];
  Timer? mentionSearchDebounce;
  int mentionSearchGeneration = 0;
  late Future<Map<String, dynamic>> bootstrap;
  int? projectId;
  String priority = 'normal';
  int? complexityId;
  int? currentEmployeeId;
  bool canCustomizePoints = false;
  int? actingForManagerId;
  Set<String> availablePriorities = {};
  bool isPrivate = false;
  final participants = <int>{};
  final attachments = <XFile>[];
  bool get ecWritable {
    final policy = ref.watch(ecCreationPolicyProvider).valueOrNull;
    return policy != null &&
        policy.canEdit &&
        !policy.isOffDay &&
        !saving &&
        !changingOffDay;
  }

  Future<void> addPhotos() async {
    try {
      final selected = await ImagePicker().pickMultiImage();
      if (!mounted || selected.isEmpty) return;
      final available = 10 - attachments.length;
      final accepted = selected.take(available).toList();
      if (accepted.isEmpty) {
        setState(() => error = 'You can upload up to 10 attachments.');
        return;
      }
      for (final image in accepted) {
        if (await image.length() > 10240 * 1024) {
          if (mounted)
            setState(() => error = 'Each attachment must be 10 MB or smaller.');
          return;
        }
      }
      if (mounted)
        setState(() {
          attachments.addAll(accepted);
          error = accepted.length < selected.length
              ? 'Only the first $available attachments were added; the limit is 10.'
              : null;
        });
    } catch (_) {
      if (mounted) setState(() => error = 'Unable to select photos.');
    }
  }

  Future<void> selectQuickPhoto(ImageSource source) async {
    try {
      final photo = await ImagePicker().pickImage(source: source);
      if (!mounted || photo == null) return;
      if (await photo.length() > 10240 * 1024) {
        if (mounted)
          setState(() => error = 'Each attachment must be 10 MB or smaller.');
        return;
      }
      if (mounted)
        setState(() {
          attachments.clear();
          attachments.add(photo);
          error = null;
        });
    } catch (_) {
      if (mounted) setState(() => error = 'Unable to select a photo.');
    }
  }

  Future<void> addFiles() async {
    try {
      final result = await FilePicker.platform.pickFiles(allowMultiple: true);
      if (!mounted || result == null || result.files.isEmpty) return;
      final available = 10 - attachments.length;
      final accepted = result.files.take(available).toList();
      if (accepted.isEmpty) {
        setState(() => error = 'You can upload up to 10 attachments.');
        return;
      }
      if (accepted.any((file) => file.size > 10240 * 1024)) {
        setState(() => error = 'Each attachment must be 10 MB or smaller.');
        return;
      }
      if (accepted.any((file) => file.path == null)) {
        setState(() => error = 'A selected file could not be opened.');
        return;
      }
      setState(() {
        attachments.addAll(result.xFiles.take(available));
        error = accepted.length < result.files.length
            ? 'Only the first $available attachments were added; the limit is 10.'
            : null;
      });
    } catch (_) {
      if (mounted) setState(() => error = 'Unable to select files.');
    }
  }

  Future<int?> pickEmployee(List<dynamic> options, String heading) =>
      showModalBottomSheet<int>(
        context: context,
        isScrollControlled: true,
        builder: (_) =>
            _EmployeeSearchSheet(employees: options, heading: heading),
      );

  Future<void> removeParticipant(int employeeId, String name) async {
    if (saving) return;
    final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
              title: const Text('Remove participant?'),
              content: Text(
                  'Remove $name from the participant list? This takes effect when you save the task.'),
              actions: [
                TextButton(
                    onPressed: () => Navigator.pop(context, false),
                    child: const Text('Cancel')),
                FilledButton(
                    onPressed: () => Navigator.pop(context, true),
                    child: const Text('Remove Participant')),
              ],
            ));
    if (confirmed == true && mounted)
      setState(() => participants.remove(employeeId));
  }

  Future<void> generateDraft() async {
    if (saving || generating || !taskFormReady || !taskCanCreate) return;
    final originalTitle = title.text;
    final originalDescription = description.text;
    final brief = originalDescription.trim();
    if (brief.runes.length < 3) {
      setState(
          () => generationMessage = 'Enter a few words about the task first.');
      return;
    }
    setState(() {
      generating = true;
      generationMessage = null;
    });
    try {
      final response = await ref.read(apiClientProvider).dio.post(
          '/tasks/generate-draft',
          data: {'description': brief},
          options: Options(receiveTimeout: const Duration(seconds: 60)));
      if (!mounted) return;
      if (description.text != originalDescription ||
          title.text != originalTitle) {
        setState(() => generationMessage =
            'The form changed while Jarvis was working. Your edits were kept.');
        return;
      }
      final data = response.data;
      final generatedTitle = data is Map ? data['title'] : null;
      final generatedDescription = data is Map ? data['description'] : null;
      if (generatedTitle is! String ||
          generatedTitle.trim().isEmpty ||
          generatedTitle.runes.length > 255 ||
          generatedDescription is! String ||
          generatedDescription.trim().isEmpty ||
          generatedDescription.runes.length > 10000) {
        setState(() => generationMessage =
            'Jarvis returned an incomplete task. Please try again.');
        return;
      }
      setState(() {
        title.text = generatedTitle;
        description.text = generatedDescription;
        generationMessage =
            'Review the title and description before creating the task.';
      });
    } catch (_) {
      if (mounted)
        setState(() => generationMessage =
            'Jarvis could not prepare the task. Please try again.');
    } finally {
      if (mounted) setState(() => generating = false);
    }
  }

  Future<void> setOffDay(bool value) async {
    if (changingOffDay || saving) return;
    setState(() => changingOffDay = true);
    try {
      await ref
          .read(apiClientProvider)
          .dio
          .post('/ec/off-day', data: {'is_off_day': value});
      if (!mounted) return;
      final updated = await ref.refresh(ecCreationPolicyProvider.future);
      if (updated.isOffDay != value)
        throw const FormatException('Off-day setting did not update');
    } catch (_) {
      if (mounted) {
        ref.invalidate(ecCreationPolicyProvider);
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text(
                'Could not confirm the off-day setting. Refresh and check it before retrying.')));
      }
    } finally {
      if (mounted) setState(() => changingOffDay = false);
    }
  }

  @override
  void initState() {
    super.initState();
    projectId = widget.projectId;
    bootstrap = widget.isEc ? Future.value({}) : loadBootstrap();
  }

  Future<Map<String, dynamic>> loadBootstrap() async {
    final response =
        await ref.read(apiClientProvider).dio.get('/tasks/form-bootstrap');
    final data = response.data;
    if (data is! Map ||
        data['bootstrap'] is! Map ||
        data['bootstrap']['employees'] is! List) {
      throw const FormatException('Unexpected task form response');
    }
    final result = Map<String, dynamic>.from(data['bootstrap'] as Map);
    final permissions = result['can'];
    if (mounted) {
      setState(() {
        taskFormReady = true;
        taskCanCreate = permissions is Map && permissions['create'] == true;
      });
    }
    currentEmployeeId = (result['currentEmployeeId'] as num?)?.toInt();
    canCustomizePoints = result['canCustomizePoints'] == true;
    final actingOptions = result['actingForOptions'];
    if (actingOptions is List && actingOptions.isNotEmpty) {
      final first = actingOptions.first;
      actingForManagerId = (result['actingForManagerId'] as num?)?.toInt() ??
          (first is Map ? (first['employee_id'] as num?)?.toInt() : null);
    }
    final priorities = result['priorities'];
    if (priorities is List) {
      availablePriorities = priorities
          .whereType<Map>()
          .map((option) => (option['priority_code'] ?? '').toString())
          .where((code) => code.isNotEmpty)
          .toSet();
    }
    final complexities = result['complexities'];
    if (complexities is List && complexityId == null) {
      for (final option in complexities.whereType<Map>()) {
        if (option['complexity_value'] == 2) {
          complexityId = (option['task_complexity_id'] as num?)?.toInt();
          break;
        }
      }
    }
    return result;
  }

  Widget taskBootstrapError(Object? exception) {
    if (exception is DioException && exception.response?.statusCode == 403) {
      return const Text('Task creation is unavailable for your account.');
    }
    return TextButton(
        onPressed: () => setState(() => bootstrap = loadBootstrap()),
        child: const Text('Unable to load task form. Tap to retry.'));
  }

  List<Map<String, dynamic>> validMentions(TextEditingController controller) {
    final text = controller.text;
    final chars = text.runes.toList();
    final leading = text.runes.length - text.trimLeft().runes.length;
    return (mentions[controller] ?? [])
        .where((mention) {
          final start = mention['start'] as int;
          final length = mention['length'] as int;
          return start >= leading &&
              start + length <= chars.length &&
              String.fromCharCodes(chars.sublist(start, start + length)) ==
                  mention['label'];
        })
        .map((mention) =>
            {...mention, 'start': (mention['start'] as int) - leading})
        .toList();
  }

  void updateMentions(TextEditingController controller, String next) {
    final before = (previousIdeaText[controller] ?? '').runes.toList();
    final after = next.runes.toList();
    var start = 0;
    var suffix = 0;
    while (start < before.length &&
        start < after.length &&
        before[start] == after[start]) {
      start++;
    }
    while (suffix < before.length - start &&
        suffix < after.length - start &&
        before[before.length - 1 - suffix] ==
            after[after.length - 1 - suffix]) {
      suffix++;
    }
    final end = before.length - suffix;
    final delta = after.length - before.length;
    mentions[controller] = (mentions[controller] ?? []).where((mention) {
      final position = mention['start'] as int;
      return position + (mention['length'] as int) <= start || position >= end;
    }).map((mention) {
      final position = mention['start'] as int;
      return {
        ...mention,
        'start': position >= end ? position + delta : position
      };
    }).toList();
    previousIdeaText[controller] = next;
  }

  void changeIdea(TextEditingController controller, String next) {
    updateMentions(controller, next);
    final cursor = controller.selection.baseOffset;
    final match = cursor >= 0 && cursor <= next.length
        ? RegExp(r'@([^@\n]{0,120})$').firstMatch(next.substring(0, cursor))
        : null;
    final alreadySelected = match != null &&
        (mentions[controller] ?? []).any((mention) =>
            mention['start'] == next.substring(0, match.start).runes.length);
    mentionSearchDebounce?.cancel();
    final generation = ++mentionSearchGeneration;
    setState(() {
      mentionQueryController =
          match != null && !alreadySelected ? controller : null;
      mentionSuggestions = [];
      if (mentionQueryController != null) {
        mentionQueryStart = match!.start;
        mentionQueryEnd = cursor;
      }
    });
    if (mentionQueryController == null) return;
    final query = match!.group(1)!;
    mentionSearchDebounce = Timer(const Duration(milliseconds: 200), () async {
      try {
        final response = await ref
            .read(apiClientProvider)
            .dio
            .get('/ec/mention-employees', queryParameters: {'search': query});
        final data = response.data;
        if (mounted &&
            generation == mentionSearchGeneration &&
            data is Map &&
            data['data'] is List) {
          setState(() => mentionSuggestions = data['data'] as List);
        }
      } catch (_) {
        if (mounted && generation == mentionSearchGeneration)
          setState(() => mentionSuggestions = []);
      }
    });
  }

  void selectInlineMention(TextEditingController controller, Map employee) {
    if (mentionQueryController != controller) return;
    final text = controller.text;
    final before = text.substring(0, mentionQueryStart);
    final after = text.substring(mentionQueryEnd);
    final label = '@${employee['full_name']}';
    controller.value = TextEditingValue(
        text: '$before$label $after',
        selection:
            TextSelection.collapsed(offset: before.length + label.length + 1));
    updateMentions(controller, controller.text);
    mentions.putIfAbsent(controller, () => []).add({
      'employee_id': employee['employee_id'],
      'label': label,
      'start': before.runes.length,
      'length': label.runes.length
    });
    mentionSearchDebounce?.cancel();
    mentionSearchGeneration++;
    setState(() {
      mentionQueryController = null;
      mentionSuggestions = [];
    });
  }

  Widget inlineMentionSuggestions(TextEditingController controller) {
    if (mentionQueryController != controller || mentionSuggestions.isEmpty)
      return const SizedBox.shrink();
    return Card(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
      for (final employee in mentionSuggestions.whereType<Map>())
        ListTile(
            dense: true,
            title: Text((employee['full_name'] ?? '').toString()),
            subtitle: employee['department'] == null
                ? null
                : Text(employee['department'].toString()),
            onTap: () => selectInlineMention(controller, employee)),
    ]));
  }

  Future<void> addMention(TextEditingController controller,
      {int? replaceAt}) async {
    try {
      mentionSearchDebounce?.cancel();
      mentionSearchGeneration++;
      setState(() {
        mentionQueryController = null;
        mentionSuggestions = [];
      });
      final selected = await showModalBottomSheet<Map<String, dynamic>>(
        context: context,
        isScrollControlled: true,
        builder: (context) => const _EcMentionPicker(),
      );
      if (selected == null || !mounted) return;
      final text = controller.text;
      final selection = controller.selection;
      final canReplaceAt = replaceAt != null &&
          replaceAt >= 0 &&
          replaceAt < text.length &&
          text[replaceAt] == '@';
      final selectionStart = canReplaceAt
          ? replaceAt
          : (selection.isValid
              ? selection.start.clamp(0, text.length)
              : text.length);
      final selectionEnd = canReplaceAt
          ? selectionStart + 1
          : (selection.isValid
              ? selection.end.clamp(selectionStart, text.length)
              : text.length);
      final before = text.substring(0, selectionStart);
      final after = text.substring(selectionEnd);
      final prefix =
          before.isEmpty || RegExp(r'\s$').hasMatch(before) ? '' : ' ';
      final label = '@${selected['full_name']}';
      final start = (before + prefix).runes.length;
      final replacement = '$prefix$label ';
      controller.value = TextEditingValue(
        text: '$before$replacement$after',
        selection:
            TextSelection.collapsed(offset: before.length + replacement.length),
      );
      updateMentions(controller, controller.text);
      mentions.putIfAbsent(controller, () => []).add({
        'employee_id': selected['employee_id'],
        'label': label,
        'start': start,
        'length': label.runes.length
      });
      setState(() {});
    } catch (_) {
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Unable to load colleagues.')));
    }
  }

  @override
  void dispose() {
    mentionSearchDebounce?.cancel();
    title.dispose();
    description.dispose();
    repeatInterval.dispose();
    for (final controller in extraIdeas) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> submit() async {
    if (saving || generating || (!widget.isEc && taskSubmissionUncertain))
      return;
    if (widget.isEc) {
      final policy = ref.read(ecCreationPolicyProvider).valueOrNull;
      if (policy == null ||
          !policy.canEdit ||
          policy.isOffDay ||
          changingOffDay) {
        setState(() => error =
            'EC creation is unavailable right now. Refresh and check today’s status.');
        return;
      }
    }
    if (!widget.isEc && (!taskFormReady || !taskCanCreate)) {
      setState(() => error = 'Task creation is unavailable for your account.');
      return;
    }
    if (title.text.trim().isEmpty ||
        (widget.isEc && extraIdeas.any((idea) => idea.text.trim().isEmpty)) ||
        (!widget.isEc && assigneeId == null)) {
      setState(() => error = title.text.trim().isEmpty ||
              widget.isEc && extraIdeas.any((idea) => idea.text.trim().isEmpty)
          ? (widget.isEc
              ? 'Enter a title for each idea.'
              : 'Enter a task title.')
          : 'Select an assignee.');
      return;
    }
    if (!widget.isEc && description.text.trim().isEmpty) {
      setState(() => error = 'Enter a task description.');
      return;
    }
    final interval = int.tryParse(repeatInterval.text);
    final intervalMaximum = repeatFrequency == 'weekly'
        ? 52
        : (repeatFrequency == 'monthly' ||
                repeatFrequency == 'monthly_nth_weekday')
            ? 12
            : 32767;
    if (!widget.isEc &&
        ((startDate != null && startDate!.isAfter(dueDate)) ||
            (repeatFrequency != null &&
                (interval == null ||
                    interval < 1 ||
                    interval > intervalMaximum)) ||
            (repeatFrequency != null &&
                repeatUntil != null &&
                repeatUntil!.isBefore(
                    DateTime(dueDate.year, dueDate.month, dueDate.day))))) {
      setState(
          () => error = 'Check the start date, due date and repeat settings.');
      return;
    }
    if (!widget.isEc &&
        canCustomizePoints &&
        assigneeId != currentEmployeeId &&
        complexityId == null) {
      setState(() => error = 'Select task complexity.');
      return;
    }
    if (!widget.isEc &&
        canCustomizePoints &&
        assigneeId != currentEmployeeId &&
        !availablePriorities.contains(priority)) {
      setState(() => error = 'Select a task priority.');
      return;
    }
    setState(() {
      saving = true;
      error = null;
    });
    final currentTitle = title.text.trim();
    final currentMentions =
        widget.isEc ? jsonEncode(validMentions(title)) : null;
    final ecSignature = widget.isEc
        ? jsonEncode([
            {'title': currentTitle, 'mentions': validMentions(title)},
            for (final idea in extraIdeas)
              {'title': idea.text.trim(), 'mentions': validMentions(idea)},
          ])
        : null;
    if (widget.isEc &&
        ecSubmissionUncertain &&
        ecSignature != uncertainEcSignature) {
      setState(() {
        saving = false;
        error =
            'The previous submission could not be confirmed. Restore the same ideas to retry, or check today’s EC before starting again.';
      });
      return;
    }
    if (widget.isEc &&
        submittedEcTitle != null &&
        (submittedEcTitle != currentTitle ||
            submittedEcMentions != currentMentions)) {
      creationKey = const Uuid().v4();
    }
    if (widget.isEc) {
      submittedEcTitle = currentTitle;
      submittedEcMentions = currentMentions;
      for (final idea in extraIdeas) {
        final text = idea.text.trim();
        final signature =
            jsonEncode({'title': text, 'mentions': validMentions(idea)});
        if (submittedIdeas[idea] != signature)
          extraIdeaKeys[idea] = const Uuid().v4();
        submittedIdeas[idea] = signature;
      }
    }
    try {
      final payload = widget.isEc
          ? (extraIdeas.isEmpty
              ? {
                  'title': currentTitle,
                  'creation_key': creationKey,
                  'mentions': validMentions(title)
                }
              : {
                  'ideas': [
                    {
                      'title': currentTitle,
                      'creation_key': creationKey,
                      'mentions': validMentions(title)
                    },
                    for (final idea in extraIdeas)
                      {
                        'title': idea.text.trim(),
                        'creation_key': extraIdeaKeys[idea],
                        'mentions': validMentions(idea)
                      },
                  ]
                })
          : {
              'title': title.text.trim(),
              'description': description.text.trim(),
              'due_date': dueDate.toIso8601String().split('T').first,
              if (startDate != null)
                'start_date': startDate!.toIso8601String().split('T').first,
              'is_recurring': repeatFrequency != null,
              if (repeatFrequency != null) ...{
                'recurrence_frequency': repeatFrequency,
                'recurrence_interval': interval,
                if (repeatUntil != null)
                  'recurrence_until':
                      repeatUntil!.toIso8601String().split('T').first,
                if (repeatFrequency == 'monthly' || repeatFrequency == 'yearly')
                  'recurrence_day_of_month': repeatDay ?? dueDate.day,
                if (repeatFrequency == 'yearly')
                  'recurrence_month': repeatMonth ?? dueDate.month,
                if (repeatFrequency == 'monthly_nth_weekday')
                  'recurrence_weekday': repeatWeekday ?? dueDate.weekday % 7,
                if (repeatFrequency == 'monthly_nth_weekday')
                  'recurrence_weekday_ordinal': repeatOrdinal ??
                      (dueDate.day + 7 >
                              DateTime(dueDate.year, dueDate.month + 1, 0).day
                          ? -1
                          : ((dueDate.day - 1) ~/ 7) + 1),
              },
              'assignee_scope': 'specific',
              'employee_ids': [assigneeId],
              'participant_ids': participants.toList(),
              'is_private': isPrivate,
              'priority': canCustomizePoints && assigneeId != currentEmployeeId
                  ? priority
                  : 'normal',
              if (actingForManagerId != null)
                'on_behalf_of_employee_id': actingForManagerId,
              if (canCustomizePoints &&
                  assigneeId != currentEmployeeId &&
                  complexityId != null)
                'complexity_id': complexityId,
              if (projectId != null) 'project_id': projectId
            };
      dynamic requestData = payload;
      if (!widget.isEc && attachments.isNotEmpty) {
        final form = FormData();
        for (final entry in payload.entries) {
          final value = entry.value;
          if (value == null) continue;
          if (value is List) {
            for (final item in value) {
              if (item != null)
                form.fields.add(MapEntry('${entry.key}[]', item.toString()));
            }
          } else {
            form.fields.add(MapEntry(entry.key,
                value is bool ? (value ? '1' : '0') : value.toString()));
          }
        }
        for (final file in attachments) {
          form.files.add(MapEntry('attachments[]',
              await MultipartFile.fromFile(file.path, filename: file.name)));
        }
        requestData = form;
      }
      final response = await ref.read(apiClientProvider).dio.post(
            widget.isEc
                ? (extraIdeas.isEmpty ? '/ec/entries' : '/ec/entries/batch')
                : '/tasks',
            data: requestData,
            options: requestData is FormData
                ? Options(contentType: 'multipart/form-data')
                : null,
          );
      if (!widget.isEc &&
          (response.data is! Map || response.data['task'] is! Map)) {
        if (mounted)
          setState(() {
            taskSubmissionUncertain = true;
            error =
                'The result could not be confirmed. Check My Tasks before creating this task again.';
          });
        return;
      }
      if (mounted) Navigator.pop(context, true);
    } on DioException catch (exception) {
      final data = exception.response?.data;
      String message =
          'Unable to create this item. Check your access and try again.';
      final uncertain = !widget.isEc &&
          (exception.response == null ||
              (exception.response!.statusCode ?? 500) >= 500);
      final ecUncertain = widget.isEc &&
          (exception.response == null ||
              (exception.response!.statusCode ?? 500) >= 500);
      if (data is Map) {
        final errors = data['errors'];
        if (errors is Map && errors.isNotEmpty) {
          final first = errors.values.first;
          if (first is List && first.isNotEmpty)
            message = first.first.toString();
        } else if (data['message'] is String) {
          message = data['message'] as String;
        }
      }
      if (mounted)
        setState(() {
          taskSubmissionUncertain = uncertain;
          ecSubmissionUncertain = ecUncertain;
          uncertainEcSignature = ecUncertain ? ecSignature : null;
          error = uncertain
              ? 'The result could not be confirmed. Check My Tasks before creating this task again.'
              : ecUncertain
                  ? 'The result could not be confirmed. Retry the same ideas or check today’s EC.'
                  : message;
        });
    } catch (_) {
      if (mounted)
        setState(() => error =
            'Unable to create this item. Check your access and try again.');
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  Future<void> submitQuickTask() async {
    if (saving || taskSubmissionUncertain || !taskCanCreate) return;
    final target = assigneeId ?? currentEmployeeId;
    if (description.text.trim().isEmpty || target == null) {
      setState(() => error =
          target == null ? 'Select an assignee.' : 'Enter a task description.');
      return;
    }
    setState(() {
      saving = true;
      error = null;
    });
    try {
      final form = FormData.fromMap({
        'quick_task': '1',
        'description': description.text.trim(),
        'assignee_scope': 'specific',
        'employee_ids[]': [target.toString()],
        if (projectId != null) 'project_id': projectId.toString(),
      });
      if (attachments.isNotEmpty) {
        final photo = attachments.first;
        form.files.add(MapEntry('attachments[]',
            await MultipartFile.fromFile(photo.path, filename: photo.name)));
      }
      final response = await ref.read(apiClientProvider).dio.post('/tasks',
          data: form, options: Options(contentType: 'multipart/form-data'));
      if (response.data is! Map || response.data['task'] is! Map) {
        if (mounted)
          setState(() {
            taskSubmissionUncertain = true;
            error =
                'The result could not be confirmed. Check My Tasks before creating this task again.';
          });
        return;
      }
      if (mounted) Navigator.pop(context, true);
    } on DioException catch (exception) {
      final uncertain = exception.response == null ||
          (exception.response!.statusCode ?? 500) >= 500;
      if (mounted)
        setState(() {
          taskSubmissionUncertain = uncertain;
          error = uncertain
              ? 'The result could not be confirmed. Check My Tasks before creating this task again.'
              : (exception.response?.data is Map
                  ? (exception.response!.data['message'] ??
                          'Unable to create task.')
                      .toString()
                  : 'Unable to create task.');
        });
    } catch (_) {
      if (mounted)
        setState(() => error = 'Unable to prepare the selected photo.');
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  Widget buildQuickTaskForm() => FutureBuilder<Map<String, dynamic>>(
        future: bootstrap,
        builder: (context, snapshot) {
          if (snapshot.hasError) return taskBootstrapError(snapshot.error);
          if (!snapshot.hasData)
            return const Center(child: CircularProgressIndicator());
          final employees = snapshot.data!['employees'] as List;
          if (!taskCanCreate)
            return const Padding(
                padding: EdgeInsets.all(16),
                child: Text('Task creation is unavailable for your account.'));
          final selected = assigneeId ?? currentEmployeeId;
          final names = employees.whereType<Map>().where((employee) =>
              (employee['employee_id'] as num?)?.toInt() == selected);
          final currentEmployee = snapshot.data!['currentEmployee'];
          final currentName = currentEmployee is Map
              ? (currentEmployee['full_name'] ?? '').toString()
              : '';
          final projects = snapshot.data!['projects'] is List
              ? snapshot.data!['projects'] as List
              : const [];
          final selectedProject = projects
              .whereType<Map>()
              .where((project) =>
                  (project['project_id'] as num?)?.toInt() == projectId)
              .firstOrNull;
          return ListView(padding: const EdgeInsets.all(16), children: [
            Wrap(
                alignment: WrapAlignment.spaceBetween,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Text('Quick Task',
                      style: Theme.of(context).textTheme.titleLarge),
                  TextButton(
                      onPressed: saving || taskSubmissionUncertain
                          ? null
                          : () => setState(() {
                                quickMode = false;
                                description.text = standardDescription ?? '';
                                title.text = standardTitle ?? '';
                                assigneeId = standardAssignee;
                                attachments
                                  ..clear()
                                  ..addAll(standardAttachments ?? []);
                                quickMentionQuery = null;
                                error = null;
                              }),
                      child: const Text('Standard task'))
                ]),
            if (attachments.isEmpty)
              Wrap(spacing: 8, children: [
                TextButton.icon(
                    onPressed: saving
                        ? null
                        : () => selectQuickPhoto(ImageSource.camera),
                    icon: const Icon(Icons.camera_alt_outlined),
                    label: const Text('Take photo')),
                TextButton.icon(
                    onPressed: saving
                        ? null
                        : () => selectQuickPhoto(ImageSource.gallery),
                    icon: const Icon(Icons.add_photo_alternate_outlined),
                    label: const Text('Choose photo')),
              ])
            else
              Card(
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                    ClipRRect(
                        borderRadius: const BorderRadius.vertical(
                            top: Radius.circular(12)),
                        child: Image.file(
                          File(attachments.first.path),
                          height: 160,
                          width: double.infinity,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => const SizedBox(
                              height: 100,
                              child: Center(
                                  child: Icon(
                                      Icons.image_not_supported_outlined))),
                        )),
                    ListTile(
                        dense: true,
                        title: Text(attachments.first.name,
                            maxLines: 1, overflow: TextOverflow.ellipsis),
                        trailing: IconButton(
                            tooltip: 'Remove photo',
                            onPressed: saving
                                ? null
                                : () => setState(attachments.clear),
                            icon: const Icon(Icons.close))),
                  ])),
            TextField(
                controller: description,
                maxLines: 6,
                maxLength: 10000,
                enabled: !saving,
                onChanged: (text) {
                  final cursor = description.selection.baseOffset;
                  final match = cursor >= 0 && cursor <= text.length
                      ? RegExp(r'@([^@\n]{0,24})$')
                          .firstMatch(text.substring(0, cursor))
                      : null;
                  setState(() {
                    quickMentionQuery = match?.group(1)?.toLowerCase();
                    if (match != null) {
                      quickMentionStart = match.start;
                      quickMentionEnd = cursor;
                    }
                  });
                },
                decoration: const InputDecoration(
                    labelText: 'Task description',
                    hintText:
                        'Describe your task. Type @ to assign a colleague.')),
            if (quickMentionQuery != null)
              Card(
                  child: Column(mainAxisSize: MainAxisSize.min, children: [
                for (final employee in employees
                    .whereType<Map>()
                    .where((employee) => (employee['full_name'] ?? '')
                        .toString()
                        .toLowerCase()
                        .contains(quickMentionQuery!))
                    .take(5))
                  ListTile(
                      dense: true,
                      title: Text(employee['full_name'].toString()),
                      onTap: () {
                        final before =
                            description.text.substring(0, quickMentionStart);
                        final after =
                            description.text.substring(quickMentionEnd);
                        final mention = '@${employee['full_name']} ';
                        description.value = TextEditingValue(
                            text: '$before$mention$after',
                            selection: TextSelection.collapsed(
                                offset: before.length + mention.length));
                        setState(() {
                          assigneeId = (employee['employee_id'] as num).toInt();
                          quickMentionQuery = null;
                        });
                      }),
              ])),
            ListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Assigned To'),
                subtitle: Text(names.isNotEmpty
                    ? names.first['full_name'].toString()
                    : selected != null && selected == currentEmployeeId
                        ? (currentName.isEmpty ? 'You' : currentName)
                        : 'Select an employee…'),
                onTap: saving
                    ? null
                    : () async {
                        final id = await pickEmployee(employees, 'Assign to');
                        if (id != null && mounted)
                          setState(() => assigneeId = id);
                      }),
            if (projectId != null)
              Text(selectedProject == null
                  ? 'This task will be added to the selected project.'
                  : 'Project: ${selectedProject['name']}'),
            if (error != null)
              Text(error!, style: const TextStyle(color: Colors.red)),
            FilledButton(
                onPressed: saving || taskSubmissionUncertain || !taskCanCreate
                    ? null
                    : submitQuickTask,
                child: Text(saving ? 'Saving…' : 'Create task')),
          ]);
        },
      );

  List<Widget> buildSchedulingControls(BuildContext context) => [
        ListTile(
          title: const Text('Start date'),
          subtitle:
              Text(startDate?.toIso8601String().split('T').first ?? 'Not set'),
          trailing: startDate == null
              ? null
              : IconButton(
                  icon: const Icon(Icons.clear),
                  onPressed:
                      saving ? null : () => setState(() => startDate = null)),
          onTap: saving
              ? null
              : () async {
                  final picked = await showDatePicker(
                      context: context,
                      initialDate: startDate ?? dueDate,
                      firstDate: DateTime(2020),
                      lastDate: DateTime(2100));
                  if (picked != null && mounted)
                    setState(() => startDate = picked);
                },
        ),
        DropdownButtonFormField<String>(
          key: ValueKey('repeat-${repeatFrequency ?? 'none'}'),
          value: repeatFrequency ?? 'none',
          isExpanded: true,
          decoration: const InputDecoration(labelText: 'Repeat'),
          items: const [
            DropdownMenuItem(value: 'none', child: Text('Does not repeat')),
            DropdownMenuItem(value: 'daily', child: Text('Daily')),
            DropdownMenuItem(value: 'weekdays', child: Text('Weekdays')),
            DropdownMenuItem(value: 'weekly', child: Text('Weekly')),
            DropdownMenuItem(value: 'biweekly', child: Text('Every two weeks')),
            DropdownMenuItem(
                value: 'monthly', child: Text('Monthly on this date')),
            DropdownMenuItem(
                value: 'monthly_nth_weekday',
                child: Text('Monthly on this weekday')),
            DropdownMenuItem(value: 'yearly', child: Text('Yearly')),
          ],
          onChanged: saving
              ? null
              : (value) => setState(() {
                    repeatFrequency = value == 'none' ? null : value;
                    final interval = int.tryParse(repeatInterval.text) ?? 1;
                    repeatInterval.text =
                        (interval < 1 ? 1 : interval).toString();
                    if (repeatFrequency != 'monthly' &&
                        repeatFrequency != 'yearly') repeatDay = null;
                    if (repeatFrequency != 'monthly_nth_weekday') {
                      repeatOrdinal = null;
                      repeatWeekday = null;
                    }
                    if (repeatFrequency != 'yearly') repeatMonth = null;
                  }),
        ),
        if (repeatFrequency != null) ...[
          if (repeatFrequency == 'weekly' ||
              repeatFrequency == 'monthly' ||
              repeatFrequency == 'monthly_nth_weekday')
            TextField(
                controller: repeatInterval,
                enabled: !saving,
                keyboardType: TextInputType.number,
                decoration:
                    const InputDecoration(labelText: 'Repeat interval')),
          if (repeatFrequency == 'monthly' || repeatFrequency == 'yearly')
            DropdownButtonFormField<int>(
              key: ValueKey('repeatDay-${repeatDay ?? dueDate.day}'),
              value: repeatDay ?? dueDate.day,
              decoration: const InputDecoration(labelText: 'Day of month'),
              items: List.generate(
                  31,
                  (index) => DropdownMenuItem(
                      value: index + 1, child: Text('${index + 1}'))),
              onChanged:
                  saving ? null : (value) => setState(() => repeatDay = value),
            ),
          if (repeatFrequency == 'yearly')
            DropdownButtonFormField<int>(
              key: ValueKey('repeatMonth-${repeatMonth ?? dueDate.month}'),
              value: repeatMonth ?? dueDate.month,
              decoration: const InputDecoration(labelText: 'Month'),
              items: List.generate(
                  12,
                  (index) => DropdownMenuItem(
                      value: index + 1,
                      child: Text(DateFormat.MMMM()
                          .format(DateTime(2024, index + 1))))),
              onChanged: saving
                  ? null
                  : (value) => setState(() => repeatMonth = value),
            ),
          if (repeatFrequency == 'monthly_nth_weekday') ...[
            DropdownButtonFormField<int>(
              key: ValueKey('repeatOrdinal-${repeatOrdinal ?? dueDate.day}'),
              value: repeatOrdinal ??
                  (dueDate.day + 7 >
                          DateTime(dueDate.year, dueDate.month + 1, 0).day
                      ? -1
                      : ((dueDate.day - 1) ~/ 7) + 1),
              decoration: const InputDecoration(labelText: 'Week of month'),
              items: const [
                DropdownMenuItem(value: 1, child: Text('First')),
                DropdownMenuItem(value: 2, child: Text('Second')),
                DropdownMenuItem(value: 3, child: Text('Third')),
                DropdownMenuItem(value: 4, child: Text('Fourth')),
                DropdownMenuItem(value: -1, child: Text('Last'))
              ],
              onChanged: saving
                  ? null
                  : (value) => setState(() => repeatOrdinal = value),
            ),
            DropdownButtonFormField<int>(
              key:
                  ValueKey('repeatWeekday-${repeatWeekday ?? dueDate.weekday}'),
              value: repeatWeekday ?? dueDate.weekday % 7,
              decoration: const InputDecoration(labelText: 'Weekday'),
              items: List.generate(
                  7,
                  (index) => DropdownMenuItem(
                      value: index,
                      child: Text(DateFormat.EEEE()
                          .format(DateTime(2024, 1, 7 + index))))),
              onChanged: saving
                  ? null
                  : (value) => setState(() => repeatWeekday = value),
            ),
          ],
          ListTile(
              title: const Text('Repeat until'),
              subtitle: Text(repeatUntil?.toIso8601String().split('T').first ??
                  'No end date'),
              trailing: repeatUntil == null
                  ? null
                  : IconButton(
                      icon: const Icon(Icons.clear),
                      onPressed: saving
                          ? null
                          : () => setState(() => repeatUntil = null)),
              onTap: saving
                  ? null
                  : () async {
                      final first =
                          DateTime(dueDate.year, dueDate.month, dueDate.day);
                      final initial =
                          repeatUntil != null && !repeatUntil!.isBefore(first)
                              ? repeatUntil!
                              : first;
                      final picked = await showDatePicker(
                          context: context,
                          initialDate: initial,
                          firstDate: first,
                          lastDate: DateTime(2100));
                      if (picked != null && mounted)
                        setState(() => repeatUntil = picked);
                    }),
        ],
      ];

  @override
  Widget build(BuildContext context) => PopScope(
      canPop: !saving && !changingOffDay,
      child: Scaffold(
        appBar: AppBar(title: Text(widget.isEc ? 'Create EC' : 'Create task')),
        body: !widget.isEc && quickMode
            ? buildQuickTaskForm()
            : ListView(padding: const EdgeInsets.all(16), children: [
                if (!widget.isEc)
                  Align(
                      alignment: Alignment.centerRight,
                      child: TextButton(
                        onPressed: saving ||
                                generating ||
                                taskSubmissionUncertain
                            ? null
                            : () => setState(() {
                                  standardDescription = description.text;
                                  standardTitle = title.text;
                                  standardAssignee = assigneeId;
                                  standardAttachments = List.of(attachments);
                                  description.clear();
                                  assigneeId = null;
                                  attachments.clear();
                                  quickMentionQuery = null;
                                  error = null;
                                  quickMode = true;
                                }),
                        child: const Text('Quick Task'),
                      )),
                if (widget.isEc)
                  ref.watch(ecCreationPolicyProvider).maybeWhen(
                        data: (policy) => policy.canEdit &&
                                policy.offDayAvailable
                            ? SwitchListTile(
                                contentPadding: EdgeInsets.zero,
                                title: const Text('Off day'),
                                subtitle: const Text(
                                    'Disable remaining EC reminders for today.'),
                                value: policy.isOffDay,
                                onChanged:
                                    changingOffDay || saving ? null : setOffDay)
                            : const SizedBox.shrink(),
                        orElse: () => const SizedBox.shrink(),
                      ),
                if (widget.isEc)
                  const Text(
                      'Add an idea for yourself today. Submissions close at 16:00 WIB.'),
                if (widget.isEc)
                  TextField(
                      controller: title,
                      enabled: ecWritable,
                      maxLines: 4,
                      maxLength: 1000,
                      onChanged: (value) => changeIdea(title, value),
                      decoration: const InputDecoration(
                          labelText: 'Your idea',
                          hintText:
                              'Write an idea. Type @ to mention a colleague.')),
                if (widget.isEc && ecWritable) inlineMentionSuggestions(title),
                if (widget.isEc)
                  Align(
                      alignment: Alignment.centerLeft,
                      child: TextButton.icon(
                          onPressed:
                              ecWritable ? () => addMention(title) : null,
                          icon: const Icon(Icons.alternate_email),
                          label: const Text('Mention colleague'))),
                if (widget.isEc) ...[
                  for (final idea in extraIdeas)
                    Column(children: [
                      Row(children: [
                        Expanded(
                            child: TextField(
                                controller: idea,
                                enabled: ecWritable,
                                onChanged: (value) => changeIdea(idea, value),
                                maxLength: 1000,
                                decoration:
                                    const InputDecoration(labelText: 'Idea'))),
                        IconButton(
                            icon: const Icon(Icons.close),
                            onPressed: !ecWritable || ecSubmissionUncertain
                                ? null
                                : () => setState(() {
                                      if (mentionQueryController == idea) {
                                        mentionSearchDebounce?.cancel();
                                        mentionSearchGeneration++;
                                        mentionQueryController = null;
                                        mentionSuggestions = [];
                                      }
                                      extraIdeas.remove(idea);
                                      extraIdeaKeys.remove(idea);
                                      submittedIdeas.remove(idea);
                                      mentions.remove(idea);
                                      previousIdeaText.remove(idea);
                                      idea.dispose();
                                    })),
                      ]),
                      if (ecWritable) inlineMentionSuggestions(idea),
                      Align(
                          alignment: Alignment.centerLeft,
                          child: TextButton.icon(
                              onPressed:
                                  ecWritable ? () => addMention(idea) : null,
                              icon: const Icon(Icons.alternate_email),
                              label: const Text('Mention colleague')))
                    ]),
                  TextButton.icon(
                      onPressed: !ecWritable ||
                              ecSubmissionUncertain ||
                              extraIdeas.length >= 19
                          ? null
                          : () => setState(
                              () => extraIdeas.add(TextEditingController())),
                      icon: const Icon(Icons.add),
                      label: const Text('Add idea')),
                ],
                if (!widget.isEc)
                  FutureBuilder<Map<String, dynamic>>(
                    future: bootstrap,
                    builder: (context, snapshot) {
                      if (snapshot.hasError)
                        return taskBootstrapError(snapshot.error);
                      if (!snapshot.hasData)
                        return const LinearProgressIndicator();
                      if (!taskCanCreate)
                        return const Text(
                            'Task creation is unavailable for your account.');
                      final data = snapshot.data!;
                      final allEmployees = data['employees'] as List;
                      final team = data['teamStaff'] is List
                          ? data['teamStaff'] as List
                          : const [];
                      final employees =
                          actingForManagerId != null && team.isNotEmpty
                              ? team
                              : allEmployees;
                      final selectedAssignee = [...allEmployees, ...team]
                          .whereType<Map>()
                          .where((employee) =>
                              (employee['employee_id'] as num?)?.toInt() ==
                              assigneeId)
                          .firstOrNull;
                      final actingOptions = data['actingForOptions'] is List
                          ? data['actingForOptions'] as List
                          : const [];
                      var actingForName = '';
                      for (final manager in actingOptions.whereType<Map>()) {
                        if ((manager['employee_id'] as num?)?.toInt() ==
                            actingForManagerId) {
                          actingForName =
                              (manager['full_name'] ?? '').toString();
                          break;
                        }
                      }
                      final projects = data['projects'] is List
                          ? data['projects'] as List
                          : const [];
                      final selfAssigned =
                          assigneeId != null && assigneeId == currentEmployeeId;
                      final canSetPriority =
                          data['canCustomizePoints'] == true && !selfAssigned;
                      final complexities = data['complexities'] is List
                          ? data['complexities'] as List
                          : const [];
                      final priorities = data['priorities'] is List
                          ? data['priorities'] as List
                          : const [];
                      const pointsMatrix = {
                        'low': {1: 1, 2: 2, 3: 4},
                        'normal': {1: 3, 2: 5, 3: 7},
                        'urgent': {1: 5, 2: 8, 3: 10}
                      };
                      final complexity = complexities
                          .whereType<Map>()
                          .where((option) =>
                              (option['task_complexity_id'] as num?)?.toInt() ==
                              complexityId)
                          .firstOrNull;
                      final complexityValue =
                          (complexity?['complexity_value'] as num?)?.toInt();
                      final points = selfAssigned
                          ? 0
                          : canSetPriority
                              ? (pointsMatrix[priority] ??
                                  const <int, int>{})[complexityValue]
                              : 1;
                      return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Assignee & Participants',
                                style: Theme.of(context).textTheme.titleMedium),
                            if (actingForManagerId != null) ...[
                              ListTile(
                                contentPadding: EdgeInsets.zero,
                                title: const Text('Acting for'),
                                subtitle: Text(actingForName),
                                trailing: Text(
                                    '${data['managerTokenBalance'] ?? 0} manager pts'),
                              ),
                              const Text(
                                  'The task will appear as assigned by this manager and points are debited from their account.'),
                            ],
                            ListTile(
                              contentPadding: EdgeInsets.zero,
                              title: const Text('Assigned To'),
                              subtitle: Text(assigneeId == null
                                  ? 'Select an employee…'
                                  : (selectedAssignee?['full_name'] ??
                                          'Selected employee')
                                      .toString()),
                              trailing: assigneeId == null
                                  ? const Icon(Icons.search)
                                  : IconButton(
                                      tooltip: 'Clear assignee',
                                      icon: const Icon(Icons.clear),
                                      onPressed: saving
                                          ? null
                                          : () =>
                                              setState(() => assigneeId = null),
                                    ),
                              onTap: saving
                                  ? null
                                  : () async {
                                      final selected = await pickEmployee(
                                          employees, 'Assign to');
                                      if (selected != null && mounted)
                                        setState(() {
                                          assigneeId = selected;
                                          participants.remove(selected);
                                        });
                                    },
                            ),
                            ListTile(
                              contentPadding: EdgeInsets.zero,
                              title: const Text('Due date'),
                              subtitle: Text(
                                  dueDate.toIso8601String().split('T').first),
                              onTap: saving
                                  ? null
                                  : () async {
                                      final picked = await showDatePicker(
                                          context: context,
                                          initialDate: dueDate,
                                          firstDate: DateTime(2020),
                                          lastDate: DateTime(2100));
                                      if (picked != null && mounted)
                                        setState(() => dueDate = picked);
                                    },
                            ),
                            ...buildSchedulingControls(context),
                            if (widget.projectId == null)
                              DropdownButtonFormField<int>(
                                key: ValueKey('project-${projectId ?? 0}'),
                                value: projectId ?? 0,
                                isExpanded: true,
                                decoration:
                                    const InputDecoration(labelText: 'Project'),
                                items: [
                                  const DropdownMenuItem<int>(
                                      value: 0, child: Text('No project')),
                                  ...projects.map((project) =>
                                      DropdownMenuItem<int>(
                                          value: (project['project_id'] as num)
                                              .toInt(),
                                          child: Text(
                                              project['name'].toString(),
                                              overflow:
                                                  TextOverflow.ellipsis))),
                                ],
                                onChanged: saving
                                    ? null
                                    : (value) => setState(() =>
                                        projectId = value == 0 ? null : value),
                              ),
                            Align(
                                alignment: Alignment.centerLeft,
                                child: TextButton.icon(
                                  onPressed: saving
                                      ? null
                                      : () async {
                                          final options = allEmployees
                                              .whereType<Map>()
                                              .where((employee) {
                                            final id =
                                                (employee['employee_id'] as num)
                                                    .toInt();
                                            return id != assigneeId &&
                                                !participants.contains(id);
                                          }).toList();
                                          final selected = await pickEmployee(
                                              options, 'Add participant');
                                          if (selected != null && mounted)
                                            setState(() =>
                                                participants.add(selected));
                                        },
                                  icon: const Icon(Icons.person_add_alt_1),
                                  label:
                                      const Text('Search & add participants…'),
                                )),
                            if (participants.isNotEmpty)
                              Align(
                                  alignment: Alignment.centerLeft,
                                  child: Wrap(spacing: 6, children: [
                                    for (final employee in allEmployees
                                        .whereType<Map>()
                                        .where((employee) =>
                                            participants.contains(
                                                (employee['employee_id'] as num)
                                                    .toInt())))
                                      InputChip(
                                          label: Text(
                                              employee['full_name'].toString()),
                                          onDeleted: saving
                                              ? null
                                              : () => removeParticipant(
                                                  (employee['employee_id']
                                                          as num)
                                                      .toInt(),
                                                  employee['full_name']
                                                      .toString())),
                                  ])),
                            SwitchListTile(
                              contentPadding: EdgeInsets.zero,
                              title: const Text('Private task'),
                              subtitle: const Text(
                                  'Visible to the assigner, assignee, participants and authorized administrators.'),
                              value: isPrivate,
                              onChanged: saving
                                  ? null
                                  : (value) async {
                                      if (!value) {
                                        setState(() => isPrivate = false);
                                        return;
                                      }
                                      final confirmed = await showDialog<bool>(
                                          context: context,
                                          builder: (context) => AlertDialog(
                                                title: const Text(
                                                    'Make this task private?'),
                                                content: const Text(
                                                    'Only the assigner, assignees, participants, and authorized administrators will be able to view this task and its discussion.'),
                                                actions: [
                                                  TextButton(
                                                      onPressed: () =>
                                                          Navigator.pop(
                                                              context, false),
                                                      child:
                                                          const Text('Cancel')),
                                                  FilledButton(
                                                      onPressed: () =>
                                                          Navigator.pop(
                                                              context, true),
                                                      child: const Text(
                                                          'Make Private')),
                                                ],
                                              ));
                                      if (confirmed == true && mounted)
                                        setState(() => isPrivate = true);
                                    },
                            ),
                            if (canSetPriority)
                              DropdownButtonFormField<String>(
                                key: ValueKey('priority-$priority'),
                                value: availablePriorities.contains(priority)
                                    ? priority
                                    : null,
                                decoration: const InputDecoration(
                                    labelText: 'Priority'),
                                hint: const Text('Select priority'),
                                items: priorities
                                    .map((option) => DropdownMenuItem<String>(
                                        value:
                                            option['priority_code'].toString(),
                                        child: Text((option['priority_name'] ??
                                                option['priority_code'])
                                            .toString())))
                                    .toList(),
                                onChanged: saving
                                    ? null
                                    : (value) {
                                        if (value != null)
                                          setState(() => priority = value);
                                      },
                              ),
                            if (canSetPriority)
                              DropdownButtonFormField<int>(
                                key: ValueKey('complexity-$complexityId'),
                                value: complexityId,
                                isExpanded: true,
                                decoration: const InputDecoration(
                                    labelText: 'Complexity'),
                                hint: const Text('Select complexity'),
                                items: complexities
                                    .map((option) => DropdownMenuItem<int>(
                                          value: (option['task_complexity_id']
                                                  as num)
                                              .toInt(),
                                          child: Text(
                                              (option['complexity_name'] ?? '')
                                                  .toString(),
                                              overflow: TextOverflow.ellipsis),
                                        ))
                                    .toList(),
                                onChanged: saving
                                    ? null
                                    : (value) =>
                                        setState(() => complexityId = value),
                              ),
                            ListTile(
                              contentPadding: EdgeInsets.zero,
                              title: Text(canSetPriority
                                  ? 'Points'
                                  : selfAssigned
                                      ? 'Self-assigned task'
                                      : 'Staff-to-staff task'),
                              subtitle: canSetPriority
                                  ? null
                                  : Text(selfAssigned
                                      ? 'Self-assigned tasks use standard priority.'
                                      : 'Staff-to-staff tasks use standard priority.'),
                              trailing: Text(points == null
                                  ? 'Select complexity'
                                  : '$points ${points == 1 ? 'point' : 'points'}'),
                            )
                          ]);
                    },
                  ),
                if (!widget.isEc) ...[
                  const SizedBox(height: 20),
                  Text('Description',
                      style: Theme.of(context).textTheme.titleMedium),
                  TextField(
                    controller: description,
                    enabled: !saving,
                    maxLines: 3,
                    maxLength: 10000,
                    onChanged: (_) => setState(() {
                      title.clear();
                      generationMessage = null;
                    }),
                    decoration: const InputDecoration(labelText: 'Description'),
                  ),
                  Align(
                      alignment: Alignment.centerLeft,
                      child: TextButton.icon(
                        onPressed: saving ||
                                generating ||
                                !taskFormReady ||
                                !taskCanCreate
                            ? null
                            : generateDraft,
                        icon: const Icon(Icons.auto_awesome_outlined),
                        label: Text(generating
                            ? 'Generating…'
                            : 'Generate with Jarvis'),
                      )),
                  if (generationMessage != null) Text(generationMessage!),
                  const SizedBox(height: 12),
                  Text('Attachments & Photos',
                      style: Theme.of(context).textTheme.titleMedium),
                  Align(
                      alignment: Alignment.centerLeft,
                      child: TextButton.icon(
                          onPressed: saving ? null : addPhotos,
                          icon: const Icon(Icons.add_photo_alternate_outlined),
                          label: const Text('Add photos'))),
                  Align(
                      alignment: Alignment.centerLeft,
                      child: TextButton.icon(
                          onPressed: saving ? null : addFiles,
                          icon: const Icon(Icons.attach_file),
                          label: const Text('Add files'))),
                  for (final file in attachments)
                    ListTile(
                      dense: true,
                      leading: const Icon(Icons.image_outlined),
                      title: Text(file.name,
                          maxLines: 1, overflow: TextOverflow.ellipsis),
                      trailing: IconButton(
                          icon: const Icon(Icons.close),
                          onPressed: saving
                              ? null
                              : () => setState(() => attachments.remove(file))),
                    ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: title,
                    readOnly: true,
                    maxLength: 255,
                    decoration: const InputDecoration(
                        labelText: 'Task Title',
                        hintText:
                            'Title will be generated by Jarvis after you fill the description'),
                  ),
                  const Text(
                      'Jarvis can make mistakes. Review the result before creating the task.'),
                ],
                if (error != null)
                  Text(error!, style: const TextStyle(color: Colors.red)),
                const SizedBox(height: 16),
                if (widget.isEc)
                  ref.watch(ecCreationPolicyProvider).when(
                        loading: () =>
                            const Center(child: CircularProgressIndicator()),
                        error: (exception, _) => exception is DioException &&
                                exception.response?.statusCode == 403
                            ? const Text(
                                'EC creation is unavailable for your account.')
                            : TextButton(
                                onPressed: () =>
                                    ref.invalidate(ecCreationPolicyProvider),
                                child: const Text(
                                    'Unable to check EC availability. Tap to retry.')),
                        data: (policy) => !policy.canEdit
                            ? const Text('EC creation is closed for today.')
                            : policy.isOffDay
                                ? const Text('Today is marked as an off day.')
                                : FilledButton(
                                    onPressed: saving || changingOffDay
                                        ? null
                                        : submit,
                                    child: Text(saving ? 'Saving…' : 'Create')),
                      )
                else
                  FilledButton(
                      onPressed: saving ||
                              generating ||
                              taskSubmissionUncertain ||
                              !taskFormReady ||
                              !taskCanCreate
                          ? null
                          : submit,
                      child: Text(saving ? 'Saving…' : 'Create')),
              ]),
      ));
}

class _EmployeeSearchSheet extends StatefulWidget {
  final List<dynamic> employees;
  final String heading;
  const _EmployeeSearchSheet({required this.employees, required this.heading});

  @override
  State<_EmployeeSearchSheet> createState() => _EmployeeSearchSheetState();
}

class _EmployeeSearchSheetState extends State<_EmployeeSearchSheet> {
  String query = '';

  @override
  Widget build(BuildContext context) {
    final matches = widget.employees.whereType<Map>().where((employee) {
      final department = employee['department'];
      final role = employee['primary_role'];
      final values = [
        employee['full_name'],
        employee['employee_code'],
        employee['job_title'],
        if (department is Map) department['department_name'],
        if (role is Map) role['role_name']
      ];
      return values
          .whereType<Object>()
          .any((value) => value.toString().toLowerCase().contains(query));
    }).toList();
    final size = MediaQuery.of(context).size;
    final inset = MediaQuery.of(context).viewInsets.bottom;
    return SafeArea(
        child: Padding(
      padding: EdgeInsets.only(bottom: inset),
      child: SizedBox(
          height: (size.height - inset) * 0.65,
          child: Column(children: [
            ListTile(title: Text(widget.heading)),
            Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: TextField(
                  decoration: const InputDecoration(
                      prefixIcon: Icon(Icons.search),
                      hintText: 'Search employees'),
                  onChanged: (value) =>
                      setState(() => query = value.trim().toLowerCase()),
                )),
            Expanded(
                child: matches.isEmpty
                    ? const Center(child: Text('No employee found.'))
                    : ListView.builder(
                        itemCount: matches.length,
                        itemBuilder: (context, index) {
                          final employee = matches[index];
                          final department = employee['department'];
                          final departmentName = department is Map
                              ? (department['department_name'] ?? '').toString()
                              : '';
                          return ListTile(
                            title:
                                Text((employee['full_name'] ?? '').toString()),
                            subtitle: Text([
                              employee['job_title'],
                              departmentName
                            ]
                                .where((value) =>
                                    value != null &&
                                    value.toString().isNotEmpty)
                                .join(' • ')),
                            onTap: () => Navigator.pop(context,
                                (employee['employee_id'] as num).toInt()),
                          );
                        },
                      )),
          ])),
    ));
  }
}

class _EcMentionPicker extends ConsumerStatefulWidget {
  const _EcMentionPicker();

  @override
  ConsumerState<_EcMentionPicker> createState() => _EcMentionPickerState();
}

class _EcMentionPickerState extends ConsumerState<_EcMentionPicker> {
  final search = TextEditingController();
  Timer? debounce;
  List<dynamic> employees = [];
  bool loading = true;
  bool failed = false;
  int generation = 0;

  @override
  void initState() {
    super.initState();
    load();
  }

  @override
  void dispose() {
    debounce?.cancel();
    search.dispose();
    super.dispose();
  }

  Future<void> load() async {
    final request = ++generation;
    setState(() {
      loading = true;
      failed = false;
    });
    try {
      final response = await ref.read(apiClientProvider).dio.get(
          '/ec/mention-employees',
          queryParameters: {'search': search.text.trim()});
      final data = response.data;
      if (data is! Map || data['data'] is! List)
        throw const FormatException('Unexpected mention response');
      if (mounted && request == generation)
        setState(() {
          employees = data['data'] as List;
          loading = false;
        });
    } catch (_) {
      if (mounted && request == generation)
        setState(() {
          failed = true;
          loading = false;
        });
    }
  }

  @override
  Widget build(BuildContext context) => SafeArea(
          child: Padding(
        padding:
            EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
        child: SizedBox(
            height: MediaQuery.of(context).size.height * 0.6,
            child: Column(children: [
              const ListTile(title: Text('Mention a colleague')),
              Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: TextField(
                    controller: search,
                    decoration: const InputDecoration(
                        prefixIcon: Icon(Icons.search),
                        hintText: 'Search colleagues'),
                    onChanged: (_) {
                      debounce?.cancel();
                      debounce = Timer(const Duration(milliseconds: 350), load);
                    },
                  )),
              Expanded(
                  child: loading
                      ? const Center(child: CircularProgressIndicator())
                      : failed
                          ? Center(
                              child: TextButton(
                                  onPressed: load,
                                  child: const Text(
                                      'Unable to load colleagues. Tap to retry.')))
                          : employees.isEmpty
                              ? const Center(
                                  child: Text('No colleagues found.'))
                              : ListView.builder(
                                  itemCount: employees.length,
                                  itemBuilder: (context, index) {
                                    final employee = Map<String, dynamic>.from(
                                        employees[index] as Map);
                                    return ListTile(
                                        title: Text(
                                            employee['full_name'].toString()),
                                        subtitle: Text(
                                            (employee['department'] ?? '')
                                                .toString()),
                                        onTap: () =>
                                            Navigator.pop(context, employee));
                                  })),
            ])),
      ));
}
