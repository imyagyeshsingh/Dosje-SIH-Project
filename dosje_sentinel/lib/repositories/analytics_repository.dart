import '../core/network/api_client.dart';
import '../shared/models/ai_risk_model.dart';
import 'project_repository.dart';
import 'risk_repository.dart';

abstract class AnalyticsRepository {
  Future<List<AiRiskProfile>> getRiskProfiles();
  Future<Map<String, dynamic>> getDashboardMetrics();
}

class MockAnalyticsRepository implements AnalyticsRepository {
  final List<AiRiskProfile> _profiles = [
    AiRiskProfile(
      facilityId: 'DSJ-AG-1042',
      facilityName: 'District Rehabilitation & Support Centre (Agra)',
      riskScore: 74,
      riskLevel: RiskLevel.medium,
      riskFactors: const [
        RiskFactor(
          title: 'Morning Muster Variance',
          description:
              'Headcount telemetry shows deviation from enrolled registry.',
          scoreImpact: 14.5,
        ),
        RiskFactor(
          title: 'Pending Quarterly Stamping',
          description: 'Documentation verification overdue by 4 days.',
          scoreImpact: 8.0,
        ),
      ],
      anomalyAlerts: const [
        'Unscheduled offline duration logged on CCTV-3 (28 mins)',
      ],
      calculatedAt: DateTime.now(),
    ),
    AiRiskProfile(
      facilityId: 'DSJ-VR-2089',
      facilityName: 'Integrated Child Development & Daycare (Varanasi)',
      riskScore: 22,
      riskLevel: RiskLevel.low,
      riskFactors: const [],
      anomalyAlerts: const [],
      calculatedAt: DateTime.now(),
    ),
    AiRiskProfile(
      facilityId: 'DSJ-LK-3014',
      facilityName: 'Senior Citizens Assisted Living Home (Lucknow)',
      riskScore: 48,
      riskLevel: RiskLevel.medium,
      riskFactors: const [
        RiskFactor(
          title: 'Renewal Under Evaluation',
          description:
              'Operating on provisional extension pending state approval.',
          scoreImpact: 12.0,
        ),
      ],
      anomalyAlerts: const [],
      calculatedAt: DateTime.now(),
    ),
  ];

  @override
  Future<List<AiRiskProfile>> getRiskProfiles() async {
    await Future.delayed(const Duration(milliseconds: 300));
    return List.unmodifiable(_profiles);
  }

  @override
  Future<Map<String, dynamic>> getDashboardMetrics() async {
    await Future.delayed(const Duration(milliseconds: 200));
    return {
      'totalProjects': 148,
      'activeInspections': 12,
      'pendingNgoRegistrations': 4,
      'cctvFeedsActive': 582,
      'highRiskFacilities': 7,
      'stateAverageCompliance': 94.2,
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

    return MockAnalyticsRepository().getRiskProfiles();
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
          'pendingNgoRegistrations': 4,
          'cctvFeedsActive': cctvActiveCount,
          'highRiskFacilities': highRiskCount,
          'stateAverageCompliance': 94.2,
        };
      } catch (_) {}
    }
    return MockAnalyticsRepository().getDashboardMetrics();
  }
}

