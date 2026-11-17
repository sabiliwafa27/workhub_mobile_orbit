import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/network/api_client.dart';
import '../../../core/storage/secure_storage_service.dart';
import '../models/user_model.dart';
import '../services/passkey_service.dart';

final storageServiceProvider = Provider<SecureStorageService>((ref) {
  return SecureStorageService();
});

final apiClientProvider = Provider<ApiClient>((ref) {
  final storage = ref.watch(storageServiceProvider);
  return ApiClient(customStorage: storage);
});

final passkeyServiceProvider = Provider<PasskeyService>((ref) {
  final apiClient = ref.watch(apiClientProvider);
  return PasskeyService(apiClient);
});

final loginBackgroundProvider =
    FutureProvider.autoDispose<LoginBackgroundModel>((ref) async {
  final apiClient = ref.watch(apiClientProvider);
  final storage = ref.watch(storageServiceProvider);
  final baseUrl = await storage.getBaseUrl();
  try {
    final response = await apiClient.dio.get('/auth/login-background');
    final raw = response.data is Map
        ? Map<String, dynamic>.from(response.data as Map)
        : <String, dynamic>{};
    return LoginBackgroundModel.fromJson(raw, fallbackBaseUrl: baseUrl);
  } catch (_) {
    return LoginBackgroundModel(webpUrl: '$baseUrl/login-desktop.webp');
  }
});

final myProfileProvider =
    FutureProvider.autoDispose<MyProfileResponse?>((ref) async {
  final isAuthenticated = ref.watch(
    authProvider.select((state) => state.isAuthenticated),
  );
  if (!isAuthenticated) return null;
  return ref.read(authProvider.notifier).fetchMyProfile(updateAuthState: false);
});

class AuthState {
  final bool isLoading;
  final bool isAuthenticated;
  final UserModel? user;
  final String? errorMessage;

  AuthState({
    this.isLoading = false,
    this.isAuthenticated = false,
    this.user,
    this.errorMessage,
  });

  AuthState copyWith({
    bool? isLoading,
    bool? isAuthenticated,
    UserModel? user,
    String? errorMessage,
  }) {
    return AuthState(
      isLoading: isLoading ?? this.isLoading,
      isAuthenticated: isAuthenticated ?? this.isAuthenticated,
      user: user ?? this.user,
      errorMessage: errorMessage,
    );
  }
}

class AuthNotifier extends StateNotifier<AuthState> {
  final ApiClient _apiClient;
  final SecureStorageService _storage;
  final PasskeyService _passkeyService;

  AuthNotifier(
    this._apiClient,
    this._storage, [
    PasskeyService? passkeyService,
  ])  : _passkeyService = passkeyService ?? PasskeyService(_apiClient),
        super(AuthState()) {
    checkAuthStatus();
  }

  Future<void> checkAuthStatus() async {
    final token = await _storage.getToken();
    if (token == null || token.isEmpty) {
      state = state.copyWith(isAuthenticated: false);
      return;
    }

    try {
      final response = await _apiClient.dio.get('/auth/me');
      final userData = response.data['data']['user'];
      final user = UserModel.fromJson(userData);
      state = state.copyWith(isAuthenticated: true, user: user);
    } catch (_) {
      await _storage.clearToken();
      state = state.copyWith(isAuthenticated: false, user: null);
    }
  }

  Future<bool> login({
    required String email,
    required String password,
    bool rememberMe = true,
  }) async {
    state = state.copyWith(isLoading: true, errorMessage: null);

    try {
      final response = await _apiClient.dio.post('/auth/login', data: {
        'email': email.trim(),
        'password': password,
        'remember_me': rememberMe,
        'device_name': 'WorkHub Flutter App',
      });

      final data = response.data['data'];
      final token = data['token'] as String;
      final user = UserModel.fromJson(data['user']);

      await _storage.saveToken(token);
      state = state.copyWith(
        isLoading: false,
        isAuthenticated: true,
        user: user,
      );
      if (user.preferredName == null || user.preferredName!.isEmpty) {
        await checkAuthStatus();
      }
      return true;
    } on DioException catch (e) {
      final msg = e.response?.data?['message'] ??
          'Login failed. Please check credentials.';
      state = state.copyWith(isLoading: false, errorMessage: msg);
      return false;
    } catch (e) {
      state = state.copyWith(isLoading: false, errorMessage: e.toString());
      return false;
    }
  }

  Future<bool> loginWithPasskey({bool rememberMe = true}) async {
    state = state.copyWith(isLoading: true, errorMessage: null);
    try {
      final result = await _passkeyService.loginWithPasskey(
        rememberMe: rememberMe,
      );
      await _storage.saveToken(result.token);
      state = state.copyWith(
        isLoading: false,
        isAuthenticated: true,
        user: result.user,
      );
      if (result.user.preferredName == null ||
          result.user.preferredName!.isEmpty) {
        await checkAuthStatus();
      }
      return true;
    } on PasskeyCancelledException {
      state = state.copyWith(isLoading: false, errorMessage: null);
      return false;
    } on PasskeyException catch (e) {
      state = state.copyWith(isLoading: false, errorMessage: e.message);
      return false;
    } catch (e) {
      state = state.copyWith(isLoading: false, errorMessage: e.toString());
      return false;
    }
  }

  Future<MyProfileResponse?> fetchMyProfile({bool updateAuthState = true}) async {
    try {
      final response = await _apiClient.dio.get('/auth/my-profile');
      final raw = response.data is Map
          ? Map<String, dynamic>.from(response.data as Map)
          : <String, dynamic>{};
      final profile = MyProfileResponse.fromJson(raw);
      if (updateAuthState) {
        if (profile.user != null) {
          final mergedUser = _mergeUserWithEmployee(
            profile.user!,
            profile.employee,
            fallbackUser: state.user,
          );
          state = state.copyWith(isAuthenticated: true, user: mergedUser);
        } else if (state.user != null && profile.employee != null) {
          final mergedUser = _mergeUserWithEmployee(
            state.user!,
            profile.employee,
          );
          state = state.copyWith(user: mergedUser);
        }
      }
      return profile;
    } catch (_) {
      return null;
    }
  }

  UserModel _mergeUserWithEmployee(
    UserModel user,
    Map<String, dynamic>? employee, {
    UserModel? fallbackUser,
  }) {
    final baseJson = <String, dynamic>{
      if (fallbackUser?.rawJson != null) ...fallbackUser!.rawJson!,
      if (user.rawJson != null) ...user.rawJson!,
    };
    if (employee != null) {
      baseJson['employee'] = employee;
    }
    if (baseJson.isEmpty) return user;
    return UserModel.fromJson(baseJson);
  }

  Future<PasskeyCredentialModel> registerPasskey({required String name}) async {
    final created = await _passkeyService.registerPasskey(name: name);
    await checkAuthStatus();
    return created;
  }

  Future<void> deletePasskey(int passkeyId) async {
    await _passkeyService.deletePasskey(passkeyId);
    await checkAuthStatus();
  }

  Future<void> logout() async {
    try {
      await _apiClient.dio.post('/auth/logout');
    } catch (_) {}
    await _storage.clearToken();
    state = state.copyWith(isAuthenticated: false, user: null);
  }
}

final authProvider = StateNotifierProvider<AuthNotifier, AuthState>((ref) {
  final apiClient = ref.watch(apiClientProvider);
  final storage = ref.watch(storageServiceProvider);
  final passkeyService = ref.watch(passkeyServiceProvider);
  return AuthNotifier(apiClient, storage, passkeyService);
});
