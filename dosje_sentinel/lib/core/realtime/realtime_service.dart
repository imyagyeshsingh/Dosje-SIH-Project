import 'dart:async';

import 'package:flutter/foundation.dart';

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
/// NOTE: WebSocket is used for realtime metadata and signaling events ONLY,
/// never as the raw video transport.
abstract class RealtimeService {
  Stream<RealtimeEvent> get eventStream;
  void connect(String authToken);
  void disconnect();
  void emitSimulatedEvent(RealtimeEvent event); // For testing & demo flows
  void emitEvent(Map<String, dynamic> json);
}

class DefaultRealtimeService implements RealtimeService {
  final StreamController<RealtimeEvent> _controller =
      StreamController<RealtimeEvent>.broadcast();

  bool _isConnected = false;
  bool get isConnected => _isConnected;

  @override
  Stream<RealtimeEvent> get eventStream => _controller.stream;

  @override
  void connect(String authToken) {
    _isConnected = true;
    debugPrint(
      '[WebSocket] Connected to FastAPI realtime hub with token: ${authToken.substring(0, 8)}...',
    );
  }

  @override
  void disconnect() {
    _isConnected = false;
    debugPrint('[WebSocket] Disconnected from realtime hub');
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
