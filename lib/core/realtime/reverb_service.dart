import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

import '../network/api_client.dart';
import '../../features/auth/providers/auth_provider.dart';

final reverbServiceProvider = Provider<ReverbRealtimeService>((ref) {
  final service = ReverbRealtimeService(ref.watch(apiClientProvider));
  ref.onDispose(service.disconnect);
  return service;
});

class ReverbRealtimeService {
  final ApiClient _apiClient;
  WebSocketChannel? _channel;
  StreamSubscription<dynamic>? _streamSubscription;
  Timer? _reconnectTimer;
  String? _authEndpoint;
  String? _socketId;
  bool _isConnected = false;
  bool _isConnecting = false;
  final Map<String, List<void Function(dynamic)>> _channelListeners = {};
  final Set<String> _subscribedChannels = {};
  final Set<String> _subscriptionsInFlight = {};

  ReverbRealtimeService(this._apiClient);

  bool get isConnected => _isConnected;

  Future<void> connect() async {
    if (_isConnected || _isConnecting) return;
    _isConnecting = true;

    try {
      final response = await _apiClient.dio.get('/realtime/config');
      final root = response.data;
      final data = root is Map && root['data'] is Map
          ? Map<String, dynamic>.from(root['data'] as Map)
          : <String, dynamic>{};
      var host = data['host'] as String? ?? 'orbit.kecapsawi.net';
      var scheme = data['scheme'] as String? ?? 'https';
      var port = (data['port'] as num?)?.toInt();

      final baseUrlStr = await _apiClient.storage.getBaseUrl();
      final baseUri = Uri.tryParse(baseUrlStr);

      if ((host == '127.0.0.1' || host == 'localhost') &&
          baseUri != null &&
          baseUri.host.isNotEmpty) {
        if (baseUri.host != '127.0.0.1' && baseUri.host != 'localhost') {
          host = baseUri.host;
          if (baseUri.scheme == 'https') {
            scheme = 'https';
            port = 443;
          }
        }
      }

      port ??= ((scheme == 'https') ? 443 : 8080);
      final appKey = data['app_key'] as String? ?? 'erplab_reverb_key';
      _authEndpoint =
          data['auth_endpoint'] as String? ?? '/broadcasting/auth';
      if (_authEndpoint == '/api/broadcasting/auth') {
        _authEndpoint = '/broadcasting/auth';
      }

      final wsScheme = scheme == 'https' ? 'wss' : 'ws';
      final portSuffix = (scheme == 'https' && port == 443) ||
              (scheme == 'http' && port == 80)
          ? ''
          : ':$port';
      final uri = Uri.parse(
        '$wsScheme://$host$portSuffix/app/$appKey?protocol=7&client=js&version=8.4.0-reverb&flash=false',
      );
      debugPrint('Reverb connecting to uri: $uri (data: $data, baseUrl: $baseUrlStr)');

      final channel = WebSocketChannel.connect(uri);
      _channel = channel;
      await channel.ready;
      _streamSubscription = channel.stream.listen(
        _handleMessage,
        onError: (Object error) {
          debugPrint('Reverb connection error: $error');
          _resetConnection(channel);
        },
        onDone: () {
          _resetConnection(channel);
        },
      );
    } catch (error) {
      debugPrint('Failed to initialize Reverb connection: $error');
      _scheduleReconnect();
    } finally {
      _isConnecting = false;
    }
  }

  void _handleMessage(dynamic rawMessage) {
    try {
      final decoded = jsonDecode(rawMessage.toString());
      if (decoded is! Map) return;

      final event = decoded['event'] as String?;
      if (event == 'pusher:connection_established') {
        final rawData = decoded['data'];
        final connectionData =
            rawData is String ? jsonDecode(rawData) : rawData;
        if (connectionData is! Map || connectionData['socket_id'] is! String) {
          debugPrint('Reverb did not provide a socket ID.');
          return;
        }

        _socketId = connectionData['socket_id'] as String;
        _isConnected = true;
        _reconnectTimer?.cancel();
        for (final channelName in _channelListeners.keys.toList()) {
          unawaited(_subscribeToChannel(channelName));
        }
        return;
      }

      if (event == 'pusher:ping') {
        _channel?.sink.add(jsonEncode({'event': 'pusher:pong', 'data': {}}));
        return;
      }
      if (event == 'pusher:error' || event == 'pusher:subscription_error') {
        debugPrint('Reverb rejected a channel operation: ${decoded['data']}');
        return;
      }

      final channelName = decoded['channel'] as String?;
      if (channelName == null) return;
      final rawData = decoded['data'];
      final data = rawData is String ? _decodeEventData(rawData) : rawData;
      for (final listener in List<void Function(dynamic)>.from(
        _channelListeners[channelName] ?? const [],
      )) {
        try {
          listener(data);
        } catch (error) {
          debugPrint('Reverb listener failed for $channelName: $error');
        }
      }
    } catch (error) {
      debugPrint('Unable to read Reverb event: $error');
    }
  }

  dynamic _decodeEventData(String rawData) {
    try {
      return jsonDecode(rawData);
    } on FormatException {
      return rawData;
    }
  }

  void Function() subscribe(
      String channelName, void Function(dynamic) onEvent) {
    final listeners = _channelListeners.putIfAbsent(channelName, () => []);
    listeners.add(onEvent);
    if (_isConnected) {
      unawaited(_subscribeToChannel(channelName));
    }

    return () {
      final activeListeners = _channelListeners[channelName];
      activeListeners?.remove(onEvent);
      if (activeListeners != null && activeListeners.isEmpty) {
        unsubscribe(channelName);
      }
    };
  }

  Future<void> _subscribeToChannel(String channelName) async {
    final channel = _channel;
    final socketId = _socketId;
    if (!_isConnected ||
        channel == null ||
        socketId == null ||
        !_channelListeners.containsKey(channelName) ||
        _subscribedChannels.contains(channelName) ||
        !_subscriptionsInFlight.add(channelName)) {
      return;
    }

    var connectionChanged = false;
    try {
      final payload = <String, dynamic>{'channel': channelName};
      if (channelName.startsWith('private-')) {
        late final dynamic responseData;
        try {
          final response = await _apiClient.dio.post(
            _authEndpoint ?? '/broadcasting/auth',
            data: {'socket_id': socketId, 'channel_name': channelName},
          );
          responseData = response.data;
        } on Exception {
          if (_authEndpoint != '/broadcasting/auth') {
            _authEndpoint = '/broadcasting/auth';
            final fallbackResponse = await _apiClient.dio.post(
              '/broadcasting/auth',
              data: {'socket_id': socketId, 'channel_name': channelName},
            );
            responseData = fallbackResponse.data;
          } else {
            rethrow;
          }
        }
        final result = responseData;
        if (result is! Map || result['auth'] is! String) {
          throw const FormatException(
              'Unexpected private channel auth response');
        }
        payload['auth'] = result['auth'];
        if (result['channel_data'] != null) {
          payload['channel_data'] = result['channel_data'];
        }
      }

      if (!identical(channel, _channel) ||
          socketId != _socketId ||
          !_channelListeners.containsKey(channelName)) {
        connectionChanged =
            !identical(channel, _channel) || socketId != _socketId;
        return;
      }
      channel.sink
          .add(jsonEncode({'event': 'pusher:subscribe', 'data': payload}));
      _subscribedChannels.add(channelName);
    } catch (error) {
      debugPrint('Unable to subscribe to Reverb channel $channelName: $error');
    } finally {
      _subscriptionsInFlight.remove(channelName);
      if (connectionChanged &&
          _isConnected &&
          _channelListeners.containsKey(channelName) &&
          !_subscribedChannels.contains(channelName)) {
        scheduleMicrotask(() => unawaited(_subscribeToChannel(channelName)));
      }
    }
  }

  void unsubscribe(String channelName) {
    _channelListeners.remove(channelName);
    _subscriptionsInFlight.remove(channelName);
    if (_isConnected && _subscribedChannels.remove(channelName)) {
      _channel?.sink.add(jsonEncode({
        'event': 'pusher:unsubscribe',
        'data': {'channel': channelName},
      }));
    }
  }

  void _resetConnection(WebSocketChannel channel) {
    if (!identical(channel, _channel)) return;
    _isConnected = false;
    _socketId = null;
    _subscribedChannels.clear();
    _subscriptionsInFlight.clear();
    _channel = null;
    _streamSubscription = null;
    if (_channelListeners.isNotEmpty) _scheduleReconnect();
  }

  void _scheduleReconnect() {
    if (_channelListeners.isEmpty || _reconnectTimer?.isActive == true) return;
    _reconnectTimer = Timer(const Duration(seconds: 5), () {
      unawaited(connect());
    });
  }

  void disconnect() {
    _reconnectTimer?.cancel();
    _streamSubscription?.cancel();
    _channel?.sink.close();
    _channel = null;
    _streamSubscription = null;
    _socketId = null;
    _isConnected = false;
    _isConnecting = false;
    _subscribedChannels.clear();
    _subscriptionsInFlight.clear();
    _channelListeners.clear();
  }
}
