@Timeout(Duration(minutes: 5))
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dosje_sentinel/core/error/app_exception.dart';
import 'package:dosje_sentinel/core/network/api_client.dart';
import 'package:dosje_sentinel/core/network/api_endpoints.dart';
import 'package:dosje_sentinel/repositories/alert_repository.dart';
import 'package:dosje_sentinel/repositories/project_repository.dart';
import 'package:dosje_sentinel/shared/models/alert_model.dart';
import 'package:dosje_sentinel/shared/models/project_model.dart';
import 'package:dosje_sentinel/shared/providers/core_providers.dart';

void main() {
  group('Alert Models & Serialization Integration', () {
    test('AlertModel deserializes backend AlertResponse accurately', () {
      final json = {
        'id': 101,
        'project_id': 20,
        'alert_type': 'RISK',
        'severity': 'HIGH',
        'message': 'Risk level elevated to HIGH: score 74',
        'confidence': 0.88,
        'status': 'OPEN',
        'source': 'RiskService',
        'detection_id': null,
        'created_at': '2026-09-24T10:00:00Z',
        'updated_at': '2026-09-24T10:00:00Z',
      };

      final alert = AlertModel.fromJson(json);

      expect(alert.id, 101);
      expect(alert.projectId, 20);
      expect(alert.alertType, 'RISK');
      expect(alert.typeEnum, AlertType.risk);
      expect(alert.severity, 'HIGH');
      expect(alert.severityEnum, AlertSeverity.high);
      expect(alert.message, 'Risk level elevated to HIGH: score 74');
      expect(alert.confidence, 0.88);
      expect(alert.status, 'OPEN');
      expect(alert.statusEnum, AlertStatus.open);
      expect(alert.source, 'RiskService');
      expect(alert.detectionId, isNull);
    });

    test('AlertModel handles nullable fields gracefully', () {
      final jsonWithNulls = {
        'id': 102,
        'project_id': 20,
        'alert_type': 'ATTENDANCE',
        'severity': 'MEDIUM',
        'message': 'Low attendance recorded',
        'confidence': null,
        'status': 'OPEN',
        'source': null,
        'detection_id': null,
        'created_at': null,
        'updated_at': null,
      };

      final alert = AlertModel.fromJson(jsonWithNulls);

      expect(alert.id, 102);
      expect(alert.confidence, isNull);
      expect(alert.source, isNull);
      expect(alert.detectionId, isNull);
      expect(alert.createdAt, isNotNull);
      expect(alert.updatedAt, isNotNull);
    });

    test('AlertType enum converts to and from backend strings', () {
      expect(AlertType.fromString('RISK'), AlertType.risk);
      expect(AlertType.fromString('AI_ACTIVITY'), AlertType.aiActivity);
      expect(AlertType.fromString('ATTENDANCE'), AlertType.attendance);
      expect(AlertType.fromString('CAMERA'), AlertType.camera);
      expect(AlertType.fromString('UNKNOWN'), AlertType.camera);

      expect(AlertType.risk.value, 'RISK');
      expect(AlertType.aiActivity.value, 'AI_ACTIVITY');
      expect(AlertType.attendance.value, 'ATTENDANCE');
      expect(AlertType.camera.value, 'CAMERA');
    });

    test('AlertSeverity enum converts to and from backend strings', () {
      expect(AlertSeverity.fromString('LOW'), AlertSeverity.low);
      expect(AlertSeverity.fromString('MEDIUM'), AlertSeverity.medium);
      expect(AlertSeverity.fromString('HIGH'), AlertSeverity.high);
      expect(AlertSeverity.fromString('CRITICAL'), AlertSeverity.critical);
      expect(AlertSeverity.fromString(null), AlertSeverity.low);

      expect(AlertSeverity.low.value, 'LOW');
      expect(AlertSeverity.medium.value, 'MEDIUM');
      expect(AlertSeverity.high.value, 'HIGH');
      expect(AlertSeverity.critical.value, 'CRITICAL');
    });

    test('AlertStatus enum converts to and from backend strings', () {
      expect(AlertStatus.fromString('OPEN'), AlertStatus.open);
      expect(AlertStatus.fromString('ACKNOWLEDGED'), AlertStatus.acknowledged);
      expect(AlertStatus.fromString('RESOLVED'), AlertStatus.resolved);
      expect(AlertStatus.fromString(null), AlertStatus.open);

      expect(AlertStatus.open.value, 'OPEN');
      expect(AlertStatus.acknowledged.value, 'ACKNOWLEDGED');
      expect(AlertStatus.resolved.value, 'RESOLVED');
    });

    test('ProjectSummaryModel correctly maps backend alerts count', () {
      final summaryJson = {
        'project': {
          'id': 20,
          'project_name': 'District Rehabilitation Centre',
          'project_code': 'DSJ-AG-1042',
          'status': 'ACTIVE',
        },
        'alerts': {
          'total': 5,
          'active': 3,
        },
      };

      final summary = ProjectSummaryModel.fromJson(summaryJson);
      expect(summary.totalAlerts, 5);
      expect(summary.activeAlerts, 3);
    });
  });

  group('MockAlertRepository Unit Tests', () {
    late MockAlertRepository repo;

    setUp(() {
      repo = MockAlertRepository();
    });

    test('getProjectAlerts returns seeded mock alerts', () async {
      final alerts = await repo.getProjectAlerts(1);
      expect(alerts, isNotEmpty);
      expect(alerts.length, 3);
      expect(alerts.first.projectId, 1);
    });

    test('getAlertById returns correct alert or null', () async {
      final alert = await repo.getAlertById(1);
      expect(alert, isNotNull);
      expect(alert!.id, 1);

      final notFound = await repo.getAlertById(999);
      expect(notFound, isNull);
    });

    test('createAlert prepends new alert', () async {
      final created = await repo.createAlert(
        projectId: 1,
        alertType: 'AI_ACTIVITY',
        severity: 'HIGH',
        message: 'Test mock alert',
      );
      expect(created.id, isPositive);
      expect(created.status, 'OPEN');

      final alerts = await repo.getProjectAlerts(1);
      expect(alerts.first.message, 'Test mock alert');
    });

    test('updateAlertStatus mutates status or throws NotFoundException', () async {
      final updated = await repo.updateAlertStatus(
        alertId: 1,
        status: 'ACKNOWLEDGED',
      );
      expect(updated.status, 'ACKNOWLEDGED');

      expect(
        () => repo.updateAlertStatus(alertId: 99999, status: 'RESOLVED'),
        throwsA(isA<NotFoundException>()),
      );
    });
  });

  group('ApiAlertRepository Live Integration against FastAPI', () {
    late ApiClient client;
    late ApiProjectRepository projectRepo;
    late ApiAlertRepository alertRepo;

    setUp(() {
      ApiEndpoints.setBaseUrl('http://127.0.0.1:8000');
      client = ApiClient();
      projectRepo = ApiProjectRepository(apiClient: client);
      alertRepo = ApiAlertRepository(
        apiClient: client,
        projectRepository: projectRepo,
      );
    });

    test(
      'Live Alerts Lifecycle: Fetch alerts -> create alert -> get by ID -> update status -> generate alerts',
      () async {
        final projects = await projectRepo.getProjects(limit: 10);
        expect(projects, isNotEmpty);
        final project = projects.firstWhere(
          (p) => !p.code.startsWith('TEST-'),
          orElse: () => projects.first,
        );
        final numericProjectId = int.parse(project.id);

        // 1. Fetch initial alerts
        final initialAlerts = await alertRepo.getProjectAlerts(numericProjectId);
        expect(initialAlerts, isA<List<AlertModel>>());

        // 2. Create a test alert via POST /alerts
        final created = await alertRepo.createAlert(
          projectId: numericProjectId,
          alertType: 'RISK',
          severity: 'HIGH',
          message: 'Integration test alert at ${DateTime.now().toIso8601String()}',
          confidence: 0.95,
          source: 'AlertIntegrationTest',
        );
        expect(created.id, isPositive);
        expect(created.projectId, numericProjectId);
        expect(created.alertType, 'RISK');
        expect(created.severity, 'HIGH');
        expect(created.status, 'OPEN');

        // 3. Fetch alert by ID via GET /alerts/{alert_id}
        final fetched = await alertRepo.getAlertById(created.id);
        expect(fetched, isNotNull);
        expect(fetched!.id, created.id);
        expect(fetched.message, created.message);

        // 4. Update status to ACKNOWLEDGED via PUT /alerts/{alert_id}/status
        final acknowledged = await alertRepo.updateAlertStatus(
          alertId: created.id,
          status: 'ACKNOWLEDGED',
        );
        expect(acknowledged.status, 'ACKNOWLEDGED');

        // 5. Update status to RESOLVED via PUT /alerts/{alert_id}/status
        final resolved = await alertRepo.updateAlertStatus(
          alertId: created.id,
          status: 'RESOLVED',
        );
        expect(resolved.status, 'RESOLVED');

        // 6. Test project code resolution (project.code -> numeric ID)
        final alertsByCode = await alertRepo.getProjectAlerts(project.code);
        expect(alertsByCode, isA<List<AlertModel>>());
        expect(alertsByCode.any((a) => a.id == created.id), isTrue);

        // 7. Test POST /alerts/generate/{project_id}
        final generated = await alertRepo.generateProjectAlerts(numericProjectId);
        expect(generated, isA<List<AlertModel>>());
      },
      timeout: const Timeout(Duration(minutes: 2)),
    );

    test('getAlertById returns null for non-existent alert (404 handling)', () async {
      final alert = await alertRepo.getAlertById(999999);
      expect(alert, isNull);
    });

    test('getProjectAlerts returns empty list for non-existent project (404 handling)', () async {
      final alerts = await alertRepo.getProjectAlerts(999999);
      expect(alerts, isEmpty);
    });

    test('createAlert throws ValidationException for invalid project ID', () async {
      expect(
        () => alertRepo.createAlert(
          projectId: 0,
          alertType: 'RISK',
          severity: 'HIGH',
          message: 'Invalid project alert',
        ),
        throwsA(isA<ValidationException>()),
      );
    });

    test('updateAlertStatus throws ValidationException for invalid alert ID', () async {
      expect(
        () => alertRepo.updateAlertStatus(
          alertId: 0,
          status: 'ACKNOWLEDGED',
        ),
        throwsA(isA<ValidationException>()),
      );
    });
  });

  group('Alert Riverpod Providers Integration', () {
    setUp(() {
      ApiEndpoints.setBaseUrl('http://127.0.0.1:8000');
    });

    test('projectAlertsProvider fetches alerts via Riverpod container', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final projectRepo = container.read(projectRepositoryProvider);
      final projects = await projectRepo.getProjects(limit: 5);
      final project = projects.firstWhere(
        (p) => !p.code.startsWith('TEST-'),
        orElse: () => projects.first,
      );

      final alerts = await container.read(projectAlertsProvider(project.id).future);
      expect(alerts, isA<List<AlertModel>>());
    });

    test('singleAlertProvider returns null for non-existent alert ID', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final alert = await container.read(singleAlertProvider(999999).future);
      expect(alert, isNull);
    });
  });
}
