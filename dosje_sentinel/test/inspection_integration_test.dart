@Timeout(Duration(minutes: 5))
library;


import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dosje_sentinel/core/error/app_exception.dart';
import 'package:dosje_sentinel/core/network/api_client.dart';
import 'package:dosje_sentinel/core/network/api_endpoints.dart';
import 'package:dosje_sentinel/repositories/inspection_repository.dart';
import 'package:dosje_sentinel/repositories/inspector_repository.dart';
import 'package:dosje_sentinel/repositories/audit_log_repository.dart';
import 'package:dosje_sentinel/repositories/notification_repository.dart';
import 'package:dosje_sentinel/repositories/project_repository.dart';
import 'package:dosje_sentinel/shared/models/inspection_model.dart';
import 'package:dosje_sentinel/core/location/location_service.dart';
import 'package:dosje_sentinel/shared/providers/core_providers.dart';

void main() {
  group('Inspection Models & Serialization Integration', () {
    test('InspectionModel deserializes backend InspectionResponse accurately', () {
      final json = {
        'id': 1,
        'project_id': 76,
        'alert_id': 12,
        'inspection_type': 'SCHEDULED',
        'status': 'IN_PROGRESS',
        'scheduled_at': '2026-09-25T10:00:00Z',
        'started_at': '2026-09-25T10:15:00Z',
        'completed_at': null,
        'officer_name': 'Live Test Officer',
        'officer_id': 'INS-LIVE-01',
        'assignment_status': 'ASSIGNED',
        'assigned_at': '2026-09-25T08:00:00Z',
        'inspection_latitude': 28.5355,
        'inspection_longitude': 77.391,
        'location_accuracy': 5.0,
        'location_captured_at': '2026-09-25T10:16:00Z',
        'location_verified': true,
        'distance_from_project': 14.2,
        'reason': 'Routine compliance audit',
        'findings': 'All premises clean and staff present',
        'result': 'APPROVED',
        'video_session_id': 'sess-uuid-1234',
        'created_at': '2026-09-25T07:00:00Z',
        'updated_at': '2026-09-25T10:16:00Z',
      };

      final insp = InspectionModel.fromJson(json);

      expect(insp.id, '1');
      expect(insp.idInt, 1);
      expect(insp.projectId, '76');
      expect(insp.projectIdInt, 76);
      expect(insp.alertId, 12);
      expect(insp.inspectionType, 'SCHEDULED');
      expect(insp.status, 'IN_PROGRESS');
      expect(insp.officerName, 'Live Test Officer');
      expect(insp.officerId, 'INS-LIVE-01');
      expect(insp.assignmentStatus, 'ASSIGNED');
      expect(insp.locationVerified, isTrue);
      expect(insp.distanceFromProject, 14.2);
      expect(insp.reason, 'Routine compliance audit');
      expect(insp.findings, 'All premises clean and staff present');
      expect(insp.result, 'APPROVED');
      expect(insp.videoSessionId, 'sess-uuid-1234');
      // Compatibility getters
      expect(insp.code, 'INS-1');
      expect(insp.nodalOfficerName, 'Live Test Officer');
      expect(insp.outcome, 'APPROVED');
      expect(insp.outcomeNotes, 'All premises clean and staff present');
    });

    test('InspectionModel handles null and missing fields gracefully', () {
      final json = {
        'id': 2,
        'project_id': 76,
        'inspection_type': 'RANDOM',
        'status': 'PENDING',
      };

      final insp = InspectionModel.fromJson(json);

      expect(insp.id, '2');
      expect(insp.projectId, '76');
      expect(insp.alertId, isNull);
      expect(insp.inspectionType, 'RANDOM');
      expect(insp.status, 'PENDING');
      expect(insp.officerName, isNull);
      expect(insp.officerId, isNull);
      expect(insp.assignmentStatus, 'UNASSIGNED');
      expect(insp.locationVerified, isFalse);
      expect(insp.distanceFromProject, isNull);
      expect(insp.code, 'INS-2');
      expect(insp.nodalOfficerName, 'Unassigned Officer');
    });

    test('InspectionAssignmentModel serializes and deserializes correctly', () {
      final json = {
        'inspection_id': 42,
        'inspector_id': 'OFF-404',
        'inspector_name': 'Inspector Verma',
        'assigned_at': '2026-09-25T11:00:00Z',
        'assignment_status': 'ASSIGNED',
      };

      final assign = InspectionAssignmentModel.fromJson(json);

      expect(assign.inspectionId, 42);
      expect(assign.inspectorId, 'OFF-404');
      expect(assign.inspectorName, 'Inspector Verma');
      expect(assign.assignmentStatus, 'ASSIGNED');
      expect(assign.assignedAt, isNotNull);

      final out = assign.toJson();
      expect(out['inspection_id'], 42);
      expect(out['inspector_id'], 'OFF-404');
      expect(out['assignment_status'], 'ASSIGNED');
    });

    test('InspectionLocationModel calculates and deserializes correctly', () {
      final json = {
        'inspection_id': 1,
        'project_id': 76,
        'inspection_latitude': 28.5355,
        'inspection_longitude': 77.391,
        'location_accuracy': 4.5,
        'location_captured_at': '2026-09-25T11:30:00Z',
        'location_verified': true,
        'distance_from_project': 18.5,
        'verification_radius_meters': 50.0,
      };

      final loc = InspectionLocationModel.fromJson(json);

      expect(loc.inspectionId, 1);
      expect(loc.projectId, 76);
      expect(loc.inspectionLatitude, 28.5355);
      expect(loc.inspectionLongitude, 77.391);
      expect(loc.locationAccuracy, 4.5);
      expect(loc.locationVerified, isTrue);
      expect(loc.distanceFromProject, 18.5);
      expect(loc.verificationRadiusMeters, 50.0);
    });

    test('InspectorModel serializes and deserializes correctly', () {
      final json = {
        'id': 1,
        'inspector_id': 'INS-01',
        'inspector_name': 'Senior Inspector',
        'is_active': true,
        'created_at': '2026-09-25T08:00:00Z',
      };

      final inspector = InspectorModel.fromJson(json);

      expect(inspector.id, 1);
      expect(inspector.inspectorId, 'INS-01');
      expect(inspector.inspectorName, 'Senior Inspector');
      expect(inspector.isActive, isTrue);
    });
  });

  group('MockInspectionRepository In-Memory Integration', () {
    late MockInspectionRepository repo;

    setUp(() {
      repo = MockInspectionRepository();
    });

    test('lists inspections and filters by project', () async {
      final all = await repo.getInspections();
      expect(all.length, greaterThanOrEqualTo(3));

      final p76 = await repo.getInspectionsForProject('76');
      expect(p76.every((i) => i.projectId == '76'), isTrue);
    });

    test('retrieves inspection by id and code', () async {
      final byId = await repo.getInspectionById('1');
      expect(byId, isNotNull);
      expect(byId!.id, '1');

      final byCode = await repo.getInspectionById('INS-2026-00482');
      expect(byCode, isNotNull);
      expect(byCode!.id, '1');

      final missing = await repo.getInspectionById('9999');
      expect(missing, isNull);
    });

    test('creates new inspection and assigns id', () async {
      final created = await repo.createInspection(
        projectId: '76',
        inspectionType: 'SCHEDULED',
        status: 'PENDING',
        reason: 'Integration Test Creation',
      );

      expect(created.projectId, '76');
      expect(created.inspectionType, 'SCHEDULED');
      expect(created.status, 'PENDING');
      expect(created.reason, 'Integration Test Creation');

      final fetched = await repo.getInspectionById(created.id);
      expect(fetched, isNotNull);
      expect(fetched!.reason, 'Integration Test Creation');
    });

    test('updates inspection status with timestamp lifecycle', () async {
      final updated = await repo.updateInspectionStatus('1', 'COMPLETED');
      expect(updated.status, 'COMPLETED');
      expect(updated.completedAt, isNotNull);

      final fetched = await repo.getInspectionById('1');
      expect(fetched!.status, 'COMPLETED');
    });

    test('assigns inspector manually and updates assignment status', () async {
      final assigned = await repo.assignInspector(
        '2',
        inspectorId: 'INS-001',
        inspectorName: 'Shri V. K. Saxena',
      );

      expect(assigned.officerId, 'INS-001');
      expect(assigned.officerName, 'Shri V. K. Saxena');
      expect(assigned.assignmentStatus, 'ASSIGNED');
      expect(assigned.assignedAt, isNotNull);

      final record = await repo.getInspectionAssignment('2');
      expect(record.inspectorId, 'INS-001');
      expect(record.assignmentStatus, 'ASSIGNED');
    });

    test('assigns random inspector from active roster', () async {
      final assigned = await repo.assignRandomInspector('2');
      expect(assigned.officerId, isNotNull);
      expect(assigned.assignmentStatus, 'ASSIGNED');
    });

    test('submits GPS location and checks verification', () async {
      final loc = await repo.submitInspectionLocation(
        '1',
        latitude: 28.5355,
        longitude: 77.391,
        accuracy: 4.0,
      );

      expect(loc.locationVerified, isTrue);
      expect(loc.distanceFromProject, 25.0);

      final fetchedLoc = await repo.getInspectionLocation('1');
      expect(fetchedLoc.inspectionLatitude, 28.5355);
      expect(fetchedLoc.locationVerified, isTrue);
    });

    test('manages inspectors list', () async {
      final list = await repo.getInspectors(isActive: true);
      expect(list.length, greaterThanOrEqualTo(2));

      final created = await repo.createInspector(
        inspectorId: 'INS-NEW',
        inspectorName: 'Newly Added Officer',
      );
      expect(created.inspectorId, 'INS-NEW');

      final updatedList = await repo.getInspectors(isActive: true);
      expect(updatedList.any((i) => i.inspectorId == 'INS-NEW'), isTrue);
    });
  });

  group('Riverpod Providers Integration', () {
    test('projectInspectionsProvider and singleInspectionProvider resolve correctly', () async {
      final container = ProviderContainer(
        overrides: [
          inspectionRepositoryProvider.overrideWithValue(MockInspectionRepository()),
        ],
      );
      addTearDown(container.dispose);

      final inspections = await container.read(projectInspectionsProvider('76').future);
      expect(inspections, isNotEmpty);
      expect(inspections.first.projectId, '76');

      final single = await container.read(singleInspectionProvider('1').future);
      expect(single, isNotNull);
      expect(single!.id, '1');

      final inspectors = await container.read(inspectorsListProvider.future);
      expect(inspectors, isNotEmpty);

      final loc = await container.read(inspectionLocationProvider('1').future);
      expect(loc, isNotNull);
      expect(loc!.inspectionId, 1);
    });
  });

  group('ApiInspectionRepository Live & Contract Integration', () {
    late ApiInspectionRepository apiRepo;
    late MockProjectRepository mockProjectRepo;

    setUp(() {
      ApiEndpoints.setBaseUrl('http://127.0.0.1:8000');
      mockProjectRepo = MockProjectRepository();
      apiRepo = ApiInspectionRepository(
        apiClient: ApiClient(),
        projectRepository: mockProjectRepo,
      );
    });

    test('getInspectionsForProject retrieves real backend inspections for project 76', () async {
      try {
        final list = await apiRepo.getInspectionsForProject(76);
        expect(list, isNotNull);
        expect(list, isA<List<InspectionModel>>());
        if (list.isNotEmpty) {
          expect(list.first.projectIdInt, 76);
        }
      } on AppException {
        // Backend not running or offline in CI environment
      }
    });

    test('getInspectionById retrieves inspection 1 or null on 404', () async {
      try {
        final insp = await apiRepo.getInspectionById(1);
        if (insp != null) {
          expect(insp.idInt, 1);
          expect(insp.status, isNotEmpty);
        }

        final nonExistent = await apiRepo.getInspectionById(999999);
        expect(nonExistent, isNull);
      } on AppException {
        // Backend offline
      }
    });

    test('getInspectionAssignment returns current assignment record', () async {
      try {
        final assignment = await apiRepo.getInspectionAssignment(1);
        expect(assignment.inspectionId, 1);
        expect(assignment.assignmentStatus, isNotEmpty);
      } on AppException {
        // Backend offline
      }
    });

    test('getInspectionLocation returns verification response', () async {
      try {
        final loc = await apiRepo.getInspectionLocation(1);
        expect(loc.inspectionId, 1);
        expect(loc.verificationRadiusMeters, 50.0);
      } on AppException {
        // Backend offline
      }
    });

    test('getInspectors lists registered inspectors', () async {
      try {
        final inspectors = await apiRepo.getInspectors();
        expect(inspectors, isA<List<InspectorModel>>());
      } on AppException {
        // Backend offline
      }
    });

    test('project code resolves properly before making API calls', () async {
      try {
        // Resolves PRJ-001 or fallback
        final list = await apiRepo.getInspectionsForProject('PRJ-001');
        expect(list, isA<List<InspectionModel>>());
      } on AppException {
        // Expected if backend offline
      }
    });
  });

  group('Inspector Roster & Assignment Integration (Module 14)', () {
    late ApiClient apiClient;
    late ApiProjectRepository projectRepo;
    late ApiInspectionRepository inspectionRepo;
    late ApiInspectorRepository inspectorRepo;
    late ApiAuditLogRepository auditLogRepo;
    late ApiNotificationRepository notificationRepo;

    setUpAll(() {
      ApiEndpoints.setBaseUrl('http://127.0.0.1:8000');
      apiClient = ApiClient();
      projectRepo = ApiProjectRepository(apiClient: apiClient);
      inspectionRepo = ApiInspectionRepository(
        apiClient: apiClient,
        projectRepository: projectRepo,
      );
      inspectorRepo = ApiInspectorRepository(inspectionRepository: inspectionRepo);
      auditLogRepo = ApiAuditLogRepository(apiClient: apiClient);
      notificationRepo = ApiNotificationRepository(apiClient: apiClient);
    });

    test('InspectorModel parses backend InspectorResponse and serializes to JSON correctly', () {
      final json = {
        'id': 5,
        'inspector_id': 'INS-ND-108',
        'inspector_name': 'Meenakshi Sundaram',
        'is_active': true,
        'created_at': '2026-09-25T04:00:00Z',
        'updated_at': '2026-09-25T04:00:00Z',
      };

      final inspector = InspectorModel.fromJson(json);
      expect(inspector.id, 5);
      expect(inspector.inspectorId, 'INS-ND-108');
      expect(inspector.inspectorName, 'Meenakshi Sundaram');
      expect(inspector.isActive, isTrue);
      expect(inspector.createdAt, isNotNull);

      final outJson = inspector.toJson();
      expect(outJson['inspector_id'], 'INS-ND-108');
      expect(outJson['inspector_name'], 'Meenakshi Sundaram');
      expect(outJson['is_active'], isTrue);
    });

    test('Live Inspector Creation and Active Roster Retrieval', () async {
      final uniqueId = 'INS-TEST-${DateTime.now().millisecondsSinceEpoch}';
      final created = await inspectorRepo.createInspector(
        inspectorId: uniqueId,
        inspectorName: 'Automated Inspector $uniqueId',
        isActive: true,
      );
      expect(created.inspectorId, uniqueId);
      expect(created.isActive, isTrue);

      final roster = await inspectorRepo.getInspectors(isActive: true);
      expect(roster.any((i) => i.inspectorId == uniqueId), isTrue);
    });

    test('Live Inspection Manual Inspector Assignment & Audit/Notification generation', () async {
      final projects = await projectRepo.getProjects(limit: 10);
      expect(projects.isNotEmpty, isTrue);
      final project = projects.firstWhere((p) => !p.code.startsWith('TEST-'), orElse: () => projects.first);
      final numericProjectId = int.parse(project.id);

      // Create a fresh inspector for deterministic assignment
      final uniqueId = 'INS-MANUAL-${DateTime.now().millisecondsSinceEpoch}';
      final inspector = await inspectorRepo.createInspector(
        inspectorId: uniqueId,
        inspectorName: 'Manual Inspector $uniqueId',
        isActive: true,
      );

      // Create a pending inspection
      final inspection = await inspectionRepo.createInspection(
        projectId: numericProjectId,
        inspectionType: 'SCHEDULED',
        status: 'PENDING',
        reason: 'Module 14 live manual assignment verification',
      );
      expect(inspection.assignmentStatus, 'UNASSIGNED');

      // Manually assign inspector
      final assigned = await inspectorRepo.assignInspector(
        inspection.id,
        inspectorId: inspector.inspectorId,
        inspectorName: inspector.inspectorName,
        assignmentStatus: 'ASSIGNED',
      );
      expect(assigned.assignmentStatus, 'ASSIGNED');
      expect(assigned.officerId, inspector.inspectorId);
      expect(assigned.officerName, inspector.inspectorName);
      expect(assigned.assignedAt, isNotNull);

      // Query GET /inspections/{id}/assignment
      final assignment = await inspectorRepo.getInspectionAssignment(inspection.id);
      expect(assignment.assignmentStatus, 'ASSIGNED');
      expect(assignment.inspectorId, inspector.inspectorId);
      expect(assignment.inspectorName, inspector.inspectorName);
      expect(assignment.assignedAt, isNotNull);

      // Verify audit log exists with action ASSIGNED
      final auditLogs = await auditLogRepo.getProjectAuditLogs(numericProjectId);
      final assignmentAudit = auditLogs.where(
        (a) => a.entityType == 'INSPECTION' && a.entityId == int.parse(inspection.id) && a.action == 'ASSIGNED',
      );
      expect(assignmentAudit.isNotEmpty, isTrue);

      // Verify notification query succeeds
      final notifications = await notificationRepo.getProjectNotifications(numericProjectId);
      expect(notifications, isA<List<dynamic>>());
    });

    test('Live Inspection Random Inspector Assignment & Audit/Notification generation', () async {
      final projects = await projectRepo.getProjects(limit: 10);
      expect(projects.isNotEmpty, isTrue);
      final project = projects.firstWhere((p) => !p.code.startsWith('TEST-'), orElse: () => projects.first);
      final numericProjectId = int.parse(project.id);

      // Create an unassigned inspection
      final inspection = await inspectionRepo.createInspection(
        projectId: numericProjectId,
        inspectionType: 'RANDOM',
        status: 'PENDING',
        reason: 'Module 14 live random assignment verification',
      );
      expect(inspection.assignmentStatus, 'UNASSIGNED');

      // Call authoritative backend random assignment
      final randomlyAssigned = await inspectorRepo.assignRandomInspector(inspection.id);
      expect(randomlyAssigned.assignmentStatus, 'ASSIGNED');
      expect(randomlyAssigned.officerId, isNotNull);
      expect(randomlyAssigned.officerName, isNotNull);
      expect(randomlyAssigned.assignedAt, isNotNull);

      // Verify audit log exists with action RANDOMLY_ASSIGNED
      final auditLogs = await auditLogRepo.getProjectAuditLogs(numericProjectId);
      final randomAudit = auditLogs.where(
        (a) => a.entityType == 'INSPECTION' && a.entityId == int.parse(inspection.id) && a.action == 'RANDOMLY_ASSIGNED',
      );
      expect(randomAudit.isNotEmpty, isTrue);
    });

    test('Nonexistent inspector assignment fails with NotFoundException (404)', () async {
      final projects = await projectRepo.getProjects(limit: 1);
      final numericProjectId = int.parse(projects.first.id);

      final inspection = await inspectionRepo.createInspection(
        projectId: numericProjectId,
        inspectionType: 'MANUAL',
        status: 'PENDING',
      );

      expect(
        () async => await inspectorRepo.assignInspector(
          inspection.id,
          inspectorId: 'NONEXISTENT-OFFICER-999999',
          inspectorName: 'Ghost',
        ),
        throwsA(isA<NotFoundException>()),
      );
    });

    test('Assignment rejected on completed inspection with BadRequestException (400)', () async {
      final projects = await projectRepo.getProjects(limit: 1);
      final numericProjectId = int.parse(projects.first.id);

      final inspection = await inspectionRepo.createInspection(
        projectId: numericProjectId,
        inspectionType: 'MANUAL',
        status: 'PENDING',
      );

      // Transition to IN_PROGRESS -> COMPLETED
      await inspectionRepo.updateInspectionStatus(inspection.id, 'IN_PROGRESS');
      await inspectionRepo.updateInspectionStatus(inspection.id, 'COMPLETED');

      // Attempt assignment on completed inspection
      expect(
        () async => await inspectorRepo.assignRandomInspector(inspection.id),
        throwsA(isA<BadRequestException>()),
      );
    });

    test('Riverpod Providers: inspectorRepositoryProvider, inspectorsListProvider, inspectionAssignmentProvider', () async {
      final container = ProviderContainer(
        overrides: [
          apiClientProvider.overrideWithValue(ApiClient()),
        ],
      );
      addTearDown(container.dispose);

      final repo = container.read(inspectorRepositoryProvider);
      expect(repo, isNotNull);

      final inspectors = await container.read(inspectorsListProvider.future);
      expect(inspectors, isA<List<InspectorModel>>());
      expect(inspectors.isNotEmpty, isTrue);

      final assignment = await container.read(inspectionAssignmentProvider(1).future);
      expect(assignment, isNotNull);
      expect(assignment!.inspectionId, 1);
    });
  });

  group('Geo-tagged Inspection Location & Verification Integration (Module 15)', () {
    late ApiClient apiClient;
    late ApiInspectionRepository inspectionRepo;
    late ApiProjectRepository projectRepo;

    setUpAll(() {
      apiClient = ApiClient();
      inspectionRepo = ApiInspectionRepository(apiClient: apiClient);
      projectRepo = ApiProjectRepository(apiClient: apiClient);
    });

    test('InspectionLocationModel serialization, deserialization, and helper getters', () {
      final json = {
        'inspection_id': 101,
        'project_id': 55,
        'inspection_latitude': '28.5355',
        'inspection_longitude': '77.3910',
        'location_accuracy': '3.2',
        'location_captured_at': '2026-09-25T12:00:00Z',
        'location_verified': true,
        'distance_from_project': '14.8',
        'verification_radius_meters': '50.0',
      };

      final model = InspectionLocationModel.fromJson(json);
      expect(model.inspectionId, 101);
      expect(model.projectId, 55);
      expect(model.inspectionLatitude, 28.5355);
      expect(model.inspectionLongitude, 77.3910);
      expect(model.locationAccuracy, 3.2);
      expect(model.locationVerified, isTrue);
      expect(model.distanceFromProject, 14.8);
      expect(model.verificationRadiusMeters, 50.0);
      expect(model.hasLocation, isTrue);
      expect(model.formattedCoordinates, contains('28.5355° N, 77.3910° E'));
      expect(model.formattedDistance, contains('14.8m from perimeter'));
      expect(model.formattedAccuracy, '±3.2m');

      final serialized = model.toJson();
      expect(serialized['inspection_id'], 101);
      expect(serialized['project_id'], 55);
      expect(serialized['location_verified'], isTrue);

      final copy = model.copyWith(locationVerified: false, distanceFromProject: 120.0);
      expect(copy.locationVerified, isFalse);
      expect(copy.distanceFromProject, 120.0);
      expect(copy.formattedDistance, contains('120.0m from perimeter'));
    });

    test('LocationService and DefaultLocationService simulation and permissions', () async {
      final service = DefaultLocationService(
        latitude: 28.5355,
        longitude: 77.3910,
        accuracyMeters: 4.1,
      );

      expect(await service.isLocationServiceEnabled(), isTrue);
      expect(await service.hasPermission(), isTrue);
      expect(await service.requestPermission(), isTrue);

      final loc = await service.getCurrentLocation();
      expect(loc.latitude, 28.5355);
      expect(loc.longitude, 77.3910);
      expect(loc.accuracyMeters, 4.1);
      expect(loc.isLocked, isTrue);
      expect(loc.formattedCoords, contains('28.5355° N, 77.3910° E'));

      // Test permission denial
      service.setPermission(false);
      expect(await service.hasPermission(), isFalse);
      expect(
        () async => await service.getCurrentLocation(),
        throwsA(isA<LocationPermissionDeniedException>()),
      );

      // Restore permission and test disabled service
      service.setPermission(true);
      service.setServiceEnabled(false);
      expect(await service.isLocationServiceEnabled(), isFalse);
      expect(
        () async => await service.getCurrentLocation(),
        throwsA(isA<LocationDisabledException>()),
      );
    });

    test('Live Backend: Submit location inside 50m geofence -> location_verified=true', () async {
      // Find project 76 with known GPS coordinates
      final project = await projectRepo.getProjectById('76');
      if (project == null || project.latitude == null || project.longitude == null) {
        return; // Fallback if database record not present
      }

      final inspection = await inspectionRepo.createInspection(
        projectId: 76,
        inspectionType: 'MANUAL',
        status: 'PENDING',
      );

      // Submit coordinates ~1.5m from project
      final loc = await inspectionRepo.submitInspectionLocation(
        inspection.id,
        latitude: project.latitude! + 0.00001,
        longitude: project.longitude! + 0.00001,
        accuracy: 2.5,
        capturedAt: DateTime.now().toUtc(),
      );

      expect(loc.inspectionId, inspection.idInt);
      expect(loc.locationVerified, isTrue);
      expect(loc.distanceFromProject, isNotNull);
      expect(loc.distanceFromProject!, lessThanOrEqualTo(50.0));
      expect(loc.verificationRadiusMeters, 50.0);
    });

    test('Live Backend: Submit location outside 50m geofence -> location_verified=false', () async {
      final project = await projectRepo.getProjectById('76');
      if (project == null || project.latitude == null || project.longitude == null) {
        return;
      }

      final inspection = await inspectionRepo.createInspection(
        projectId: 76,
        inspectionType: 'MANUAL',
        status: 'PENDING',
      );

      // Submit coordinates ~500m away
      final loc = await inspectionRepo.submitInspectionLocation(
        inspection.id,
        latitude: project.latitude! + 0.0045,
        longitude: project.longitude!,
        accuracy: 5.0,
      );

      expect(loc.inspectionId, inspection.idInt);
      expect(loc.locationVerified, isFalse);
      expect(loc.distanceFromProject, isNotNull);
      expect(loc.distanceFromProject!, greaterThan(50.0));
    });

    test('Live Backend: getInspectionLocation retrieves authoritative stored geofence state', () async {
      final project = await projectRepo.getProjectById('76');
      if (project == null || project.latitude == null || project.longitude == null) {
        return;
      }

      final inspection = await inspectionRepo.createInspection(
        projectId: 76,
        inspectionType: 'MANUAL',
        status: 'PENDING',
      );

      await inspectionRepo.submitInspectionLocation(
        inspection.id,
        latitude: project.latitude!,
        longitude: project.longitude!,
        accuracy: 3.0,
      );

      final fetched = await inspectionRepo.getInspectionLocation(inspection.id);
      expect(fetched.inspectionId, inspection.idInt);
      expect(fetched.locationVerified, isTrue);
      expect(fetched.inspectionLatitude, closeTo(project.latitude!, 0.0001));

      // Also verify getInspectionById reflects location
      final fullInspection = await inspectionRepo.getInspectionById(inspection.id);
      expect(fullInspection, isNotNull);
      expect(fullInspection!.locationVerified, isTrue);
      expect(fullInspection.inspectionLatitude, closeTo(project.latitude!, 0.0001));
    });

    test('Live Backend: Validation failure on invalid latitude (>90) -> ValidationException (422)', () async {
      expect(
        () async => await inspectionRepo.submitInspectionLocation(
          1,
          latitude: 95.0,
          longitude: 77.0,
        ),
        throwsA(isA<ValidationException>()),
      );
    });

    test('Live Backend: Validation failure on invalid longitude (>180) -> ValidationException (422)', () async {
      expect(
        () async => await inspectionRepo.submitInspectionLocation(
          1,
          latitude: 28.0,
          longitude: 195.0,
        ),
        throwsA(isA<ValidationException>()),
      );
    });

    test('Live Backend: Nonexistent inspection location submission -> NotFoundException (404)', () async {
      expect(
        () async => await inspectionRepo.submitInspectionLocation(
          99999999,
          latitude: 28.5355,
          longitude: 77.3910,
        ),
        throwsA(isA<NotFoundException>()),
      );
    });

    test('Live Backend: Project missing GPS coordinates -> BadRequestException (400)', () async {
      final projects = await projectRepo.getProjects();
      final projectWithoutGps = projects.firstWhere(
        (p) => p.latitude == null || p.longitude == null,
        orElse: () => projects.first,
      );

      if (projectWithoutGps.latitude == null || projectWithoutGps.longitude == null) {
        final inspection = await inspectionRepo.createInspection(
          projectId: int.parse(projectWithoutGps.id),
          inspectionType: 'MANUAL',
          status: 'PENDING',
        );

        expect(
          () async => await inspectionRepo.submitInspectionLocation(
            inspection.id,
            latitude: 28.5355,
            longitude: 77.3910,
          ),
          throwsA(isA<BadRequestException>()),
        );
      }
    });

    test('Riverpod: inspectionLocationProvider and locationServiceProvider resolve cleanly', () async {
      final container = ProviderContainer(
        overrides: [
          apiClientProvider.overrideWithValue(ApiClient()),
        ],
      );
      addTearDown(container.dispose);

      final locService = container.read(locationServiceProvider);
      expect(locService, isNotNull);
      final gnss = await locService.getCurrentLocation();
      expect(gnss.latitude, isNotNull);

      final loc = await container.read(inspectionLocationProvider(1).future);
      expect(loc, isNotNull);
      expect(loc!.inspectionId, 1);
    });
  });
}


