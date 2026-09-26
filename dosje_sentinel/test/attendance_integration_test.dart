@Timeout(Duration(minutes: 5))
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dosje_sentinel/core/network/api_client.dart';
import 'package:dosje_sentinel/core/network/api_endpoints.dart';
import 'package:dosje_sentinel/core/error/app_exception.dart';
import 'package:dosje_sentinel/repositories/project_repository.dart';
import 'package:dosje_sentinel/repositories/attendance_repository.dart';
import 'package:dosje_sentinel/shared/models/attendance_model.dart';
import 'package:dosje_sentinel/shared/providers/core_providers.dart';

void main() {
  group('Attendance Models & Serialization Integration', () {
    test('AttendanceConfigModel deserializes AttendanceResponse accurately', () {
      final json = {
        'id': 12,
        'project_id': 34,
        'expected_workers': 50,
        'created_at': '2026-09-24T10:00:00Z',
        'updated_at': '2026-09-24T11:00:00Z',
      };

      final config = AttendanceConfigModel.fromJson(json);

      expect(config.id, 12);
      expect(config.projectId, 34);
      expect(config.expectedWorkers, 50);
      expect(config.createdAt, DateTime.parse('2026-09-24T10:00:00Z'));
      expect(config.updatedAt, DateTime.parse('2026-09-24T11:00:00Z'));

      final outJson = config.toJson();
      expect(outJson['id'], 12);
      expect(outJson['project_id'], 34);
      expect(outJson['expected_workers'], 50);
    });

    test('AttendanceSummaryModel handles nullable fields gracefully', () {
      final jsonWithNulls = {
        'project_id': 34,
        'expected_workers': null,
        'detected_workers': null,
        'attendance_percentage': null,
        'detection_timestamp': null,
      };

      final summary = AttendanceSummaryModel.fromJson(jsonWithNulls);

      expect(summary.projectId, 34);
      expect(summary.expectedWorkers, isNull);
      expect(summary.detectedWorkers, isNull);
      expect(summary.attendancePercentage, isNull);
      expect(summary.detectionTimestamp, isNull);

      final jsonWithData = {
        'project_id': 34,
        'expected_workers': 40,
        'detected_workers': 36,
        'attendance_percentage': 90.0,
        'detection_timestamp': '2026-09-24T12:00:00Z',
      };

      final summaryWithData = AttendanceSummaryModel.fromJson(jsonWithData);

      expect(summaryWithData.projectId, 34);
      expect(summaryWithData.expectedWorkers, 40);
      expect(summaryWithData.detectedWorkers, 36);
      expect(summaryWithData.attendancePercentage, 90.0);
      expect(summaryWithData.detectionTimestamp, isNotNull);
    });
  });

  group('MockAttendanceRepository Unit Tests', () {
    late MockAttendanceRepository repo;

    setUp(() {
      repo = MockAttendanceRepository();
    });

    test('Create, retrieve, and update attendance configuration in mock', () async {
      final config = await repo.createAttendanceConfig(
        projectId: 1,
        expectedWorkers: 25,
      );
      expect(config.expectedWorkers, 25);
      expect(config.projectId, 1);

      final retrieved = await repo.getAttendanceConfig(1);
      expect(retrieved, isNotNull);
      expect(retrieved!.expectedWorkers, 25);

      final updated = await repo.updateAttendanceConfig(
        projectId: 1,
        expectedWorkers: 35,
      );
      expect(updated.expectedWorkers, 35);

      final summary = await repo.getAttendanceSummary(1);
      expect(summary, isNotNull);
      expect(summary!.expectedWorkers, 35);
    });

    test('Duplicate create throws ConflictException in mock', () async {
      await repo.createAttendanceConfig(projectId: 2, expectedWorkers: 10);
      expect(
        () async => await repo.createAttendanceConfig(projectId: 2, expectedWorkers: 15),
        throwsA(isA<ConflictException>()),
      );
    });

    test('Updating non-existent config throws NotFoundException in mock', () async {
      expect(
        () async => await repo.updateAttendanceConfig(projectId: 999, expectedWorkers: 15),
        throwsA(isA<NotFoundException>()),
      );
    });
  });

  group('ApiAttendanceRepository Live Integration against FastAPI', () {
    late ApiClient client;
    late ApiProjectRepository projectRepo;
    late ApiAttendanceRepository attendanceRepo;

    setUp(() {
      ApiEndpoints.setBaseUrl('http://127.0.0.1:8000');
      client = ApiClient();
      projectRepo = ApiProjectRepository(apiClient: client);
      attendanceRepo = ApiAttendanceRepository(
        apiClient: client,
        projectRepository: projectRepo,
      );
    });

    test(
      'Full Attendance Config & Summary Lifecycle against live backend',
      () async {
        // 1. Fetch an existing permanent project from backend
        final projects = await projectRepo.getProjects(limit: 10);
        expect(projects, isNotEmpty);
        final project = projects.firstWhere(
          (p) => !p.code.startsWith('TEST-'),
          orElse: () => projects.first,
        );
        final numericProjectId = int.parse(project.id);

        // 2. Check if attendance config already exists or create one
        AttendanceConfigModel? config =
            await attendanceRepo.getAttendanceConfig(numericProjectId);

        if (config == null) {
          config = await attendanceRepo.createAttendanceConfig(
            projectId: numericProjectId,
            expectedWorkers: 40,
          );
          expect(config.id, greaterThan(0));
          expect(config.projectId, numericProjectId);
          expect(config.expectedWorkers, 40);
        } else {
          // If already exists, verify conflict on duplicate creation
          expect(
            () async => await attendanceRepo.createAttendanceConfig(
              projectId: numericProjectId,
              expectedWorkers: 50,
            ),
            throwsA(isA<ConflictException>()),
          );
        }

        // 3. Update attendance configuration
        final updatedConfig = await attendanceRepo.updateAttendanceConfig(
          projectId: numericProjectId,
          expectedWorkers: 45,
        );
        expect(updatedConfig.expectedWorkers, 45);
        expect(updatedConfig.projectId, numericProjectId);

        // Verify update persisted
        final verifiedConfig =
            await attendanceRepo.getAttendanceConfig(numericProjectId);
        expect(verifiedConfig, isNotNull);
        expect(verifiedConfig!.expectedWorkers, 45);

        // 4. Test code resolution (project.code -> numeric ID)
        final configByCode =
            await attendanceRepo.getAttendanceConfig(project.code);
        expect(configByCode, isNotNull);
        expect(configByCode!.expectedWorkers, 45);

        // 5. Query live attendance summary
        final summary =
            await attendanceRepo.getAttendanceSummary(numericProjectId);
        expect(summary, isNotNull);
        expect(summary!.projectId, numericProjectId);
        expect(summary.expectedWorkers, 45);
      },
      timeout: const Timeout(Duration(minutes: 2)),
    );

    test('getAttendanceConfig returns null for non-existent project (404 handling)', () async {
      final config = await attendanceRepo.getAttendanceConfig(999999);
      expect(config, isNull);
    });

    test('getAttendanceSummary returns null for non-existent project (404 handling)', () async {
      final summary = await attendanceRepo.getAttendanceSummary(999999);
      expect(summary, isNull);
    });

    test('Validation Error: negative expected_workers throws ValidationException on create', () async {
      expect(
        () async => await attendanceRepo.createAttendanceConfig(
          projectId: 999999,
          expectedWorkers: -5,
        ),
        throwsA(isA<ValidationException>()),
      );
    });

    test('Validation Error: negative expected_workers throws ValidationException on update', () async {
      final projects = await projectRepo.getProjects(limit: 1);
      final numericProjectId = int.parse(projects.first.id);

      expect(
        () async => await attendanceRepo.updateAttendanceConfig(
          projectId: numericProjectId,
          expectedWorkers: -10,
        ),
        throwsA(isA<ValidationException>()),
      );
    });
  });

  group('Attendance Riverpod Providers Integration', () {
    setUp(() {
      ApiEndpoints.setBaseUrl('http://127.0.0.1:8000');
    });

    test('attendanceConfigProvider fetches config via Riverpod container', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final projectRepo = container.read(projectRepositoryProvider);
      final projects = await projectRepo.getProjects(limit: 1);
      expect(projects, isNotEmpty);

      final config = await container.read(
        attendanceConfigProvider(projects.first.id).future,
      );
      // Either null or AttendanceConfigModel
      if (config != null) {
        expect(config.projectId, int.parse(projects.first.id));
      }
    });

    test('attendanceSummaryProvider fetches summary via Riverpod container', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final projectRepo = container.read(projectRepositoryProvider);
      final projects = await projectRepo.getProjects(limit: 1);
      expect(projects, isNotEmpty);

      final summary = await container.read(
        attendanceSummaryProvider(projects.first.id).future,
      );
      expect(summary, isNotNull);
      expect(summary!.projectId, int.parse(projects.first.id));
    });

    test('attendanceSummaryProvider returns null for non-existent project 999999', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final summary = await container.read(
        attendanceSummaryProvider('999999').future,
      );
      expect(summary, isNull);
    });
  });
}
