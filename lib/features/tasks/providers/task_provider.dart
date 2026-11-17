import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/network/api_client.dart';
import '../../../core/realtime/reverb_service.dart';
import '../../auth/providers/auth_provider.dart';

enum TaskScope {
  assignedToMe,
  delegatedByMe,
}

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
    // Robust status extraction: string or Map like {status_name: ...}
    String status = 'in_progress';
    if (json['status'] is String) {
      status = json['status'] as String;
    } else if (json['status'] is Map && json['status']['status_name'] != null) {
      status = json['status']['status_name'].toString();
    } else if (json['status_name'] != null) {
      status = json['status_name'].toString();
    }

    // Robust project name extraction
    String? projectName = json['project_name'] as String?;
    if (projectName == null && json['project'] is Map) {
      projectName = (json['project'] as Map)['name']?.toString();
    }

    // Robust assignees extraction
    final List<String> assignees = [];
    if (json['assignees'] is List) {
      for (final person in (json['assignees'] as List)) {
        if (person is Map) {
          if (person['full_name'] != null &&
              person['full_name'].toString().isNotEmpty) {
            assignees.add(person['full_name'].toString());
          } else if (person['employee'] is Map &&
              person['employee']['full_name'] != null) {
            final name = person['employee']['full_name'].toString();
            if (name.isNotEmpty) assignees.add(name);
          } else if (person['name'] != null) {
            assignees.add(person['name'].toString());
          }
        } else if (person is String && person.isNotEmpty) {
          assignees.add(person);
        }
      }
    } else if (json['assignee'] is Map) {
      final a = json['assignee'] as Map;
      final name = (a['full_name'] ?? a['name'])?.toString();
      if (name != null && name.isNotEmpty) assignees.add(name);
    } else if (json['assigned_to'] != null) {
      assignees.add(json['assigned_to'].toString());
    }

    return TaskItemModel(
      id: json['task_id'] as int? ?? json['id'] as int? ?? 0,
      title: json['title'] as String? ?? json['subject'] as String? ?? 'Task',
      description:
          json['description'] as String? ?? json['detail'] as String? ?? '',
      status: status,
      progressPercent:
          json['progress_percent'] as int? ?? json['progress'] as int? ?? 0,
      dueDate: json['due_date'] as String? ?? '',
      priority: json['priority'] as String? ?? 'medium',
      projectName: projectName,
      rowAction: json['row_action'] as String?,
      hasPendingReview: json['has_pending_review'] == true,
      priorityEligible: json['personal_priority_eligible'] == true,
      isPersonalPriority: json['personal_priority_position'] != null,
      attachmentCount: (json['attachment_count'] as num?)?.toInt() ?? 0,
      assignees: assignees,
    );
  }

  factory TaskItemModel.fromInboxJson(Map<String, dynamic> json) {
    final status = json['status'] as String? ?? 'open';
    final isComplete = json['is_complete'] == true || status == 'completed';
    final title = (json['item_name'] as String?)?.isNotEmpty == true
        ? json['item_name'] as String
        : (json['title'] as String? ?? 'Task')
            .replaceFirst(RegExp(r'^WorkHub:\s*'), '');
    return TaskItemModel(
      id: (json['subject_id'] as num?)?.toInt() ?? 0,
      title: title,
      description: json['description'] as String? ?? '',
      status: status,
      progressPercent:
          isComplete ? 100 : ((json['progress_percent'] as num?)?.toInt() ?? 0),
      dueDate: (json['due_date'] as String? ?? '').split('T').first,
      priority: json['priority'] as String? ?? 'normal',
      projectName: json['project_name'] as String?,
      hasPendingReview: json['pending_review'] == true,
      assignees: json['assignee_name'] != null
          ? [json['assignee_name'].toString()]
          : (json['assigner_name'] != null
              ? [json['assigner_name'].toString()]
              : const []),
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
      {TaskScope scope = TaskScope.assignedToMe,
      String status = 'all',
      String search = '',
      String priority = '',
      String? from,
      String? to,
      int page = 1}) async {
    if (scope == TaskScope.delegatedByMe) {
      return _fetchDelegatedTasks(
        status: status,
        search: search,
        priority: priority,
        from: from,
        to: to,
        page: page,
      );
    }
    try {
      dynamic responseData;
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
        responseData = response.data;
      } on DioException catch (dioErr) {
        if (dioErr.response?.statusCode == 404) {
          final myResponse =
              await _apiClient.dio.get('/tasks/my', queryParameters: {
            if (status != 'all') 'status': status,
            if (search.isNotEmpty) 'search': search,
            if (priority.isNotEmpty) 'priority': priority,
            if (from != null) 'from': from,
            if (to != null) 'to': to,
            'page': page,
            'per_page': 25,
          });
          responseData = myResponse.data;
        } else {
          rethrow;
        }
      }

      if (responseData is Map || responseData is List) {
        final List raw;
        Map? meta;
        if (responseData is List) {
          raw = responseData;
        } else {
          final map = responseData as Map;
          raw =
              (map['data'] ?? map['tasks'] ?? map['incomplete'] ?? []) as List;
          meta = map['meta'] as Map?;
        }

        var parsedTasks = raw
            .map((json) =>
                TaskItemModel.fromJson(Map<String, dynamic>.from(json as Map)))
            .toList();

        return TaskPage(
          tasks: parsedTasks,
          page: meta is Map
              ? (meta['current_page'] as num? ?? page).toInt()
              : page,
          lastPage:
              meta is Map ? (meta['last_page'] as num? ?? page).toInt() : page,
          total: meta is Map
              ? (meta['total'] as num? ?? parsedTasks.length).toInt()
              : parsedTasks.length,
        );
      }
      throw const FormatException('Unexpected task list response');
    } catch (_) {
      rethrow;
    }
  }

  Future<TaskPage> _fetchDelegatedTasks({
    String status = 'all',
    String search = '',
    String priority = '',
    String? from,
    String? to,
    int page = 1,
  }) async {
    try {
      dynamic responseData;
      // Try dedicated endpoint /tasks/assigned first
      try {
        final assignedResponse =
            await _apiClient.dio.get('/tasks/assigned', queryParameters: {
          if (status != 'all') 'status': status,
          if (search.isNotEmpty) 'search': search,
          if (priority.isNotEmpty) 'priority': priority,
          'page': page,
          'per_page': 25,
        });
        if (assignedResponse.data is Map || assignedResponse.data is List) {
          responseData = assignedResponse.data;
        } else {
          throw FormatException(
              'Unexpected response type: ${assignedResponse.data.runtimeType}');
        }
      } catch (e) {
        // Fallback to inbox delegated tasks
        final view = status == 'completed'
            ? 'complete'
            : (status == 'open' ||
                    status == 'in_progress' ||
                    status == 'overdue')
                ? 'incomplete'
                : 'all';
        final response = await _apiClient.dio.get(
          '/inbox/api/todos',
          queryParameters: {
            'view': view,
            if (search.isNotEmpty) 'search': search,
          },
        );
        responseData = response.data;
      }

      if (responseData is Map || responseData is List) {
        final List raw;
        Map? meta;
        bool isFromInbox = false;

        if (responseData is List) {
          raw = responseData;
        } else {
          final map = responseData as Map;
          raw =
              (map['data'] ?? map['tasks'] ?? map['incomplete'] ?? []) as List;
          meta = map['meta'] as Map?;
          if (map.containsKey('view') ||
              raw.any((item) =>
                  item is Map &&
                  item['id'].toString().startsWith('task-assigned-'))) {
            isFromInbox = true;
          }
        }

        final now = DateTime.now();
        final todayStr =
            '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';

        List<TaskItemModel> items;
        if (isFromInbox) {
          items = raw
              .whereType<Map>()
              .where(
                  (item) => item['id'].toString().startsWith('task-assigned-'))
              .map((json) =>
                  TaskItemModel.fromInboxJson(Map<String, dynamic>.from(json)))
              .toList();
        } else {
          items = raw
              .whereType<Map>()
              .map((json) =>
                  TaskItemModel.fromJson(Map<String, dynamic>.from(json)))
              .toList();
        }

        if (status == 'overdue') {
          items = items.where((t) {
            final isComplete = t.status == 'completed';
            return !isComplete &&
                (t.status == 'overdue' ||
                    (t.dueDate.isNotEmpty &&
                        t.dueDate.compareTo(todayStr) < 0));
          }).toList();
        } else if (from != null && to != null) {
          items = items.where((t) {
            if (t.dueDate.isEmpty) return true;
            final due = t.dueDate.split('T').first;
            return due.compareTo(from) >= 0 && due.compareTo(to) <= 0;
          }).toList();
        }

        if (priority.isNotEmpty) {
          items = items
              .where((t) => t.priority.toLowerCase() == priority.toLowerCase())
              .toList();
        }

        const perPage = 25;
        final total = meta != null && meta['total'] != null
            ? (meta['total'] as num).toInt()
            : items.length;
        final lastPage = meta != null && meta['last_page'] != null
            ? (meta['last_page'] as num).toInt()
            : (total / perPage).ceil().clamp(1, 999);
        final startIndex = ((page - 1) * perPage).clamp(0, items.length);
        final endIndex = (startIndex + perPage).clamp(0, items.length);
        final paginated =
            meta != null ? items : items.sublist(startIndex, endIndex);

        return TaskPage(
          tasks: paginated,
          page: page,
          lastPage: lastPage,
          total: total,
        );
      }
      return TaskPage(tasks: [], page: 1, lastPage: 1, total: 0);
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
    try {
      final response = await _apiClient.dio.get('/tasks/my/priorities');
      if (response.data is List) {
        return {'data': response.data};
      } else if (response.data is Map) {
        return Map<String, dynamic>.from(response.data as Map);
      }
    } catch (_) {
      try {
        final fallback = await _apiClient.dio.get('/tasks/priorities');
        if (fallback.data is Map) {
          return Map<String, dynamic>.from(fallback.data as Map);
        }
      } catch (_) {}
    }
    return {'data': []};
  }

  Future<void> addPriority(int taskId) async {
    try {
      await _apiClient.dio.post('/tasks/my/priorities/$taskId');
    } catch (_) {
      await _apiClient.dio.post('/tasks/priorities/$taskId');
    }
  }

  Future<void> removePriority(int taskId) async {
    try {
      await _apiClient.dio.delete('/tasks/my/priorities/$taskId');
    } catch (_) {
      await _apiClient.dio.delete('/tasks/priorities/$taskId');
    }
  }

  Future<bool> completeTask(int taskId) async {
    try {
      final response = await _apiClient.dio.post('/tasks/$taskId/complete');
      final statusCode = response.statusCode;
      return statusCode != null && statusCode >= 200 && statusCode < 300;
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
  final TaskScope scope;

  TaskListState({
    this.tasks = const [],
    this.isLoading = false,
    this.error,
    this.page = 1,
    this.lastPage = 1,
    this.isLoadingMore = false,
    this.loadMoreError,
    this.total = 0,
    this.scope = TaskScope.assignedToMe,
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
    TaskScope? scope,
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
      scope: scope ?? this.scope,
    );
  }
}

class TaskNotifier extends StateNotifier<TaskListState> {
  final TaskRepository _repo;
  final ReverbRealtimeService _reverb;
  final int? _userId;
  int _generation = 0;
  TaskScope _scope = TaskScope.assignedToMe;
  String _status = 'all';
  String _search = '';
  String _priority = '';
  String? _from;
  String? _to;
  bool _hasLoaded = false;

  TaskNotifier(this._repo, this._reverb, this._userId)
      : super(TaskListState()) {
    loadTasks();
    _setupRealtime();
  }

  TaskScope get scope => _scope;

  Future<void> loadTasks(
      {TaskScope? scope,
      String? status,
      String? search,
      String? priority,
      String? from,
      String? to,
      bool clearDateRange = false,
      bool showLoading = true}) async {
    _scope = scope ?? _scope;
    _status = status ?? _status;
    _search = search ?? _search;
    _priority = priority ?? _priority;
    _from = clearDateRange ? null : from ?? _from;
    _to = clearDateRange ? null : to ?? _to;
    final generation = ++_generation;
    if (showLoading && !_hasLoaded) {
      state = state.copyWith(
          isLoading: true, isLoadingMore: false, error: null, scope: _scope);
    }
    try {
      final page = await _repo.fetchTasks(
          scope: _scope,
          status: _status,
          search: _search,
          priority: _priority,
          from: _from,
          to: _to);
      if (!mounted || generation != _generation) return;
      _hasLoaded = true;
      state = state.copyWith(
          tasks: page.tasks,
          page: page.page,
          lastPage: page.lastPage,
          total: page.total,
          isLoading: false,
          scope: _scope);
    } catch (e) {
      if (!mounted || generation != _generation) return;
      _hasLoaded = true;
      state =
          state.copyWith(isLoading: false, error: e.toString(), scope: _scope);
    }
  }

  Future<void> loadMore() async {
    if (state.isLoading || state.isLoadingMore || state.page >= state.lastPage)
      return;
    final generation = _generation;
    state = state.copyWith(isLoadingMore: true);
    try {
      final page = await _repo.fetchTasks(
          scope: _scope,
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
      _reverb.subscribe('private-inbox.user.$_userId', (eventData) {
        loadTasks(showLoading: false);
      });
      _reverb.subscribe('private-App.Models.User.$_userId', (eventData) {
        loadTasks(showLoading: false);
      });
    }

    _reverb.subscribe('task-updates', (eventData) {
      loadTasks(showLoading: false);
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
