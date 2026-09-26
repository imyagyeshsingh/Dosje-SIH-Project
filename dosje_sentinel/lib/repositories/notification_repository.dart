import '../core/error/app_exception.dart';
import '../core/network/api_client.dart';
import '../core/network/api_endpoints.dart';
import '../shared/models/notification_model.dart';
import 'project_repository.dart';

abstract class NotificationRepository {
  Future<List<NotificationItem>> getNotifications({
    String? recipientId,
    String? recipientRole,
    dynamic projectId,
    String? notificationType,
    bool? isRead,
    int limit = 50,
    int offset = 0,
  });

  Future<List<NotificationItem>> getProjectNotifications(dynamic projectId);

  Future<NotificationItem?> getNotificationById(dynamic notificationId);

  Future<NotificationSummary> getNotificationSummary({
    String? recipientId,
    String? recipientRole,
    dynamic projectId,
  });

  Future<NotificationItem> createNotification({
    required dynamic projectId,
    required String notificationType,
    required String message,
    required String source,
    String? severity,
    String? title,
    String? recipientId,
    String? recipientRole,
    int? alertId,
    int? inspectionId,
  });

  Future<NotificationItem> markAsRead(dynamic notificationId);

  Future<NotificationBulkReadResult> markAllAsRead({
    String? recipientId,
    String? recipientRole,
    dynamic projectId,
  });
}

class MockNotificationRepository implements NotificationRepository {
  final List<NotificationItem> _notifications = [
    NotificationItem(
      id: '1',
      projectId: 1,
      title: 'Action Required: Response Due for INSP-2026-089',
      message:
          'Inspector flagged deficiency in residential dining area. Submit geotagged photographic remediation within 48 hours.',
      notificationType: NotificationType.alert,
      severity: NotificationSeverity.critical,
      source: 'ALERT_ENGINE',
      createdAt: DateTime.now().subtract(const Duration(hours: 2)),
      isRead: false,
      projectCode: 'DOSJE-DL-2024-001',
      routePath: '/ngo/inspections/detail/INSP-2026-089',
      alertId: 1,
    ),
    NotificationItem(
      id: '2',
      projectId: 1,
      title: 'Surprise Video Inspection Logged',
      message:
          'Scheduled remote spot audit was successfully completed by Shri R. K. Sharma (Joint Director).',
      notificationType: NotificationType.videoSession,
      severity: NotificationSeverity.low,
      source: 'SYSTEM',
      createdAt: DateTime.now().subtract(const Duration(hours: 5)),
      isRead: true,
      projectCode: 'DOSJE-DL-2024-001',
    ),
    NotificationItem(
      id: '3',
      projectId: 2,
      title: 'Compliance Audit Dossier Verified',
      message:
          'Departmental review of Project PRJ-002 quarterly outcomes has been approved.',
      notificationType: NotificationType.report,
      severity: NotificationSeverity.low,
      source: 'SYSTEM',
      createdAt: DateTime.now().subtract(const Duration(days: 1)),
      isRead: true,
      projectCode: 'DOSJE-DL-2024-002',
    ),
    NotificationItem(
      id: '4',
      projectId: 3,
      title: 'Field Inspection Scheduled for INSP-2026-091',
      message:
          'PMU inspection team assigned for on-site physical verification on 26 Sep 2026.',
      notificationType: NotificationType.inspection,
      severity: NotificationSeverity.medium,
      source: 'INSPECTION_ENGINE',
      createdAt: DateTime.now().subtract(const Duration(days: 2)),
      isRead: true,
      projectCode: 'DOSJE-DL-2024-003',
      inspectionId: 4,
    ),
  ];

  @override
  Future<List<NotificationItem>> getNotifications({
    String? recipientId,
    String? recipientRole,
    dynamic projectId,
    String? notificationType,
    bool? isRead,
    int limit = 50,
    int offset = 0,
  }) async {
    await Future.delayed(const Duration(milliseconds: 100));
    var filtered = List<NotificationItem>.from(_notifications);

    if (recipientId != null) {
      filtered = filtered.where((n) => n.recipientId == recipientId).toList();
    }
    if (recipientRole != null) {
      filtered =
          filtered.where((n) => n.recipientRole == recipientRole).toList();
    }
    if (projectId != null) {
      final pid = int.tryParse(projectId.toString());
      if (pid != null) {
        filtered = filtered.where((n) => n.projectId == pid).toList();
      }
    }
    if (notificationType != null) {
      filtered = filtered
          .where((n) =>
              n.notificationType.value.toUpperCase() ==
              notificationType.toUpperCase())
          .toList();
    }
    if (isRead != null) {
      filtered = filtered.where((n) => n.isRead == isRead).toList();
    }

    filtered.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return filtered.skip(offset).take(limit).toList();
  }

  @override
  Future<List<NotificationItem>> getProjectNotifications(
      dynamic projectId) async {
    await Future.delayed(const Duration(milliseconds: 100));
    final pid = int.tryParse(projectId.toString()) ?? 1;
    final list = _notifications.where((n) => n.projectId == pid).toList();
    list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return list;
  }

  @override
  Future<NotificationItem?> getNotificationById(dynamic notificationId) async {
    await Future.delayed(const Duration(milliseconds: 80));
    final idStr = notificationId.toString();
    try {
      return _notifications.firstWhere((n) => n.id == idStr);
    } catch (_) {
      return null;
    }
  }

  @override
  Future<NotificationSummary> getNotificationSummary({
    String? recipientId,
    String? recipientRole,
    dynamic projectId,
  }) async {
    await Future.delayed(const Duration(milliseconds: 80));
    final notifs = await getNotifications(
      recipientId: recipientId,
      recipientRole: recipientRole,
      projectId: projectId,
      limit: 1000,
    );
    final unread = notifs.where((n) => !n.isRead).length;
    return NotificationSummary(total: notifs.length, unread: unread);
  }

  @override
  Future<NotificationItem> createNotification({
    required dynamic projectId,
    required String notificationType,
    required String message,
    required String source,
    String? severity,
    String? title,
    String? recipientId,
    String? recipientRole,
    int? alertId,
    int? inspectionId,
  }) async {
    await Future.delayed(const Duration(milliseconds: 100));
    final pid = int.tryParse(projectId.toString()) ?? 1;
    final newId = (_notifications.length + 1).toString();
    final item = NotificationItem(
      id: newId,
      projectId: pid,
      notificationType: NotificationType.fromString(notificationType),
      severity: NotificationSeverity.fromString(severity),
      title: title ?? 'Notification',
      message: message,
      source: source,
      recipientId: recipientId,
      recipientRole: recipientRole,
      alertId: alertId,
      inspectionId: inspectionId,
      createdAt: DateTime.now(),
      isRead: false,
    );
    _notifications.insert(0, item);
    return item;
  }

  @override
  Future<NotificationItem> markAsRead(dynamic notificationId) async {
    await Future.delayed(const Duration(milliseconds: 80));
    final idStr = notificationId.toString();
    final idx = _notifications.indexWhere((n) => n.id == idStr);
    if (idx == -1) {
      throw NotFoundException('Notification not found');
    }
    final existing = _notifications[idx];
    final updated = existing.copyWith(
      isRead: true,
      readAt: existing.readAt ?? DateTime.now(),
    );
    _notifications[idx] = updated;
    return updated;
  }

  @override
  Future<NotificationBulkReadResult> markAllAsRead({
    String? recipientId,
    String? recipientRole,
    dynamic projectId,
  }) async {
    await Future.delayed(const Duration(milliseconds: 100));
    int count = 0;
    final pid = projectId != null ? int.tryParse(projectId.toString()) : null;
    final now = DateTime.now();

    for (int i = 0; i < _notifications.length; i++) {
      final n = _notifications[i];
      if (n.isRead) continue;
      if (recipientId != null && n.recipientId != recipientId) continue;
      if (recipientRole != null && n.recipientRole != recipientRole) continue;
      if (pid != null && n.projectId != pid) continue;

      _notifications[i] = n.copyWith(isRead: true, readAt: n.readAt ?? now);
      count++;
    }

    return NotificationBulkReadResult(markedRead: count);
  }
}

class ApiNotificationRepository implements NotificationRepository {
  final ApiClient apiClient;
  final ProjectRepository? projectRepository;

  ApiNotificationRepository({
    required this.apiClient,
    this.projectRepository,
  });

  Future<int> _resolveProjectId(dynamic rawId) async {
    if (rawId == null) return 0;
    if (rawId is int) return rawId;
    final parsed = int.tryParse(rawId.toString());
    if (parsed != null) return parsed;

    if (projectRepository != null) {
      try {
        final project =
            await projectRepository!.getProjectById(rawId.toString());
        if (project != null) {
          final idNum = int.tryParse(project.id);
          if (idNum != null) return idNum;
        }
      } catch (_) {}
    }
    return 0;
  }

  @override
  Future<List<NotificationItem>> getNotifications({
    String? recipientId,
    String? recipientRole,
    dynamic projectId,
    String? notificationType,
    bool? isRead,
    int limit = 50,
    int offset = 0,
  }) async {
    final query = <String, dynamic>{
      'limit': limit,
      'offset': offset,
    };
    if (recipientId != null && recipientId.trim().isNotEmpty) {
      query['recipient_id'] = recipientId.trim();
    }
    if (recipientRole != null && recipientRole.trim().isNotEmpty) {
      query['recipient_role'] = recipientRole.trim();
    }
    if (projectId != null) {
      final pid = await _resolveProjectId(projectId);
      if (pid > 0) {
        query['project_id'] = pid;
      }
    }
    if (notificationType != null && notificationType.trim().isNotEmpty) {
      query['notification_type'] = notificationType.trim().toUpperCase();
    }
    if (isRead != null) {
      query['is_read'] = isRead;
    }

    try {
      final response = await apiClient.get(
        ApiEndpoints.notifications,
        queryParameters: query,
      );
      if (response.data == null) return [];
      final list = response.data as List<dynamic>;
      return list
          .map((item) => NotificationItem.fromJson(item as Map<String, dynamic>))
          .toList();
    } catch (_) {
      return [];
    }
  }

  @override
  Future<List<NotificationItem>> getProjectNotifications(
      dynamic projectId) async {
    final numericId = await _resolveProjectId(projectId);
    if (numericId <= 0) return [];

    try {
      final response = await apiClient.get(
        ApiEndpoints.notificationsByProject(numericId),
      );
      if (response.data == null) return [];
      final list = response.data as List<dynamic>;
      return list
          .map((item) => NotificationItem.fromJson(item as Map<String, dynamic>))
          .toList();
    } on NotFoundException {
      return [];
    } catch (_) {
      return [];
    }
  }

  @override
  Future<NotificationItem?> getNotificationById(dynamic notificationId) async {
    final numericId = int.tryParse(notificationId.toString());
    if (numericId == null || numericId <= 0) return null;

    try {
      final response = await apiClient.get(
        ApiEndpoints.notificationById(numericId),
      );
      if (response.data == null) return null;
      return NotificationItem.fromJson(response.data as Map<String, dynamic>);
    } on NotFoundException {
      return null;
    } catch (_) {
      return null;
    }
  }

  @override
  Future<NotificationSummary> getNotificationSummary({
    String? recipientId,
    String? recipientRole,
    dynamic projectId,
  }) async {
    final query = <String, dynamic>{};
    if (recipientId != null && recipientId.trim().isNotEmpty) {
      query['recipient_id'] = recipientId.trim();
    }
    if (recipientRole != null && recipientRole.trim().isNotEmpty) {
      query['recipient_role'] = recipientRole.trim();
    }
    if (projectId != null) {
      final pid = await _resolveProjectId(projectId);
      if (pid > 0) {
        query['project_id'] = pid;
      }
    }

    try {
      final response = await apiClient.get(
        ApiEndpoints.notificationsSummary,
        queryParameters: query.isEmpty ? null : query,
      );
      if (response.data == null) {
        return const NotificationSummary();
      }
      return NotificationSummary.fromJson(
          response.data as Map<String, dynamic>);
    } catch (_) {
      return const NotificationSummary();
    }
  }

  @override
  Future<NotificationItem> createNotification({
    required dynamic projectId,
    required String notificationType,
    required String message,
    required String source,
    String? severity,
    String? title,
    String? recipientId,
    String? recipientRole,
    int? alertId,
    int? inspectionId,
  }) async {
    final numericId = await _resolveProjectId(projectId);
    if (numericId <= 0) {
      throw ValidationException('Invalid project ID for notification creation');
    }

    final body = <String, dynamic>{
      'project_id': numericId,
      'notification_type': notificationType.toUpperCase(),
      'message': message,
      'source': source,
    };
    if (severity != null && severity.trim().isNotEmpty) {
      body['severity'] = severity.trim().toUpperCase();
    }
    if (title != null && title.trim().isNotEmpty) {
      body['title'] = title.trim();
    }
    if (recipientId != null && recipientId.trim().isNotEmpty) {
      body['recipient_id'] = recipientId.trim();
    }
    if (recipientRole != null && recipientRole.trim().isNotEmpty) {
      body['recipient_role'] = recipientRole.trim();
    }
    if (alertId != null && alertId > 0) {
      body['alert_id'] = alertId;
    }
    if (inspectionId != null && inspectionId > 0) {
      body['inspection_id'] = inspectionId;
    }

    final response = await apiClient.post(
      ApiEndpoints.notifications,
      data: body,
    );
    return NotificationItem.fromJson(response.data as Map<String, dynamic>);
  }

  @override
  Future<NotificationItem> markAsRead(dynamic notificationId) async {
    final numericId = int.tryParse(notificationId.toString());
    if (numericId == null || numericId <= 0) {
      throw ValidationException('Invalid notification ID for mark read');
    }

    final response = await apiClient.put(
      ApiEndpoints.notificationRead(numericId),
    );
    return NotificationItem.fromJson(response.data as Map<String, dynamic>);
  }

  @override
  Future<NotificationBulkReadResult> markAllAsRead({
    String? recipientId,
    String? recipientRole,
    dynamic projectId,
  }) async {
    final query = <String, dynamic>{};
    if (recipientId != null && recipientId.trim().isNotEmpty) {
      query['recipient_id'] = recipientId.trim();
    }
    if (recipientRole != null && recipientRole.trim().isNotEmpty) {
      query['recipient_role'] = recipientRole.trim();
    }
    if (projectId != null) {
      final pid = await _resolveProjectId(projectId);
      if (pid > 0) {
        query['project_id'] = pid;
      }
    }

    final response = await apiClient.put(
      ApiEndpoints.notificationsReadAll,
      queryParameters: query.isEmpty ? null : query,
    );
    return NotificationBulkReadResult.fromJson(
        response.data as Map<String, dynamic>);
  }
}
