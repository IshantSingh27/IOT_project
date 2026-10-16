import 'dart:async';
import 'dart:convert';
import 'package:web_socket_channel/web_socket_channel.dart';
import '../constants/api_constants.dart';
import 'storage_service.dart';

class WebSocketService {
  WebSocketChannel? _channel;
  final StreamController<Map<String, dynamic>> _controller = 
      StreamController<Map<String, dynamic>>.broadcast();

  Timer? _reconnectTimer;
  Timer? _pingTimer;
  bool _isDisposed = false;
  bool isConnected = false;

  Stream<Map<String, dynamic>> get eventStream => _controller.stream;

  Future<void> connect() async {
    if (_isDisposed) return;

    try {
      final baseUrl = await StorageService.getBaseUrl();
      // Replace http:// or https:// with ws:// or wss://
      final wsUrl = baseUrl.replaceFirst(RegExp(r'^http'), 'ws') + ApiConstants.wsEvents;
      
      _channel?.sink.close();
      _channel = WebSocketChannel.connect(Uri.parse(wsUrl));

      isConnected = true;
      _startPing();

      _channel!.stream.listen(
        (data) {
          try {
            final Map<String, dynamic> json = jsonDecode(data);
            if (json['type'] != 'pong') {
              _controller.add(json);
            }
          } catch (_) {}
        },
        onDone: () {
          isConnected = false;
          _scheduleReconnect();
        },
        onError: (err) {
          isConnected = false;
          _scheduleReconnect();
        },
        cancelOnError: true,
      );
    } catch (e) {
      isConnected = false;
      _scheduleReconnect();
    }
  }

  void _startPing() {
    _pingTimer?.cancel();
    _pingTimer = Timer.periodic(const Duration(seconds: 25), (timer) {
      if (isConnected && _channel != null) {
        try {
          _channel!.sink.add('ping');
        } catch (_) {}
      }
    });
  }

  void _scheduleReconnect() {
    if (_isDisposed) return;
    _pingTimer?.cancel();
    _reconnectTimer?.cancel();
    _reconnectTimer = Timer(const Duration(seconds: 4), () {
      connect();
    });
  }

  void disconnect() {
    _isDisposed = true;
    _pingTimer?.cancel();
    _reconnectTimer?.cancel();
    _channel?.sink.close();
    isConnected = false;
  }
}
