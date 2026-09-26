import '../core/error/app_exception.dart';
import '../core/network/api_client.dart';
import '../core/network/api_endpoints.dart';
import '../shared/models/attendance_model.dart';
import 'project_repository.dart';

abstract class AttendanceRepository {
  Future<AttendanceConfigModel?> getAttendanceConfig(dynamic projectId);

  Future<AttendanceConfigModel> createAttendanceConfig({
    required dynamic projectId,
    required int expectedWorkers,
  });

  Future<AttendanceConfigModel> updateAttendanceConfig({
    required dynamic projectId,
    required int expectedWorkers,
  });

  Future<AttendanceSummaryModel?> getAttendanceSummary(dynamic projectId);
}

class MockAttendanceRepository implements AttendanceRepository {
  final Map<int, AttendanceConfigModel> _configs = {};

  @override
  Future<AttendanceConfigModel?> getAttendanceConfig(dynamic projectId) async {
    await Future.delayed(const Duration(milliseconds: 150));
    final idInt = int.tryParse(projectId.toString()) ?? 1;
    return _configs[idInt];
  }

  @override
  Future<AttendanceConfigModel> createAttendanceConfig({
    required dynamic projectId,
    required int expectedWorkers,
  }) async {
    await Future.delayed(const Duration(milliseconds: 150));
    final idInt = int.tryParse(projectId.toString()) ?? 1;
    if (_configs.containsKey(idInt)) {
      throw ConflictException(
        'Attendance configuration already exists for this project',
      );
    }
    final config = AttendanceConfigModel(
      id: _configs.length + 1,
      projectId: idInt,
      expectedWorkers: expectedWorkers,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );
    _configs[idInt] = config;
    return config;
  }

  @override
  Future<AttendanceConfigModel> updateAttendanceConfig({
    required dynamic projectId,
    required int expectedWorkers,
  }) async {
    await Future.delayed(const Duration(milliseconds: 150));
    final idInt = int.tryParse(projectId.toString()) ?? 1;
    final existing = _configs[idInt];
    if (existing == null) {
      throw NotFoundException(
        'Attendance configuration not found for this project',
      );
    }
    final updated = existing.copyWith(
      expectedWorkers: expectedWorkers,
      updatedAt: DateTime.now(),
    );
    _configs[idInt] = updated;
    return updated;
  }

  @override
  Future<AttendanceSummaryModel?> getAttendanceSummary(dynamic projectId) async {
    await Future.delayed(const Duration(milliseconds: 150));
    final idInt = int.tryParse(projectId.toString()) ?? 1;
    final config = _configs[idInt];
    return AttendanceSummaryModel(
      projectId: idInt,
      expectedWorkers: config?.expectedWorkers,
      detectedWorkers: null,
      attendancePercentage: null,
      detectionTimestamp: null,
    );
  }
}

class ApiAttendanceRepository implements AttendanceRepository {
  final ApiClient apiClient;
  final ProjectRepository? projectRepository;

  ApiAttendanceRepository({
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
  Future<AttendanceConfigModel?> getAttendanceConfig(dynamic projectId) async {
    final numericId = await _resolveProjectId(projectId);
    if (numericId <= 0) return null;

    try {
      final response = await apiClient.get(
        ApiEndpoints.attendanceByProject(numericId),
      );
      if (response.data == null) return null;
      return AttendanceConfigModel.fromJson(
        response.data as Map<String, dynamic>,
      );
    } on NotFoundException {
      return null;
    }
  }

  @override
  Future<AttendanceConfigModel> createAttendanceConfig({
    required dynamic projectId,
    required int expectedWorkers,
  }) async {
    final numericId = await _resolveProjectId(projectId);
    final response = await apiClient.post(
      ApiEndpoints.attendance,
      data: {
        'project_id': numericId,
        'expected_workers': expectedWorkers,
      },
    );
    return AttendanceConfigModel.fromJson(
      response.data as Map<String, dynamic>,
    );
  }

  @override
  Future<AttendanceConfigModel> updateAttendanceConfig({
    required dynamic projectId,
    required int expectedWorkers,
  }) async {
    final numericId = await _resolveProjectId(projectId);
    final response = await apiClient.put(
      ApiEndpoints.attendanceByProject(numericId),
      data: {
        'expected_workers': expectedWorkers,
      },
    );
    return AttendanceConfigModel.fromJson(
      response.data as Map<String, dynamic>,
    );
  }

  @override
  Future<AttendanceSummaryModel?> getAttendanceSummary(dynamic projectId) async {
    final numericId = await _resolveProjectId(projectId);
    if (numericId <= 0) return null;

    try {
      final response = await apiClient.get(
        ApiEndpoints.attendanceSummary(numericId),
      );
      if (response.data == null) return null;
      return AttendanceSummaryModel.fromJson(
        response.data as Map<String, dynamic>,
      );
    } on NotFoundException {
      return null;
    }
  }
}
