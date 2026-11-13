import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/network/api_client.dart';
import '../../../core/realtime/reverb_service.dart';
import '../../auth/providers/auth_provider.dart';
import '../models/chat_item_model.dart';

final chatRepositoryProvider = Provider<ChatRepository>((ref) {
  final apiClient = ref.watch(apiClientProvider);
  return ChatRepository(apiClient);
});

final employeeChatRepositoryProvider = Provider<EmployeeChatRepository>((ref) {
  return EmployeeChatRepository(ref.watch(apiClientProvider));
});

class EmployeeChatRepository {
  final ApiClient _apiClient;

  EmployeeChatRepository(this._apiClient);

  Future<List<Map<String, dynamic>>> fetchConversations() async {
    final response = await _apiClient.dio.get('/employee-chat/conversations');
    final data = response.data;
    if (data is! Map || data['data'] is! List) {
      throw const FormatException('Unexpected employee chat response');
    }
    return (data['data'] as List)
        .whereType<Map>()
        .map((row) => Map<String, dynamic>.from(row))
        .toList();
  }
}

class ChatRepository {
  final ApiClient _apiClient;

  ChatRepository(this._apiClient);

  Future<List<ChatItemModel>> fetchConversations({String? search, String? filter}) async {
    try {
      final queryParams = <String, dynamic>{};
      if (search != null && search.isNotEmpty) queryParams['search'] = search;
      if (filter != null && filter.isNotEmpty) queryParams['filter'] = filter;

      final response = await _apiClient.dio.get('/conversations', queryParameters: queryParams);
      if (response.data is Map && response.data['data'] is List) {
        final list = response.data['data'] as List;
        return list.map((json) => ChatItemModel.fromJson(json as Map<String, dynamic>)).toList();
      }
      return [];
    } catch (e) {
      // Return empty list on failure or network error
      return [];
    }
  }

  Future<bool> markRead(String customerUuid) async {
    try {
      await _apiClient.dio.put('/conversations/$customerUuid/read');
      return true;
    } catch (_) {
      return false;
    }
  }
}

class ChatListState {
  final List<ChatItemModel> chats;
  final bool isLoading;
  final String? error;

  ChatListState({
    this.chats = const [],
    this.isLoading = false,
    this.error,
  });

  ChatListState copyWith({
    List<ChatItemModel>? chats,
    bool? isLoading,
    String? error,
  }) {
    return ChatListState(
      chats: chats ?? this.chats,
      isLoading: isLoading ?? this.isLoading,
      error: error,
    );
  }
}

class ChatNotifier extends StateNotifier<ChatListState> {
  final ChatRepository _repo;
  final ReverbRealtimeService _reverb;
  final int? _userId;

  ChatNotifier(this._repo, this._reverb, this._userId) : super(ChatListState()) {
    loadChats();
    _setupRealtime();
  }

  Future<void> loadChats({String? search, String? filter}) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final items = await _repo.fetchConversations(search: search, filter: filter);
      state = state.copyWith(chats: items, isLoading: false);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  void _setupRealtime() {
    if (_userId != null) {
      _reverb.subscribe('private-App.Models.User.$_userId', (eventData) {
        // Reload conversations when user receives a new message/mention
        loadChats();
      });
    }

    _reverb.subscribe('chat-updates', (eventData) {
      loadChats();
    });
  }

  void updateWithNewMessage(ChatItemModel updatedChat) {
    final existingIndex = state.chats.indexWhere((c) => c.id == updatedChat.id);
    List<ChatItemModel> updatedList = List.from(state.chats);
    if (existingIndex != -1) {
      updatedList.removeAt(existingIndex);
    }
    updatedList.insert(0, updatedChat);
    state = state.copyWith(chats: updatedList);
  }
}

final chatNotifierProvider = StateNotifierProvider<ChatNotifier, ChatListState>((ref) {
  final repo = ref.watch(chatRepositoryProvider);
  final reverb = ref.watch(reverbServiceProvider);
  final user = ref.watch(authProvider).user;
  return ChatNotifier(repo, reverb, user?.id);
});
