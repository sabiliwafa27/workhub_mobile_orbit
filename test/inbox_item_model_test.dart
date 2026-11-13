import 'package:flutter_test/flutter_test.dart';
import 'package:workhub_mobile/features/inbox/models/inbox_item_model.dart';
import 'package:workhub_mobile/features/inbox/screens/inbox_screen.dart';

void main() {
  test('guest and officer previews include mention authors', () {
    final guest = InboxItemModel.fromJson({
      'module_code': 'guest-book',
      'latest_mention_actor': 'Ari',
      'comment_snippet': 'Please check'
    });
    expect(guest.subtitle, 'Ari: Please check');
    final officer = InboxItemModel.fromJson({
      'module_code': 'logistic-in',
      'subject_type': 'wms.logistic_in_line',
      'logistic_in_item_assignment_id': 3,
      'role_code': 'QC',
      'has_mention_attention': true,
      'latest_mention_actor': 'Sari',
      'comment_snippet': 'Check quality'
    });
    expect(officer.subtitle, 'Sari: Check quality');
  });
  test('EC time and task previews match their Inbox rows', () {
    final ec = InboxItemModel.fromJson({
      'module_code': 'workhub_ec',
      'created_at': '2026-01-01T08:00:00Z',
      'updated_at': '2026-01-02T08:00:00Z'
    });
    expect(ec.displayAt, '2026-01-02T08:00:00Z');
    final task = InboxItemModel.fromJson({
      'module_code': 'task-mine',
      'latest_comment_actor': 'Ari',
      'latest_comment_snippet': 'Please review'
    });
    expect(task.subtitle, 'Ari: Please review');
    expect(
        InboxItemModel.fromJson(
            {'module_code': 'task-mine', 'reason': 'review'}).subtitle,
        'Review Request');
  });
  test('sort timestamp follows the web fallback order', () {
    final submitted = InboxItemModel.fromJson({
      'submitted_at': '2026-01-02T03:00:00Z',
      'visit_time': '2026-01-01T03:00:00Z'
    });
    expect(submitted.sortAt, '2026-01-02T03:00:00Z');
    final visit =
        InboxItemModel.fromJson({'visit_time': '2026-01-01T03:00:00Z'});
    expect(visit.sortAt, '2026-01-01T03:00:00Z');
  });
  test('read identity preserves source and guest identifiers', () {
    final guest = InboxItemModel.fromJson({
      'module_code': 'guest-book',
      'subject_key': 'selection',
      'source_subject_key': 'route',
      'guest_id': 42
    });
    expect(guest.readIdentity,
        (module: 'guest-book', routeKey: 'route', type: 'guest', key: '42'));
    final outgoing = InboxItemModel.fromJson({
      'module_code': 'logistic-out',
      'subject_key': 'selection',
      'source_subject_key': 'warehouse:12'
    });
    expect(outgoing.readIdentity, (
      module: 'logistic-out',
      routeKey: 'warehouse:12',
      type: 'logistic_out_po',
      key: 'warehouse:12'
    ));
  });
  test('accepts composite and numeric inbox identifiers', () {
    expect(InboxItemModel.fromJson({'id': 'ec:123'}).id, 'ec:123');
    expect(InboxItemModel.fromJson({'id': 42}).id, '42');
    expect(InboxItemModel.fromJson({'subject_key': '17'}).id, '17');
  });

  test('normalizes intake filter without changing its action identity', () {
    final item = InboxItemModel.fromJson(
        {'module_code': 'logistic-arrival-intake', 'subject_key': '42'});
    expect(item.filterSource, 'logistic-arrival');
    expect(item.moduleCode, 'logistic-arrival-intake');
    expect(item.subjectKey, '42');
  });

  test('maps a guest source row to its name and details', () {
    final item = InboxItemModel.fromJson({
      'module_code': 'guest-book',
      'subject_type': 'guest',
      'subject_key': '4',
      'full_name': 'Visitor',
      'company_name': 'Example',
      'purpose_dimension': {'purpose_name': 'Official visit'},
    });
    expect(item.title, 'Guest: Visitor');
    expect(item.sourceLabel, 'Guests');
    expect(item.subtitle, 'Official visit');
    expect(item.details['Company'], 'Example');
  });

  test('resolves Logistic Out operational and mention references safely', () {
    final operational = InboxItemModel.fromJson(
        {'module_code': 'logistic-out', 'subject_key': 'trip:27'});
    expect(operational.logisticOutReference, (stage: 'trip', id: 27));
    final mention = InboxItemModel.fromJson({
      'kind': 'mention',
      'comment_module_code': 'wms.logistic-out',
      'comment_subject_type': 'wms.logistic_out_po',
      'comment_subject_key': '19'
    });
    expect(mention.logisticOutReference, (stage: 'mention', id: 19));
    final invalid = InboxItemModel.fromJson(
        {'module_code': 'logistic-out', 'subject_key': 'trip:0'});
    expect(invalid.logisticOutReference, isNull);
    final attention = InboxItemModel.fromJson({
      'kind': 'mention',
      'notification_type': 'comment_reply',
      'payload': {
        'module_code': 'wms.logistic-out',
        'subject_type': 'wms.logistic_out_po',
        'subject_id': 19
      },
    });
    expect(attention.logisticOutMentionId, 19);
    final noAttention = InboxItemModel.fromJson({
      'comment_module_code': 'wms.logistic-out',
      'comment_subject_type': 'wms.logistic_out_po',
      'comment_subject_key': '19',
    });
    expect(noAttention.logisticOutMentionId, isNull);
  });

  test('resolves Logistic In mention only for the exact line identity', () {
    final item = InboxItemModel.fromJson({
      'has_mention_attention': true,
      'subject_key': 'notification-9',
      'payload': {'subject_type': 'wms.logistic_in_line', 'subject_key': '23'},
    });
    expect(item.logisticInMentionId, 23);
    final wrongType = InboxItemModel.fromJson({
      'has_mention_attention': true,
      'subject_type': 'task',
      'subject_key': '23'
    });
    expect(wrongType.logisticInMentionId, isNull);
    final noAttention = InboxItemModel.fromJson(
        {'subject_type': 'wms.logistic_in_line', 'subject_key': '23'});
    expect(noAttention.logisticInMentionId, isNull);
  });

  test('preserves exact Logistic In assignment or mention detail context', () {
    final assignment = InboxItemModel.fromJson({
      'module_code': 'logistic-in',
      'logistic_in_line_id': 23,
      'logistic_in_item_assignment_id': 91,
    });
    expect(assignment.logisticInDetail,
        (line: '23', assignment: 91, mention: false));
    final mention = InboxItemModel.fromJson({
      'kind': 'mention',
      'notification_type': 'comment_mention',
      'comment_module_code': 'wms.logistic-in',
      'comment_subject_type': 'wms.logistic_in_line',
      'comment_subject_key': '23',
    });
    expect(mention.logisticInDetail,
        (line: '23', assignment: null, mention: true));
    final invalid = InboxItemModel.fromJson(
        {'module_code': 'logistic-in', 'subject_key': '../23'});
    expect(invalid.logisticInDetail, isNull);
  });

  test('Logistic In officer unread count follows web attention precedence', () {
    final item = InboxItemModel.fromJson({
      'module_code': 'logistic-in',
      'subject_type': 'wms.logistic_in_line',
      'logistic_in_item_assignment_id': 5,
      'role_code': 'QC',
      'logistic_in_line_id': 23,
      'item_name': 'Material',
      'supplier_name': 'Supplier',
      'operational_unread': true,
      'mention_unread_count': 2,
      'mention_notification_ids': [7, '8', 7, 0],
    });
    expect(item.unreadCount, 2);
    expect(item.unreadMentionNotificationIds, [7, 8]);
    expect(item.isUnread, isTrue);
    expect(item.title, 'QC: Material');
    expect(item.subtitle, 'Supplier');
    expect(item.readIdentity,
        (module: 'logistic-in', routeKey: '23', type: 'assignment', key: '5'));
  });

  test('Inbox timestamps use Jakarta calendar days', () {
    final now = DateTime.utc(2026, 1, 2, 12);
    expect(inboxRowTime('2026-01-02T03:14:00Z', now: now), '10:14');
    expect(inboxRowTime('2026-01-01T03:14:00Z', now: now), 'Yesterday');
    expect(inboxRowTime('2025-12-31T03:14:00Z', now: now), '31/12/25');
  });
}
