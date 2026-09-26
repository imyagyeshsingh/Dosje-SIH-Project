import '../core/error/app_exception.dart';
import '../core/network/api_client.dart';
import '../core/network/api_endpoints.dart';
import '../shared/models/alert_model.dart';
import 'project_repository.dart';

abstract class AlertRepository {
  Future<List<AlertModel>> getProjectAlerts(dynamic projectId, {int limit = 50, int offset = 0});
  Future<AlertModel?> getAlertById(dynamic alertId);
  Future<AlertModel> createAlert({
    required dynamic projectId,
    required String alertType,
    required String severity,
    required String message,
    double? confidence,
    String? source,
    int? detectionId,
  });
  Future<AlertModel> updateAlertStatus({
    required dynamic alertId,
    required String status,
  });
  Future<List<AlertModel>> generateProjectAlerts(dynamic projectId);
}

class MockAlertRepository implements AlertRepository {
  final List<AlertModel> _alerts = [
    AlertModel(
      id: 1,
      projectId: 1,
      alertType: 'RISK',
      severity: 'HIGH',
      message: 'High composite risk score detected: 74',
      confidence: 0.85,
      status: 'OPEN',
      source: 'RiskEngine',
      createdAt: DateTime.now().subtract(const Duration(hours: 2)),
      updatedAt: DateTime.now().subtract(const Duration(hours: 2)),
    ),
    AlertModel(
      id: 2,
      projectId: 1,
      alertType: 'AI_ACTIVITY',
      severity: 'HIGH',
      message: 'Suspicious activity detected in perimeter zone',
      confidence: 0.92,
      status: 'OPEN',
      source: 'AIDetection',
      createdAt: DateTime.now().subtract(const Duration(hours: 1)),
      updatedAt: DateTime.now().subtract(const Duration(hours: 1)),
    ),
    AlertModel(
      id: 3,
      projectId: 1,
      alertType: 'ATTENDANCE',
      severity: 'MEDIUM',
      message: 'Critical attendance shortfall: below 50%',
      confidence: 0.78,
      status: 'RESOLVED',
      source: 'AttendanceService',
      createdAt: DateTime.now().subtract(const Duration(days: 1)),
      updatedAt: DateTime.now().subtract(const Duration(hours: 12)),
    ),
  ];

  @override
  Future<List<AlertModel>> getProjectAlerts(dynamic projectId, {int limit = 50, int offset = 0}) async {
    await Future.delayed(const Duration(milliseconds: 150));
    final idInt = int.tryParse(projectId.toString()) ?? 1;
    return _alerts.where((a) => a.projectId == idInt).skip(offset).take(limit).toList();
  }

  @override
  Future<AlertModel?> getAlertById(dynamic alertId) async {
    await Future.delayed(const Duration(milliseconds: 100));
    final idInt = int.tryParse(alertId.toString());
    try {
      return _alerts.firstWhere((a) => a.id == idInt);
    } catch (_) {
      return null;
    }
  }

  @override
  Future<AlertModel> createAlert({
    required dynamic projectId,
    required String alertType,
    required String severity,
    required String message,
    double? confidence,
    String? source,
    int? detectionId,
  }) async {
    await Future.delayed(const Duration(milliseconds: 150));
    final idInt = int.tryParse(projectId.toString()) ?? 1;
    final alert = AlertModel(
      id: _alerts.length + 1,
      projectId: idInt,
      alertType: alertType,
      severity: severity,
      message: message,
      confidence: confidence,
      status: 'OPEN',
      source: source,
      detectionId: detectionId,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );
    _alerts.insert(0, alert);
    return alert;
  }

  @override
  Future<AlertModel> updateAlertStatus({
    required dynamic alertId,
    required String status,
  }) async {
    await Future.delayed(const Duration(milliseconds: 150));
    final idInt = int.tryParse(alertId.toString());
    final index = _alerts.indexWhere((a) => a.id == idInt);
    if (index == -1) {
      throw NotFoundException('Alert not found');
    }
    final updated = _alerts[index].copyWith(
      status: status,
      updatedAt: DateTime.now(),
    );
    _alerts[index] = updated;
    return updated;
  }

  @override
  Future<List<AlertModel>> generateProjectAlerts(dynamic projectId) async {
    await Future.delayed(const Duration(milliseconds: 200));
    final idInt = int.tryParse(projectId.toString()) ?? 1;
    return _alerts.where((a) => a.projectId == idInt).toList();
  }
}

class ApiAlertRepository implements AlertRepository {
  final ApiClient apiClient;
  final ProjectRepository? projectRepository;

  ApiAlertRepository({
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
  Future<List<AlertModel>> getProjectAlerts(dynamic projectId, {int limit = 50, int offset = 0}) async {
    final numericId = await _resolveProjectId(projectId);
    if (numericId <= 0) return [];

    try {
      final response = await apiClient.get(
        ApiEndpoints.alertsByProject(numericId),
        queryParameters: {'limit': limit, 'offset': offset},
      );
      if (response.data == null) return [];
      final list = response.data as List<dynamic>;
      return list.map((item) => AlertModel.fromJson(item as Map<String, dynamic>)).toList();
    } on NotFoundException {
      return [];
    }
  }

  @override
  Future<AlertModel?> getAlertById(dynamic alertId) async {
    final numericAlertId = int.tryParse(alertId.toString());
    if (numericAlertId == null || numericAlertId <= 0) return null;

    try {
      final response = await apiClient.get(ApiEndpoints.alertById(numericAlertId));
      if (response.data == null) return null;
      return AlertModel.fromJson(response.data as Map<String, dynamic>);
    } on NotFoundException {
      return null;
    }
  }

  @override
  Future<AlertModel> createAlert({
    required dynamic projectId,
    required String alertType,
    required String severity,
    required String message,
    double? confidence,
    String? source,
    int? detectionId,
  }) async {
    final numericId = await _resolveProjectId(projectId);
    if (numericId <= 0) {
      throw ValidationException('Invalid project ID for alert creation');
    }

    final body = <String, dynamic>{
      'project_id': numericId,
      'alert_type': alertType,
      'severity': severity,
      'message': message,
      // ignore: use_null_aware_elements
      if (confidence != null) 'confidence': confidence,
      // ignore: use_null_aware_elements
      if (source != null) 'source': source,
      // ignore: use_null_aware_elements
      if (detectionId != null) 'detection_id': detectionId,
    };

    final response = await apiClient.post(ApiEndpoints.alerts, data: body);
    return AlertModel.fromJson(response.data as Map<String, dynamic>);
  }

  @override
  Future<AlertModel> updateAlertStatus({
    required dynamic alertId,
    required String status,
  }) async {
    final numericAlertId = int.tryParse(alertId.toString());
    if (numericAlertId == null || numericAlertId <= 0) {
      throw ValidationException('Invalid alert ID for status update');
    }

    final body = {'status': status};
    final response = await apiClient.put(
      ApiEndpoints.alertStatus(numericAlertId),
      data: body,
    );
    return AlertModel.fromJson(response.data as Map<String, dynamic>);
  }

  @override
  Future<List<AlertModel>> generateProjectAlerts(dynamic projectId) async {
    final numericId = await _resolveProjectId(projectId);
    if (numericId <= 0) return [];

    try {
      final response = await apiClient.post(ApiEndpoints.alertGenerate(numericId));
      if (response.data == null) return [];
      final list = response.data as List<dynamic>;
      return list.map((item) => AlertModel.fromJson(item as Map<String, dynamic>)).toList();
    } on NotFoundException {
      return [];
    }
  }
}
