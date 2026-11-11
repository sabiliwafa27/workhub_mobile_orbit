import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/realtime/reverb_service.dart';
import '../../auth/providers/auth_provider.dart';

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
      id: json['id'] as int? ?? 0,
      name: json['name'] as String? ?? json['title'] as String? ?? 'Project',
      description: json['description'] as String? ?? '',
      progress: json['progress'] as int? ?? json['progress_percent'] as int? ?? 0,
      activeTasks: json['active_tasks'] as int? ?? 0,
      completedTasks: json['completed_tasks'] as int? ?? 0,
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
      final response = await _apiClient.dio.get('/sso/inbox/ec');
      if (response.data is Map && response.data['data'] is List) {
        final list = response.data['data'] as List;
        return list.map((json) => ProjectItemModel.fromJson(json as Map<String, dynamic>)).toList();
      }
      return [];
    } catch (_) {
      return [];
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

    _reverb.subscribe('project-updates', (eventData) {
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
