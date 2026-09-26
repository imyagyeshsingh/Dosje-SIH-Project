import 'dart:async';

import 'video_signaling_service.dart';
import '../../repositories/video_session_repository.dart';

enum VideoCallState { idle, incoming, connecting, connected, ended }

/// Standalone WebRTC / Video conference service abstraction.
/// Decoupled completely from WebSocket application event bus.
abstract class VideoInspectionService {
  Stream<VideoCallState> get callStateStream;
  VideoCallState get currentState;

  Future<void> joinSession(String sessionId, {String role = 'officer'});
  Future<void> leaveSession();
  void toggleMic(bool enabled);
  void toggleCamera(bool enabled);
  void switchCamera();
  void toggleTorch(bool enabled);
}

class DefaultVideoInspectionService implements VideoInspectionService {
  final StreamController<VideoCallState> _stateController =
      StreamController<VideoCallState>.broadcast();
  VideoCallState _currentState = VideoCallState.idle;

  @override
  Stream<VideoCallState> get callStateStream => _stateController.stream;

  @override
  VideoCallState get currentState => _currentState;

  @override
  Future<void> joinSession(String sessionId, {String role = 'officer'}) async {
    _currentState = VideoCallState.connecting;
    _stateController.add(_currentState);
    await Future.delayed(const Duration(milliseconds: 700));
    _currentState = VideoCallState.connected;
    _stateController.add(_currentState);
  }

  @override
  Future<void> leaveSession() async {
    _currentState = VideoCallState.ended;
    _stateController.add(_currentState);
    await Future.delayed(const Duration(milliseconds: 300));
    _currentState = VideoCallState.idle;
    _stateController.add(_currentState);
  }

  @override
  void toggleMic(bool enabled) {}

  @override
  void toggleCamera(bool enabled) {}

  @override
  void switchCamera() {}

  @override
  void toggleTorch(bool enabled) {}
}

class ApiVideoInspectionService implements VideoInspectionService {
  final VideoSignalingService signalingService;
  final VideoSessionRepository? sessionRepository;

  final StreamController<VideoCallState> _stateController =
      StreamController<VideoCallState>.broadcast();

  VideoCallState _currentState = VideoCallState.idle;
  StreamSubscription? _signalingSub;
  String? _activeSessionId;

  ApiVideoInspectionService({
    required this.signalingService,
    this.sessionRepository,
  }) {
    _signalingSub = signalingService.messageStream.listen(_onSignalingMessage);
  }

  @override
  Stream<VideoCallState> get callStateStream => _stateController.stream;

  @override
  VideoCallState get currentState => _currentState;

  void _onSignalingMessage(dynamic message) {
    final type = message.type;
    if (type == 'participant-joined') {
      _updateState(VideoCallState.connected);
    } else if (type == 'participant-left' || type == 'ended') {
      _updateState(VideoCallState.ended);
    } else if (type == 'error') {
      _updateState(VideoCallState.idle);
    }
  }

  void _updateState(VideoCallState newState) {
    _currentState = newState;
    _stateController.add(newState);
  }

  @override
  Future<void> joinSession(String sessionId, {String role = 'officer'}) async {
    _activeSessionId = sessionId;
    _updateState(VideoCallState.connecting);

    await signalingService.connect(sessionId);
    await signalingService.join(role);

    // If already connected on socket, update state
    _updateState(VideoCallState.connected);
  }

  @override
  Future<void> leaveSession() async {
    _updateState(VideoCallState.ended);

    await signalingService.leave();

    if (_activeSessionId != null && sessionRepository != null) {
      try {
        final parsed = int.tryParse(_activeSessionId!);
        if (parsed != null) {
          await sessionRepository!.endVideoSession(parsed);
        }
      } catch (_) {}
    }

    _activeSessionId = null;
    _updateState(VideoCallState.idle);
  }

  @override
  void toggleMic(bool enabled) {}

  @override
  void toggleCamera(bool enabled) {}

  @override
  void switchCamera() {}

  @override
  void toggleTorch(bool enabled) {}

  void dispose() {
    _signalingSub?.cancel();
    _stateController.close();
  }
}
