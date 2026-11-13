import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../tasks/providers/task_provider.dart';

enum DashboardPeriod { today, week, month }

extension DashboardPeriodRange on DashboardPeriod {
  String get label => switch (this) {
        DashboardPeriod.today => 'Today',
        DashboardPeriod.week => 'Week',
        DashboardPeriod.month => 'Month',
      };

  (DateTime, DateTime) range(DateTime now) {
    final today = DateTime(now.year, now.month, now.day);
    return switch (this) {
      DashboardPeriod.today => (today, today),
      DashboardPeriod.week => (
          today.subtract(Duration(days: today.weekday - 1)),
          today.add(Duration(days: 7 - today.weekday)),
        ),
      DashboardPeriod.month => (
          DateTime(now.year, now.month),
          DateTime(now.year, now.month + 1, 0),
        ),
    };
  }
}

class DashboardTaskStats {
  final int total, open, inProgress, completed;
  const DashboardTaskStats(
      {required this.total,
      required this.open,
      required this.inProgress,
      required this.completed});
}

/// Read server totals, rather than treating the first task page as all tasks.
final dashboardTaskStatsProvider = FutureProvider.autoDispose
    .family<DashboardTaskStats, DashboardPeriod>((ref, period) async {
  ref.watch(dashboardTasksProvider(period).select((state) => state.tasks));
  final repository = ref.watch(taskRepositoryProvider);
  final (start, end) = period.range(DateTime.now());
  String date(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
  final pages = await Future.wait([
    for (final status in ['all', 'open', 'in_progress', 'completed'])
      repository.fetchTasks(status: status, from: date(start), to: date(end)),
  ]);
  return DashboardTaskStats(
      total: pages[0].total,
      open: pages[1].total,
      inProgress: pages[2].total,
      completed: pages[3].total);
});

/// Keep dashboard date filters separate from the Task Board's filters.
class DashboardTasksNotifier extends StateNotifier<TaskListState> {
  final TaskRepository repository;
  final DashboardPeriod period;
  int _generation = 0;
  DashboardTasksNotifier(this.repository, this.period)
      : super(TaskListState()) {
    loadTasks();
  }

  Future<TaskPage> _fetch(int page) {
    final (start, end) = period.range(DateTime.now());
    String date(DateTime d) =>
        '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
    return repository.fetchTasks(from: date(start), to: date(end), page: page);
  }

  Future<void> loadTasks() async {
    final generation = ++_generation;
    state = state.copyWith(isLoading: true, isLoadingMore: false, error: null);
    try {
      final page = await _fetch(1);
      if (!mounted || generation != _generation) return;
      state = state.copyWith(
          tasks: page.tasks,
          total: page.total,
          page: page.page,
          lastPage: page.lastPage,
          isLoading: false);
    } catch (error) {
      if (mounted && generation == _generation) {
        state = state.copyWith(isLoading: false, error: error.toString());
      }
    }
  }

  Future<void> loadMore() async {
    if (state.isLoading || state.isLoadingMore || state.page >= state.lastPage)
      return;
    final generation = _generation;
    state = state.copyWith(isLoadingMore: true);
    try {
      final page = await _fetch(state.page + 1);
      if (!mounted || generation != _generation) return;
      final seen = state.tasks.map((task) => task.id).toSet();
      state = state.copyWith(
          tasks: [
            ...state.tasks,
            ...page.tasks.where((task) => seen.add(task.id))
          ],
          page: page.page,
          lastPage: page.lastPage,
          total: page.total,
          isLoadingMore: false);
    } catch (error) {
      if (mounted && generation == _generation) {
        state = state.copyWith(
            isLoadingMore: false, loadMoreError: error.toString());
      }
    }
  }
}

final dashboardTasksProvider = StateNotifierProvider.autoDispose
    .family<DashboardTasksNotifier, TaskListState, DashboardPeriod>(
        (ref, period) {
  final notifier =
      DashboardTasksNotifier(ref.watch(taskRepositoryProvider), period);
  ref.listen(taskNotifierProvider.select((state) => state.tasks), (_, __) {
    notifier.loadTasks();
  });
  return notifier;
});
