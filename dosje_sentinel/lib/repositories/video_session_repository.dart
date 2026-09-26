import 'dart:convert';
import 'package:dio/dio.dart';

import '../core/error/app_exception.dart';
import '../core/network/api_client.dart';
import '../core/network/api_endpoints.dart';
import '../shared/models/video_session_model.dart';
import 'project_repository.dart';

abstract class VideoSessionRepository {
  Future<VideoSessionModel> createVideoSession({
    required dynamic projectId,
    dynamic inspectionId,
    String? officerName,
    String? representativeName,
  });

  Future<VideoSessionModel> getVideoSession(dynamic videoSessionId);

  Future<List<VideoSessionModel>> getVideoSessionsForProject(
    dynamic projectId, {
    int limit = 50,
    int offset = 0,
  });

  Future<VideoSessionModel> updateVideoSession(
    dynamic videoSessionId, {
    String? officerName,
    String? representativeName,
  });

  Future<VideoSessionModel> startVideoSession(dynamic videoSessionId);

  Future<VideoSessionModel> endVideoSession(dynamic videoSessionId);

  Future<VideoSessionModel> cancelVideoSession(dynamic videoSessionId);

  Future<VideoSessionModel> createVideoSessionForInspection(dynamic inspectionId);

  Future<VideoSessionModel> getInspectionVideoSession(dynamic inspectionId);
}

class MockVideoSessionRepository implements VideoSessionRepository {
  final List<VideoSessionModel> _sessions = [
    VideoSessionModel(
      id: 1,
      projectId: 1,
      inspectionId: 1,
      sessionId: '550e8400-e29b-41d4-a716-446655440101',
      status: VideoSessionStatus.active,
      officerName: 'Inspector Sharma',
      representativeName: 'Dr. Rathore',
      startedAt: DateTime.now().subtract(const Duration(minutes: 5)),
      createdAt: DateTime.now().subtract(const Duration(minutes: 10)),
    ),
  ];

  @override
  Future<VideoSessionModel> createVideoSession({
    required dynamic projectId,
    dynamic inspectionId,
    String? officerName,
    String? representativeName,
  }) async {
    final newSession = VideoSessionModel(
      id: _sessions.length + 1,
      projectId: projectId is int ? projectId : 1,
      inspectionId: inspectionId is int ? inspectionId : (inspectionId != null ? 1 : null),
      sessionId: 'mock-session-${DateTime.now().millisecondsSinceEpoch}',
      status: VideoSessionStatus.created,
      officerName: officerName,
      representativeName: representativeName,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );
    _sessions.add(newSession);
    return newSession;
  }

  @override
  Future<VideoSessionModel> getVideoSession(dynamic videoSessionId) async {
    final found = _sessions.firstWhere(
      (s) => s.id.toString() == videoSessionId.toString() || s.sessionId == videoSessionId.toString(),
      orElse: () => throw NotFoundException('Video session not found'),
    );
    return found;
  }

  @override
  Future<List<VideoSessionModel>> getVideoSessionsForProject(
    dynamic projectId, {
    int limit = 50,
    int offset = 0,
  }) async {
    return _sessions
        .where((s) => s.projectId.toString() == projectId.toString())
        .skip(offset)
        .take(limit)
        .toList();
  }

  @override
  Future<VideoSessionModel> updateVideoSession(
    dynamic videoSessionId, {
    String? officerName,
    String? representativeName,
  }) async {
    final idx = _sessions.indexWhere(
      (s) => s.id.toString() == videoSessionId.toString() || s.sessionId == videoSessionId.toString(),
    );
    if (idx == -1) throw NotFoundException('Video session not found');

    final cur = _sessions[idx];
    final updated = VideoSessionModel(
      id: cur.id,
      projectId: cur.projectId,
      inspectionId: cur.inspectionId,
      sessionId: cur.sessionId,
      status: cur.status,
      officerName: officerName ?? cur.officerName,
      representativeName: representativeName ?? cur.representativeName,
      startedAt: cur.startedAt,
      endedAt: cur.endedAt,
      createdAt: cur.createdAt,
      updatedAt: DateTime.now(),
    );
    _sessions[idx] = updated;
    return updated;
  }

  @override
  Future<VideoSessionModel> startVideoSession(dynamic videoSessionId) async {
    final idx = _sessions.indexWhere(
      (s) => s.id.toString() == videoSessionId.toString() || s.sessionId == videoSessionId.toString(),
    );
    if (idx == -1) throw NotFoundException('Video session not found');
    final cur = _sessions[idx];
    if (cur.status != VideoSessionStatus.created) {
      throw BadRequestException('Invalid video session transition: ${cur.status.toBackendString()} -> ACTIVE');
    }
    final updated = VideoSessionModel(
      id: cur.id,
      projectId: cur.projectId,
      inspectionId: cur.inspectionId,
      sessionId: cur.sessionId,
      status: VideoSessionStatus.active,
      officerName: cur.officerName,
      representativeName: cur.representativeName,
      startedAt: DateTime.now(),
      createdAt: cur.createdAt,
      updatedAt: DateTime.now(),
    );
    _sessions[idx] = updated;
    return updated;
  }

  @override
  Future<VideoSessionModel> endVideoSession(dynamic videoSessionId) async {
    final idx = _sessions.indexWhere(
      (s) => s.id.toString() == videoSessionId.toString() || s.sessionId == videoSessionId.toString(),
    );
    if (idx == -1) throw NotFoundException('Video session not found');
    final cur = _sessions[idx];
    if (cur.status != VideoSessionStatus.active) {
      throw BadRequestException('Invalid video session transition: ${cur.status.toBackendString()} -> ENDED');
    }
    final updated = VideoSessionModel(
      id: cur.id,
      projectId: cur.projectId,
      inspectionId: cur.inspectionId,
      sessionId: cur.sessionId,
      status: VideoSessionStatus.ended,
      officerName: cur.officerName,
      representativeName: cur.representativeName,
      startedAt: cur.startedAt,
      endedAt: DateTime.now(),
      createdAt: cur.createdAt,
      updatedAt: DateTime.now(),
    );
    _sessions[idx] = updated;
    return updated;
  }

  @override
  Future<VideoSessionModel> cancelVideoSession(dynamic videoSessionId) async {
    final idx = _sessions.indexWhere(
      (s) => s.id.toString() == videoSessionId.toString() || s.sessionId == videoSessionId.toString(),
    );
    if (idx == -1) throw NotFoundException('Video session not found');
    final cur = _sessions[idx];
    if (cur.status != VideoSessionStatus.created) {
      throw BadRequestException('Invalid video session transition: ${cur.status.toBackendString()} -> CANCELLED');
    }
    final updated = VideoSessionModel(
      id: cur.id,
      projectId: cur.projectId,
      inspectionId: cur.inspectionId,
      sessionId: cur.sessionId,
      status: VideoSessionStatus.cancelled,
      officerName: cur.officerName,
      representativeName: cur.representativeName,
      startedAt: cur.startedAt,
      endedAt: cur.endedAt,
      createdAt: cur.createdAt,
      updatedAt: DateTime.now(),
    );
    _sessions[idx] = updated;
    return updated;
  }

  @override
  Future<VideoSessionModel> createVideoSessionForInspection(dynamic inspectionId) async {
    final existing = _sessions.where((s) => s.inspectionId.toString() == inspectionId.toString()).toList();
    if (existing.isNotEmpty) {
      return existing.first;
    }
    return createVideoSession(projectId: 1, inspectionId: inspectionId);
  }

  @override
  Future<VideoSessionModel> getInspectionVideoSession(dynamic inspectionId) async {
    final found = _sessions.firstWhere(
      (s) => s.inspectionId.toString() == inspectionId.toString(),
      orElse: () => throw NotFoundException('Video session not found for inspection'),
    );
    return found;
  }
}

class ApiVideoSessionRepository implements VideoSessionRepository {
  final ApiClient apiClient;
  final ProjectRepository? projectRepository;

  ApiVideoSessionRepository({
    required this.apiClient,
    this.projectRepository,
  });

  Future<int> _resolveProjectId(dynamic raw) async {
    if (raw is int) return raw;
    final parsed = int.tryParse(raw.toString());
    if (parsed != null) return parsed;

    if (projectRepository != null) {
      try {
        final projects = await projectRepository!.getProjects();
        final found = projects.firstWhere(
          (p) => p.code == raw.toString() || p.id.toString() == raw.toString(),
        );
        return int.tryParse(found.id.toString()) ?? 1;
      } catch (_) {}
    }
    return 1;
  }

  int _resolveNumericId(dynamic raw) {
    if (raw is int) return raw;
    final parsed = int.tryParse(raw.toString());
    if (parsed != null) return parsed;
    throw BadRequestException('Numeric ID required: $raw');
  }

  @override
  Future<VideoSessionModel> createVideoSession({
    required dynamic projectId,
    dynamic inspectionId,
    String? officerName,
    String? representativeName,
  }) async {
    final numericProjId = await _resolveProjectId(projectId);
    final numericInspId = inspectionId != null ? _resolveNumericId(inspectionId) : null;

    final payload = {
      'project_id': numericProjId,
      'inspection_id': numericInspId,
      if (officerName != null) 'officer_name': officerName,
      if (representativeName != null) 'representative_name': representativeName,
    };

    try {
      final response = await apiClient.post(ApiEndpoints.videoSessions, data: payload);
      final data = response.data is String ? jsonDecode(response.data) : response.data;
      return VideoSessionModel.fromJson(data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw _handleDioError(e);
    } catch (e) {
      if (e is AppException) rethrow;
      throw AppException(e.toString());
    }
  }

  @override
  Future<VideoSessionModel> getVideoSession(dynamic videoSessionId) async {
    final numericId = _resolveNumericId(videoSessionId);
    try {
      final response = await apiClient.get(ApiEndpoints.videoSessionById(numericId));
      final data = response.data is String ? jsonDecode(response.data) : response.data;
      return VideoSessionModel.fromJson(data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw _handleDioError(e);
    } catch (e) {
      if (e is AppException) rethrow;
      throw AppException(e.toString());
    }
  }

  @override
  Future<List<VideoSessionModel>> getVideoSessionsForProject(
    dynamic projectId, {
    int limit = 50,
    int offset = 0,
  }) async {
    final numericProjId = await _resolveProjectId(projectId);
    try {
      final response = await apiClient.get(
        ApiEndpoints.videoSessionsByProject(numericProjId),
        queryParameters: {'limit': limit, 'offset': offset},
      );
      final rawList = response.data is String ? jsonDecode(response.data) : response.data;
      if (rawList is List) {
        return rawList
            .map((item) => VideoSessionModel.fromJson(item as Map<String, dynamic>))
            .toList();
      }
      return [];
    } on DioException catch (e) {
      throw _handleDioError(e);
    } catch (e) {
      if (e is AppException) rethrow;
      throw AppException(e.toString());
    }
  }

  @override
  Future<VideoSessionModel> updateVideoSession(
    dynamic videoSessionId, {
    String? officerName,
    String? representativeName,
  }) async {
    final numericId = _resolveNumericId(videoSessionId);
    final payload = <String, dynamic>{};
    if (officerName != null) payload['officer_name'] = officerName;
    if (representativeName != null) payload['representative_name'] = representativeName;

    try {
      final response = await apiClient.put(
        ApiEndpoints.videoSessionById(numericId),
        data: payload,
      );
      final data = response.data is String ? jsonDecode(response.data) : response.data;
      return VideoSessionModel.fromJson(data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw _handleDioError(e);
    } catch (e) {
      if (e is AppException) rethrow;
      throw AppException(e.toString());
    }
  }

  @override
  Future<VideoSessionModel> startVideoSession(dynamic videoSessionId) async {
    final numericId = _resolveNumericId(videoSessionId);
    try {
      final response = await apiClient.post(ApiEndpoints.videoSessionStart(numericId));
      final data = response.data is String ? jsonDecode(response.data) : response.data;
      return VideoSessionModel.fromJson(data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw _handleDioError(e);
    } catch (e) {
      if (e is AppException) rethrow;
      throw AppException(e.toString());
    }
  }

  @override
  Future<VideoSessionModel> endVideoSession(dynamic videoSessionId) async {
    final numericId = _resolveNumericId(videoSessionId);
    try {
      final response = await apiClient.post(ApiEndpoints.videoSessionEnd(numericId));
      final data = response.data is String ? jsonDecode(response.data) : response.data;
      return VideoSessionModel.fromJson(data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw _handleDioError(e);
    } catch (e) {
      if (e is AppException) rethrow;
      throw AppException(e.toString());
    }
  }

  @override
  Future<VideoSessionModel> cancelVideoSession(dynamic videoSessionId) async {
    final numericId = _resolveNumericId(videoSessionId);
    try {
      final response = await apiClient.post(ApiEndpoints.videoSessionCancel(numericId));
      final data = response.data is String ? jsonDecode(response.data) : response.data;
      return VideoSessionModel.fromJson(data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw _handleDioError(e);
    } catch (e) {
      if (e is AppException) rethrow;
      throw AppException(e.toString());
    }
  }

  @override
  Future<VideoSessionModel> createVideoSessionForInspection(dynamic inspectionId) async {
    final numericInspId = _resolveNumericId(inspectionId);
    try {
      final response = await apiClient.post(ApiEndpoints.inspectionVideoSession(numericInspId));
      final data = response.data is String ? jsonDecode(response.data) : response.data;
      return VideoSessionModel.fromJson(data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw _handleDioError(e);
    } catch (e) {
      if (e is AppException) rethrow;
      throw AppException(e.toString());
    }
  }

  @override
  Future<VideoSessionModel> getInspectionVideoSession(dynamic inspectionId) async {
    final numericInspId = _resolveNumericId(inspectionId);
    try {
      final response = await apiClient.get(ApiEndpoints.inspectionVideoSession(numericInspId));
      final data = response.data is String ? jsonDecode(response.data) : response.data;
      return VideoSessionModel.fromJson(data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw _handleDioError(e);
    } catch (e) {
      if (e is AppException) rethrow;
      throw AppException(e.toString());
    }
  }

  AppException _handleDioError(DioException e) {
    final statusCode = e.response?.statusCode;
    final data = e.response?.data;
    String detail = 'Request failed';
    if (data is Map && data.containsKey('detail')) {
      detail = data['detail'].toString();
    } else if (data is String) {
      detail = data;
    }

    switch (statusCode) {
      case 400:
        return BadRequestException(detail, data);
      case 401:
        return UnauthorizedException(detail);
      case 403:
        return ForbiddenException(detail);
      case 404:
        return NotFoundException(detail);
      case 409:
        return ConflictException(detail, data);
      case 422:
        return ValidationException(detail, data);
      case 500:
        return ServerException(detail);
      default:
        return AppException(detail, statusCode: statusCode, details: data);
    }
  }
}
