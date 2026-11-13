import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/network/api_client.dart';
import '../../../core/realtime/reverb_service.dart';
import '../../auth/providers/auth_provider.dart';

class TaskItemModel {
  final int id;
  final String title;
  final String description;
  final String status;
  final int progressPercent;
  final String dueDate;
  final String priority;
  final String? projectName;
  final String? rowAction;
  final bool hasPendingReview;
  final bool priorityEligible;
  final bool isPersonalPriority;
  final int attachmentCount;
  final List<String> assignees;

  TaskItemModel({
    required this.id,
    required this.title,
    required this.description,
    required this.status,
    required this.progressPercent,
    required this.dueDate,
    required this.priority,
    this.projectName,
    this.rowAction,
    this.hasPendingReview = false,
    this.priorityEligible = false,
    this.isPersonalPriority = false,
    this.attachmentCount = 0,
    this.assignees = const [],
  });

  factory TaskItemModel.fromJson(Map<String, dynamic> json) {
    return TaskItemModel(
      id: json['task_id'] as int? ?? json['id'] as int? ?? 0,
      title: json['title'] as String? ?? json['subject'] as String? ?? 'Task',
      description:
          json['description'] as String? ?? json['detail'] as String? ?? '',
      status: json['status'] as String? ?? 'in_progress',
      progressPercent:
          json['progress_percent'] as int? ?? json['progress'] as int? ?? 0,
      dueDate: json['due_date'] as String? ?? '',
      priority: json['priority'] as String? ?? 'medium',
      projectName: json['project_name'] as String?,
      rowAction: json['row_action'] as String?,
      hasPendingReview: json['has_pending_review'] == true,
      priorityEligible: json['personal_priority_eligible'] == true,
      isPersonalPriority: json['personal_priority_position'] != null,
      attachmentCount: (json['attachment_count'] as num?)?.toInt() ?? 0,
      assignees:
          (json['assignees'] is List ? json['assignees'] as List : const [])
              .whereType<Map>()
              .map((person) => (person['full_name'] ?? '').toString())
              .where((name) => name.isNotEmpty)
              .toList(),
    );
  }
}

final taskRepositoryProvider = Provider<TaskRepository>((ref) {
  final apiClient = ref.watch(apiClientProvider);
  return TaskRepository(apiClient);
});

class TaskRepository {
  final ApiClient _apiClient;

  TaskRepository(this._apiClient);

  Future<TaskPage> fetchTasks(
      {String status = 'all',
      String search = '',
      String priority = '',
      String? from,
      String? to,
      int page = 1}) async {
    try {
      final response = await _apiClient.dio.get('/tasks', queryParameters: {
        'status': status,
        'search': search,
        if (priority.isNotEmpty) 'priority': priority,
        if (from != null) 'from': from,
        if (to != null) 'to': to,
        'page': page,
        'per_page': 25,
      });
      if (response.data is Map) {
        final raw = response.data['data'] ??
            response.data['tasks'] ??
            response.data['incomplete'];
        if (raw is List) {
          final meta = response.data['meta'];
          return TaskPage(
            tasks: raw
                .map((json) =>
                    TaskItemModel.fromJson(json as Map<String, dynamic>))
                .toList(),
            page: meta is Map
                ? (meta['current_page'] as num? ?? page).toInt()
                : page,
            lastPage: meta is Map
                ? (meta['last_page'] as num? ?? page).toInt()
                : page,
            total: meta is Map
                ? (meta['total'] as num? ?? raw.length).toInt()
                : raw.length,
          );
        }
      }
      throw const FormatException('Unexpected task list response');
    } catch (_) {
      rethrow;
    }
  }

  Future<Map<String, dynamic>?> fetchTaskDetail(int taskId) async {
    try {
      final response = await _apiClient.dio.get('/tasks/$taskId/payload');
      if (response.data is Map) {
        return response.data as Map<String, dynamic>;
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  Future<Map<String, dynamic>> fetchPriorities() async {
    final response = await _apiClient.dio.get('/tasks/priorities');
    if (response.data is! Map)
      throw const FormatException('Unexpected priority response');
    return Map<String, dynamic>.from(response.data as Map);
  }

  Future<void> addPriority(int taskId) async =>
      _apiClient.dio.post('/tasks/priorities/$taskId');
  Future<void> removePriority(int taskId) async =>
      _apiClient.dio.delete('/tasks/priorities/$taskId');

  Future<bool> completeTask(int taskId) async {
    try {
      final response = await _apiClient.dio.post('/tasks/$taskId/complete');
      return response.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  Future<bool> requestReview(int taskId, {String? notes}) async {
    try {
      final response = await _apiClient.dio.post(
        '/tasks/$taskId/request-review',
        data: notes != null ? {'note': notes} : null,
      );
      return response.statusCode == 200;
    } catch (_) {
      return false;
    }
  }
}

class TaskPage {
  final List<TaskItemModel> tasks;
  final int page;
  final int lastPage;
  final int total;
  TaskPage(
      {required this.tasks,
      required this.page,
      required this.lastPage,
      required this.total});
}

class TaskListState {
  final List<TaskItemModel> tasks;
  final bool isLoading;
  final String? error;
  final int page;
  final int lastPage;
  final bool isLoadingMore;
  final String? loadMoreError;
  final int total;

  TaskListState({
    this.tasks = const [],
    this.isLoading = false,
    this.error,
    this.page = 1,
    this.lastPage = 1,
    this.isLoadingMore = false,
    this.loadMoreError,
    this.total = 0,
  });

  TaskListState copyWith({
    List<TaskItemModel>? tasks,
    bool? isLoading,
    String? error,
    int? page,
    int? lastPage,
    bool? isLoadingMore,
    String? loadMoreError,
    int? total,
  }) {
    return TaskListState(
      tasks: tasks ?? this.tasks,
      isLoading: isLoading ?? this.isLoading,
      error: error,
      page: page ?? this.page,
      lastPage: lastPage ?? this.lastPage,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
      loadMoreError: loadMoreError,
      total: total ?? this.total,
    );
  }
}

class TaskNotifier extends StateNotifier<TaskListState> {
  final TaskRepository _repo;
  final ReverbRealtimeService _reverb;
  final int? _userId;
  int _generation = 0;
  String _status = 'all';
  String _search = '';
  String _priority = '';
  String? _from;
  String? _to;

  TaskNotifier(this._repo, this._reverb, this._userId)
      : super(TaskListState()) {
    loadTasks();
    _setupRealtime();
  }

  Future<void> loadTasks(
      {String? status,
      String? search,
      String? priority,
      String? from,
      String? to,
      bool clearDateRange = false}) async {
    _status = status ?? _status;
    _search = search ?? _search;
    _priority = priority ?? _priority;
    _from = clearDateRange ? null : from ?? _from;
    _to = clearDateRange ? null : to ?? _to;
    final generation = ++_generation;
    state = state.copyWith(isLoading: true, isLoadingMore: false, error: null);
    try {
      final page = await _repo.fetchTasks(
          status: _status,
          search: _search,
          priority: _priority,
          from: _from,
          to: _to);
      if (!mounted || generation != _generation) return;
      state = state.copyWith(
          tasks: page.tasks,
          page: page.page,
          lastPage: page.lastPage,
          total: page.total,
          isLoading: false);
    } catch (e) {
      if (!mounted || generation != _generation) return;
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  Future<void> loadMore() async {
    if (state.isLoading || state.isLoadingMore || state.page >= state.lastPage)
      return;
    final generation = _generation;
    state = state.copyWith(isLoadingMore: true);
    try {
      final page = await _repo.fetchTasks(
          status: _status,
          search: _search,
          priority: _priority,
          from: _from,
          to: _to,
          page: state.page + 1);
      if (!mounted || generation != _generation) return;
      final existing = state.tasks.map((task) => task.id).toSet();
      state = state.copyWith(
          tasks: [
            ...state.tasks,
            ...page.tasks.where((task) => !existing.contains(task.id))
          ],
          page: page.page,
          lastPage: page.lastPage,
          total: page.total,
          isLoadingMore: false);
    } catch (e) {
      if (!mounted || generation != _generation) return;
      state = state.copyWith(isLoadingMore: false, loadMoreError: e.toString());
    }
  }

  Future<void> completeTask(int taskId) async {
    await _repo.completeTask(taskId);
    await loadTasks();
  }

  void _setupRealtime() {
    if (_userId != null) {
      _reverb.subscribe('private-App.Models.User.$_userId', (eventData) {
        loadTasks();
      });
    }

    _reverb.subscribe('task-updates', (eventData) {
      loadTasks();
    });
  }
}

final taskNotifierProvider =
    StateNotifierProvider<TaskNotifier, TaskListState>((ref) {
  final repo = ref.watch(taskRepositoryProvider);
  final reverb = ref.watch(reverbServiceProvider);
  final user = ref.watch(authProvider).user;
  return TaskNotifier(repo, reverb, user?.id);
});
