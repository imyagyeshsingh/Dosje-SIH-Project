import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/network/api_client.dart';
import '../../core/auth/auth_service.dart';
import '../../core/auth/auth_state.dart';
import '../../core/realtime/realtime_service.dart';
import '../../core/storage/offline_queue_service.dart';
import '../../core/video/video_inspection_service.dart';
import '../../core/location/location_service.dart';
import '../../core/notifications/notification_service.dart';
import '../../repositories/ngo_repository.dart';
import '../../repositories/official_ngo_repository.dart';
import '../../repositories/project_repository.dart';
import '../../repositories/inspection_repository.dart';
import '../../repositories/evidence_repository.dart';
import '../../repositories/cctv_repository.dart';
import '../../repositories/analytics_repository.dart';
import '../../repositories/ai_detection_repository.dart';
import '../../repositories/attendance_repository.dart';
import '../../repositories/risk_repository.dart';
import '../../repositories/alert_repository.dart';
import '../../repositories/video_session_repository.dart';
import '../../repositories/report_repository.dart';
import '../../repositories/notification_repository.dart';
import '../../repositories/audit_log_repository.dart';
import '../../repositories/inspector_repository.dart';
import '../../core/video/video_signaling_service.dart';
import '../models/audit_log_model.dart';
import '../models/ai_detection_model.dart';
import '../models/ai_risk_model.dart';
import '../models/alert_model.dart';
import '../models/attendance_model.dart';
import '../models/cctv_camera_model.dart';
import '../models/evidence_model.dart';
import '../models/inspection_model.dart';
import '../models/ngo_registration_status.dart';
import '../models/project_model.dart';
import '../models/report_model.dart';
import '../models/user_role.dart';
import '../models/video_session_model.dart';
import '../models/notification_model.dart';

// Core Network & Realtime
final apiClientProvider = Provider<ApiClient>((ref) => ApiClient());
final realtimeServiceProvider = Provider<RealtimeService>(
  (ref) => DefaultRealtimeService(),
);
final offlineQueueServiceProvider = Provider<OfflineQueueService>(
  (ref) => DefaultOfflineQueueService(),
);
final videoSignalingServiceProvider = Provider<VideoSignalingService>((ref) {
  return WebSocketVideoSignalingService();
});

final videoInspectionServiceProvider = Provider<VideoInspectionService>((ref) {
  final signaling = ref.watch(videoSignalingServiceProvider);
  final sessionRepo = ref.watch(videoSessionRepositoryProvider);
  return ApiVideoInspectionService(
    signalingService: signaling,
    sessionRepository: sessionRepo,
  );
});
final locationServiceProvider = Provider<LocationService>(
  (ref) => DefaultLocationService(),
);

// Auth Service & State
final authServiceProvider = Provider<AuthService>((ref) {
  final client = ref.watch(apiClientProvider);
  return DefaultAuthService(apiClient: client);
});

class AuthNotifier extends StateNotifier<AuthState> {
  final AuthService _authService;
  final RealtimeService _realtimeService;

  AuthNotifier(this._authService, this._realtimeService)
    : super(const AuthState());

  Future<String?> sendOtp(String email) async {
    return await _authService.sendOtp(email);
  }

  Future<void> verifyOtp({
    required String email,
    required String otp,
    NgoRegistrationStatus? status,
    UserRole? roleHint,
  }) async {
    state = state.copyWith(status: AuthStatus.authenticating);
    try {
      state = state.copyWith(status: AuthStatus.resolvingAuthorization);
      final newState = await _authService.verifyOtp(
        email: email,
        otp: otp,
        status: status,
        roleHint: roleHint,
      );
      state = newState;
      if (newState.token != null) {
        _realtimeService.connect(newState.token!);
      }
    } catch (e) {
      state = state.copyWith(
        status: AuthStatus.error,
        errorMessage: e.toString(),
      );
      rethrow;
    }
  }

  Future<void> signInWithClerk({
    required String email,
    required String password,
    NgoRegistrationStatus? status,
    UserRole? roleHint,
  }) async {
    state = state.copyWith(status: AuthStatus.authenticating);
    try {
      state = state.copyWith(status: AuthStatus.resolvingAuthorization);
      final newState = await _authService.signInWithClerk(
        email: email,
        password: password,
        status: status,
        roleHint: roleHint,
      );
      state = newState;
      if (newState.token != null) {
        _realtimeService.connect(newState.token!);
      }
    } catch (e) {
      state = state.copyWith(
        status: AuthStatus.error,
        errorMessage: e.toString(),
      );
    }
  }

  Future<void> signInStaff({
    required String email,
    required String password,
  }) async {
    return signInWithClerk(email: email, password: password);
  }

  void updateNgoRegistrationStatus(NgoRegistrationStatus newStatus) {
    state = state.copyWith(ngoRegistrationStatus: newStatus);
  }

  Future<void> signOut() async {
    _realtimeService.disconnect();
    state = await _authService.signOut();
  }

  Future<void> logout() => signOut();
}

final authStateProvider = StateNotifierProvider<AuthNotifier, AuthState>((ref) {
  final authService = ref.watch(authServiceProvider);
  final realtimeService = ref.watch(realtimeServiceProvider);
  return AuthNotifier(authService, realtimeService);
});

final authNotifierProvider = authStateProvider;

// Repositories
final ngoRepositoryProvider = Provider<NgoRepository>((ref) {
  final client = ref.watch(apiClientProvider);
  return ApiNgoRepository(apiClient: client);
});

final officialNgoRepositoryProvider = Provider<OfficialNgoRepository>((ref) {
  final client = ref.watch(apiClientProvider);
  return ApiOfficialNgoRepository(apiClient: client);
});

final projectRepositoryProvider = Provider<ProjectRepository>((ref) {
  final client = ref.watch(apiClientProvider);
  return ApiProjectRepository(apiClient: client);
});

final inspectionRepositoryProvider = Provider<InspectionRepository>((ref) {
  final client = ref.watch(apiClientProvider);
  final projectRepo = ref.watch(projectRepositoryProvider);
  return ApiInspectionRepository(
    apiClient: client,
    projectRepository: projectRepo,
  );
});

final evidenceRepositoryProvider = Provider<EvidenceRepository>((ref) {
  final client = ref.watch(apiClientProvider);
  return ApiEvidenceRepository(apiClient: client);
});

final reportRepositoryProvider = Provider<ReportRepository>((ref) {
  final client = ref.watch(apiClientProvider);
  return ApiReportRepository(apiClient: client);
});

final cctvRepositoryProvider = Provider<CctvRepository>((ref) {
  final client = ref.watch(apiClientProvider);
  final projectRepo = ref.watch(projectRepositoryProvider);
  return ApiCctvRepository(apiClient: client, projectRepository: projectRepo);
});

final analyticsRepositoryProvider = Provider<AnalyticsRepository>((ref) {
  final client = ref.watch(apiClientProvider);
  final projectRepo = ref.watch(projectRepositoryProvider);
  final riskRepo = ref.watch(riskRepositoryProvider);
  return ApiAnalyticsRepository(
    apiClient: client,
    projectRepository: projectRepo,
    riskRepository: riskRepo,
  );
});

// Project Summary Providers
final projectSummaryProvider = FutureProvider.family<ProjectSummaryModel?, String>((
  ref,
  id,
) async {
  final repo = ref.watch(projectRepositoryProvider);
  return await repo.getProjectSummary(id);
});

final primaryProjectSummaryProvider = FutureProvider<ProjectSummaryModel?>((ref) async {
  final repo = ref.watch(projectRepositoryProvider);
  final projects = await repo.getProjects(limit: 1);
  if (projects.isEmpty) return null;
  return await repo.getProjectSummary(projects.first.id);
});

final allRegisteredProjectsProvider = FutureProvider<List<ProjectModel>>((ref) async {
  final repo = ref.watch(projectRepositoryProvider);
  return await repo.getProjects(limit: 100);
});

// CCTV Providers
final cctvCamerasProvider = FutureProvider.family<List<CctvCamera>, String?>((
  ref,
  facilityId,
) async {
  final repo = ref.watch(cctvRepositoryProvider);
  return await repo.getCameras(facilityId: facilityId);
});

final singleCameraProvider = FutureProvider.family<CctvCamera?, String>((
  ref,
  cameraId,
) async {
  final repo = ref.watch(cctvRepositoryProvider);
  return await repo.getCameraById(cameraId);
});

// AI Detection Providers
final aiDetectionRepositoryProvider = Provider<AiDetectionRepository>((ref) {
  final client = ref.watch(apiClientProvider);
  final projectRepo = ref.watch(projectRepositoryProvider);
  return ApiAiDetectionRepository(
    apiClient: client,
    projectRepository: projectRepo,
  );
});

final projectDetectionsProvider = FutureProvider.family<List<AiDetectionModel>, dynamic>((
  ref,
  projectId,
) async {
  final repo = ref.watch(aiDetectionRepositoryProvider);
  return await repo.getProjectDetections(projectId);
});

final projectDetectionSummaryProvider = FutureProvider.family<AiDetectionSummaryModel?, dynamic>((
  ref,
  projectId,
) async {
  final repo = ref.watch(aiDetectionRepositoryProvider);
  return await repo.getProjectDetectionSummary(projectId);
});

// Attendance Providers
final attendanceRepositoryProvider = Provider<AttendanceRepository>((ref) {
  final client = ref.watch(apiClientProvider);
  final projectRepo = ref.watch(projectRepositoryProvider);
  return ApiAttendanceRepository(
    apiClient: client,
    projectRepository: projectRepo,
  );
});

final attendanceConfigProvider = FutureProvider.family<AttendanceConfigModel?, dynamic>((
  ref,
  projectId,
) async {
  final repo = ref.watch(attendanceRepositoryProvider);
  return await repo.getAttendanceConfig(projectId);
});

final attendanceSummaryProvider = FutureProvider.family<AttendanceSummaryModel?, dynamic>((
  ref,
  projectId,
) async {
  final repo = ref.watch(attendanceRepositoryProvider);
  return await repo.getAttendanceSummary(projectId);
});

// Risk Providers
final riskRepositoryProvider = Provider<RiskRepository>((ref) {
  final client = ref.watch(apiClientProvider);
  final projectRepo = ref.watch(projectRepositoryProvider);
  return ApiRiskRepository(
    apiClient: client,
    projectRepository: projectRepo,
  );
});

final projectRiskProvider = FutureProvider.family<ProjectRiskModel?, dynamic>((
  ref,
  projectId,
) async {
  final repo = ref.watch(riskRepositoryProvider);
  return await repo.getProjectRisk(projectId);
});

// Alert Providers
final alertRepositoryProvider = Provider<AlertRepository>((ref) {
  final client = ref.watch(apiClientProvider);
  final projectRepo = ref.watch(projectRepositoryProvider);
  return ApiAlertRepository(
    apiClient: client,
    projectRepository: projectRepo,
  );
});

final projectAlertsProvider = FutureProvider.family<List<AlertModel>, dynamic>((
  ref,
  projectId,
) async {
  final repo = ref.watch(alertRepositoryProvider);
  return await repo.getProjectAlerts(projectId);
});

final singleAlertProvider = FutureProvider.family<AlertModel?, dynamic>((
  ref,
  alertId,
) async {
  final repo = ref.watch(alertRepositoryProvider);
  return await repo.getAlertById(alertId);
});

// Inspection Providers
final projectInspectionsProvider = FutureProvider.family<List<InspectionModel>, dynamic>((
  ref,
  projectId,
) async {
  final repo = ref.watch(inspectionRepositoryProvider);
  return await repo.getInspectionsForProject(projectId);
});

final singleInspectionProvider = FutureProvider.family<InspectionModel?, dynamic>((
  ref,
  inspectionId,
) async {
  final repo = ref.watch(inspectionRepositoryProvider);
  return await repo.getInspectionById(inspectionId);
});

final inspectorRepositoryProvider = Provider<InspectorRepository>((ref) {
  final inspectionRepo = ref.watch(inspectionRepositoryProvider);
  return ApiInspectorRepository(inspectionRepository: inspectionRepo);
});

final inspectorsListProvider = FutureProvider<List<InspectorModel>>((ref) async {
  final repo = ref.watch(inspectionRepositoryProvider);
  return await repo.getInspectors(isActive: true);
});

final inspectionAssignmentProvider = FutureProvider.family<InspectionAssignmentModel?, dynamic>((
  ref,
  inspectionId,
) async {
  final repo = ref.watch(inspectionRepositoryProvider);
  return await repo.getInspectionAssignment(inspectionId);
});

final inspectionLocationProvider = FutureProvider.family<InspectionLocationModel?, dynamic>((
  ref,
  inspectionId,
) async {
  final repo = ref.watch(inspectionRepositoryProvider);
  return await repo.getInspectionLocation(inspectionId);
});

// Video Session Providers
final videoSessionRepositoryProvider = Provider<VideoSessionRepository>((ref) {
  final client = ref.watch(apiClientProvider);
  final projectRepo = ref.watch(projectRepositoryProvider);
  return ApiVideoSessionRepository(
    apiClient: client,
    projectRepository: projectRepo,
  );
});

final projectVideoSessionsProvider = FutureProvider.family<List<VideoSessionModel>, dynamic>((
  ref,
  projectId,
) async {
  final repo = ref.watch(videoSessionRepositoryProvider);
  return await repo.getVideoSessionsForProject(projectId);
});

final singleVideoSessionProvider = FutureProvider.family<VideoSessionModel?, dynamic>((
  ref,
  sessionId,
) async {
  final repo = ref.watch(videoSessionRepositoryProvider);
  return await repo.getVideoSession(sessionId);
});

final inspectionVideoSessionProvider = FutureProvider.family<VideoSessionModel?, dynamic>((
  ref,
  inspectionId,
) async {
  final repo = ref.watch(videoSessionRepositoryProvider);
  try {
    return await repo.getInspectionVideoSession(inspectionId);
  } catch (_) {
    return null;
  }
});

// Report & Evidence Providers
final projectReportsProvider = FutureProvider.family<List<ReportModel>, dynamic>((
  ref,
  projectId,
) async {
  final repo = ref.watch(reportRepositoryProvider);
  return await repo.getReportsForProject(projectId);
});

final singleReportProvider = FutureProvider.family<ReportModel?, dynamic>((
  ref,
  reportId,
) async {
  final repo = ref.watch(reportRepositoryProvider);
  return await repo.getReportById(reportId);
});

final reportAggregationProvider = FutureProvider.family<ReportAggregationModel?, dynamic>((
  ref,
  reportId,
) async {
  final repo = ref.watch(reportRepositoryProvider);
  return await repo.getReportAggregation(reportId);
});

final inspectionEvidenceProvider = FutureProvider.family<List<EvidenceModel>, dynamic>((
  ref,
  inspectionId,
) async {
  final repo = ref.watch(evidenceRepositoryProvider);
  return await repo.getEvidenceForInspection(inspectionId);
});

final reportEvidenceReferencesProvider = FutureProvider.family<List<ReportEvidenceReferenceModel>, dynamic>((
  ref,
  reportId,
) async {
  final repo = ref.watch(reportRepositoryProvider);
  return await repo.getReportEvidence(reportId);
});

// Notification Providers
final notificationRepositoryProvider = Provider<NotificationRepository>((ref) {
  final client = ref.watch(apiClientProvider);
  final projectRepo = ref.watch(projectRepositoryProvider);
  return ApiNotificationRepository(
    apiClient: client,
    projectRepository: projectRepo,
  );
});

final notificationsProvider = FutureProvider.autoDispose<List<NotificationItem>>((ref) async {
  final repo = ref.watch(notificationRepositoryProvider);
  return await repo.getNotifications();
});

final projectNotificationsProvider = FutureProvider.family<List<NotificationItem>, dynamic>((
  ref,
  projectId,
) async {
  final repo = ref.watch(notificationRepositoryProvider);
  return await repo.getProjectNotifications(projectId);
});

final notificationSummaryProvider = FutureProvider.autoDispose<NotificationSummary>((ref) async {
  final repo = ref.watch(notificationRepositoryProvider);
  return await repo.getNotificationSummary();
});

final singleNotificationProvider = FutureProvider.family<NotificationItem?, dynamic>((
  ref,
  notificationId,
) async {
  final repo = ref.watch(notificationRepositoryProvider);
  return await repo.getNotificationById(notificationId);
});

final notificationServiceProvider = Provider<NotificationService>((ref) {
  return DefaultNotificationService(ref.watch(notificationRepositoryProvider));
});

// Audit Log Providers
final auditLogRepositoryProvider = Provider<AuditLogRepository>((ref) {
  final client = ref.watch(apiClientProvider);
  final projectRepo = ref.watch(projectRepositoryProvider);
  return ApiAuditLogRepository(
    apiClient: client,
    projectRepository: projectRepo,
  );
});

final auditLogsProvider = FutureProvider.autoDispose<List<AuditLogModel>>((ref) async {
  final repo = ref.watch(auditLogRepositoryProvider);
  return await repo.getAuditLogs();
});

final projectAuditLogsProvider = FutureProvider.family<List<AuditLogModel>, dynamic>((
  ref,
  projectId,
) async {
  final repo = ref.watch(auditLogRepositoryProvider);
  return await repo.getProjectAuditLogs(projectId);
});

final singleAuditLogProvider = FutureProvider.family<AuditLogModel?, dynamic>((
  ref,
  auditLogId,
) async {
  final repo = ref.watch(auditLogRepositoryProvider);
  return await repo.getAuditLogById(auditLogId);
});

final entityAuditLogsProvider = FutureProvider.family<List<AuditLogModel>, ({String entityType, int entityId})>((
  ref,
  params,
) async {
  final repo = ref.watch(auditLogRepositoryProvider);
  return await repo.getAuditLogs(
    entityType: params.entityType,
    entityId: params.entityId,
  );
});
