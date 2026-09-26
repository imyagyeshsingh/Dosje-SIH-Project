@Timeout(Duration(minutes: 5))
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dosje_sentinel/core/network/api_client.dart';
import 'package:dosje_sentinel/core/network/api_endpoints.dart';
import 'package:dosje_sentinel/core/error/app_exception.dart';
import 'package:dosje_sentinel/repositories/project_repository.dart';
import 'package:dosje_sentinel/repositories/cctv_repository.dart';
import 'package:dosje_sentinel/repositories/ai_detection_repository.dart';
import 'package:dosje_sentinel/shared/models/ai_detection_model.dart';
import 'package:dosje_sentinel/shared/providers/core_providers.dart';

void main() {
  group('AiDetectionModel & Serialization Integration', () {
    test('AiDetectionModel deserializes backend AIDetectionResponse accurately', () {
      final json = {
        'id': 101,
        'project_id': 20,
        'camera_id': 17,
        'people_detected': 8,
        'activity': 'NORMAL',
        'confidence': 0.9525,
        'timestamp': '2026-09-24T12:00:00Z',
        'created_at': '2026-09-24T12:00:01.123456Z',
      };

      final detection = AiDetectionModel.fromJson(json);

      expect(detection.id, 101);
      expect(detection.projectId, 20);
      expect(detection.cameraId, 17);
      expect(detection.peopleDetected, 8);
      expect(detection.activity, 'NORMAL');
      expect(detection.confidence, 0.9525);
      expect(detection.timestamp, DateTime.parse('2026-09-24T12:00:00Z'));
      expect(detection.createdAt, DateTime.parse('2026-09-24T12:00:01.123456Z'));

      final outJson = detection.toJson();
      expect(outJson['id'], 101);
      expect(outJson['project_id'], 20);
      expect(outJson['activity'], 'NORMAL');
    });

    test('AiDetectionSummaryModel handles nullable fields gracefully', () {
      final jsonWithNulls = {
        'project_id': 25,
        'latest_people_detected': null,
        'latest_activity': null,
        'latest_confidence': null,
        'latest_timestamp': null,
        'detection_count': 0,
      };

      final summary = AiDetectionSummaryModel.fromJson(jsonWithNulls);

      expect(summary.projectId, 25);
      expect(summary.latestPeopleDetected, isNull);
      expect(summary.latestActivity, isNull);
      expect(summary.latestConfidence, isNull);
      expect(summary.latestTimestamp, isNull);
      expect(summary.detectionCount, 0);

      final jsonWithData = {
        'project_id': 20,
        'latest_people_detected': 5,
        'latest_activity': 'NORMAL',
        'latest_confidence': 0.94,
        'latest_timestamp': '2026-09-24T12:00:00Z',
        'detection_count': 3,
      };

      final summaryWithData = AiDetectionSummaryModel.fromJson(jsonWithData);

      expect(summaryWithData.projectId, 20);
      expect(summaryWithData.latestPeopleDetected, 5);
      expect(summaryWithData.latestActivity, 'NORMAL');
      expect(summaryWithData.latestConfidence, 0.94);
      expect(summaryWithData.detectionCount, 3);
    });
  });

  group('ApiAiDetectionRepository Live Integration against FastAPI', () {
    late ApiClient client;
    late ApiProjectRepository projectRepo;
    late ApiCctvRepository cctvRepo;
    late ApiAiDetectionRepository aiRepo;

    setUp(() {
      ApiEndpoints.setBaseUrl('http://127.0.0.1:8000');
      client = ApiClient();
      projectRepo = ApiProjectRepository(apiClient: client);
      cctvRepo = ApiCctvRepository(
        apiClient: client,
        projectRepository: projectRepo,
      );
      aiRepo = ApiAiDetectionRepository(
        apiClient: client,
        projectRepository: projectRepo,
      );
    });

    test(
      'Full AI Detection Ingestion & Query Lifecycle against live backend',
      () async {
      // 1. Fetch an existing project and camera to associate with detection
      final projects = await projectRepo.getProjects(limit: 10);
      expect(projects, isNotEmpty);
      final project = projects.firstWhere(
        (p) => !p.code.startsWith('TEST-'),
        orElse: () => projects.first,
      );
      final numericProjectId = int.parse(project.id);

      // Ensure camera exists for this project
      var cameras = await cctvRepo.getCameras(facilityId: project.id);
      if (cameras.isEmpty) {
        final newCam = await cctvRepo.createCamera({
          'project_id': numericProjectId,
          'camera_name': 'AI Test Camera',
          'stream_url': 'rtsp://ai-test.local/stream1',
          'video_path': null,
          'resolution': '1080p',
          'fps': 30,
        });
        cameras = [newCam];
      }
      final camera = cameras.first;

      // 2. Ingest a detection through repository
      final detectionData = {
        'project_id': numericProjectId,
        'camera_id': camera.id,
        'people_detected': 4,
        'activity': 'NORMAL',
        'confidence': 0.92,
        'timestamp': DateTime.now().toUtc().toIso8601String(),
      };

      final created = await aiRepo.submitDetection(detectionData);
      expect(created.id, greaterThan(0));
      expect(created.projectId, numericProjectId);
      expect(created.cameraId, int.parse(camera.id));
      expect(created.peopleDetected, 4);
      expect(created.activity, 'NORMAL');
      expect(created.confidence, closeTo(0.92, 0.01));

      // 3. List detections for this project
      final list = await aiRepo.getProjectDetections(numericProjectId);
      expect(list.any((d) => d.id == created.id), isTrue);

      // 4. Also test resolution via project code
      final listByCode = await aiRepo.getProjectDetections(project.code);
      expect(listByCode.any((d) => d.id == created.id), isTrue);

      // 5. Get detection summary for this project
      final summary = await aiRepo.getProjectDetectionSummary(numericProjectId);
      expect(summary, isNotNull);
      expect(summary!.projectId, numericProjectId);
      expect(summary.detectionCount, greaterThanOrEqualTo(1));
      expect(summary.latestPeopleDetected, isNotNull);
      expect(summary.latestActivity, isNotNull);
    }, timeout: const Timeout(Duration(minutes: 3)));

    test('getProjectDetections returns empty list for non-existent project (404 handling)', () async {
      final list = await aiRepo.getProjectDetections(999999);
      expect(list, isEmpty);
    }, timeout: const Timeout(Duration(minutes: 2)));

    test('getProjectDetectionSummary returns null for non-existent project (404 handling)', () async {
      final summary = await aiRepo.getProjectDetectionSummary(999999);
      expect(summary, isNull);
    }, timeout: const Timeout(Duration(minutes: 2)));


    test('Validation Error: negative people_detected throws ValidationException', () async {
      final projects = await projectRepo.getProjects(limit: 1);
      final numericProjectId = int.parse(projects.first.id);

      expect(
        () async => await aiRepo.submitDetection({
          'project_id': numericProjectId,
          'camera_id': 1,
          'people_detected': -5,
          'activity': 'NORMAL',
          'confidence': 0.9,
          'timestamp': DateTime.now().toUtc().toIso8601String(),
        }),
        throwsA(isA<ValidationException>()),
      );
    });

    test('Validation Error: invalid activity string throws ValidationException', () async {
      final projects = await projectRepo.getProjects(limit: 1);
      final numericProjectId = int.parse(projects.first.id);

      expect(
        () async => await aiRepo.submitDetection({
          'project_id': numericProjectId,
          'camera_id': 1,
          'people_detected': 3,
          'activity': 'UNSUPPORTED_RANDOM_ACTION',
          'confidence': 0.9,
          'timestamp': DateTime.now().toUtc().toIso8601String(),
        }),
        throwsA(isA<ValidationException>()),
      );
    });
  });

  group('AI Detection Riverpod Providers Integration', () {
    setUp(() {
      ApiEndpoints.setBaseUrl('http://127.0.0.1:8000');
    });

    test('projectDetectionsProvider fetches detections via Riverpod container', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final projectRepo = container.read(projectRepositoryProvider);
      final projects = await projectRepo.getProjects(limit: 1);
      expect(projects, isNotEmpty);

      final detections = await container.read(
        projectDetectionsProvider(projects.first.id).future,
      );
      expect(detections, isA<List<AiDetectionModel>>());
    });

    test('projectDetectionSummaryProvider fetches summary via Riverpod container', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final projectRepo = container.read(projectRepositoryProvider);
      final projects = await projectRepo.getProjects(limit: 1);
      expect(projects, isNotEmpty);

      final summary = await container.read(
        projectDetectionSummaryProvider(projects.first.id).future,
      );
      expect(summary, isNotNull);
      expect(summary!.projectId, int.parse(projects.first.id));
    });

    test('projectDetectionSummaryProvider returns null for non-existent project 999999', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final summary = await container.read(
        projectDetectionSummaryProvider('999999').future,
      );
      expect(summary, isNull);
    });
  });
}
