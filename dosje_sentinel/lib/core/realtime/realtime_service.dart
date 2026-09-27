import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';

import '../network/api_endpoints.dart';

class RealtimeEvent {
  final String event;
  final Map<String, dynamic> data;
  final DateTime timestamp;

  RealtimeEvent({required this.event, required this.data, DateTime? timestamp})
    : timestamp = timestamp ?? DateTime.now();

  factory RealtimeEvent.fromJson(Map<String, dynamic> json) {
    return RealtimeEvent(
      event: json['event'] as String? ?? 'UNKNOWN',
      data: (json['data'] as Map<String, dynamic>?) ?? json,
      timestamp: json['timestamp'] != null
          ? DateTime.tryParse(json['timestamp'] as String)
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() => {
    'event': event,
    'data': data,
    'timestamp': timestamp.toIso8601String(),
  };
}

/// Realtime Service handling JSON application events via FastAPI WebSocket.
abstract class RealtimeService {
  Stream<RealtimeEvent> get eventStream;
  void connect(String authToken);
  void disconnect();
  void emitSimulatedEvent(RealtimeEvent event); // For testing & local events
  void emitEvent(Map<String, dynamic> json);
}

class DefaultRealtimeService implements RealtimeService {
  final StreamController<RealtimeEvent> _controller =
      StreamController<RealtimeEvent>.broadcast();

  WebSocket? _socket;
  StreamSubscription? _subscription;
  bool _isConnected = false;
  bool _isConnecting = false;
  Timer? _reconnectTimer;
  Timer? _pingTimer;

  bool get isConnected => _isConnected;

  @override
  Stream<RealtimeEvent> get eventStream => _controller.stream;

  @override
  void connect(String authToken) {
    if (_isConnected || _isConnecting) return;
    _establishConnection();
  }

  Future<void> _establishConnection() async {
    _isConnecting = true;
    final wsUrl = ApiEndpoints.realtimeWsUrl;

    try {
      debugPrint('[Realtime] Connecting to WebSocket: $wsUrl');
      _socket = await WebSocket.connect(wsUrl).timeout(
        const Duration(seconds: 4),
      );
    } catch (primaryErr) {
      if (wsUrl.contains('10.47.11.97') || wsUrl.contains('10.0.2.2')) {
        final altWsUrl = wsUrl.contains('10.47.11.97')
            ? wsUrl.replaceAll('10.47.11.97', '10.0.2.2')
            : wsUrl.replaceAll('10.0.2.2', '10.47.11.97');
        try {
          debugPrint('[Realtime] Primary WS failed, trying fallback: $altWsUrl');
          _socket = await WebSocket.connect(altWsUrl).timeout(
            const Duration(seconds: 4),
          );
        } catch (_) {
          _isConnecting = false;
          _isConnected = false;
          debugPrint('[Realtime] Connection failed (running in offline/local mode): $primaryErr');
          _scheduleReconnect();
          return;
        }
      } else {
        _isConnecting = false;
        _isConnected = false;
        debugPrint('[Realtime] Connection failed (running in offline/local mode): $primaryErr');
        _scheduleReconnect();
        return;
      }
    }

    try {
      _isConnected = true;
      _isConnecting = false;
      debugPrint('[Realtime] WebSocket connected successfully');

      // Setup keepalive ping
      _pingTimer?.cancel();
      _pingTimer = Timer.periodic(const Duration(seconds: 30), (_) {
        if (_isConnected && _socket != null) {
          try {
            _socket!.add('ping');
          } catch (_) {}
        }
      });

      _subscription = _socket!.listen(
        (data) {
          try {
            if (data == 'pong') return;
            final parsed = jsonDecode(data.toString()) as Map<String, dynamic>;
            final event = RealtimeEvent.fromJson(parsed);
            _controller.add(event);
          } catch (e) {
            debugPrint('[Realtime] Error parsing event: $e');
          }
        },
        onError: (err) {
          debugPrint('[Realtime] WebSocket error: $err');
          _handleDisconnect();
        },
        onDone: () {
          debugPrint('[Realtime] WebSocket closed');
          _handleDisconnect();
        },
        cancelOnError: false,
      );
    } catch (e) {
      _isConnecting = false;
      _isConnected = false;
      debugPrint('[Realtime] Socket listener setup error: $e');
      _scheduleReconnect();
    }
  }

  void _handleDisconnect() {
    _isConnected = false;
    _isConnecting = false;
    _pingTimer?.cancel();
    _subscription?.cancel();
    _socket = null;
    _scheduleReconnect();
  }

  void _scheduleReconnect() {
    _reconnectTimer?.cancel();
    _reconnectTimer = Timer(const Duration(seconds: 5), () {
      if (!_isConnected) {
        _establishConnection();
      }
    });
  }

  @override
  void disconnect() {
    _reconnectTimer?.cancel();
    _pingTimer?.cancel();
    _subscription?.cancel();
    _socket?.close();
    _socket = null;
    _isConnected = false;
    _isConnecting = false;
    debugPrint('[Realtime] Disconnected from realtime hub');
  }

  @override
  void emitSimulatedEvent(RealtimeEvent event) {
    _controller.add(event);
  }

  @override
  void emitEvent(Map<String, dynamic> json) {
    _controller.add(RealtimeEvent.fromJson(json));
  }
}
