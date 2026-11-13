import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dio/dio.dart';
import '../../../core/network/api_client.dart';
import '../../../core/realtime/reverb_service.dart';
import '../../auth/providers/auth_provider.dart';
import '../models/inbox_item_model.dart';

final inboxRepositoryProvider = Provider<InboxRepository>((ref) {
  final apiClient = ref.watch(apiClientProvider);
  return InboxRepository(apiClient);
});

String inboxErrorMessage(Object error) {
  if (error is DioException && error.response?.statusCode == 403) {
    return 'You do not have access to Inbox. Contact your administrator.';
  }
  if (error is DioException && error.response?.statusCode == 401) {
    return 'Inbox authentication was rejected. Sign in again or contact your administrator.';
  }
  return 'Unable to load Inbox. Please try again.';
}

class InboxRepository {
  final ApiClient _apiClient;

  InboxRepository(this._apiClient);

  Future<InboxFetchResult> fetchTodos({String status = 'pending', String search = ''}) async {
    try {
      final view = status == 'complete' ? 'complete' : 'incomplete';
      final response = await _apiClient.dio.get('/inbox/api/todos', queryParameters: {'view': view, if (search.isNotEmpty) 'search': search});
      if (response.data is Map) {
        final raw = response.data['tasks'] ?? response.data[view] ?? response.data['data'];
        if (raw is List) {
          final data = response.data as Map;
          List<InboxItemModel> parse(Object? rows) => rows is List
              ? rows.map((row) => InboxItemModel.fromJson(Map<String, dynamic>.from(row as Map))).toList()
              : [];
          final current = parse(raw);
          final incomplete = data['incomplete'] is List ? parse(data['incomplete']) : (view == 'incomplete' ? current : <InboxItemModel>[]);
          final complete = data['complete'] is List ? parse(data['complete']) : (view == 'complete' ? current : <InboxItemModel>[]);
          final allItems = [...incomplete, ...complete];
          return InboxFetchResult(
            items: current,
            incompleteCount: (data['incomplete_count'] as num?)?.toInt(),
            completeCount: (data['complete_count'] as num?)?.toInt(),
            incompleteUnreadCount: data['incomplete'] is List ? incomplete.where((item) => item.isUnread).length : null,
            completeUnreadCount: data['complete'] is List ? complete.where((item) => item.isUnread).length : null,
            sources: {for (final item in allItems) item.filterSource: item.filterSourceLabel},
            sourceCounts: data['incomplete'] is List && data['complete'] is List ? {
              for (final source in allItems.map((item) => item.filterSource).toSet()) source: [
                incomplete.where((item) => item.filterSource == source).length,
                complete.where((item) => item.filterSource == source).length,
                incomplete.where((item) => item.filterSource == source && item.isUnread).length,
                complete.where((item) => item.filterSource == source && item.isUnread).length,
              ],
            } : const {},
            sourceCountsComplete: data['incomplete'] is List && data['complete'] is List,
            guestActions: data['guest_actions'] is Map ? Map<String, dynamic>.from(data['guest_actions'] as Map) : const {},
            canCompleteComment: data['can_complete_comment'] == true,
          );
        }
      }
      throw const FormatException('Unexpected Inbox response');
    } catch (_) {
      rethrow;
    }
  }

  Future<bool> markRead(String module, String subjectKey, {String? readSubjectType, String? readSubjectKey}) async {
    try {
      final response = await _apiClient.dio.post('/inbox/api/${Uri.encodeComponent(module)}/${Uri.encodeComponent(subjectKey)}/mark-read',
          data: readSubjectType != null && readSubjectKey != null ? {'read_subject_type': readSubjectType, 'read_subject_key': readSubjectKey} : null);
      return response.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  Future<void> markMentionNotificationsRead(List<int> ids) async {
    await Future.wait(ids.toSet().map((id) => _apiClient.dio.post('/inbox/api/notifications/$id/read')));
  }

  Future<bool> completeTodo(String module, String subjectKey) async {
    try {
      final response = await _apiClient.dio.post('/inbox/api/$module/$subjectKey/complete');
      return response.statusCode == 200;
    } catch (_) {
      return false;
    }
  }
}

class InboxFetchResult {
  final List<InboxItemModel> items;
  final int? incompleteCount;
  final int? completeCount;
  final Map<String, dynamic> guestActions;
  final bool canCompleteComment;
  final int? incompleteUnreadCount;
  final int? completeUnreadCount;
  final Map<String, String> sources;
  final Map<String, List<int>> sourceCounts;
  final bool sourceCountsComplete;
  InboxFetchResult({required this.items, this.incompleteCount, this.completeCount, this.guestActions = const {}, this.canCompleteComment = false,
    this.incompleteUnreadCount, this.completeUnreadCount, this.sources = const {}, this.sourceCounts = const {}, this.sourceCountsComplete = false});
}

class InboxListState {
  final List<InboxItemModel> items;
  final bool isLoading;
  final String? error;
  final int? incompleteCount;
  final int? completeCount;
  final Map<String, dynamic> guestActions;
  final bool canCompleteComment;
  final int? incompleteUnreadCount;
  final int? completeUnreadCount;
  final Map<String, String> sources;
  final Map<String, List<int>> sourceCounts;
  final bool sourceCountsComplete;
  final String status;
  final String search;

  InboxListState({
    this.items = const [],
    this.isLoading = false,
    this.error,
    this.incompleteCount,
    this.completeCount,
    this.guestActions = const {},
    this.canCompleteComment = false,
    this.incompleteUnreadCount,
    this.completeUnreadCount,
    this.sources = const {},
    this.sourceCounts = const {},
    this.sourceCountsComplete = false,
    this.status = 'pending',
    this.search = '',
  });

  InboxListState copyWith({
    List<InboxItemModel>? items,
    bool? isLoading,
    String? error,
    int? incompleteCount,
    int? completeCount,
    Map<String, dynamic>? guestActions,
    bool? canCompleteComment,
    int? incompleteUnreadCount,
    int? completeUnreadCount,
    Map<String, String>? sources,
    Map<String, List<int>>? sourceCounts,
    bool? sourceCountsComplete,
    String? status,
    String? search,
  }) {
    return InboxListState(
      items: items ?? this.items,
      isLoading: isLoading ?? this.isLoading,
      error: error,
      incompleteCount: incompleteCount ?? this.incompleteCount,
      completeCount: completeCount ?? this.completeCount,
      guestActions: guestActions ?? this.guestActions,
      canCompleteComment: canCompleteComment ?? this.canCompleteComment,
      incompleteUnreadCount: incompleteUnreadCount ?? this.incompleteUnreadCount,
      completeUnreadCount: completeUnreadCount ?? this.completeUnreadCount,
      sources: sources ?? this.sources,
      sourceCounts: sourceCounts ?? this.sourceCounts,
      sourceCountsComplete: sourceCountsComplete ?? this.sourceCountsComplete,
      status: status ?? this.status,
      search: search ?? this.search,
    );
  }
}

class InboxNotifier extends StateNotifier<InboxListState> {
  final InboxRepository _repo;
  final ReverbRealtimeService _reverb;
  final int? _userId;
  String _status = 'pending';
  String _search = '';
  int _requestNumber = 0;
  final List<void Function()> _cancelRealtimeSubscriptions = [];

  InboxNotifier(this._repo, this._reverb, this._userId) : super(InboxListState()) {
    loadInbox();
    _setupRealtime();
  }

  Future<void> loadInbox({String? status, String? search}) async {
    _status = status ?? _status;
    _search = search ?? _search;
    final requestNumber = ++_requestNumber;
    state = state.copyWith(isLoading: true, error: null, status: _status, search: _search);
    try {
      final todos = await _repo.fetchTodos(status: _status, search: _search);
      if (!mounted || requestNumber != _requestNumber) return;
      state = InboxListState(items: todos.items, incompleteCount: todos.incompleteCount, completeCount: todos.completeCount,
          incompleteUnreadCount: todos.incompleteUnreadCount, completeUnreadCount: todos.completeUnreadCount, sources: todos.sources, sourceCounts: todos.sourceCounts, sourceCountsComplete: todos.sourceCountsComplete,
          guestActions: todos.guestActions, canCompleteComment: todos.canCompleteComment, isLoading: false, status: _status, search: _search);
    } catch (e) {
      if (!mounted || requestNumber != _requestNumber) return;
      state = state.copyWith(isLoading: false, error: inboxErrorMessage(e));
    }
  }

  Future<bool> completeItem(InboxItemModel item) async {
    if (item.moduleCode != null && item.subjectKey != null) {
      final completed = await _repo.completeTodo(item.moduleCode!, item.subjectKey!);
      if (!completed) return false;
      await loadInbox();
      return true;
    }
    return false;
  }

  void _setupRealtime() {
    if (_userId != null) {
      _cancelRealtimeSubscriptions.add(_reverb.subscribe('private-inbox.user.$_userId', (eventData) {
        loadInbox();
      }));
      _cancelRealtimeSubscriptions.add(_reverb.subscribe('private-App.Models.User.$_userId', (eventData) {
        loadInbox();
      }));
    }
  }

  @override
  void dispose() {
    for (final cancel in _cancelRealtimeSubscriptions) {
      cancel();
    }
    super.dispose();
  }
}

final inboxNotifierProvider = StateNotifierProvider<InboxNotifier, InboxListState>((ref) {
  final repo = ref.watch(inboxRepositoryProvider);
  final reverb = ref.watch(reverbServiceProvider);
  final user = ref.watch(authProvider).user;
  return InboxNotifier(repo, reverb, user?.id);
});
