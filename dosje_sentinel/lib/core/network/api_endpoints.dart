import 'package:flutter/foundation.dart';

class ApiEndpoints {
  ApiEndpoints._();

  static String _resolveDefaultBaseUrl() {
    const envUrl = String.fromEnvironment('API_BASE_URL');
    if (envUrl.isNotEmpty) return envUrl;

    // Public HTTPS tunnel accessible from any phone on cellular (4G/5G) or any Wi-Fi
    return 'https://satin-species-kilometer.ngrok-free.dev';
  }

  static String _customBaseUrl = _resolveDefaultBaseUrl();

  static String get baseUrl => _customBaseUrl;

  static void setBaseUrl(String url) {
    _customBaseUrl = url.endsWith('/') ? url.substring(0, url.length - 1) : url;
  }

  static String get realtimeWsUrl {
    final clean = baseUrl.replaceFirst(RegExp(r'^http'), 'ws');
    return '$clean/ws/realtime';
  }

  // Auth & Identity Handshake
  static const String login = '/api/v1/auth/login';
  static const String logout = '/api/v1/auth/logout';
  static const String me = '/api/v1/auth/me';
  static const String resolveRole = '/api/v1/auth/resolve-role';
  static const String sendOtp = '/api/v1/auth/otp/send';
  static const String verifyOtp = '/api/v1/auth/otp/verify';
  static const String authWhitelist = '/api/v1/auth/whitelist';

  // Clerk Configuration
  static const String clerkPublishableKey =
      String.fromEnvironment('CLERK_PUBLISHABLE_KEY', defaultValue: 'pk_test_Z3VpZGluZy1zYXdmaXNoLTQ4NTAuY2xlcmsuYWNjb3VudHMuZGV2JA');
  static const String clerkFrontendApi =
      String.fromEnvironment('CLERK_FRONTEND_API', defaultValue: 'https://guiding-sawfish-4850.clerk.accounts.dev');

  // Legacy/Frontend Aliases for backwards compatibility
  static const String ngoMe = '/api/v1/ngo/me';
  static const String ngoRegistrationStatus = '/api/v1/ngo/registration-status';
  static const String ngoProfile = '/api/v1/ngo/profile';
  static const String ngoSubmitRegistration = '/api/v1/ngo/registration/submit';
  static const String ngoProjects = '/projects';
  static const String ngoInspections = '/inspections';
  static const String ngoEvidence = '/inspections';
  static const String ngoNotifications = '/notifications';
  static const String inspectorAssignments = '/inspections';
  static const String inspectorSubmitFindings = '/inspections';
  static const String officialDashboard = '/projects';
  static const String officialProjects = '/projects';
  static const String officialNgos = '/api/v1/official/ngos';
  static const String officialCctv = '/cctv';
  static const String officialAiRisk = '/risk';
  static const String officialScheduleInspection = '/inspections';
  static const String officialApproveAudit = '/inspections';
  static const String presignUpload = '/cctv';
  static const String wsEvents = '/ws/events';


  // Projects Module (Locked FastAPI Backend Contract)
  static const String projects = '/projects';
  static String projectById(dynamic id) => '/projects/$id';
  static String projectSummary(dynamic id) => '/projects/$id/summary';

  // CCTV Module
  static const String cctv = '/cctv';
  static String cctvByProject(dynamic projectId) => '/cctv/project/$projectId';
  static String cctvById(dynamic cameraId) => '/cctv/$cameraId';
  static String cctvStatus(dynamic cameraId) => '/cctv/$cameraId/status';
  static String cctvMedia(dynamic cameraId) => '/cctv/$cameraId/media';
  static String cctvHealth(dynamic cameraId) => '/cctv/$cameraId/health';

  // Inspectors Module
  static const String inspectors = '/inspectors';

  // Inspections Module
  static const String inspections = '/inspections';
  static const String inspectionsRandom = '/inspections/random';
  static String inspectionById(dynamic inspectionId) => '/inspections/$inspectionId';
  static String inspectionByProject(dynamic projectId) => '/inspections/project/$projectId';
  static String inspectionStatus(dynamic inspectionId) => '/inspections/$inspectionId/status';
  static String inspectionAssign(dynamic inspectionId) => '/inspections/$inspectionId/assign';
  static String inspectionAssignRandom(dynamic inspectionId) => '/inspections/$inspectionId/assign-random';
  static String inspectionAssignment(dynamic inspectionId) => '/inspections/$inspectionId/assignment';
  static String inspectionLocation(dynamic inspectionId) => '/inspections/$inspectionId/location';
  static String inspectionEvidence(dynamic inspectionId) => '/inspections/$inspectionId/evidence';
  static String inspectionVideoSession(dynamic inspectionId) => '/inspections/$inspectionId/video-session';
  static String inspectionFromAlert(dynamic alertId) => '/inspections/from-alert/$alertId';

  // AI Detection Module
  static const String ai = '/ai';
  static const String aiDetection = '/ai/detection';
  static String aiDetectionByProject(dynamic projectId) => '/ai/detection/$projectId';
  static String aiDetectionSummaryByProject(dynamic projectId) => '/ai/detection/$projectId/summary';

  // Risk Module
  static const String risk = '/risk';
  static String riskByProject(dynamic projectId) => '/risk/$projectId';

  // Alerts Module
  static const String alerts = '/alerts';
  static String alertsByProject(dynamic projectId) => '/alerts/project/$projectId';
  static String alertById(dynamic alertId) => '/alerts/$alertId';
  static String alertStatus(dynamic alertId) => '/alerts/$alertId/status';
  static String alertGenerate(dynamic projectId) => '/alerts/generate/$projectId';
  static String alertAcknowledge(dynamic alertId) => '/alerts/$alertId/status';
  static String alertResolve(dynamic alertId) => '/alerts/$alertId/status';

  // Notifications Module
  static const String notifications = '/notifications';
  static const String notificationsSummary = '/notifications/summary';
  static const String notificationsReadAll = '/notifications/read-all';
  static String notificationsByProject(dynamic projectId) => '/notifications/project/$projectId';
  static String notificationById(dynamic notificationId) => '/notifications/$notificationId';
  static String notificationRead(dynamic notificationId) => '/notifications/$notificationId/read';

  // Attendance Module
  static const String attendance = '/attendance';
  static String attendanceByProject(dynamic projectId) => '/attendance/$projectId';
  static String attendanceSummary(dynamic projectId) => '/attendance/summary/$projectId';

  // Audit Logs Module
  static const String auditLogs = '/audit-logs';
  static String auditLogsByProject(dynamic projectId) => '/audit-logs/project/$projectId';
  static String auditLogById(dynamic auditLogId) => '/audit-logs/$auditLogId';

  // Reports Module
  static const String reports = '/reports';
  static String reportById(dynamic reportId) => '/reports/$reportId';
  static String reportsByProject(dynamic projectId) => '/reports/project/$projectId';
  static String reportEvidence(dynamic reportId) => '/reports/$reportId/evidence';
  static String reportEvidenceById(dynamic reportId, dynamic refId) => '/reports/$reportId/evidence/$refId';
  static String reportAggregation(dynamic reportId) => '/reports/$reportId/aggregation';

  // Video Sessions Module
  static const String videoSessions = '/video-sessions';
  static String videoSessionById(dynamic sessionId) => '/video-sessions/$sessionId';
  static String videoSessionsByProject(dynamic projectId) => '/video-sessions/project/$projectId';
  static String videoSessionStart(dynamic sessionId) => '/video-sessions/$sessionId/start';
  static String videoSessionEnd(dynamic sessionId) => '/video-sessions/$sessionId/end';
  static String videoSessionCancel(dynamic sessionId) => '/video-sessions/$sessionId/cancel';

  // WebSocket Signaling
  static String wsVideoSession(String sessionId) {
    var base = baseUrl.replaceFirst('http://', 'ws://').replaceFirst('https://', 'wss://');
    if (base.contains('localhost')) {
      base = base.replaceFirst('localhost', '127.0.0.1');
    }
    return '$base/ws/video/$sessionId';
  }
}
