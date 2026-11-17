import 'dart:async';
import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_app_badger/flutter_app_badger.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../features/auth/providers/auth_provider.dart';
import '../../firebase_options.dart';
import '../network/api_client.dart';
import '../storage/secure_storage_service.dart';

@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  debugPrint('FCM background message received: ${message.messageId}');
}

final fcmNotificationServiceProvider = Provider<FcmNotificationService>((ref) {
  final apiClient = ref.watch(apiClientProvider);
  final storage = ref.watch(storageServiceProvider);
  final service = FcmNotificationService(apiClient, storage: storage);
  ref.onDispose(() => service.dispose());
  return service;
});

class FcmNotificationService {
  final ApiClient _apiClient;
  final SecureStorageService _storage;
  final FlutterLocalNotificationsPlugin _localNotifications;
  StreamSubscription<String>? _tokenRefreshSubscription;
  bool _initialized = false;
  Future<void>? _initialization;

  FcmNotificationService(
    this._apiClient, {
    SecureStorageService? storage,
    FlutterLocalNotificationsPlugin? localNotifications,
  })  : _storage = storage ?? _apiClient.storage,
        _localNotifications =
            localNotifications ?? FlutterLocalNotificationsPlugin();

  String _resolvePlatform() {
    if (kIsWeb) return 'web';
    if (defaultTargetPlatform == TargetPlatform.android) return 'android';
    // Backend Laravel ORBIT currently restricts 'platform' to 'web' or 'android'.
    return 'android';
  }

  Future<void> initialize() async {
    if (_initialized) {
      // Re-trigger token synchronization when re-initializing or re-authenticating
      await syncFcmToken();
      return;
    }
    if (_initialization != null) {
      await _initialization;
      return;
    }
    _initialization = _initializeOnce();
    await _initialization;
  }

  Future<void> _initializeOnce() async {
    try {
      if (!Firebase.apps.any((app) => app.name == '[DEFAULT]')) {
        await Firebase.initializeApp(
          options: DefaultFirebaseOptions.currentPlatform,
        );
      }

      FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

      // Request notification permissions
      final messaging = FirebaseMessaging.instance;
      final settings = await messaging.requestPermission(
        alert: true,
        announcement: false,
        badge: true,
        carPlay: false,
        criticalAlert: false,
        provisional: false,
        sound: true,
      );

      debugPrint('[FCM] User granted permission: ${settings.authorizationStatus}');

      // Initialize local notifications channel for Android foreground notifications
      const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
      const initSettings = InitializationSettings(android: androidInit);
      await _localNotifications.initialize(initSettings);

      const androidChannel = AndroidNotificationChannel(
        'orbit_mentions_high_v1',
        'Orbit Notifications',
        description: 'Notifications for Orbit WorkHub tasks, inbox, and approvals',
        importance: Importance.max,
      );

      await _localNotifications
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>()
          ?.createNotificationChannel(androidChannel);

      // Handle foreground notifications
      FirebaseMessaging.onMessage.listen((RemoteMessage message) {
        debugPrint('[FCM] Foreground notification received');
        final notification = message.notification;
        final title = notification?.title ?? message.data['title']?.toString();
        final body = notification?.body ?? message.data['body']?.toString();

        if ((title?.isNotEmpty ?? false) || (body?.isNotEmpty ?? false)) {
          _localNotifications.show(
            message.messageId?.hashCode ?? DateTime.now().millisecondsSinceEpoch,
            title ?? 'Orbit WorkHub',
            body ?? '',
            NotificationDetails(
              android: AndroidNotificationDetails(
                androidChannel.id,
                androidChannel.name,
                channelDescription: androidChannel.description,
                icon: '@mipmap/ic_launcher',
                importance: Importance.max,
                priority: Priority.high,
              ),
            ),
            payload: jsonEncode(message.data),
          );
        }
      });

      // Handle token refreshes from Firebase
      _tokenRefreshSubscription?.cancel();
      _tokenRefreshSubscription = messaging.onTokenRefresh.listen(
        (newToken) async {
          debugPrint('[FCM] Firebase token refresh event received');
          await registerTokenWithBackend(newToken);
        },
        onError: (Object error) {
          debugPrint('[FCM] Error listening to onTokenRefresh: $error');
        },
      );

      // Register device token with backend after authentication
      await syncFcmToken();
      _initialized = true;
    } catch (e, st) {
      debugPrint('[FCM] Failed to initialize FCM: $e\n$st');
      _initialization = null;
    }
  }

  Future<void> syncFcmToken() async {
    try {
      final token = await FirebaseMessaging.instance.getToken();
      if (token != null && token.isNotEmpty) {
        await registerTokenWithBackend(token);
      } else {
        debugPrint('[FCM] No FCM token returned from Firebase');
      }
    } catch (e) {
      debugPrint('[FCM] Error getting FCM token: $e');
    }
  }

  Future<bool> registerTokenWithBackend(String token) async {
    // Only proceed when token is present and valid
    if (token.isEmpty || token.length > 4096) {
      debugPrint('[FCM] Invalid token length: ${token.length}');
      return false;
    }

    try {
      final authToken = await _storage.getToken();
      if (authToken == null || authToken.isEmpty) {
        debugPrint('[FCM] Registration deferred: user is not authenticated');
        return false;
      }

      final platform = _resolvePlatform();
      await _apiClient.dio.post(
        '/fcm-device-tokens',
        data: {
          'token': token,
          'platform': platform,
        },
      );
      debugPrint('[FCM] Token successfully registered to backend (platform: $platform)');
      return true;
    } on DioException catch (e) {
      final statusCode = e.response?.statusCode;
      final responseData = e.response?.data;
      final body = responseData is Map
          ? Map<String, dynamic>.from(responseData)
          : <String, dynamic>{};

      debugPrint('[FCM] Token registration failed: HTTP ${statusCode ?? 'unknown'}');
      debugPrint('[FCM] Validation message: ${body['message'] ?? 'No message returned'}');
      if (body['errors'] != null) {
        debugPrint('[FCM] Validation errors: ${body['errors']}');
      }
      return false;
    } catch (e) {
      debugPrint('[FCM] Unexpected error registering token: $e');
      return false;
    }
  }

  void dispose() {
    _tokenRefreshSubscription?.cancel();
    _tokenRefreshSubscription = null;
  }

  /// Update the launcher app icon badge count
  static void updateAppBadge(int count) {
    try {
      FlutterAppBadger.isAppBadgeSupported().then((supported) {
        if (supported) {
          if (count > 0) {
            FlutterAppBadger.updateBadgeCount(count);
          } else {
            FlutterAppBadger.removeBadge();
          }
        }
      });
    } catch (e) {
      debugPrint('Error updating app badge: $e');
    }
  }
}
