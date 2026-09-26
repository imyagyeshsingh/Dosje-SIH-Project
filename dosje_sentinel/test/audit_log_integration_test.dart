@Timeout(Duration(minutes: 5))
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dosje_sentinel/core/error/app_exception.dart';
import 'package:dosje_sentinel/core/network/api_client.dart';
import 'package:dosje_sentinel/core/network/api_endpoints.dart';
import 'package:dosje_sentinel/repositories/audit_log_repository.dart';
import 'package:dosje_sentinel/repositories/project_repository.dart';
import 'package:dosje_sentinel/repositories/inspection_repository.dart';
import 'package:dosje_sentinel/shared/models/audit_log_model.dart';
import 'package:dosje_sentinel/shared/providers/core_providers.dart';

void main() {
  group('AuditLogModel & Serialization Integration', () {
    test('AuditLogModel deserializes backend AuditLogResponse accurately', () {
      final json = {
        'id': 101,
        'project_id': 20,
        'entity_type': 'INSPECTION',
        'entity_id': 42,
        'action': 'CREATED',
        'actor_id': 'OFF-77',
        'actor_name': 'Inspector Jane',
        'details': 'Surprise field inspection initiated',
        'created_at': '2026-09-24T12:00:00.123456Z',
      };

      final log = AuditLogModel.fromJson(json);

      expect(log.id, 101);
      expect(log.projectId, 20);
      expect(log.entityType, 'INSPECTION');
      expect(log.entityId, 42);
      expect(log.action, 'CREATED');
      expect(log.actorId, 'OFF-77');
      expect(log.actorName, 'Inspector Jane');
      expect(log.details, 'Surprise field inspection initiated');
      expect(log.createdAt, DateTime.parse('2026-09-24T12:00:00.123456Z'));
      expect(log.actorDisplay, 'Inspector Jane (OFF-77)');
      expect(log.displayTitle, 'INSPECTION • CREATED');
    });

    test('AuditLogModel handles nullable fields gracefully', () {
      final json = {
        'id': 102,
        'project_id': null,
        'entity_type': 'ALERT',
        'entity_id': null,
        'action': 'CREATED',
        'actor_id': null,
        'actor_name': null,
        'details': null,
        'created_at': '2026-09-24T12:05:00Z',
      };

      final log = AuditLogModel.fromJson(json);

      expect(log.id, 102);
      expect(log.projectId, isNull);
      expect(log.entityId, isNull);
      expect(log.actorId, isNull);
      expect(log.actorName, isNull);
      expect(log.details, isNull);
      expect(log.actorDisplay, 'System Engine');
    });

    test('AuditLogModel helper getters format actor and dates properly', () {
      final logOnlyId = AuditLogModel(
        id: 1,
        entityType: 'PROJECT',
        action: 'UPDATED',
        actorId: 'ACTOR-1',
        createdAt: DateTime(2026, 9, 25, 14, 30),
      );
      expect(logOnlyId.actorDisplay, 'ACTOR-1');
      expect(logOnlyId.formattedDate, '2026-09-25 14:30');

      final logOnlyName = AuditLogModel(
        id: 2,
        entityType: 'REPORT',
        action: 'SUBMITTED',
        actorName: 'Nodal Officer',
        createdAt: DateTime(2026, 9, 25, 9, 5),
      );
      expect(logOnlyName.actorDisplay, 'Nodal Officer');
      expect(logOnlyName.formattedDate, '2026-09-25 09:05');
    });

    test('AuditLogModel serializes to JSON matching backend AuditLogCreate contract', () {
      final log = AuditLogModel(
        id: 200,
        projectId: 76,
        entityType: 'INSPECTION',
        entityId: 99,
        action: 'STATUS_CHANGED',
        actorId: 'OFF-1',
        actorName: 'Director',
        details: 'Approved compliance dossier',
        createdAt: DateTime(2026, 9, 25, 10, 0),
      );

      final json = log.toJson();

      expect(json['id'], 200);
      expect(json['project_id'], 76);
      expect(json['entity_type'], 'INSPECTION');
      expect(json['entity_id'], 99);
      expect(json['action'], 'STATUS_CHANGED');
      expect(json['actor_id'], 'OFF-1');
      expect(json['actor_name'], 'Director');
      expect(json['details'], 'Approved compliance dossier');
      expect(json['created_at'], isNotEmpty);
    });
  });

  group('MockAuditLogRepository In-Memory Integration', () {
    late MockAuditLogRepository repo;

    setUp(() {
      repo = MockAuditLogRepository();
    });

    test('returns seeded audit logs sorted newest first', () async {
      final logs = await repo.getAuditLogs();
      expect(logs.length, 4);
      for (int i = 0; i < logs.length - 1; i++) {
        expect(logs[i].createdAt.isAfter(logs[i + 1].createdAt) ||
               logs[i].createdAt.isAtSameMomentAs(logs[i + 1].createdAt), isTrue);
      }
    });

    test('filters by project_id, entity_type, action, and actor_id', () async {
      final project1Logs = await repo.getProjectAuditLogs(1);
      expect(project1Logs.length, 3);
      for (final l in project1Logs) {
        expect(l.projectId, 1);
      }

      final inspectionLogs = await repo.getAuditLogs(entityType: 'INSPECTION');
      expect(inspectionLogs.length, 2);
      for (final l in inspectionLogs) {
        expect(l.entityType, 'INSPECTION');
      }

      final alertLogs = await repo.getAuditLogs(entityType: 'ALERT');
      expect(alertLogs.length, 1);
      expect(alertLogs.first.entityType, 'ALERT');

      final assignedLogs = await repo.getAuditLogs(action: 'ASSIGNED');
      expect(assignedLogs.length, 1);
      expect(assignedLogs.first.action, 'ASSIGNED');
    });

    test('pagination supports limit and offset', () async {
      final page1 = await repo.getAuditLogs(limit: 2, offset: 0);
      expect(page1.length, 2);

      final page2 = await repo.getAuditLogs(limit: 2, offset: 2);
      expect(page2.length, 2);

      expect(page1.first.id, isNot(page2.first.id));

      final emptyPage = await repo.getAuditLogs(limit: 10, offset: 100);
      expect(emptyPage, isEmpty);
    });

    test('retrieves audit log by ID and returns null for missing ID', () async {
      final log1 = await repo.getAuditLogById(1);
      expect(log1, isNotNull);
      expect(log1!.id, 1);
      expect(log1.entityType, 'INSPECTION');

      final missing = await repo.getAuditLogById(99999);
      expect(missing, isNull);
    });

    test('creates new audit log and prepends to log stream', () async {
      final created = await repo.createAuditLog(
        projectId: 1,
        entityType: 'REPORT',
        entityId: 10,
        action: 'VERIFIED',
        actorId: 'OFF-88',
        actorName: 'Senior Auditor',
        details: 'Verified financial expenditure and meal vouchers',
      );

      expect(created.id, greaterThan(4));
      expect(created.entityType, 'REPORT');
      expect(created.action, 'VERIFIED');

      final all = await repo.getAuditLogs();
      expect(all.first.id, created.id);
      expect(all.length, 5);
    });
  });

  group('Riverpod Providers Integration', () {
    test('auditLogsProvider fetches logs via Riverpod container', () async {
      final mockRepo = MockAuditLogRepository();
      final container = ProviderContainer(
        overrides: [
          auditLogRepositoryProvider.overrideWithValue(mockRepo),
        ],
      );
      addTearDown(container.dispose);

      final logs = await container.read(auditLogsProvider.future);
      expect(logs, isA<List<AuditLogModel>>());
      expect(logs.length, 4);
    });

    test('projectAuditLogsProvider fetches project-scoped audit logs', () async {
      final mockRepo = MockAuditLogRepository();
      final container = ProviderContainer(
        overrides: [
          auditLogRepositoryProvider.overrideWithValue(mockRepo),
        ],
      );
      addTearDown(container.dispose);

      final logs = await container.read(projectAuditLogsProvider(1).future);
      expect(logs.length, 3);
      for (final l in logs) {
        expect(l.projectId, 1);
      }
    });

    test('singleAuditLogProvider retrieves single log or null', () async {
      final mockRepo = MockAuditLogRepository();
      final container = ProviderContainer(
        overrides: [
          auditLogRepositoryProvider.overrideWithValue(mockRepo),
        ],
      );
      addTearDown(container.dispose);

      final log = await container.read(singleAuditLogProvider(1).future);
      expect(log, isNotNull);
      expect(log!.id, 1);

      final missing = await container.read(singleAuditLogProvider(9999).future);
      expect(missing, isNull);
    });

    test('entityAuditLogsProvider filters logs for specific entity', () async {
      final mockRepo = MockAuditLogRepository();
      final container = ProviderContainer(
        overrides: [
          auditLogRepositoryProvider.overrideWithValue(mockRepo),
        ],
      );
      addTearDown(container.dispose);

      final logs = await container.read(
        entityAuditLogsProvider((entityType: 'INSPECTION', entityId: 101)).future,
      );
      expect(logs.length, 2);
      for (final l in logs) {
        expect(l.entityType, 'INSPECTION');
        expect(l.entityId, 101);
      }
    });
  });

  group('ApiAuditLogRepository Live Integration against FastAPI', () {
    late ApiClient apiClient;
    late ApiAuditLogRepository auditRepo;
    late ApiProjectRepository projectRepo;
    late ApiInspectionRepository inspectionRepo;
    late int stableProjectId;

    setUpAll(() async {
      ApiEndpoints.setBaseUrl('http://127.0.0.1:8000');
      apiClient = ApiClient();
      projectRepo = ApiProjectRepository(apiClient: apiClient);
      auditRepo = ApiAuditLogRepository(
        apiClient: apiClient,
        projectRepository: projectRepo,
      );
      inspectionRepo = ApiInspectionRepository(
        apiClient: apiClient,
        projectRepository: projectRepo,
      );

      final projects = await projectRepo.getProjects(limit: 10);
      final stable = projects.firstWhere(
        (p) => p.code == 'NEON-TEST-001',
        orElse: () => projects.first,
      );
      stableProjectId = int.parse(stable.id);
    });

    test('Live Audit Log: fetch audit logs with default limit and pagination', () async {
      final logs = await auditRepo.getAuditLogs(limit: 10);
      expect(logs, isA<List<AuditLogModel>>());

      if (logs.isNotEmpty) {
        final first = logs.first;
        expect(first.id, greaterThan(0));
        expect(first.entityType, isNotEmpty);
        expect(first.action, isNotEmpty);
      }
    }, timeout: const Timeout(Duration(minutes: 2)));

    test('Live Audit Log: create audit log entry via POST /audit-logs and verify 201 response', () async {
      final testUnique = DateTime.now().millisecondsSinceEpoch;
      final created = await auditRepo.createAuditLog(
        projectId: stableProjectId,
        entityType: 'INSPECTION_AUDIT',
        entityId: 99,
        action: 'LIVE_TEST_ACTION',
        actorId: 'OFFICER_$testUnique',
        actorName: 'Audit Test Officer',
        details: 'Live automated verification of audit log creation $testUnique',
      );

      expect(created.id, greaterThan(0));
      expect(created.projectId, stableProjectId);
      expect(created.entityType, 'INSPECTION_AUDIT');
      expect(created.action, 'LIVE_TEST_ACTION');
      expect(created.actorId, 'OFFICER_$testUnique');
      expect(created.actorName, 'Audit Test Officer');
      expect(created.details, contains('Live automated verification'));

      // Fetch by ID
      final fetched = await auditRepo.getAuditLogById(created.id);
      expect(fetched, isNotNull);
      expect(fetched!.id, created.id);
      expect(fetched.action, 'LIVE_TEST_ACTION');
    }, timeout: const Timeout(Duration(minutes: 2)));

    test('Live Audit Log: query project audit logs via GET /audit-logs/project/{project_id}', () async {
      final projectLogs = await auditRepo.getProjectAuditLogs(stableProjectId, limit: 20);
      expect(projectLogs, isA<List<AuditLogModel>>());
      for (final log in projectLogs) {
        expect(log.projectId, stableProjectId);
      }
    }, timeout: const Timeout(Duration(minutes: 2)));

    test('Live Audit Log: query with filters (entity_type, action, actor_id)', () async {
      final testUnique = DateTime.now().millisecondsSinceEpoch;
      final created = await auditRepo.createAuditLog(
        projectId: stableProjectId,
        entityType: 'TEST_FILTER_TYPE',
        entityId: 77,
        action: 'FILTER_VERIFIED',
        actorId: 'ACTOR_$testUnique',
        details: 'Testing filter parameters',
      );

      final filteredLogs = await auditRepo.getAuditLogs(
        entityType: 'TEST_FILTER_TYPE',
        action: 'FILTER_VERIFIED',
        actorId: 'ACTOR_$testUnique',
      );

      expect(filteredLogs, isNotEmpty);
      expect(filteredLogs.first.id, created.id);
      expect(filteredLogs.first.entityType, 'TEST_FILTER_TYPE');
      expect(filteredLogs.first.action, 'FILTER_VERIFIED');
    }, timeout: const Timeout(Duration(minutes: 2)));

    test('Live Audit Log: backend inspection generation automatically creates audit log', () async {
      final testUnique = DateTime.now().millisecondsSinceEpoch;
      // Creating an inspection automatically logs an INSPECTION / CREATED audit log in inspections.py:151
      final inspection = await inspectionRepo.createInspection(
        projectId: stableProjectId,
        inspectionType: 'SCHEDULED',
        status: 'PENDING',
        reason: 'Live test audit trigger $testUnique',
      );

      expect(inspection, isNotNull);

      // Verify that the backend recorded an audit log for this inspection
      final matchingLogs = await auditRepo.getAuditLogs(
        projectId: stableProjectId,
        entityType: 'INSPECTION',
        entityId: int.parse(inspection.id),
        action: 'CREATED',
        limit: 5,
      );

      expect(matchingLogs, isNotEmpty);
      expect(matchingLogs.first.entityType, 'INSPECTION');
      expect(matchingLogs.first.action, 'CREATED');
      expect(matchingLogs.first.entityId, int.parse(inspection.id));
    }, timeout: const Timeout(Duration(minutes: 2)));

    test('Live Audit Log: 404 handling for non-existent audit log ID returns null', () async {
      final missing = await auditRepo.getAuditLogById(99999999);
      expect(missing, isNull);
    }, timeout: const Timeout(Duration(minutes: 2)));

    test('Live Audit Log: project audit logs for non-existent project returns empty list', () async {
      final logs = await auditRepo.getProjectAuditLogs(99999999);
      expect(logs, isEmpty);
    }, timeout: const Timeout(Duration(minutes: 2)));

    test('Live Audit Log: validation error on blank entity_type/action throws ValidationException (422)', () async {
      expect(
        () => auditRepo.createAuditLog(
          projectId: stableProjectId,
          entityType: '   ',
          action: 'VALID_ACTION',
        ),
        throwsA(isA<AppException>()),
      );

      expect(
        () => auditRepo.createAuditLog(
          projectId: stableProjectId,
          entityType: 'VALID_TYPE',
          action: '   ',
        ),
        throwsA(isA<AppException>()),
      );
    }, timeout: const Timeout(Duration(minutes: 2)));
  });
}
