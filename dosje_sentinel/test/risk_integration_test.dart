@Timeout(Duration(minutes: 5))
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dosje_sentinel/core/network/api_client.dart';
import 'package:dosje_sentinel/core/network/api_endpoints.dart';
import 'package:dosje_sentinel/repositories/project_repository.dart';
import 'package:dosje_sentinel/repositories/risk_repository.dart';
import 'package:dosje_sentinel/shared/models/ai_risk_model.dart';
import 'package:dosje_sentinel/shared/models/project_model.dart';
import 'package:dosje_sentinel/shared/providers/core_providers.dart';

void main() {
  group('Risk Models & Serialization Integration', () {
    test('ProjectRiskModel deserializes backend RiskResponse accurately', () {
      final json = {
        'score': 64,
        'level': 'HIGH',
      };

      final risk = ProjectRiskModel.fromJson(json);

      expect(risk.score, 64);
      expect(risk.level, 'HIGH');
      expect(risk.riskLevel, RiskLevel.high);

      final outJson = risk.toJson();
      expect(outJson['score'], 64);
      expect(outJson['level'], 'HIGH');
    });

    test('ProjectRiskModel handles nullable fields gracefully', () {
      final jsonWithNulls = {
        'score': null,
        'level': null,
      };

      final risk = ProjectRiskModel.fromJson(jsonWithNulls);

      expect(risk.score, isNull);
      expect(risk.level, isNull);
      expect(risk.riskLevel, isNull);
    });

    test('RiskLevel enum parses all backend levels correctly', () {
      expect(RiskLevel.fromString('LOW'), RiskLevel.low);
      expect(RiskLevel.fromString('MEDIUM'), RiskLevel.medium);
      expect(RiskLevel.fromString('HIGH'), RiskLevel.high);
      expect(RiskLevel.fromString('CRITICAL'), RiskLevel.critical);
      expect(RiskLevel.fromString(null), RiskLevel.low);

      expect(RiskLevel.critical.label, 'Critical Risk');
      expect(RiskLevel.high.label, 'High Risk');
      expect(RiskLevel.medium.label, 'Medium Risk');
      expect(RiskLevel.low.label, 'Low Risk');
    });

    test('ProjectSummaryModel correctly maps backend risk sub-object', () {
      final summaryJson = {
        'project': {
          'id': 20,
          'project_name': 'District Rehabilitation Centre',
          'project_code': 'DSJ-AG-1042',
          'status': 'ACTIVE',
        },
        'risk': {
          'score': 72,
          'level': 'HIGH',
        },
      };

      final summary = ProjectSummaryModel.fromJson(summaryJson);
      expect(summary.riskScore, 72);
      expect(summary.riskLevel, 'HIGH');
    });
  });

  group('MockRiskRepository Unit Tests', () {
    late MockRiskRepository repo;

    setUp(() {
      repo = MockRiskRepository();
    });

    test('getProjectRisk returns configured mock risk data', () async {
      final risk = await repo.getProjectRisk(1);
      expect(risk, isNotNull);
      expect(risk!.score, 74);
      expect(risk.level, 'HIGH');
    });

    test('getProjectRisk fallback returns low risk for unknown ID', () async {
      final risk = await repo.getProjectRisk(999);
      expect(risk, isNotNull);
      expect(risk!.score, 0);
      expect(risk.level, 'LOW');
    });
  });

  group('ApiRiskRepository Live Integration against FastAPI', () {
    late ApiClient client;
    late ApiProjectRepository projectRepo;
    late ApiRiskRepository riskRepo;

    setUp(() {
      ApiEndpoints.setBaseUrl('http://127.0.0.1:8000');
      client = ApiClient();
      projectRepo = ApiProjectRepository(apiClient: client);
      riskRepo = ApiRiskRepository(
        apiClient: client,
        projectRepository: projectRepo,
      );
    });

    test(
      'Live Risk Query: GET /risk/{project_id} matches Project Summary risk',
      () async {
        final projects = await projectRepo.getProjects(limit: 10);
        expect(projects, isNotEmpty);
        final project = projects.firstWhere(
          (p) => !p.code.startsWith('TEST-'),
          orElse: () => projects.first,
        );
        final numericProjectId = int.parse(project.id);

        // 1. Fetch risk from dedicated /risk/{project_id} endpoint
        final risk = await riskRepo.getProjectRisk(numericProjectId);
        expect(risk, isNotNull);
        expect(risk!.score, isNotNull);
        expect(risk.level, isNotNull);
        expect(risk.score, inInclusiveRange(0, 100));

        // 2. Fetch summary from /projects/{project_id}/summary
        final summary = await projectRepo.getProjectSummary(numericProjectId);
        expect(summary, isNotNull);

        // 3. Verify single source of truth: summary risk matches dedicated risk
        expect(summary!.riskScore, risk.score);
        expect(summary.riskLevel, risk.level);

        // 4. Test code resolution (project.code -> numeric ID)
        final riskByCode = await riskRepo.getProjectRisk(project.code);
        expect(riskByCode, isNotNull);
        expect(riskByCode!.score, risk.score);
        expect(riskByCode.level, risk.level);
      },
      timeout: const Timeout(Duration(minutes: 2)),
    );

    test('getProjectRisk returns null for non-existent project (404 handling)', () async {
      final risk = await riskRepo.getProjectRisk(999999);
      expect(risk, isNull);
    });
  });

  group('Risk Riverpod Providers Integration', () {
    setUp(() {
      ApiEndpoints.setBaseUrl('http://127.0.0.1:8000');
    });

    test('projectRiskProvider fetches risk via Riverpod container', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final projectRepo = container.read(projectRepositoryProvider);
      final projects = await projectRepo.getProjects(limit: 10);
      expect(projects, isNotEmpty);
      final project = projects.firstWhere(
        (p) => !p.code.startsWith('TEST-'),
        orElse: () => projects.first,
      );

      final risk = await container.read(
        projectRiskProvider(project.id).future,
      );
      expect(risk, isNotNull);
      expect(risk!.score, inInclusiveRange(0, 100));
    });

    test('projectRiskProvider returns null for non-existent project 999999', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final risk = await container.read(
        projectRiskProvider('999999').future,
      );
      expect(risk, isNull);
    });

    test('analyticsRepositoryProvider resolves backend risk profiles', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final analyticsRepo = container.read(analyticsRepositoryProvider);
      final profiles = await analyticsRepo.getRiskProfiles();
      expect(profiles, isNotEmpty);

      final first = profiles.first;
      expect(first.facilityId, isNotEmpty);
      expect(first.facilityName, isNotEmpty);
      expect(first.riskScore, inInclusiveRange(0, 100));
      expect(first.riskLevel, isA<RiskLevel>());
    });
  });
}
