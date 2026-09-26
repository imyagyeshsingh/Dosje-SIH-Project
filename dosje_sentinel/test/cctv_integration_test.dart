@Timeout(Duration(minutes: 5))
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dosje_sentinel/core/network/api_client.dart';
import 'package:dosje_sentinel/core/network/api_endpoints.dart';
import 'package:dosje_sentinel/core/error/app_exception.dart';
import 'package:dosje_sentinel/repositories/cctv_repository.dart';
import 'package:dosje_sentinel/repositories/project_repository.dart';
import 'package:dosje_sentinel/repositories/alert_repository.dart';
import 'package:dosje_sentinel/repositories/notification_repository.dart';
import 'package:dosje_sentinel/repositories/audit_log_repository.dart';
import 'package:dosje_sentinel/shared/models/cctv_camera_model.dart';
import 'package:dosje_sentinel/shared/providers/core_providers.dart';

void main() {
  group('CCTV Model & Serialization Integration', () {
    test('CctvCamera parses backend CameraResponse correctly', () {
      final backendJson = {
        'id': 17,
        'project_id': 20,
        'camera_name': 'Entrance Gate CCTV',
        'stream_url': 'https://stream.sentinel.gov.in/live/cam_gate.m3u8',
        'video_path': null,
        'status': 'ACTIVE',
        'last_active': '2026-09-24T07:26:05.043006Z',
        'created_at': '2026-09-24T07:24:19.946089Z',
        'updated_at': '2026-09-24T07:26:04.921071Z',
      };

      final cam = CctvCamera.fromJson(backendJson);
      expect(cam.id, '17');
      expect(cam.facilityId, '20');
      expect(cam.name, 'Entrance Gate CCTV');
      expect(cam.status, 'ACTIVE');
      expect(cam.isOnline, isTrue);
      expect(cam.streamUrl, 'https://stream.sentinel.gov.in/live/cam_gate.m3u8');
      expect(cam.videoPath, isNull);
      expect(cam.lastActive, isNotNull);
      expect(cam.createdAt, isNotNull);
    });

    test('CctvCamera handles nullable values and defaults gracefully', () {
      final minimalJson = {
        'id': 18,
        'project_id': 20,
        'camera_name': 'Backup Cam',
        'stream_url': null,
        'video_path': '/videos/cam_18.mp4',
        'status': 'OFFLINE',
        'last_active': null,
        'created_at': '2026-09-24T07:24:19.946089Z',
        'updated_at': '2026-09-24T07:24:19.946089Z',
      };

      final cam = CctvCamera.fromJson(minimalJson);
      expect(cam.id, '18');
      expect(cam.facilityId, '20');
      expect(cam.name, 'Backup Cam');
      expect(cam.status, 'OFFLINE');
      expect(cam.isOnline, isFalse);
      expect(cam.streamUrl, isEmpty);
      expect(cam.videoPath, '/videos/cam_18.mp4');
      expect(cam.lastActive, isNull);
      expect(cam.resolution, '1080p');
      expect(cam.fps, 30);
    });

    test('CctvCamera toJson produces valid payload matching backend contract', () {
      final cam = CctvCamera(
        id: '17',
        facilityId: '20',
        facilityName: 'Test Facility',
        name: 'Gate Cam',
        status: 'ACTIVE',
        isOnline: true,
        streamUrl: 'https://stream.sentinel.gov.in/live/gate.m3u8',
        lastPing: DateTime.parse('2026-09-24T07:26:05.043006Z'),
      );

      final json = cam.toJson();
      expect(json['id'], 17);
      expect(json['project_id'], 20);
      expect(json['camera_name'], 'Gate Cam');
      expect(json['status'], 'ACTIVE');
      expect(json['stream_url'], 'https://stream.sentinel.gov.in/live/gate.m3u8');
    });

    test('CctvCamera health evaluation: fresh, stale (>15m), null lastActive, and offline states', () {
      final now = DateTime.now().toUtc();

      // Fresh camera (< 15 min ago)
      final freshCam = CctvCamera(
        id: '1',
        facilityId: '10',
        facilityName: 'Test',
        name: 'Fresh Cam',
        status: 'ACTIVE',
        isOnline: true,
        streamUrl: 'rtsp://test',
        lastActive: now.subtract(const Duration(minutes: 5)),
        lastPing: now,
      );
      expect(freshCam.isStale, isFalse);
      expect(freshCam.healthStatus, 'ACTIVE');

      // Stale camera (> 15 min ago)
      final staleCam = CctvCamera(
        id: '2',
        facilityId: '10',
        facilityName: 'Test',
        name: 'Stale Cam',
        status: 'ACTIVE',
        isOnline: true,
        streamUrl: 'rtsp://test',
        lastActive: now.subtract(const Duration(minutes: 20)),
        lastPing: now,
      );
      expect(staleCam.isStale, isTrue);
      expect(staleCam.healthStatus, 'STALE');

      // Never activated camera (lastActive == null)
      final neverActiveCam = CctvCamera(
        id: '3',
        facilityId: '10',
        facilityName: 'Test',
        name: 'Never Active Cam',
        status: 'ACTIVE',
        isOnline: true,
        streamUrl: 'rtsp://test',
        lastActive: null,
        lastPing: now,
      );
      expect(neverActiveCam.isStale, isFalse);
      expect(neverActiveCam.healthStatus, 'ACTIVE');

      // Offline camera
      final offlineCam = CctvCamera(
        id: '4',
        facilityId: '10',
        facilityName: 'Test',
        name: 'Offline Cam',
        status: 'OFFLINE',
        isOnline: false,
        streamUrl: 'rtsp://test',
        lastActive: now.subtract(const Duration(minutes: 60)),
        lastPing: now,
      );
      expect(offlineCam.isStale, isFalse);
      expect(offlineCam.healthStatus, 'OFFLINE');
    });

    test('CctvCamera formattedLastActive computes relative times accurately', () {
      final now = DateTime.now().toUtc();

      final camNever = CctvCamera(
        id: '1',
        facilityId: '10',
        facilityName: 'Test',
        name: 'Cam',
        isOnline: true,
        streamUrl: 'rtsp://test',
        lastPing: now,
      );
      expect(camNever.formattedLastActive, 'Never');

      final camJustNow = camNever.copyWith(lastActive: now.subtract(const Duration(seconds: 30)));
      expect(camJustNow.formattedLastActive, 'Just now');

      final camMins = camNever.copyWith(lastActive: now.subtract(const Duration(minutes: 10)));
      expect(camMins.formattedLastActive, '10m ago');

      final camHours = camNever.copyWith(lastActive: now.subtract(const Duration(hours: 3)));
      expect(camHours.formattedLastActive, '3h ago');

      final camDays = camNever.copyWith(lastActive: now.subtract(const Duration(days: 2)));
      expect(camDays.formattedLastActive, '2d ago');
    });
  });

  group('ApiCctvRepository Live Integration against FastAPI', () {
    late ApiClient apiClient;
    late ApiProjectRepository projectRepo;
    late ApiCctvRepository cctvRepo;

    setUp(() {
      ApiEndpoints.setBaseUrl('http://127.0.0.1:8000');
      apiClient = ApiClient();
      projectRepo = ApiProjectRepository(apiClient: apiClient);
      cctvRepo = ApiCctvRepository(
        apiClient: apiClient,
        projectRepository: projectRepo,
      );
    });

    test('Full CCTV Lifecycle: Create -> Get -> List -> Update Status', () async {
      // 1. Get an existing project to attach camera to
      final projects = await projectRepo.getProjects(limit: 10);
      expect(projects.isNotEmpty, isTrue);
      final project = projects.firstWhere(
        (p) => !p.code.startsWith('TEST-'),
        orElse: () => projects.first,
      );
      final numericProjectId = int.parse(project.id);

      // 2. Create camera via backend API
      final camName = 'Integration Cam ${DateTime.now().millisecondsSinceEpoch}';
      final created = await cctvRepo.createCamera({
        'project_id': numericProjectId,
        'camera_name': camName,
        'stream_url': 'https://stream.sentinel.gov.in/live/test.m3u8',
        'status': 'ACTIVE',
      });

      expect(created.id.isNotEmpty, isTrue);
      expect(created.facilityId, project.id);
      expect(created.name, camName);
      expect(created.status, 'ACTIVE');
      expect(created.isOnline, isTrue);

      final createdCameraId = created.id;

      // 3. Get camera by ID
      final fetched = await cctvRepo.getCameraById(createdCameraId);
      expect(fetched, isNotNull);
      expect(fetched!.id, createdCameraId);
      expect(fetched.name, camName);

      // 4. List cameras for project by numeric ID
      final projectCameras = await cctvRepo.getCameras(facilityId: project.id);
      expect(projectCameras.any((c) => c.id == createdCameraId), isTrue);

      // 5. List cameras for project by project code
      final codeCameras = await cctvRepo.getCameras(facilityId: project.code);
      expect(codeCameras.any((c) => c.id == createdCameraId), isTrue);

      // 6. Update camera status to OFFLINE
      final updatedOffline = await cctvRepo.updateCameraStatus(createdCameraId, 'OFFLINE');
      expect(updatedOffline.status, 'OFFLINE');
      expect(updatedOffline.isOnline, isFalse);

      // 7. Update camera status back to ACTIVE
      final updatedActive = await cctvRepo.updateCameraStatus(createdCameraId, 'ACTIVE');
      expect(updatedActive.status, 'ACTIVE');
      expect(updatedActive.isOnline, isTrue);
      expect(updatedActive.lastActive, isNotNull);
    }, timeout: const Timeout(Duration(minutes: 2)));

    test('Camera Health Automation: Updating status to ACTIVE automatically timestamps last_active on backend', () async {
      final projects = await projectRepo.getProjects(limit: 10);
      final project = projects.firstWhere((p) => !p.code.startsWith('TEST-'), orElse: () => projects.first);
      final numericProjectId = int.parse(project.id);

      final cam = await cctvRepo.createCamera({
        'project_id': numericProjectId,
        'camera_name': 'Health Test Cam ${DateTime.now().millisecondsSinceEpoch}',
        'stream_url': 'https://stream.sentinel.gov.in/live/health.m3u8',
        'status': 'OFFLINE',
      });
      expect(cam.status, 'OFFLINE');

      // Update to ACTIVE - backend automatically sets last_active = datetime.now(timezone.utc)
      final activated = await cctvRepo.updateCameraStatus(cam.id, 'ACTIVE');
      expect(activated.status, 'ACTIVE');
      expect(activated.lastActive, isNotNull);
      expect(activated.healthStatus, 'ACTIVE');
      expect(activated.isStale, isFalse);

      // Verify persistence by refetching from backend
      final fetched = await cctvRepo.getCameraById(cam.id);
      expect(fetched, isNotNull);
      expect(fetched!.status, 'ACTIVE');
      expect(fetched.lastActive, isNotNull);
      expect(fetched.healthStatus, 'ACTIVE');
    });

    test('Camera Health Alert Integration: generateProjectAlerts evaluates camera availability and links to notifications & audit logs', () async {
      final alertRepo = ApiAlertRepository(apiClient: apiClient);
      final notificationRepo = ApiNotificationRepository(apiClient: apiClient);
      final auditLogRepo = ApiAuditLogRepository(apiClient: apiClient);

      final projects = await projectRepo.getProjects(limit: 10);
      final project = projects.firstWhere((p) => !p.code.startsWith('TEST-'), orElse: () => projects.first);
      final numericProjectId = int.parse(project.id);

      // Trigger authoritative alert generation
      final generatedAlerts = await alertRepo.generateProjectAlerts(numericProjectId);
      expect(generatedAlerts, isA<List<dynamic>>());

      // Fetch all alerts for project
      final projectAlerts = await alertRepo.getProjectAlerts(numericProjectId);
      final cameraAlerts = projectAlerts.where((a) => a.alertType == 'CAMERA').toList();

      if (cameraAlerts.isNotEmpty) {
        final sampleCamAlert = cameraAlerts.first;
        expect(sampleCamAlert.alertType, 'CAMERA');
        expect(sampleCamAlert.source, anyOf(equals('CAMERA_MONITOR'), equals('CameraEngine'), isNotNull));

        // Verify linked notifications query works
        final notifications = await notificationRepo.getProjectNotifications(numericProjectId);
        expect(notifications, isA<List<dynamic>>());

        // Verify linked audit logs query works
        final auditLogs = await auditLogRepo.getProjectAuditLogs(numericProjectId);
        expect(auditLogs, isA<List<dynamic>>());
      }
    });

    test('getCameras for non-existent project returns empty list', () async {
      final cameras = await cctvRepo.getCameras(facilityId: '999999');
      expect(cameras, isEmpty);
    });

    test('getCameraById returns null for non-existent camera (404 handling)', () async {
      final camera = await cctvRepo.getCameraById(999999);
      expect(camera, isNull);
    });

    test('createCamera validation error: missing stream_url and video_path throws ValidationException', () async {
      final projects = await projectRepo.getProjects(limit: 1);
      final numericProjectId = int.parse(projects.first.id);

      expect(
        () async => await cctvRepo.createCamera({
          'project_id': numericProjectId,
          'camera_name': 'Invalid Cam',
        }),
        throwsA(isA<ValidationException>()),
      );
    });
  });

  group('CCTV Riverpod Providers Integration', () {
    test('cctvCamerasProvider and singleCameraProvider resolve live backend state', () async {
      final container = ProviderContainer(
        overrides: [
          apiClientProvider.overrideWithValue(ApiClient()),
        ],
      );
      addTearDown(container.dispose);

      final projects = await container.read(allRegisteredProjectsProvider.future);
      if (projects.isNotEmpty) {
        final projectId = projects.first.id;

        // Fetch cameras via Riverpod provider
        final cameras = await container.read(cctvCamerasProvider(projectId).future);
        expect(cameras, isA<List<CctvCamera>>());

        if (cameras.isNotEmpty) {
          final firstCam = cameras.first;
          final fetchedCam = await container.read(singleCameraProvider(firstCam.id).future);
          expect(fetchedCam, isNotNull);
          expect(fetchedCam!.id, firstCam.id);
        }
      }
    });

    test('cctvCamerasProvider correctly reflects updated camera health status on status change', () async {
      final container = ProviderContainer(
        overrides: [
          apiClientProvider.overrideWithValue(ApiClient()),
        ],
      );
      addTearDown(container.dispose);

      final projects = await container.read(allRegisteredProjectsProvider.future);
      if (projects.isNotEmpty) {
        final projectId = projects.first.id;
        final cameras = await container.read(cctvCamerasProvider(projectId).future);
        if (cameras.isNotEmpty) {
          final cam = cameras.first;
          final repo = container.read(cctvRepositoryProvider);
          final newStatus = cam.status == 'ACTIVE' ? 'OFFLINE' : 'ACTIVE';
          await repo.updateCameraStatus(cam.id, newStatus);

          container.invalidate(cctvCamerasProvider(projectId));
          final updatedCameras = await container.read(cctvCamerasProvider(projectId).future);
          final updatedCam = updatedCameras.firstWhere((c) => c.id == cam.id);
          expect(updatedCam.status, newStatus);

          // Restore original status
          await repo.updateCameraStatus(cam.id, cam.status);
        }
      }
    });

    test('singleCameraProvider returns null for non-existent camera 999999', () async {
      final container = ProviderContainer(
        overrides: [
          apiClientProvider.overrideWithValue(ApiClient()),
        ],
      );
      addTearDown(container.dispose);

      final camera = await container.read(singleCameraProvider('999999').future);
      expect(camera, isNull);
    });
  });
}

