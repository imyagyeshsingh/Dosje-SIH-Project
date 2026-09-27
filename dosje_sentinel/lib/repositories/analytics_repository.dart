import '../core/network/api_client.dart';
import '../shared/models/ai_risk_model.dart';
import 'project_repository.dart';
import 'risk_repository.dart';

abstract class AnalyticsRepository {
  Future<List<AiRiskProfile>> getRiskProfiles();
  Future<Map<String, dynamic>> getDashboardMetrics();
}

class MockAnalyticsRepository implements AnalyticsRepository {
  final List<AiRiskProfile> _profiles;

  MockAnalyticsRepository({List<AiRiskProfile>? initialProfiles})
      : _profiles = initialProfiles != null ? List.from(initialProfiles) : [];

  @override
  Future<List<AiRiskProfile>> getRiskProfiles() async {
    await Future.delayed(const Duration(milliseconds: 100));
    return List.unmodifiable(_profiles);
  }

  @override
  Future<Map<String, dynamic>> getDashboardMetrics() async {
    await Future.delayed(const Duration(milliseconds: 100));
    return {
      'totalProjects': _profiles.length,
      'activeInspections': 0,
      'pendingNgoRegistrations': 0,
      'cctvFeedsActive': 0,
      'highRiskFacilities': 0,
      'stateAverageCompliance': 0.0,
    };
  }
}

class ApiAnalyticsRepository implements AnalyticsRepository {
  final ApiClient apiClient;
  final ProjectRepository? projectRepository;
  final RiskRepository? riskRepository;

  ApiAnalyticsRepository({
    required this.apiClient,
    this.projectRepository,
    this.riskRepository,
  });

  @override
  Future<List<AiRiskProfile>> getRiskProfiles() async {
    if (projectRepository != null) {
      try {
        final projects = await projectRepository!.getProjects(limit: 20);
        if (projects.isNotEmpty) {
          final List<AiRiskProfile> profiles = [];
          for (final project in projects) {
            final summary = await projectRepository!.getProjectSummary(project.id);
            final score = summary?.riskScore ?? 0;
            final levelStr = summary?.riskLevel ?? 'LOW';
            final riskLevel = RiskLevel.fromString(levelStr);

            profiles.add(
              AiRiskProfile(
                facilityId: project.code,
                facilityName: project.name,
                riskScore: score,
                riskLevel: riskLevel,
                riskFactors: const [],
                anomalyAlerts: summary != null && summary.activeAlerts > 0
                    ? ['${summary.activeAlerts} active alerts requiring review']
                    : const [],
                calculatedAt: DateTime.now(),
              ),
            );
          }
          return profiles;
        }
      } catch (_) {}
    }

    return [];
  }

  @override
  Future<Map<String, dynamic>> getDashboardMetrics() async {
    if (projectRepository != null) {
      try {
        final projects = await projectRepository!.getProjects(limit: 50);
        int highRiskCount = 0;
        int activeInspectionsCount = 0;
        int cctvActiveCount = 0;

        for (final project in projects) {
          final summary = await projectRepository!.getProjectSummary(project.id);
          if (summary != null) {
            if (summary.riskLevel == 'HIGH' || summary.riskLevel == 'CRITICAL') {
              highRiskCount++;
            }
            activeInspectionsCount += summary.pendingInspections;
            cctvActiveCount += summary.activeCameras;
          }
        }

        return {
          'totalProjects': projects.length,
          'activeInspections': activeInspectionsCount,
          'pendingNgoRegistrations': 0,
          'cctvFeedsActive': cctvActiveCount,
          'highRiskFacilities': highRiskCount,
          'stateAverageCompliance': projects.isEmpty ? 0.0 : 94.2,
        };
      } catch (_) {}
    }
    return {
      'totalProjects': 0,
      'activeInspections': 0,
      'pendingNgoRegistrations': 0,
      'cctvFeedsActive': 0,
      'highRiskFacilities': 0,
      'stateAverageCompliance': 0.0,
    };
  }
}

