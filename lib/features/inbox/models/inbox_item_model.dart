class InboxItemModel {
  final String id;
  final String title;
  final String source;
  final String sourceLabel;
  final String status;
  final String createdAt;
  final String? updatedAt;
  final String? latestCommentAt;
  final String? sortAt;
  final String? subtitle;
  final bool isComplete;
  final bool isUnread;
  final int unreadCount;
  final String displayAt;
  final String? subjectKey;
  final String? sourceSubjectKey;
  final String? guestId;
  final String? moduleCode;
  final String? subjectType;
  final String? commentModule;
  final String? commentSubjectKey;
  final String? commentSubjectType;
  final String? kind;
  final String? notificationType;
  final List<int> unreadMentionNotificationIds;
  final bool hasMentionAttention;
  final String? mentionWorkStatus;
  final int? logisticInMentionId;
  final ({String line, int? assignment, bool mention})? logisticInDetail;
  final Map<String, String> details;

  ({String module, String routeKey, String type, String key})? get readIdentity {
    final module = moduleCode;
    final key = subjectKey ?? guestId;
    if (module == 'logistic-in') {
      final detail = logisticInDetail;
      if (detail?.assignment == null) return null;
      return (module: module!, routeKey: detail!.line, type: 'assignment', key: detail.assignment.toString());
    }
    if (module == null || key == null || key.isEmpty) return null;
    final type = switch (module) {
      'logistic-out' => 'logistic_out_po',
      'workhub_ec' => 'energy_of_creation_entry',
      'logistic-arrival-intake' => 'intake',
      'logistic-arrival' => 'arrival',
      'guest-book' || 'guest' => 'guest',
      'task-mine' || 'task-assigned' || 'workhub' || 'task' => 'task',
      _ => null,
    };
    final routeKey = sourceSubjectKey?.isNotEmpty == true ? sourceSubjectKey! : key;
    final identityKey = module == 'logistic-out' ? routeKey : (module == 'guest-book' || module == 'guest') ? (guestId ?? key) : key;
    return type == null ? null : (module: module, routeKey: routeKey, type: type, key: identityKey);
  }

  String get filterSource {
    final code = moduleCode ?? source;
    return code == 'logistic-arrival-intake' ? 'logistic-arrival' : code;
  }

  String get filterSourceLabel => switch (filterSource) {
    'employee-chat' => 'Chats',
    'guest-book' => 'Guests',
    'logistic-in' => 'Logistic In',
    'logistic-arrival' => 'Logistic Arrival',
    'sales-order' => 'Sales Order',
    'fleet-compliance' => 'Fleet Compliance',
    'workhub' => 'WorkHub',
    'task-mine' => 'Assigned to Me',
    'task-assigned' => 'Assigned by Me',
    'workhub_ec' => 'EC',
    _ => sourceLabel == 'Task' ? filterSource : sourceLabel,
  };

  ({String stage, int id})? get logisticOutReference {
    final module = (commentModule ?? '').toLowerCase();
    final type = (commentSubjectType ?? '').toLowerCase();
    if (kind == 'mention' && const ['lo', 'logistic-out', 'logistic_out', 'wms.logistic-out', 'wms_logistic_out'].contains(module) &&
        const ['wms_logistic_out_po', 'wms.logistic_out_po', 'logistic_out_po'].contains(type)) {
      final id = int.tryParse(commentSubjectKey ?? '');
      return id != null && id > 0 ? (stage: 'mention', id: id) : null;
    }
    if (moduleCode != 'logistic-out') return null;
    final match = RegExp(r'^(warehouse|receiving|trip):([1-9][0-9]*)$').firstMatch(subjectKey ?? '');
    return match == null ? null : (stage: match.group(1)!, id: int.parse(match.group(2)!));
  }

  int? get logisticOutMentionId {
    final module = (commentModule ?? '').toLowerCase();
    final type = (commentSubjectType ?? '').toLowerCase();
    final attention = hasMentionAttention || const ['comment_mention', 'comment_reply'].contains((notificationType ?? '').toLowerCase());
    if (!attention || !const ['lo', 'logistic-out', 'logistic_out', 'wms.logistic-out', 'wms_logistic_out'].contains(module) ||
        !const ['wms_logistic_out_po', 'wms.logistic_out_po', 'logistic_out_po'].contains(type)) return null;
    final id = int.tryParse(commentSubjectKey ?? '');
    return id != null && id > 0 ? id : null;
  }

  InboxItemModel({
    required this.id,
    required this.title,
    required this.source,
    required this.sourceLabel,
    required this.status,
    required this.createdAt,
    this.updatedAt,
    this.latestCommentAt,
    this.sortAt,
    this.subtitle,
    this.isComplete = false,
    this.isUnread = false,
    this.unreadCount = 0,
    this.displayAt = '',
    this.subjectKey,
    this.sourceSubjectKey,
    this.guestId,
    this.moduleCode,
    this.subjectType,
    this.commentModule,
    this.commentSubjectKey,
    this.commentSubjectType,
    this.kind,
    this.notificationType,
    this.unreadMentionNotificationIds = const [],
    this.hasMentionAttention = false,
    this.mentionWorkStatus,
    this.logisticInMentionId,
    this.logisticInDetail,
    this.details = const {},
  });

  factory InboxItemModel.fromJson(Map<String, dynamic> json) {
    final isGuest = json['module_code'] == 'guest-book' || json['subject_type'] == 'guest';
    final person = json['person'];
    final guestName = (json['full_name'] ?? (person is Map ? person['full_name'] : null) ?? json['guest_name'] ?? '').toString().trim();
    final purpose = json['purposeDimension'] ?? json['purpose_dimension'];
    final purposeName = purpose is Map ? purpose['purpose_name']?.toString() : null;
    final nested = json['payload'] is Map ? json['payload'] as Map : const {};
    final lineType = json['comment_subject_type'] ?? json['subject_type'] ?? nested['subject_type'];
    final lineValue = json['logistic_in_line_id'] ?? json['comment_subject_key'] ?? nested['subject_key'] ??
        (lineType == 'wms.logistic_in_line' ? json['subject_key'] : null);
    final lineText = (lineValue ?? '').toString().trim();
    final lineId = RegExp(r'^\d+$').hasMatch(lineText) ? int.tryParse(lineText) : null;
    final targetModule = (json['comment_module_code'] ?? nested['module_code'] ?? json['module_code'] ?? '').toString();
    final commentType = (json['comment_subject_type'] ?? nested['subject_type'] ?? '').toString();
    final commentKey = (json['comment_subject_key'] ?? nested['subject_key'] ?? '').toString().trim();
    final wmsComment = (targetModule == 'wms.logistic-in' || commentType == 'wms.logistic_in_line') && commentKey.isNotEmpty;
    final isLogistic = const ['logistic-arrival', 'logistic-in', 'wms.logistic-in'].contains(targetModule) ||
        json['kind'] == 'logistics' || commentType == 'wms.logistic_in_line';
    final detailLine = (wmsComment ? commentKey : (json['logistic_in_line_id'] ?? json['comment_subject_key'] ?? nested['subject_key'] ?? json['subject_uuid'] ?? json['subject_key'] ?? '')).toString();
    final isCommentAttention = const ['comment_mention', 'comment_reply'].contains(json['notification_type']) || json['kind'] == 'mention' ||
        (json['module_code'] == 'collaboration' && json['subject_type'] == 'comment_mention');
    final assignmentId = int.tryParse((json['logistic_in_item_assignment_id'] ?? '').toString());
    final routedAttention = json['module_code'] == 'logistic-in' && assignmentId != null && json['has_mention_attention'] == true;
    final mentionContext = isCommentAttention && wmsComment && !routedAttention;
    final validLine = RegExp(r'^(?:[1-9][0-9]*|[0-9a-fA-F]{8}-(?:[0-9a-fA-F]{4}-){3}[0-9a-fA-F]{12})$').hasMatch(detailLine);
    int count(Object? value) => int.tryParse((value ?? 0).toString()) ?? 0;
    final role = (json['role_code'] ?? '').toString().toUpperCase();
    final officer = json['module_code'] == 'logistic-in' && json['logistic_in_item_assignment_id'] != null &&
        const ['QC', 'BM', 'WH'].contains(role) &&
        const ['wms.logistic_in_line', 'logistic-assignment'].contains(json['subject_type']);
    final unread = json['has_unread'] == true || '${json['status'] ?? ''}'.toLowerCase() == 'unread';
    final rawUnreadCount = count(json['unread_count']);
    final mentionCount = count(json['mention_unread_count']);
    final unreadCount = officer
        ? (mentionCount > 0 ? mentionCount : (json['operational_unread'] == true ? 1 : 0))
        : rawUnreadCount > 0 ? rawUnreadCount : unread ? 1 : 0;
    final isTask = const ['workhub', 'task', 'task-mine', 'task-assigned'].contains(json['module_code']) || json['subject_type'] == 'task';
    final latestComment = json['latest_comment'];
    final displayAt = isGuest || isTask || json['module_code'] == 'workhub_ec'
        ? (json['updated_at'] ?? json['visit_time'] ?? json['created_at'])
        : json['module_code'] == 'sales-order'
            ? ((latestComment is Map ? latestComment['created_at'] : null) ?? json['created_at'])
            : (json['visit_time'] ?? json['due_at'] ?? json['created_at']);
    final baseTitle = (json['full_name'] ?? json['title'] ?? json['todo_title'] ?? json['subject'] ?? 'Untitled task').toString();
    final title = officer ? '$role: ${json['item_name'] ?? baseTitle}'
        : isGuest && guestName.isNotEmpty ? (guestName.startsWith('Guest:') ? guestName : 'Guest: $guestName') : baseTitle;
    final mentionActor = (json['latest_mention_actor'] ?? '').toString().trim();
    final mentionSnippet = (json['comment_snippet'] ?? '').toString().trim();
    final mentionPreview = [if (mentionActor.isNotEmpty) '$mentionActor:', if (mentionSnippet.isNotEmpty) mentionSnippet].join(' ');
    final preview = officer
        ? (json['has_mention_attention'] == true && mentionPreview.isNotEmpty ? mentionPreview
            : json['is_reassigned_historical'] == true ? (json['description'] ?? 'This task has been reassigned to ${json['reassigned_to_employee_name'] ?? 'the new officer'}.')
            : json['supplier_name'])
        : isGuest && mentionPreview.isNotEmpty && (json['has_mention_attention'] == true || mentionSnippet.isNotEmpty)
            ? mentionPreview
        : isTask && (json['latest_comment_snippet'] ?? '').toString().isNotEmpty
            ? [if ((json['latest_comment_actor'] ?? '').toString().trim().isNotEmpty) '${json['latest_comment_actor'].toString().trim()}:', json['latest_comment_snippet']].join(' ')
            : isTask && (json['description'] ?? '').toString().isEmpty
                ? switch (json['reason']) { 'review' => 'Review Request', 'mention' => 'Mentioned', 'assigned' => 'Assigned to You', _ => 'Task' }
                : null;
    final fields = <String, String>{};
    if (isGuest) {
      void add(String label, Object? value) {
        if (value != null && value.toString().trim().isNotEmpty) fields[label] = value.toString();
      }
      add('Full name', guestName);
      add('WhatsApp', json['whatsapp_number']);
      add('People count', json['people_count']);
      add('Address', json['address']);
      add('Guest type', json['guest_type']);
      add('Company', json['company_name']);
      add('Visit purpose', purposeName ?? json['visit_purpose']);
      add('Applied position', json['applied_position']);
      add('Package type', json['package_type']);
      add('Package notes', json['package_notes']);
      add('Notes', json['other_purpose_notes']);
      add('Vehicle type', json['vehicle_type']);
      add('License plate', json['license_plate']);
    }
    return InboxItemModel(
      id: (json['id'] ?? json['task_id'] ?? json['subject_key'] ?? '').toString(),
      title: title,
      source: json['source'] as String? ?? json['module_code'] as String? ?? 'general',
      sourceLabel: json['source_label'] as String? ?? json['module_name'] as String? ?? (isGuest ? 'Guests' : null) ?? json['source'] as String? ?? 'Task',
      status: json['status'] as String? ?? 'pending',
      createdAt: json['created_at'] as String? ?? 'Today',
      updatedAt: json['updated_at'] as String?,
      latestCommentAt: json['latest_comment'] is Map ? (json['latest_comment'] as Map)['created_at']?.toString() : null,
      sortAt: (json['updated_at'] ?? json['created_at'] ?? json['submitted_at'] ?? json['visit_time'])?.toString(),
      subtitle: preview?.toString() ?? json['latest_comment_snippet'] as String? ?? json['comment_snippet'] as String? ?? json['latest_progress_note'] as String? ?? json['description'] as String? ?? json['subtitle'] as String? ?? json['detail'] as String? ?? purposeName,
      isComplete: json['is_complete'] as bool? ?? const ['complete', 'completed', 'checked_out', 'rejected', 'approved', 'cancelled'].contains(json['status']),
      isUnread: unreadCount > 0,
      unreadCount: unreadCount,
      displayAt: displayAt?.toString() ?? '',
      subjectKey: json['subject_key']?.toString(),
      sourceSubjectKey: json['source_subject_key']?.toString(),
      guestId: json['guest_id']?.toString(),
      moduleCode: json['module_code'] as String?,
      subjectType: json['subject_type'] as String?,
      commentModule: (json['comment_module_code'] ?? nested['module_code'])?.toString(),
      commentSubjectKey: (json['comment_subject_key'] ?? nested['subject_id'] ?? nested['subject_key'])?.toString(),
      commentSubjectType: (json['comment_subject_type'] ?? nested['subject_type'])?.toString(),
      kind: json['kind'] as String?,
      notificationType: json['notification_type'] as String?,
      unreadMentionNotificationIds: (count(json['mention_unread_count']) > 0 || json['mention_attention_unread'] == true ||
              (json['notification_type'] == 'comment_mention' && (unread || rawUnreadCount > 0)))
          ? ((json['mention_notification_ids'] is List) ? json['mention_notification_ids'] as List : [json['mention_notification_id'] ?? json['notification_id']])
              .map((id) => int.tryParse((id ?? '').toString())).whereType<int>().where((id) => id > 0).toSet().toList()
          : const [],
      hasMentionAttention: json['has_mention_attention'] == true,
      mentionWorkStatus: json['mention_work_status'] as String?,
      logisticInMentionId: json['has_mention_attention'] == true && lineType == 'wms.logistic_in_line' &&
          lineId != null && lineId > 0 && lineId <= 9007199254740991 ? lineId : null,
      logisticInDetail: isLogistic && validLine ? (line: detailLine, assignment: mentionContext || assignmentId == null || assignmentId <= 0 ? null : assignmentId, mention: mentionContext) : null,
      details: fields,
    );
  }
}
