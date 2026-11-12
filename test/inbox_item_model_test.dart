import 'package:flutter_test/flutter_test.dart';
import 'package:workhub_mobile/features/inbox/models/inbox_item_model.dart';

void main() {
  test('accepts composite and numeric inbox identifiers', () {
    expect(InboxItemModel.fromJson({'id': 'ec:123'}).id, 'ec:123');
    expect(InboxItemModel.fromJson({'id': 42}).id, '42');
    expect(InboxItemModel.fromJson({'subject_key': '17'}).id, '17');
  });
}
