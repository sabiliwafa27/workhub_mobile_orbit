import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/realtime/reverb_service.dart';
import '../../auth/providers/auth_provider.dart';
import '../models/inbox_item_model.dart';

final inboxRepositoryProvider = Provider<InboxRepository>((ref) {
  final apiClient = ref.watch(apiClientProvider);
  return InboxRepository(apiClient);
});

class InboxRepository {
  final ApiClient _apiClient;

  InboxRepository(this._apiClient);

  Future<List<InboxItemModel>> fetchTodos({String status = 'pending'}) async {
    try {
      final response = await _apiClient.dio.get('/inbox/api/todos', queryParameters: {'status': status});
      if (response.data is Map && response.data['data'] is List) {
        final list = response.data['data'] as List;
        return list.map((json) => InboxItemModel.fromJson(json as Map<String, dynamic>)).toList();
      }
      return [];
    } catch (_) {
      return [];
    }
  }
}

class InboxListState {
  final List<InboxItemModel> items;
  final bool isLoading;
  final String? error;

  InboxListState({
    this.items = const [],
    this.isLoading = false,
    this.error,
  });

  InboxListState copyWith({
    List<InboxItemModel>? items,
    bool? isLoading,
    String? error,
  }) {
    return InboxListState(
      items: items ?? this.items,
      isLoading: isLoading ?? this.isLoading,
      error: error,
    );
  }
}

class InboxNotifier extends StateNotifier<InboxListState> {
  final InboxRepository _repo;
  final ReverbRealtimeService _reverb;
  final int? _userId;

  InboxNotifier(this._repo, this._reverb, this._userId) : super(InboxListState()) {
    loadInbox();
    _setupRealtime();
  }

  Future<void> loadInbox({String status = 'pending'}) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final todos = await _repo.fetchTodos(status: status);
      state = state.copyWith(items: todos, isLoading: false);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  void _setupRealtime() {
    if (_userId != null) {
      _reverb.subscribe('private-App.Models.User.$_userId', (eventData) {
        loadInbox();
      });
    }

    _reverb.subscribe('inbox-updates', (eventData) {
      loadInbox();
    });
  }
}

final inboxNotifierProvider = StateNotifierProvider<InboxNotifier, InboxListState>((ref) {
  final repo = ref.watch(inboxRepositoryProvider);
  final reverb = ref.watch(reverbServiceProvider);
  final user = ref.watch(authProvider).user;
  return InboxNotifier(repo, reverb, user?.id);
});
