import 'dart:async';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:workhub_mobile/core/network/api_client.dart';
import 'package:workhub_mobile/core/realtime/reverb_service.dart';
import 'package:workhub_mobile/features/inbox/models/inbox_item_model.dart';
import 'package:workhub_mobile/features/inbox/providers/inbox_provider.dart';

class _Repository extends InboxRepository {
  _Repository(ApiClient client) : super(client);
  final slow = Completer<InboxFetchResult>();
  @override
  Future<InboxFetchResult> fetchTodos(
      {String status = 'pending', String search = ''}) async {
    if (search == 'old') return slow.future;
    return InboxFetchResult(items: [
      InboxItemModel.fromJson({'title': search.isEmpty ? 'Initial' : search})
    ]);
  }
}

class _PartialRepository extends InboxRepository {
  _PartialRepository(ApiClient client) : super(client);
  int calls = 0;
  @override
  Future<InboxFetchResult> fetchTodos(
      {String status = 'pending', String search = ''}) async {
    calls++;
    return calls == 1
        ? InboxFetchResult(
            items: [], incompleteCount: 3, incompleteUnreadCount: 2)
        : InboxFetchResult(items: []);
  }
}

void main() {
  test('a response without counts clears previous counts', () async {
    final api = ApiClient(customDio: Dio());
    final repository = _PartialRepository(api);
    final notifier =
        InboxNotifier(repository, ReverbRealtimeService(api), null);
    addTearDown(notifier.dispose);
    await Future<void>.delayed(Duration.zero);
    expect(notifier.state.incompleteCount, 3);
    await notifier.loadInbox();
    expect(notifier.state.incompleteCount, isNull);
    expect(notifier.state.incompleteUnreadCount, isNull);
  });

  test('an older Inbox response cannot replace newer search results', () async {
    final api = ApiClient(customDio: Dio());
    final repository = _Repository(api);
    final notifier =
        InboxNotifier(repository, ReverbRealtimeService(api), null);
    addTearDown(notifier.dispose);
    await Future<void>.delayed(Duration.zero);
    final oldRequest = notifier.loadInbox(search: 'old');
    await notifier.loadInbox(status: 'complete', search: 'new');
    repository.slow.complete(InboxFetchResult(items: [
      InboxItemModel.fromJson({'title': 'Old result'})
    ]));
    await oldRequest;
    expect(notifier.state.items.single.title, 'new');
    expect(notifier.state.status, 'complete');
    expect(notifier.state.search, 'new');
  });
}
