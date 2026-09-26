import '../core/error/app_exception.dart';
import '../core/network/api_client.dart';
import '../core/network/api_endpoints.dart';
import '../shared/models/project_model.dart';


abstract class ProjectRepository {
  Future<List<ProjectModel>> getProjects({bool onlyAssigned = true, int limit = 50, int offset = 0});
  Future<ProjectModel?> getProjectById(dynamic id);
  Future<ProjectSummaryModel?> getProjectSummary(dynamic id);
  Future<ProjectModel> createProject(Map<String, dynamic> projectData);
  Future<ProjectModel> updateProject(dynamic id, Map<String, dynamic> projectData);
  Future<void> deleteProject(dynamic id);
}

class MockProjectRepository implements ProjectRepository {
  final List<ProjectModel> _projects = [
    ProjectModel(
      id: '1',
      code: 'DSJ-AG-1042',
      name: 'District Rehabilitation & Support Centre',
      category: 'Disability Welfare & Skill Training',
      organizationId: 'org_8821',
      organizationName: 'Samarpan Welfare Society',
      organizationCode: 'NGO-UP-8821',
      district: 'Agra',
      state: 'Uttar Pradesh',
      address: 'Plot 14, Sanjay Place, Agra, Uttar Pradesh - 282002',
      status: 'ACTIVE',
      hasActiveInspection: true,
      activeInspectionId: 'INS-2026-00482',
      activeInspectionType: 'SURPRISE EVALUATION',
      cctvOnline: true,
      cctvActiveCameras: 4,
      cctvTotalCameras: 4,
      lastInspectionDate: DateTime(2026, 9, 23, 10, 42),
      assignedNodalOfficer: 'Shri V. K. Saxena',
      nodalOfficerDesignation: 'Deputy Director, DoSJE',
      progress: 68.0,
    ),
    ProjectModel(
      id: '2',
      code: 'DSJ-VR-2089',
      name: 'Integrated Child Development & Daycare Centre',
      category: 'Child Nutrition & Social Care',
      organizationId: 'org_8821',
      organizationName: 'Samarpan Welfare Society',
      organizationCode: 'NGO-UP-8821',
      district: 'Varanasi',
      state: 'Uttar Pradesh',
      address: 'Plot 8B, Sigra, Varanasi, Uttar Pradesh - 221002',
      status: 'ACTIVE',
      hasActiveInspection: false,
      cctvOnline: true,
      cctvActiveCameras: 4,
      cctvTotalCameras: 4,
      lastInspectionDate: DateTime(2026, 8, 11),
      assignedNodalOfficer: 'Smt. P. Verma',
      nodalOfficerDesignation: 'Assistant Director',
      progress: 82.5,
    ),
    ProjectModel(
      id: '3',
      code: 'DSJ-LK-3014',
      name: 'Senior Citizens Assisted Living Home',
      category: 'Geriatric Support Services',
      organizationId: 'org_8821',
      organizationName: 'Samarpan Welfare Society',
      organizationCode: 'NGO-UP-8821',
      district: 'Lucknow',
      state: 'Uttar Pradesh',
      address: 'Sector 5, Gomti Nagar, Lucknow, Uttar Pradesh - 226010',
      status: 'UNDER REVIEW',
      hasActiveInspection: false,
      cctvOnline: true,
      cctvActiveCameras: 4,
      cctvTotalCameras: 4,
      lastInspectionDate: DateTime(2026, 7, 28),
      assignedNodalOfficer: 'Shri R. K. Singh',
      nodalOfficerDesignation: 'Nodal Officer',
      progress: 45.0,
    ),
  ];

  @override
  Future<List<ProjectModel>> getProjects({bool onlyAssigned = true, int limit = 50, int offset = 0}) async {
    await Future.delayed(const Duration(milliseconds: 100));
    return List.unmodifiable(_projects);
  }

  @override
  Future<ProjectModel?> getProjectById(dynamic id) async {
    await Future.delayed(const Duration(milliseconds: 50));
    final idStr = id.toString();
    try {
      return _projects.firstWhere((p) => p.id == idStr || p.code == idStr);
    } catch (_) {
      return null;
    }
  }

  @override
  Future<ProjectSummaryModel?> getProjectSummary(dynamic id) async {
    final proj = await getProjectById(id);
    if (proj == null) return null;
    return ProjectSummaryModel(
      project: proj,
      riskScore: 24,
      riskLevel: 'LOW',
      expectedWorkers: 15,
      detectedWorkers: 14,
      attendancePercentage: 93.3,
      totalAlerts: 1,
      activeAlerts: 0,
      totalInspections: 2,
      pendingInspections: 0,
      completedInspections: 2,
      totalCameras: proj.cctvTotalCameras,
      activeCameras: proj.cctvActiveCameras,
    );
  }

  @override
  Future<ProjectModel> createProject(Map<String, dynamic> projectData) async {
    final newId = (_projects.length + 1).toString();
    final newProj = ProjectModel(
      id: newId,
      code: projectData['project_code'] ?? 'DSJ-PRJ-$newId',
      name: projectData['project_name'] ?? 'New Project',
      category: projectData['department'] ?? 'Welfare',
      address: projectData['location'] ?? '',
      status: projectData['status'] ?? 'PLANNED',
      progress: (projectData['progress'] as num?)?.toDouble() ?? 0.0,
    );
    _projects.add(newProj);
    return newProj;
  }

  @override
  Future<ProjectModel> updateProject(dynamic id, Map<String, dynamic> projectData) async {
    final idStr = id.toString();
    final index = _projects.indexWhere((p) => p.id == idStr || p.code == idStr);
    if (index == -1) throw Exception('Project not found');
    final existing = _projects[index];
    final updated = ProjectModel(
      id: existing.id,
      code: projectData['project_code'] ?? existing.code,
      name: projectData['project_name'] ?? existing.name,
      category: projectData['department'] ?? existing.category,
      address: projectData['location'] ?? existing.address,
      status: projectData['status'] ?? existing.status,
      progress: (projectData['progress'] as num?)?.toDouble() ?? existing.progress,
      cctvOnline: existing.cctvOnline,
      cctvActiveCameras: existing.cctvActiveCameras,
      cctvTotalCameras: existing.cctvTotalCameras,
    );
    _projects[index] = updated;
    return updated;
  }

  @override
  Future<void> deleteProject(dynamic id) async {
    final idStr = id.toString();
    _projects.removeWhere((p) => p.id == idStr || p.code == idStr);
  }
}

class ApiProjectRepository implements ProjectRepository {
  final ApiClient apiClient;

  ApiProjectRepository({required this.apiClient});

  @override
  Future<List<ProjectModel>> getProjects({
    bool onlyAssigned = true,
    int limit = 50,
    int offset = 0,
  }) async {
    final response = await apiClient.get(
      ApiEndpoints.projects,
      queryParameters: {'limit': limit, 'offset': offset},
    );
    final list = response.data as List<dynamic>? ?? [];
    return list
        .map((e) => ProjectModel.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  @override
  Future<ProjectModel?> getProjectById(dynamic id) async {
    if (int.tryParse(id.toString()) == null) {
      // Non-numeric ID indicates a project code: lookup via list
      final list = await getProjects(limit: 500);
      try {
        return list.firstWhere(
          (p) => p.id == id.toString() || p.code == id.toString(),
        );
      } catch (_) {
        return null;
      }
    }
    try {
      final response = await apiClient.get(ApiEndpoints.projectById(id));
      if (response.data == null) return null;
      return ProjectModel.fromJson(response.data as Map<String, dynamic>);
    } on NotFoundException {
      return null;
    }
  }

  @override
  Future<ProjectSummaryModel?> getProjectSummary(dynamic id) async {
    dynamic targetId = id;
    if (int.tryParse(id.toString()) == null) {
      final project = await getProjectById(id);
      if (project == null || int.tryParse(project.id) == null) {
        return null;
      }
      targetId = project.id;
    }
    try {
      final response = await apiClient.get(ApiEndpoints.projectSummary(targetId));
      if (response.data == null) return null;
      return ProjectSummaryModel.fromJson(response.data as Map<String, dynamic>);
    } on NotFoundException {
      return null;
    }
  }

  @override
  Future<ProjectModel> createProject(Map<String, dynamic> projectData) async {
    final response = await apiClient.post(
      ApiEndpoints.projects,
      data: projectData,
    );
    return ProjectModel.fromJson(response.data as Map<String, dynamic>);
  }

  @override
  Future<ProjectModel> updateProject(dynamic id, Map<String, dynamic> projectData) async {
    final response = await apiClient.put(
      ApiEndpoints.projectById(id),
      data: projectData,
    );
    return ProjectModel.fromJson(response.data as Map<String, dynamic>);
  }

  @override
  Future<void> deleteProject(dynamic id) async {
    await apiClient.delete(ApiEndpoints.projectById(id));
  }
}

