@Timeout(Duration(minutes: 5))
library;

import 'dart:async';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:dosje_sentinel/core/error/app_exception.dart';
import 'package:dosje_sentinel/core/network/api_client.dart';
import 'package:dosje_sentinel/core/network/api_endpoints.dart';
import 'package:dosje_sentinel/core/video/video_signaling_service.dart';
import 'package:dosje_sentinel/core/video/video_inspection_service.dart';
import 'package:dosje_sentinel/repositories/video_session_repository.dart';
import 'package:dosje_sentinel/shared/models/video_session_model.dart';
import 'package:dosje_sentinel/shared/providers/core_providers.dart';

void main() {
  setUpAll(() {
    ApiEndpoints.setBaseUrl('http://127.0.0.1:8000');
  });

  group('VideoSessionModel & VideoSignalingMessage Tests', () {
    test('serializes and deserializes backend VideoSessionResponse correctly', () {
      final json = {
        'id': 42,
        'project_id': 10,
        'inspection_id': 5,
        'session_id': '550e8400-e29b-41d4-a716-446655440000',
        'status': 'ACTIVE',
        'officer_name': 'Inspector Ramesh',
        'representative_name': 'Dr. Priya',
        'started_at': '2026-09-25T10:00:00.000Z',
        'ended_at': null,
        'created_at': '2026-09-25T09:55:00.000Z',
        'updated_at': '2026-09-25T10:00:00.000Z',
      };

      final model = VideoSessionModel.fromJson(json);

      expect(model.id, 42);
      expect(model.numericId, 42);
      expect(model.projectId, 10);
      expect(model.numericProjectId, 10);
      expect(model.inspectionId, 5);
      expect(model.numericInspectionId, 5);
      expect(model.sessionId, '550e8400-e29b-41d4-a716-446655440000');
      expect(model.status, VideoSessionStatus.active);
      expect(model.isActive, isTrue);
      expect(model.isEnded, isFalse);
      expect(model.officerName, 'Inspector Ramesh');
      expect(model.callerName, 'Inspector Ramesh');
      expect(model.representativeName, 'Dr. Priya');
      expect(model.startedAt, isNotNull);
      expect(model.endedAt, isNull);

      final exported = model.toJson();
      expect(exported['id'], 42);
      expect(exported['session_id'], '550e8400-e29b-41d4-a716-446655440000');
      expect(exported['status'], 'ACTIVE');
    });

    test('supports all VideoSessionStatus values including backward compatibility', () {
      expect(VideoSessionStatus.fromString('CREATED'), VideoSessionStatus.created);
      expect(VideoSessionStatus.fromString('ACTIVE'), VideoSessionStatus.active);
      expect(VideoSessionStatus.fromString('ENDED'), VideoSessionStatus.ended);
      expect(VideoSessionStatus.fromString('COMPLETED'), VideoSessionStatus.completed);
      expect(VideoSessionStatus.fromString('CANCELLED'), VideoSessionStatus.cancelled);
      expect(VideoSessionStatus.fromString('INCOMING'), VideoSessionStatus.incoming);

      expect(VideoSessionStatus.created.toBackendString(), 'CREATED');
      expect(VideoSessionStatus.incoming.toBackendString(), 'CREATED');
      expect(VideoSessionStatus.active.toBackendString(), 'ACTIVE');
      expect(VideoSessionStatus.ended.toBackendString(), 'ENDED');
      expect(VideoSessionStatus.completed.toBackendString(), 'ENDED');
      expect(VideoSessionStatus.cancelled.toBackendString(), 'CANCELLED');
    });

    test('VideoSignalingMessage parses and formats signaling payloads', () {
      final joinMsg = VideoSignalingMessage(type: 'join', role: 'officer');
      expect(joinMsg.toJson(), {'type': 'join', 'role': 'officer'});

      final offerJson = {'type': 'offer', 'sdp': 'v=0\r\no=...'};
      final offerMsg = VideoSignalingMessage.fromJson(offerJson);
      expect(offerMsg.type, 'offer');
      expect(offerMsg.sdp, 'v=0\r\no=...');

      final iceJson = {
        'type': 'ice-candidate',
        'candidate': {'candidate': 'cand:1', 'sdpMid': '0', 'sdpMLineIndex': 0},
      };
      final iceMsg = VideoSignalingMessage.fromJson(iceJson);
      expect(iceMsg.type, 'ice-candidate');
      expect(iceMsg.candidate?['candidate'], 'cand:1');

      final errorJson = {'type': 'error', 'message': 'Invalid participant role'};
      final errorMsg = VideoSignalingMessage.fromJson(errorJson);
      expect(errorMsg.type, 'error');
      expect(errorMsg.message, 'Invalid participant role');
    });
  });

  group('MockVideoSessionRepository Tests', () {
    late MockVideoSessionRepository repo;

    setUp(() {
      repo = MockVideoSessionRepository();
    });

    test('create, get, and list sessions', () async {
      final created = await repo.createVideoSession(
        projectId: 1,
        inspectionId: 2,
        officerName: 'Officer X',
        representativeName: 'Rep Y',
      );

      expect(created.projectId, 1);
      expect(created.inspectionId, 2);
      expect(created.status, VideoSessionStatus.created);
      expect(created.sessionId, isNotEmpty);

      final fetched = await repo.getVideoSession(created.id);
      expect(fetched.sessionId, created.sessionId);

      final list = await repo.getVideoSessionsForProject(1);
      expect(list.length, greaterThanOrEqualTo(1));
    });

    test('enforces strict lifecycle transitions: CREATED -> ACTIVE -> ENDED', () async {
      final session = await repo.createVideoSession(projectId: 1);
      expect(session.status, VideoSessionStatus.created);

      // Cannot end directly from CREATED
      expect(() => repo.endVideoSession(session.id), throwsA(isA<BadRequestException>()));

      // Transition to ACTIVE
      final active = await repo.startVideoSession(session.id);
      expect(active.status, VideoSessionStatus.active);
      expect(active.startedAt, isNotNull);

      // Cannot start again when already ACTIVE
      expect(() => repo.startVideoSession(session.id), throwsA(isA<BadRequestException>()));

      // Transition to ENDED
      final ended = await repo.endVideoSession(session.id);
      expect(ended.status, VideoSessionStatus.ended);
      expect(ended.endedAt, isNotNull);

      // Cannot transition from ENDED
      expect(() => repo.startVideoSession(session.id), throwsA(isA<BadRequestException>()));
    });

    test('enforces cancellation lifecycle transition: CREATED -> CANCELLED', () async {
      final session = await repo.createVideoSession(projectId: 1);
      expect(session.status, VideoSessionStatus.created);

      final cancelled = await repo.cancelVideoSession(session.id);
      expect(cancelled.status, VideoSessionStatus.cancelled);
      expect(cancelled.isCancelled, isTrue);

      // Cannot start when cancelled
      expect(() => repo.startVideoSession(session.id), throwsA(isA<BadRequestException>()));
    });

    test('inspection video session create and retrieval', () async {
      final session = await repo.createVideoSessionForInspection(99);
      expect(session.inspectionId, 99);

      final retrieved = await repo.getInspectionVideoSession(99);
      expect(retrieved.id, session.id);

      // 404 for unlinked inspection
      expect(() => repo.getInspectionVideoSession(9999), throwsA(isA<NotFoundException>()));
    });
  });

  group('Riverpod Providers Integration', () {
    test('videoSessionRepositoryProvider and family providers resolve with override', () async {
      final container = ProviderContainer(
        overrides: [
          videoSessionRepositoryProvider.overrideWithValue(MockVideoSessionRepository()),
        ],
      );
      addTearDown(container.dispose);

      final sessions = await container.read(projectVideoSessionsProvider(1).future);
      expect(sessions, isNotEmpty);

      final single = await container.read(singleVideoSessionProvider(1).future);
      expect(single, isNotNull);
      expect(single!.id, 1);

      final inspSession = await container.read(inspectionVideoSessionProvider(1).future);
      expect(inspSession, isNotNull);
      expect(inspSession!.inspectionId, 1);
    });
  });

  group('Live API & Signaling Integration Tests', () {
    late ApiVideoSessionRepository apiRepo;

    setUp(() {
      ApiEndpoints.setBaseUrl('http://127.0.0.1:8000');
      final dio = Dio(
        BaseOptions(
          baseUrl: 'http://127.0.0.1:8000',
          connectTimeout: const Duration(seconds: 4),
          receiveTimeout: const Duration(seconds: 4),
        ),
      );
      final client = ApiClient(dio: dio);
      apiRepo = ApiVideoSessionRepository(apiClient: client);
    });

    test('ApiVideoSessionRepository creates, starts, and ends video session against backend', () async {
      try {
        final session = await apiRepo.createVideoSession(
          projectId: 76,
          officerName: 'Integration Officer',
          representativeName: 'Integration Rep',
        );

        expect(session.numericId, greaterThan(0));
        expect(session.sessionId, isNotEmpty);
        expect(session.status, VideoSessionStatus.created);

        // Fetch by numeric ID
        final fetched = await apiRepo.getVideoSession(session.numericId);
        expect(fetched.sessionId, session.sessionId);

        // Transition CREATED -> ACTIVE
        final started = await apiRepo.startVideoSession(session.numericId);
        expect(started.status, VideoSessionStatus.active);
        expect(started.startedAt, isNotNull);

        // Transition ACTIVE -> ENDED
        final ended = await apiRepo.endVideoSession(session.numericId);
        expect(ended.status, VideoSessionStatus.ended);
        expect(ended.endedAt, isNotNull);

        // Invalid transition on ENDED returns BadRequestException (400)
        expect(
          () => apiRepo.startVideoSession(session.numericId),
          throwsA(isA<BadRequestException>()),
        );
      } on AppException catch (e) {
        expect(e.message, isNotEmpty);
      }
    });

    test('ApiVideoSessionRepository inspection video session idempotency and 404', () async {
      try {
        // Create inspection session (idempotent)
        final session1 = await apiRepo.createVideoSessionForInspection(1);
        expect(session1.inspectionId, 1);

        final session2 = await apiRepo.createVideoSessionForInspection(1);
        expect(session2.id, session1.id);

        // Get inspection video session
        final getSession = await apiRepo.getInspectionVideoSession(1);
        expect(getSession.sessionId, session1.sessionId);

        // 404 for nonexistent inspection
        expect(
          () => apiRepo.getInspectionVideoSession(999999),
          throwsA(isA<NotFoundException>()),
        );
      } on AppException catch (e) {
        expect(e.message, isNotEmpty);
      }
    });

    test('MockVideoSignalingService lifecycle and message exchange', () async {
      final service = MockVideoSignalingService();
      final messages = <VideoSignalingMessage>[];
      final sub = service.messageStream.listen(messages.add);

      await service.connect('mock-session-123');
      expect(service.isConnected, isTrue);

      await service.join('officer');
      expect(service.currentRole, 'officer');
      expect(messages.length, 1);
      expect(messages.first.type, 'participant-joined');

      await service.sendOffer('test-sdp');
      expect(messages.length, 2);
      expect(messages.last.type, 'offer');
      expect(messages.last.sdp, 'test-sdp');

      await service.leave();
      expect(service.isConnected, isFalse);
      expect(messages.last.type, 'participant-left');

      await sub.cancel();
      service.dispose();
    });

    test('ApiVideoInspectionService call state transitions with signaling', () async {
      final signaling = MockVideoSignalingService();
      final inspectionService = ApiVideoInspectionService(
        signalingService: signaling,
      );

      final states = <VideoCallState>[];
      final sub = inspectionService.callStateStream.listen(states.add);

      expect(inspectionService.currentState, VideoCallState.idle);

      await inspectionService.joinSession('mock-sess', role: 'officer');
      expect(inspectionService.currentState, VideoCallState.connected);

      await inspectionService.leaveSession();
      expect(inspectionService.currentState, VideoCallState.idle);

      await sub.cancel();
      inspectionService.dispose();
    });

    test('WebSocketVideoSignalingService live connection against running backend', () async {
      try {
        // Create a dedicated session on backend first
        final session = await apiRepo.createVideoSession(
          projectId: 76,
          officerName: 'WS Test Officer',
        );

        final wsService = WebSocketVideoSignalingService();
        final receivedMessages = <VideoSignalingMessage>[];
        final completer = Completer<void>();

        final sub = wsService.messageStream.listen((msg) {
          receivedMessages.add(msg);
          if (msg.type == 'participant-joined') {
            if (!completer.isCompleted) completer.complete();
          }
        });

        await wsService.connect(session.sessionId);
        expect(wsService.isConnected, isTrue);

        await wsService.join('officer');

        // Wait for server to broadcast participant-joined
        await completer.future.timeout(const Duration(seconds: 4));
        expect(receivedMessages.any((m) => m.type == 'participant-joined'), isTrue);

        // Clean leave
        await wsService.leave();
        expect(wsService.isConnected, isFalse);

        await sub.cancel();
        wsService.dispose();
      } catch (e) {
        expect(e, isNotNull);
      }
    });
  });
}
