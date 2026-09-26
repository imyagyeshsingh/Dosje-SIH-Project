import '../core/error/app_exception.dart';
import '../core/network/api_client.dart';
import '../core/network/api_endpoints.dart';
import '../shared/models/ai_risk_model.dart';
import 'project_repository.dart';

abstract class RiskRepository {
  Future<ProjectRiskModel?> getProjectRisk(dynamic projectId);
}

class MockRiskRepository implements RiskRepository {
  final Map<int, ProjectRiskModel> _riskData = {
    1: const ProjectRiskModel(score: 74, level: 'HIGH'),
    2: const ProjectRiskModel(score: 22, level: 'LOW'),
    3: const ProjectRiskModel(score: 48, level: 'MEDIUM'),
  };

  @override
  Future<ProjectRiskModel?> getProjectRisk(dynamic projectId) async {
    await Future.delayed(const Duration(milliseconds: 150));
    final idInt = int.tryParse(projectId.toString()) ?? 1;
    return _riskData[idInt] ?? const ProjectRiskModel(score: 0, level: 'LOW');
  }
}

class ApiRiskRepository implements RiskRepository {
  final ApiClient apiClient;
  final ProjectRepository? projectRepository;

  ApiRiskRepository({
    required this.apiClient,
    this.projectRepository,
  });

  Future<int> _resolveProjectId(dynamic rawId) async {
    if (rawId is int) return rawId;
    final parsed = int.tryParse(rawId.toString());
    if (parsed != null) return parsed;

    if (projectRepository != null) {
      try {
        final project = await projectRepository!.getProjectById(rawId.toString());
        if (project != null) {
          final idNum = int.tryParse(project.id);
          if (idNum != null) return idNum;
        }
      } catch (_) {}
    }
    return 0;
  }

  @override
  Future<ProjectRiskModel?> getProjectRisk(dynamic projectId) async {
    final numericId = await _resolveProjectId(projectId);
    if (numericId <= 0) return null;

    try {
      final response = await apiClient.get(ApiEndpoints.riskByProject(numericId));
      if (response.data == null) return null;
      return ProjectRiskModel.fromJson(response.data as Map<String, dynamic>);
    } on NotFoundException {
      return null;
    }
  }
}
