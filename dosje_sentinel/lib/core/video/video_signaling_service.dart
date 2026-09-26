import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';

import '../network/api_endpoints.dart';
import '../../shared/models/video_session_model.dart';

abstract class VideoSignalingService {
  Stream<VideoSignalingMessage> get messageStream;
  bool get isConnected;
  String? get currentSessionId;
  String? get currentRole;

  Future<void> connect(String sessionId);
  Future<void> join(String role);
  Future<void> sendOffer(String sdp);
  Future<void> sendAnswer(String sdp);
  Future<void> sendIceCandidate(Map<String, dynamic> candidate);
  Future<void> leave();
  Future<void> end();
  Future<void> disconnect();
  void dispose();
}

class WebSocketVideoSignalingService implements VideoSignalingService {
  final StreamController<VideoSignalingMessage> _messageController =
      StreamController<VideoSignalingMessage>.broadcast();

  WebSocket? _socket;
  StreamSubscription? _subscription;
  String? _sessionId;
  String? _role;
  bool _isConnecting = false;

  @override
  Stream<VideoSignalingMessage> get messageStream => _messageController.stream;

  @override
  bool get isConnected => _socket != null && _socket!.readyState == WebSocket.open;

  @override
  String? get currentSessionId => _sessionId;

  @override
  String? get currentRole => _role;

  @override
  Future<void> connect(String sessionId) async {
    if (isConnected && _sessionId == sessionId) {
      debugPrint('[VideoSignaling] Already connected to session: $sessionId');
      return;
    }

    if (_isConnecting) return;
    _isConnecting = true;

    try {
      await disconnect();
      _sessionId = sessionId;

      final url = ApiEndpoints.wsVideoSession(sessionId);
      debugPrint('[VideoSignaling] Connecting to: $url');

      _socket = await WebSocket.connect(url);
      _isConnecting = false;

      _subscription = _socket!.listen(
        _onData,
        onError: _onError,
        onDone: _onDone,
        cancelOnError: false,
      );
    } catch (e) {
      _isConnecting = false;
      debugPrint('[VideoSignaling] Connection failed: $e');
      _messageController.add(
        VideoSignalingMessage(
          type: 'error',
          message: 'Connection failed: ${e.toString()}',
        ),
      );
      rethrow;
    }
  }

  void _onData(dynamic data) {
    try {
      final jsonMap = jsonDecode(data.toString()) as Map<String, dynamic>;
      final message = VideoSignalingMessage.fromJson(jsonMap);
      _messageController.add(message);
    } catch (e) {
      debugPrint('[VideoSignaling] Malformed frame: $e');
    }
  }

  void _onError(dynamic error) {
    debugPrint('[VideoSignaling] Socket error: $error');
    _messageController.add(
      VideoSignalingMessage(
        type: 'error',
        message: 'WebSocket error: ${error.toString()}',
      ),
    );
  }

  void _onDone() {
    debugPrint('[VideoSignaling] Socket closed. Code: ${_socket?.closeCode}, Reason: ${_socket?.closeReason}');
    _socket = null;
    _subscription = null;
  }

  void _send(Map<String, dynamic> payload) {
    if (!isConnected) {
      throw StateError('Cannot send signaling message: WebSocket is not connected');
    }
    final jsonStr = jsonEncode(payload);
    _socket!.add(jsonStr);
  }

  @override
  Future<void> join(String role) async {
    _role = role;
    _send({'type': 'join', 'role': role});
  }

  @override
  Future<void> sendOffer(String sdp) async {
    _send({'type': 'offer', 'sdp': sdp});
  }

  @override
  Future<void> sendAnswer(String sdp) async {
    _send({'type': 'answer', 'sdp': sdp});
  }

  @override
  Future<void> sendIceCandidate(Map<String, dynamic> candidate) async {
    _send({'type': 'ice-candidate', 'candidate': candidate});
  }

  @override
  Future<void> leave() async {
    try {
      _send({'type': 'leave'});
    } catch (_) {}
    await disconnect();
  }

  @override
  Future<void> end() async {
    try {
      _send({'type': 'end'});
    } catch (_) {}
    await disconnect();
  }

  @override
  Future<void> disconnect() async {
    try {
      await _subscription?.cancel();
    } catch (_) {}
    _subscription = null;

    try {
      if (_socket != null) {
        await _socket!.close(WebSocketStatus.normalClosure, 'User disconnected');
      }
    } catch (_) {}
    _socket = null;
    _sessionId = null;
    _role = null;
    _isConnecting = false;
  }

  @override
  void dispose() {
    disconnect();
    _messageController.close();
  }
}

class MockVideoSignalingService implements VideoSignalingService {
  final StreamController<VideoSignalingMessage> _messageController =
      StreamController<VideoSignalingMessage>.broadcast();

  bool _connected = false;
  String? _sessionId;
  String? _role;

  @override
  Stream<VideoSignalingMessage> get messageStream => _messageController.stream;

  @override
  bool get isConnected => _connected;

  @override
  String? get currentSessionId => _sessionId;

  @override
  String? get currentRole => _role;

  @override
  Future<void> connect(String sessionId) async {
    _sessionId = sessionId;
    _connected = true;
  }

  @override
  Future<void> join(String role) async {
    _role = role;
    // Simulate server response: participant-joined
    _messageController.add(
      VideoSignalingMessage(type: 'participant-joined', role: role),
    );
  }

  @override
  Future<void> sendOffer(String sdp) async {
    _messageController.add(VideoSignalingMessage(type: 'offer', sdp: sdp));
  }

  @override
  Future<void> sendAnswer(String sdp) async {
    _messageController.add(VideoSignalingMessage(type: 'answer', sdp: sdp));
  }

  @override
  Future<void> sendIceCandidate(Map<String, dynamic> candidate) async {
    _messageController.add(
      VideoSignalingMessage(type: 'ice-candidate', candidate: candidate),
    );
  }

  @override
  Future<void> leave() async {
    _messageController.add(
      VideoSignalingMessage(type: 'participant-left', role: _role),
    );
    await disconnect();
  }

  @override
  Future<void> end() async {
    _messageController.add(
      VideoSignalingMessage(type: 'ended', role: _role),
    );
    await disconnect();
  }

  @override
  Future<void> disconnect() async {
    _connected = false;
    _sessionId = null;
    _role = null;
  }

  @override
  void dispose() {
    disconnect();
    _messageController.close();
  }
}
