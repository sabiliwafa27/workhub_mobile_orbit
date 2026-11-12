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

  TaskItemModel({
    required this.id,
    required this.title,
    required this.description,
    required this.status,
    required this.progressPercent,
    required this.dueDate,
    required this.priority,
  });

  factory TaskItemModel.fromJson(Map<String, dynamic> json) {
    return TaskItemModel(
      id: json['task_id'] as int? ?? json['id'] as int? ?? 0,
      title: json['title'] as String? ?? json['subject'] as String? ?? 'Task',
      description: json['description'] as String? ?? json['detail'] as String? ?? '',
      status: json['status'] as String? ?? 'in_progress',
      progressPercent: json['progress_percent'] as int? ?? json['progress'] as int? ?? 0,
      dueDate: json['due_date'] as String? ?? json['created_at'] as String? ?? '',
      priority: json['priority'] as String? ?? 'medium',
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

  Future<List<TaskItemModel>> fetchTasks({String status = 'all'}) async {
    try {
      final response = await _apiClient.dio.get('/tasks', queryParameters: {
        'status': status,
      });
      if (response.data is Map) {
        final raw = response.data['data'] ?? response.data['tasks'] ?? response.data['incomplete'];
        if (raw is List) {
          return raw.map((json) => TaskItemModel.fromJson(json as Map<String, dynamic>)).toList();
        }
      }
      return [];
    } catch (_) {
      return [];
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
        data: notes != null ? {'notes': notes} : null,
      );
      return response.statusCode == 200;
    } catch (_) {
      return false;
    }
  }
}

class TaskListState {
  final List<TaskItemModel> tasks;
  final bool isLoading;
  final String? error;

  TaskListState({
    this.tasks = const [],
    this.isLoading = false,
    this.error,
  });

  TaskListState copyWith({
    List<TaskItemModel>? tasks,
    bool? isLoading,
    String? error,
  }) {
    return TaskListState(
      tasks: tasks ?? this.tasks,
      isLoading: isLoading ?? this.isLoading,
      error: error,
    );
  }
}

class TaskNotifier extends StateNotifier<TaskListState> {
  final TaskRepository _repo;
  final ReverbRealtimeService _reverb;
  final int? _userId;

  TaskNotifier(this._repo, this._reverb, this._userId) : super(TaskListState()) {
    loadTasks();
    _setupRealtime();
  }

  Future<void> loadTasks({String status = 'all'}) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final items = await _repo.fetchTasks(status: status);
      state = state.copyWith(tasks: items, isLoading: false);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
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

final taskNotifierProvider = StateNotifierProvider<TaskNotifier, TaskListState>((ref) {
  final repo = ref.watch(taskRepositoryProvider);
  final reverb = ref.watch(reverbServiceProvider);
  final user = ref.watch(authProvider).user;
  return TaskNotifier(repo, reverb, user?.id);
});
