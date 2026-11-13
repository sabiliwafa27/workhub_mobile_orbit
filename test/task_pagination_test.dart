import 'dart:async';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:workhub_mobile/core/network/api_client.dart';
import 'package:workhub_mobile/core/realtime/reverb_service.dart';
import 'package:workhub_mobile/features/tasks/providers/task_provider.dart';

TaskItemModel item(int id) => TaskItemModel(id: id, title: 'Task $id', description: '', status: 'open', progressPercent: 0, dueDate: '', priority: 'normal');

class _Repository extends TaskRepository {
  _Repository(ApiClient client) : super(client);
  int firstPageCalls = 0;
  final older = Completer<TaskPage>();
  @override
  Future<TaskPage> fetchTasks({String status = 'all', int page = 1}) async {
    if (page == 2) return older.future;
    firstPageCalls++;
    return TaskPage(tasks: [item(firstPageCalls == 1 ? 1 : 3)], page: 1, lastPage: 2, total: 2);
  }
}

class _RetryRepository extends TaskRepository {
  _RetryRepository(ApiClient client) : super(client);
  int pageTwoCalls = 0;
  @override
  Future<TaskPage> fetchTasks({String status = 'all', int page = 1}) async {
    if (page == 2 && pageTwoCalls++ == 0) throw Exception('Network error');
    return TaskPage(tasks: [item(page)], page: page, lastPage: 2, total: 2);
  }
}

class _OverlapRepository extends TaskRepository {
  _OverlapRepository(ApiClient client) : super(client);
  @override
  Future<TaskPage> fetchTasks({String status = 'all', int page = 1}) async => TaskPage(
    tasks: page == 1 ? [item(1), item(2)] : [item(2), item(3)], page: page, lastPage: 2, total: 3,
  );
}

void main() {
  test('overlapping task pages do not duplicate rows', () async {
    final api = ApiClient(customDio: Dio());
    final notifier = TaskNotifier(_OverlapRepository(api), ReverbRealtimeService(api), null);
    addTearDown(notifier.dispose);
    await Future<void>.delayed(Duration.zero);
    await notifier.loadMore();
    expect(notifier.state.tasks.map((task) => task.id), [1, 2, 3]);
  });

  test('failed next page retains existing tasks and can be retried', () async {
    final api = ApiClient(customDio: Dio());
    final notifier = TaskNotifier(_RetryRepository(api), ReverbRealtimeService(api), null);
    addTearDown(notifier.dispose);
    await Future<void>.delayed(Duration.zero);
    await notifier.loadMore();
    expect(notifier.state.tasks.map((task) => task.id), [1]);
    expect(notifier.state.loadMoreError, isNotNull);
    await notifier.loadMore();
    expect(notifier.state.tasks.map((task) => task.id), [1, 2]);
    expect(notifier.state.loadMoreError, isNull);
  });

  test('refresh ignores an older page that completes afterward', () async {
    final api = ApiClient(customDio: Dio());
    final repository = _Repository(api);
    final notifier = TaskNotifier(repository, ReverbRealtimeService(api), null);
    addTearDown(notifier.dispose);
    await Future<void>.delayed(Duration.zero);
    final loadingOlder = notifier.loadMore();
    await notifier.loadTasks();
    repository.older.complete(TaskPage(tasks: [item(2)], page: 2, lastPage: 2, total: 2));
    await loadingOlder;
    expect(notifier.state.tasks.map((task) => task.id), [3]);
    expect(notifier.state.page, 1);
    expect(notifier.state.isLoadingMore, isFalse);
  });
}
