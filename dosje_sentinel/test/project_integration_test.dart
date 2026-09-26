@Timeout(Duration(minutes: 5))
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dosje_sentinel/core/network/api_client.dart';
import 'package:dosje_sentinel/core/network/api_endpoints.dart';
import 'package:dosje_sentinel/core/error/app_exception.dart';
import 'package:dosje_sentinel/repositories/project_repository.dart';
import 'package:dosje_sentinel/shared/models/project_model.dart';
import 'package:dosje_sentinel/shared/providers/core_providers.dart';

void main() {
  group('Project Model & Serialization Integration', () {
    test('ProjectModel parses backend ProjectResponse correctly', () {
      final backendJson = {
        'id': 20,
        'project_name': 'District Rehabilitation Centre',
        'project_code': 'DSJ-AG-1042',
        'description': 'Main facility description',
        'location': 'Plot 14, Sanjay Place, Agra, Uttar Pradesh - 282002',
        'latitude': 27.1767,
        'longitude': 78.0081,
        'department': 'Disability Welfare',
        'status': 'ACTIVE',
        'start_date': '2026-01-01',
        'expected_end_date': '2026-12-31',
        'progress': '68.50',
        'created_at': '2026-09-21T07:36:53.665147Z',
        'updated_at': '2026-09-21T07:36:53.665147Z',
      };

      final project = ProjectModel.fromJson(backendJson);
      expect(project.id, '20');
      expect(project.name, 'District Rehabilitation Centre');
      expect(project.code, 'DSJ-AG-1042');
      expect(project.category, 'Disability Welfare');
      expect(project.status, 'ACTIVE');
      expect(project.progress, 68.5);
      expect(project.latitude, 27.1767);
      expect(project.longitude, 78.0081);
      expect(project.district, 'Agra');
      expect(project.state, 'Uttar Pradesh');
    });

    test('ProjectSummaryModel parses backend ProjectSummaryResponse correctly', () {
      final summaryJson = {
        'project': {
          'id': 20,
          'project_name': 'District Rehabilitation Centre',
          'project_code': 'DSJ-AG-1042',
          'description': 'Main facility',
          'location': 'Agra, Uttar Pradesh',
          'latitude': null,
          'longitude': null,
          'department': 'Disability Welfare',
          'status': 'ACTIVE',
          'start_date': null,
          'expected_end_date': null,
          'progress': '10.00',
        },
        'risk': {'score': 35, 'level': 'LOW'},
        'attendance': {'expected_workers': 20, 'detected_workers': 18, 'percentage': '90.00'},
        'alerts': {'total': 2, 'active': 1},
        'inspections': {'total': 3, 'pending': 1, 'completed': 2},
        'cctv': {'total_cameras': 4, 'active_cameras': 4},
      };

      final summary = ProjectSummaryModel.fromJson(summaryJson);
      expect(summary.project.id, '20');
      expect(summary.riskScore, 35);
      expect(summary.riskLevel, 'LOW');
      expect(summary.expectedWorkers, 20);
      expect(summary.detectedWorkers, 18);
      expect(summary.attendancePercentage, 90.0);
      expect(summary.totalAlerts, 2);
      expect(summary.activeAlerts, 1);
      expect(summary.totalInspections, 3);
      expect(summary.pendingInspections, 1);
      expect(summary.completedInspections, 2);
      expect(summary.totalCameras, 4);
      expect(summary.activeCameras, 4);
    });

    test('ProjectSummaryModel handles nullable and missing sub-structures gracefully', () {
      final minimalJson = {
        'project': {
          'id': 20,
          'project_name': 'Minimal Project',
          'project_code': 'MIN-001',
          'department': null,
          'location': null,
          'latitude': null,
          'longitude': null,
          'status': 'PLANNED',
          'start_date': null,
          'expected_end_date': null,
          'progress': '0.00',
        },
      };

      final summary = ProjectSummaryModel.fromJson(minimalJson);
      expect(summary.project.id, '20');
      expect(summary.project.name, 'Minimal Project');
      expect(summary.riskScore, isNull);
      expect(summary.riskLevel, isNull);
      expect(summary.expectedWorkers, isNull);
      expect(summary.detectedWorkers, isNull);
      expect(summary.attendancePercentage, isNull);
      expect(summary.totalAlerts, 0);
      expect(summary.activeAlerts, 0);
      expect(summary.totalInspections, 0);
      expect(summary.pendingInspections, 0);
      expect(summary.completedInspections, 0);
      expect(summary.totalCameras, 0);
      expect(summary.activeCameras, 0);
    });
  });

  group('ApiProjectRepository Live Integration against FastAPI', () {
    late ApiClient apiClient;
    late ApiProjectRepository repo;

    setUp(() {
      ApiEndpoints.setBaseUrl('http://127.0.0.1:8000');
      apiClient = ApiClient();
      repo = ApiProjectRepository(apiClient: apiClient);
    });

    test('getProjects() fetches projects list from backend', () async {
      final projects = await repo.getProjects(limit: 10);
      expect(projects, isA<List<ProjectModel>>());
      expect(projects.isNotEmpty, isTrue);
      final first = projects.first;
      expect(first.id.isNotEmpty, isTrue);
      expect(first.name.isNotEmpty, isTrue);
      expect(first.code.isNotEmpty, isTrue);
    });

    test('Full CRUD Flow: Create -> Get -> Summary -> Update -> Delete', () async {
      final uniqueCode = 'TEST-PRJ-${DateTime.now().millisecondsSinceEpoch}';

      // 1. Create
      final created = await repo.createProject({
        'project_name': 'Test Integration Project',
        'project_code': uniqueCode,
        'department': 'Skill Development',
        'location': 'Sector 62, Noida, Uttar Pradesh - 201301',
        'status': 'PLANNED',
        'progress': 0.0,
      });

      expect(created.id.isNotEmpty, isTrue);
      expect(created.code, uniqueCode);
      expect(created.name, 'Test Integration Project');

      final projectId = created.id;

      // 2. Get By ID
      final fetched = await repo.getProjectById(projectId);
      expect(fetched, isNotNull);
      expect(fetched!.id, projectId);
      expect(fetched.code, uniqueCode);

      // 3. Get Summary
      final summary = await repo.getProjectSummary(projectId);
      expect(summary, isNotNull);
      expect(summary!.project.id, projectId);
      expect(summary.totalCameras, 0);

      // 4. Update
      final updated = await repo.updateProject(projectId, {
        'status': 'ACTIVE',
        'progress': 25.0,
      });
      expect(updated.status, 'ACTIVE');
      expect(updated.progress, 25.0);

      // 5. Delete
      await repo.deleteProject(projectId);

      // Verify Deleted
      final afterDelete = await repo.getProjectById(projectId);
      expect(afterDelete, isNull);
    }, timeout: const Timeout(Duration(minutes: 2)));

    test('Validation Error: empty project_name throws ValidationException', () async {
      expect(
        () async => await repo.createProject({
          'project_name': '   ',
          'project_code': 'INVALID-CODE',
        }),
        throwsA(isA<ValidationException>()),
      );
    });

    test('Conflict Error: duplicate project_code throws ConflictException', () async {
      final uniqueCode = 'DUPL-${DateTime.now().millisecondsSinceEpoch}';
      await repo.createProject({
        'project_name': 'First Duplicate Entry',
        'project_code': uniqueCode,
      });

      expect(
        () async => await repo.createProject({
          'project_name': 'Second Duplicate Entry',
          'project_code': uniqueCode,
        }),
        throwsA(isA<ConflictException>()),
      );

      // Cleanup
      final list = await repo.getProjects();
      final item = list.firstWhere((p) => p.code == uniqueCode);
      await repo.deleteProject(item.id);
    });

    test('Not Found Error: non-existent project delete throws NotFoundException', () async {
      expect(
        () async => await repo.deleteProject(999999),
        throwsA(isA<NotFoundException>()),
      );
    });

    test('getProjectSummary returns null for non-existent project (404 handling)', () async {
      final summary = await repo.getProjectSummary(999999);
      expect(summary, isNull);
    });

    test('getProjectSummary resolves project code to ID and fetches summary', () async {
      final projects = await repo.getProjects(limit: 1);
      if (projects.isNotEmpty) {
        final existing = projects.first;
        final summary = await repo.getProjectSummary(existing.code);
        expect(summary, isNotNull);
        expect(summary!.project.code, existing.code);
      }
    }, timeout: const Timeout(Duration(minutes: 2)));
  });

  group('Project Summary Riverpod Providers Integration', () {
    test('projectSummaryProvider returns summary for existing project', () async {
      final container = ProviderContainer(
        overrides: [
          apiClientProvider.overrideWithValue(ApiClient()),
        ],
      );
      addTearDown(container.dispose);

      final primarySummary = await container.read(primaryProjectSummaryProvider.future);
      if (primarySummary != null) {
        expect(primarySummary.project.id.isNotEmpty, isTrue);

        final specificSummary = await container.read(
          projectSummaryProvider(primarySummary.project.id).future,
        );
        expect(specificSummary, isNotNull);
        expect(specificSummary!.project.id, primarySummary.project.id);
      }
    }, timeout: const Timeout(Duration(minutes: 2)));

    test('projectSummaryProvider returns null for non-existent project 999999', () async {
      final container = ProviderContainer(
        overrides: [
          apiClientProvider.overrideWithValue(ApiClient()),
        ],
      );
      addTearDown(container.dispose);

      final summary = await container.read(projectSummaryProvider('999999').future);
      expect(summary, isNull);
    });
  });
}
