import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/network/api_client.dart';
import '../../../core/realtime/reverb_service.dart';
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
      id: json['id'] as int? ?? json['task_id'] as int? ?? 0,
      name: json['name'] as String? ?? json['title'] as String? ?? json['subject'] as String? ?? 'Project',
      description: json['description'] as String? ?? json['detail'] as String? ?? '',
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
      final response = await _apiClient.dio.get('/inbox/api/todos', queryParameters: {
        'source': 'workhub_ec',
        'view': 'incomplete',
      });
      if (response.data is Map) {
        final raw = response.data['tasks'] ?? response.data['incomplete'] ?? response.data['data'];
        if (raw is List) {
          return raw.map((json) => ProjectItemModel.fromJson(json as Map<String, dynamic>)).toList();
        }
      }
      return [];
    } catch (_) {
      return [];
    }
  }

  Future<Map<String, dynamic>?> fetchProjectDetail(int ecId) async {
    try {
      final response = await _apiClient.dio.get('/inbox/api/workhub-tasks/ec/$ecId/detail');
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
