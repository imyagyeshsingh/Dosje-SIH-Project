import '../core/error/app_exception.dart';
import '../core/network/api_client.dart';
import '../core/network/api_endpoints.dart';
import '../shared/models/ai_detection_model.dart';
import 'project_repository.dart';

abstract class AiDetectionRepository {
  Future<List<AiDetectionModel>> getProjectDetections(
    dynamic projectId, {
    int limit = 50,
    int offset = 0,
  });

  Future<AiDetectionSummaryModel?> getProjectDetectionSummary(
    dynamic projectId,
  );

  Future<AiDetectionModel> submitDetection(Map<String, dynamic> data);
}

class MockAiDetectionRepository implements AiDetectionRepository {
  final List<AiDetectionModel> _detections = [];

  @override
  Future<List<AiDetectionModel>> getProjectDetections(
    dynamic projectId, {
    int limit = 50,
    int offset = 0,
  }) async {
    await Future.delayed(const Duration(milliseconds: 150));
    final idInt = int.tryParse(projectId.toString()) ?? 1;
    return _detections.where((d) => d.projectId == idInt).toList();
  }

  @override
  Future<AiDetectionSummaryModel?> getProjectDetectionSummary(
    dynamic projectId,
  ) async {
    await Future.delayed(const Duration(milliseconds: 150));
    final idInt = int.tryParse(projectId.toString()) ?? 1;
    final projectDetections =
        _detections.where((d) => d.projectId == idInt).toList();
    if (projectDetections.isEmpty) {
      return AiDetectionSummaryModel(
        projectId: idInt,
        detectionCount: 0,
      );
    }
    final latest = projectDetections.last;
    return AiDetectionSummaryModel(
      projectId: idInt,
      latestPeopleDetected: latest.peopleDetected,
      latestActivity: latest.activity,
      latestConfidence: latest.confidence,
      latestTimestamp: latest.timestamp,
      detectionCount: projectDetections.length,
    );
  }

  @override
  Future<AiDetectionModel> submitDetection(Map<String, dynamic> data) async {
    await Future.delayed(const Duration(milliseconds: 150));
    final detection = AiDetectionModel(
      id: _detections.length + 1,
      projectId: data['project_id'] as int? ?? 1,
      cameraId: data['camera_id'] as int? ?? 1,
      peopleDetected: data['people_detected'] as int? ?? 0,
      activity: data['activity'] as String? ?? 'NORMAL',
      confidence: (data['confidence'] as num?)?.toDouble() ?? 0.9,
      timestamp: DateTime.now(),
      createdAt: DateTime.now(),
    );
    _detections.add(detection);
    return detection;
  }
}

class ApiAiDetectionRepository implements AiDetectionRepository {
  final ApiClient apiClient;
  final ProjectRepository? projectRepository;

  ApiAiDetectionRepository({
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
  Future<List<AiDetectionModel>> getProjectDetections(
    dynamic projectId, {
    int limit = 50,
    int offset = 0,
  }) async {
    final numericId = await _resolveProjectId(projectId);
    if (numericId <= 0) return [];

    try {
      final response = await apiClient.get(
        ApiEndpoints.aiDetectionByProject(numericId),
        queryParameters: {'limit': limit, 'offset': offset},
      );
      final list = response.data as List<dynamic>? ?? [];
      return list
          .map((e) => AiDetectionModel.fromJson(e as Map<String, dynamic>))
          .toList();
    } on NotFoundException {
      return [];
    }
  }

  @override
  Future<AiDetectionSummaryModel?> getProjectDetectionSummary(
    dynamic projectId,
  ) async {
    final numericId = await _resolveProjectId(projectId);
    if (numericId <= 0) return null;

    try {
      final response = await apiClient.get(
        ApiEndpoints.aiDetectionSummaryByProject(numericId),
      );
      if (response.data == null) return null;
      return AiDetectionSummaryModel.fromJson(
        response.data as Map<String, dynamic>,
      );
    } on NotFoundException {
      return null;
    }
  }

  @override
  Future<AiDetectionModel> submitDetection(Map<String, dynamic> data) async {
    final response = await apiClient.post(
      ApiEndpoints.aiDetection,
      data: data,
    );
    return AiDetectionModel.fromJson(response.data as Map<String, dynamic>);
  }
}
