import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/network/api_client.dart';
import '../../../core/realtime/reverb_service.dart';
import '../../auth/providers/auth_provider.dart';
import '../../tasks/providers/task_provider.dart';

final projectTasksProvider = FutureProvider.family<List<TaskItemModel>, int>((ref, projectId) async {
  final response = await ref.watch(apiClientProvider).dio.get('/projects/$projectId/tasks');
  final data = response.data;
  if (data is! Map || data['data'] is! List) {
    throw const FormatException('Unexpected project tasks response');
  }
  return (data['data'] as List)
      .map((item) => TaskItemModel.fromJson(Map<String, dynamic>.from(item as Map)))
      .toList();
});

class ProjectItemModel {
  final int id;
  final String name;
  final String description;
  final int progress;
  final int activeTasks;
  final int completedTasks;
  final String status;

  ProjectItemModel({
    required this.id,
    required this.name,
    required this.description,
    required this.progress,
    required this.activeTasks,
    required this.completedTasks,
    required this.status,
  });

  factory ProjectItemModel.fromJson(Map<String, dynamic> json) {
    return ProjectItemModel(
      id: json['id'] as int? ?? json['project_id'] as int? ?? 0,
      name: json['name'] as String? ?? json['title'] as String? ?? 'Project',
      description: json['description'] as String? ?? '',
      progress: json['progress'] as int? ?? json['progress_percent'] as int? ?? 0,
      activeTasks: json['active_tasks'] as int? ?? json['open_count'] as int? ?? 0,
      completedTasks: json['completed_tasks'] as int? ?? json['completed_count'] as int? ?? 0,
      status: json['status'] as String? ?? 'active',
    );
  }
}

final projectRepositoryProvider = Provider<ProjectRepository>((ref) {
  final apiClient = ref.watch(apiClientProvider);
  return ProjectRepository(apiClient);
});

class ProjectRepository {
  final ApiClient _apiClient;

  ProjectRepository(this._apiClient);

  Future<List<ProjectItemModel>> fetchProjects() async {
    try {
      final response = await _apiClient.dio.get('/projects');
      if (response.data is Map) {
        final raw = response.data['data'] ?? response.data['projects'] ?? response.data['tasks'];
        if (raw is List) {
          return raw.map((json) => ProjectItemModel.fromJson(json as Map<String, dynamic>)).toList();
        }
      }
      return [];
    } catch (_) {
      rethrow;
    }
  }

  Future<Map<String, dynamic>?> fetchProjectDetail(int projectId) async {
    try {
      final response = await _apiClient.dio.get('/projects/$projectId/tasks');
      if (response.data is Map) {
        return response.data as Map<String, dynamic>;
      }
      return null;
    } catch (_) {
      return null;
    }
  }
}

class ProjectListState {
  final List<ProjectItemModel> projects;
  final bool isLoading;
  final String? error;

  ProjectListState({
    this.projects = const [],
    this.isLoading = false,
    this.error,
  });

  ProjectListState copyWith({
    List<ProjectItemModel>? projects,
    bool? isLoading,
    String? error,
  }) {
    return ProjectListState(
      projects: projects ?? this.projects,
      isLoading: isLoading ?? this.isLoading,
      error: error,
    );
  }
}

class ProjectNotifier extends StateNotifier<ProjectListState> {
  final ProjectRepository _repo;
  final ReverbRealtimeService _reverb;
  final int? _userId;

  ProjectNotifier(this._repo, this._reverb, this._userId) : super(ProjectListState()) {
    loadProjects();
    _setupRealtime();
  }

  Future<void> loadProjects() async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final items = await _repo.fetchProjects();
      state = state.copyWith(projects: items, isLoading: false);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  void _setupRealtime() {
    if (_userId != null) {
      _reverb.subscribe('private-App.Models.User.$_userId', (eventData) {
        loadProjects();
      });
    }

    _reverb.subscribe('ec-updates', (eventData) {
      loadProjects();
    });
  }
}

final projectNotifierProvider = StateNotifierProvider<ProjectNotifier, ProjectListState>((ref) {
  final repo = ref.watch(projectRepositoryProvider);
  final reverb = ref.watch(reverbServiceProvider);
  final user = ref.watch(authProvider).user;
  return ProjectNotifier(repo, reverb, user?.id);
});
