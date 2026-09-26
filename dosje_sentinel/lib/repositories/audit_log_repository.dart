import '../core/error/app_exception.dart';
import '../core/network/api_client.dart';
import '../core/network/api_endpoints.dart';
import '../shared/models/audit_log_model.dart';
import 'project_repository.dart';

abstract class AuditLogRepository {
  Future<List<AuditLogModel>> getAuditLogs({
    dynamic projectId,
    String? entityType,
    int? entityId,
    String? action,
    String? actorId,
    int limit = 100,
    int offset = 0,
  });

  Future<List<AuditLogModel>> getProjectAuditLogs(
    dynamic projectId, {
    int limit = 100,
    int offset = 0,
  });

  Future<AuditLogModel?> getAuditLogById(dynamic auditLogId);

  Future<AuditLogModel> createAuditLog({
    dynamic projectId,
    required String entityType,
    int? entityId,
    required String action,
    String? actorId,
    String? actorName,
    String? details,
  });
}

class MockAuditLogRepository implements AuditLogRepository {
  final List<AuditLogModel> _logs = [
    AuditLogModel(
      id: 1,
      projectId: 1,
      entityType: 'INSPECTION',
      entityId: 101,
      action: 'CREATED',
      actorId: 'OFF-77',
      actorName: 'Inspector Jane',
      details: 'Surprise field audit initiated for residential quarters',
      createdAt: DateTime.now().subtract(const Duration(hours: 3)),
    ),
    AuditLogModel(
      id: 2,
      projectId: 1,
      entityType: 'INSPECTION',
      entityId: 101,
      action: 'ASSIGNED',
      actorId: 'OFF-77',
      actorName: 'Director Sharma',
      details: 'Assigned to nodal inspector Rajesh Kumar',
      createdAt: DateTime.now().subtract(const Duration(hours: 2)),
    ),
    AuditLogModel(
      id: 3,
      projectId: 1,
      entityType: 'ALERT',
      entityId: 501,
      action: 'CREATED',
      actorId: null,
      actorName: null,
      details: 'Alert created with severity HIGH: attendance threshold breached',
      createdAt: DateTime.now().subtract(const Duration(hours: 1)),
    ),
    AuditLogModel(
      id: 4,
      projectId: 2,
      entityType: 'AI_DETECTION',
      entityId: 801,
      action: 'CREATED',
      actorId: null,
      actorName: null,
      details: 'Ingested 8 detections from Camera #1',
      createdAt: DateTime.now().subtract(const Duration(minutes: 30)),
    ),
  ];

  @override
  Future<List<AuditLogModel>> getAuditLogs({
    dynamic projectId,
    String? entityType,
    int? entityId,
    String? action,
    String? actorId,
    int limit = 100,
    int offset = 0,
  }) async {
    await Future.delayed(const Duration(milliseconds: 50));
    final pid = projectId != null ? int.tryParse(projectId.toString()) : null;

    final filtered = _logs.where((log) {
      if (pid != null && log.projectId != pid) return false;
      if (entityType != null &&
          log.entityType.toUpperCase() != entityType.toUpperCase()) {
        return false;
      }
      if (entityId != null && log.entityId != entityId) return false;
      if (action != null &&
          log.action.toUpperCase() != action.toUpperCase()) {
        return false;
      }
      if (actorId != null && log.actorId != actorId) return false;
      return true;
    }).toList();

    filtered.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    if (offset >= filtered.length) return [];
    final end = (offset + limit < filtered.length) ? offset + limit : filtered.length;
    return filtered.sublist(offset, end);
  }

  @override
  Future<List<AuditLogModel>> getProjectAuditLogs(
    dynamic projectId, {
    int limit = 100,
    int offset = 0,
  }) async {
    return getAuditLogs(projectId: projectId, limit: limit, offset: offset);
  }

  @override
  Future<AuditLogModel?> getAuditLogById(dynamic auditLogId) async {
    await Future.delayed(const Duration(milliseconds: 50));
    final id = int.tryParse(auditLogId.toString());
    try {
      return _logs.firstWhere((log) => log.id == id);
    } catch (_) {
      return null;
    }
  }

  @override
  Future<AuditLogModel> createAuditLog({
    dynamic projectId,
    required String entityType,
    int? entityId,
    required String action,
    String? actorId,
    String? actorName,
    String? details,
  }) async {
    await Future.delayed(const Duration(milliseconds: 50));
    final pid = projectId != null ? int.tryParse(projectId.toString()) : null;
    final newId = (_logs.map((e) => e.id).fold(0, (max, v) => v > max ? v : max)) + 1;

    final newLog = AuditLogModel(
      id: newId,
      projectId: pid,
      entityType: entityType.trim(),
      entityId: entityId,
      action: action.trim(),
      actorId: actorId?.trim(),
      actorName: actorName?.trim(),
      details: details?.trim(),
      createdAt: DateTime.now(),
    );
    _logs.insert(0, newLog);
    return newLog;
  }
}

class ApiAuditLogRepository implements AuditLogRepository {
  final ApiClient apiClient;
  final ProjectRepository? projectRepository;

  ApiAuditLogRepository({
    required this.apiClient,
    this.projectRepository,
  });

  Future<int?> _resolveProjectId(dynamic rawId) async {
    if (rawId == null) return null;
    if (rawId is int) return rawId;
    final parsed = int.tryParse(rawId.toString());
    if (parsed != null) return parsed;

    if (projectRepository != null) {
      try {
        final projects = await projectRepository!.getProjects();
        final match = projects.where((p) => p.code == rawId.toString()).toList();
        if (match.isNotEmpty) {
          final pIdParsed = int.tryParse(match.first.id);
          if (pIdParsed != null) return pIdParsed;
        }
      } catch (_) {}
    }
    return null;
  }

  @override
  Future<List<AuditLogModel>> getAuditLogs({
    dynamic projectId,
    String? entityType,
    int? entityId,
    String? action,
    String? actorId,
    int limit = 100,
    int offset = 0,
  }) async {
    final queryParams = <String, dynamic>{
      'limit': limit,
      'offset': offset,
    };

    if (projectId != null) {
      final pId = await _resolveProjectId(projectId);
      if (pId != null) {
        queryParams['project_id'] = pId;
      }
    }
    if (entityType != null && entityType.trim().isNotEmpty) {
      queryParams['entity_type'] = entityType.trim();
    }
    if (entityId != null) {
      queryParams['entity_id'] = entityId;
    }
    if (action != null && action.trim().isNotEmpty) {
      queryParams['action'] = action.trim();
    }
    if (actorId != null && actorId.trim().isNotEmpty) {
      queryParams['actor_id'] = actorId.trim();
    }

    try {
      final response = await apiClient.get(
        ApiEndpoints.auditLogs,
        queryParameters: queryParams,
      );

      if (response.data == null) return [];
      final List<dynamic> data = response.data is List ? response.data as List<dynamic> : [];
      return data
          .map((item) => AuditLogModel.fromJson(item as Map<String, dynamic>))
          .toList();
    } on AppException {
      rethrow;
    } catch (e) {
      throw ServerException('Failed to fetch audit logs: $e');
    }
  }

  @override
  Future<List<AuditLogModel>> getProjectAuditLogs(
    dynamic projectId, {
    int limit = 100,
    int offset = 0,
  }) async {
    final pId = await _resolveProjectId(projectId);
    if (pId == null) return [];

    try {
      final response = await apiClient.get(
        ApiEndpoints.auditLogsByProject(pId),
        queryParameters: {
          'limit': limit,
          'offset': offset,
        },
      );

      if (response.data == null) return [];
      final List<dynamic> data = response.data is List ? response.data as List<dynamic> : [];
      return data
          .map((item) => AuditLogModel.fromJson(item as Map<String, dynamic>))
          .toList();
    } on NotFoundException {
      return [];
    } on AppException {
      rethrow;
    } catch (e) {
      throw ServerException('Failed to fetch project audit logs: $e');
    }
  }

  @override
  Future<AuditLogModel?> getAuditLogById(dynamic auditLogId) async {
    try {
      final response = await apiClient.get(ApiEndpoints.auditLogById(auditLogId));
      if (response.data == null) return null;
      return AuditLogModel.fromJson(response.data as Map<String, dynamic>);
    } on NotFoundException {
      return null;
    } on AppException {
      rethrow;
    } catch (e) {
      throw ServerException('Failed to fetch audit log $auditLogId: $e');
    }
  }

  @override
  Future<AuditLogModel> createAuditLog({
    dynamic projectId,
    required String entityType,
    int? entityId,
    required String action,
    String? actorId,
    String? actorName,
    String? details,
  }) async {
    int? pId;
    if (projectId != null) {
      pId = await _resolveProjectId(projectId);
    }

    final payload = <String, dynamic>{
      if (pId != null) 'project_id': pId,
      'entity_type': entityType.trim(),
      if (entityId != null) 'entity_id': entityId,
      'action': action.trim(),
      if (actorId != null && actorId.trim().isNotEmpty) 'actor_id': actorId.trim(),
      if (actorName != null && actorName.trim().isNotEmpty) 'actor_name': actorName.trim(),
      if (details != null && details.trim().isNotEmpty) 'details': details.trim(),
    };

    try {
      final response = await apiClient.post(
        ApiEndpoints.auditLogs,
        data: payload,
      );
      return AuditLogModel.fromJson(response.data as Map<String, dynamic>);
    } on AppException {
      rethrow;
    } catch (e) {
      throw ServerException('Failed to create audit log: $e');
    }
  }
}
