import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import '../network/api_client.dart';
import '../../features/auth/providers/auth_provider.dart';

final reverbServiceProvider = Provider<ReverbRealtimeService>((ref) {
  final apiClient = ref.watch(apiClientProvider);
  final service = ReverbRealtimeService(apiClient);
  
  ref.onDispose(() {
    service.disconnect();
  });
  
  return service;
});

class ReverbRealtimeService {
  final ApiClient _apiClient;
  WebSocketChannel? _channel;
  bool _isConnected = false;
  final Map<String, List<Function(dynamic)>> _channelListeners = {};

  ReverbRealtimeService(this._apiClient);

  bool get isConnected => _isConnected;

  Future<void> connect() async {
    if (_isConnected) return;

    try {
      final response = await _apiClient.dio.get('/realtime/config');
      final data = response.data['data'];
      final host = data['host'] as String? ?? '10.11.2.49';
      final port = data['port'] as int? ?? 8080;
      final scheme = data['scheme'] as String? ?? 'http';
      final appKey = data['app_key'] as String? ?? 'erplab_reverb_key';

      final wsScheme = scheme == 'https' ? 'wss' : 'ws';
      final uri = Uri.parse('$wsScheme://$host:$port/app/$appKey?protocol=7&client=js&version=8.4.0-reverb&flash=false');

      _channel = WebSocketChannel.connect(uri);
      _isConnected = true;

      // Resubscribe active channels upon reconnect
      for (final channelName in _channelListeners.keys) {
        _channel?.sink.add(jsonEncode({
          'event': 'pusher:subscribe',
          'data': {'channel': channelName}
        }));
      }

      _channel?.stream.listen(
        (message) {
          _handleMessage(message);
        },
        onError: (error) {
          _isConnected = false;
          debugPrint('Reverb error: $error');
        },
        onDone: () {
          _isConnected = false;
          debugPrint('Reverb connection closed');
        },
      );
    } catch (e) {
      _isConnected = false;
      debugPrint('Failed to initialize Reverb connection: $e');
    }
  }

  void _handleMessage(dynamic rawMessage) {
    try {
      final decoded = jsonDecode(rawMessage.toString());
      final event = decoded['event'] as String?;
      final channel = decoded['channel'] as String?;
      final data = decoded['data'];

      if (event == 'pusher:ping') {
        _channel?.sink.add(jsonEncode({'event': 'pusher:pong', 'data': {}}));
        return;
      }

      if (channel != null && _channelListeners.containsKey(channel)) {
        for (final listener in _channelListeners[channel]!) {
          listener(data);
        }
      }
    } catch (_) {}
  }

  void subscribe(String channelName, Function(dynamic) onEvent) {
    _channelListeners.putIfAbsent(channelName, () => []).add(onEvent);

    if (_isConnected) {
      _channel?.sink.add(jsonEncode({
        'event': 'pusher:subscribe',
        'data': {'channel': channelName}
      }));
    }
  }

  void unsubscribe(String channelName) {
    _channelListeners.remove(channelName);
    if (_isConnected) {
      _channel?.sink.add(jsonEncode({
        'event': 'pusher:unsubscribe',
        'data': {'channel': channelName}
      }));
    }
  }

  void disconnect() {
    _channel?.sink.close();
    _channel = null;
    _isConnected = false;
    _channelListeners.clear();
  }
}
