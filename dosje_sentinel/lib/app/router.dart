import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../core/auth/auth_guard.dart';
import '../features/auth/presentation/login_screen.dart';
import '../features/auth/presentation/splash_screen.dart';

// NGO Onboarding
import '../features/ngo/onboarding/presentation/ngo_registration_screen.dart';
import '../features/ngo/onboarding/presentation/registration_correction_screen.dart';
import '../features/ngo/onboarding/presentation/registration_submitted_screen.dart';
import '../features/ngo/onboarding/presentation/registration_under_review_screen.dart';

// NGO Portal
import '../features/ngo/evidence/presentation/ngo_evidence_capture_screen.dart';
import '../features/ngo/evidence/presentation/ngo_offline_queue_screen.dart';
import '../features/ngo/home/presentation/ngo_home_screen.dart';
import '../features/ngo/inspections/presentation/ngo_follow_up_screen.dart';
import '../features/ngo/inspections/presentation/ngo_inspection_detail_screen.dart';
import '../features/ngo/inspections/presentation/ngo_inspections_screen.dart';
import '../features/ngo/inspections/presentation/ngo_outcome_screen.dart';
import '../features/ngo/inspections/presentation/ngo_response_form_screen.dart';
import '../features/ngo/inspections/presentation/ngo_response_review_screen.dart';
import '../features/ngo/inspections/presentation/ngo_submission_receipt_screen.dart';
import '../features/ngo/notifications/presentation/ngo_notifications_screen.dart';
import '../features/ngo/profile/presentation/ngo_organization_screen.dart';
import '../features/ngo/profile/presentation/ngo_profile_screen.dart';
import '../features/ngo/profile/presentation/ngo_settings_screen.dart';
import '../features/ngo/projects/presentation/ngo_project_details_screen.dart';
import '../features/ngo/projects/presentation/ngo_projects_screen.dart';
import '../features/ngo/video/presentation/ngo_incoming_video_screen.dart';
import '../features/ngo/video/presentation/ngo_video_completed_screen.dart';
import '../features/ngo/video/presentation/ngo_video_session_screen.dart';

// Inspector
import '../features/inspector/assignments/presentation/assigned_inspections_screen.dart';
import '../features/inspector/assignments/presentation/inspection_execution_screen.dart';
import '../features/inspector/dashboard/presentation/inspector_dashboard_screen.dart';
import '../features/inspector/profile/presentation/inspector_profile_screen.dart';
import '../features/inspector/reports/presentation/inspection_report_draft_screen.dart';
import '../features/inspector/video/presentation/inspector_video_screen.dart';

// Official
import '../features/official/analytics/presentation/ai_risk_analytics_screen.dart';
import '../features/official/cctv_wall/presentation/cctv_monitor_screen.dart';
import '../features/official/dashboard/presentation/official_dashboard_screen.dart';
import '../features/official/ngos/presentation/all_ngos_screen.dart';
import '../features/official/ngos/presentation/ngo_details_screen.dart';
import '../features/official/ngos/presentation/ngo_registration_review_screen.dart';
import '../features/official/profile/presentation/official_profile_screen.dart';
import '../features/official/reports/presentation/audit_dossier_screen.dart';
import '../features/official/scheduler/presentation/schedule_inspection_screen.dart';

// Scaffolds
import '../navigation/inspector_scaffold.dart';
import '../navigation/ngo_scaffold.dart';
import '../navigation/official_scaffold.dart';
import '../shared/models/video_session_model.dart';
import '../shared/providers/core_providers.dart';

final routerProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    initialLocation: '/login',
    refreshListenable: _RiverpodRefreshListenable(ref),
    redirect: (context, state) =>
        AuthGuard.redirect(context, state, ref.read(authNotifierProvider)),
    routes: [
      // Splash & Login
      GoRoute(
        path: '/splash',
        builder: (context, state) => const SplashScreen(),
      ),
      GoRoute(path: '/login', builder: (context, state) => const LoginScreen()),

      // NGO Onboarding (Standalone routes)
      GoRoute(
        path: '/ngo/onboarding/register',
        builder: (context, state) => const NgoRegistrationScreen(),
      ),
      GoRoute(
        path: '/ngo/onboarding/submitted',
        builder: (context, state) => const RegistrationSubmittedScreen(),
      ),
      GoRoute(
        path: '/ngo/onboarding/under-review',
        builder: (context, state) => const RegistrationUnderReviewScreen(),
      ),
      GoRoute(
        path: '/ngo/onboarding/correction',
        builder: (context, state) => const RegistrationCorrectionScreen(),
      ),

      // NGO Standalone Sub-routes
      GoRoute(
        path: '/ngo/evidence/capture',
        builder: (context, state) {
          final inspectionId = state.extra as String? ?? 'INS-2026-00482';
          return NgoEvidenceCaptureScreen(inspectionId: inspectionId);
        },
      ),
      GoRoute(
        path: '/ngo/evidence/queue',
        builder: (context, state) => const NgoOfflineQueueScreen(),
      ),
      GoRoute(
        path: '/ngo/video/incoming',
        builder: (context, state) {
          final session =
              state.extra as VideoSessionModel? ??
              VideoSessionModel(
                id: 'SURPRISE-${DateTime.now().millisecondsSinceEpoch}',
                inspectionId: 'ins_1',
                projectName: 'District Rehabilitation & Support Centre',
                callerName: 'Shri R. K. Sharma',
                callerDesignation: 'Joint Director, DoSJE',
                startedAt: DateTime.now(),
              );
          return NgoIncomingVideoScreen(session: session);
        },
      ),
      GoRoute(
        path: '/ngo/video/session',
        builder: (context, state) {
          final session =
              state.extra as VideoSessionModel? ??
              VideoSessionModel(
                id: 'SURPRISE-${DateTime.now().millisecondsSinceEpoch}',
                inspectionId: 'ins_1',
                projectName: 'District Rehabilitation & Support Centre',
                callerName: 'Shri R. K. Sharma',
                callerDesignation: 'Joint Director, DoSJE',
                startedAt: DateTime.now(),
              );
          return NgoVideoSessionScreen(session: session);
        },
      ),
      GoRoute(
        path: '/ngo/video/completed',
        builder: (context, state) {
          final session =
              state.extra as VideoSessionModel? ??
              VideoSessionModel(
                id: 'SURPRISE-${DateTime.now().millisecondsSinceEpoch}',
                inspectionId: 'ins_1',
                projectName: 'District Rehabilitation & Support Centre',
                callerName: 'Shri R. K. Sharma',
                callerDesignation: 'Joint Director, DoSJE',
                startedAt: DateTime.now(),
                durationSeconds: 184,
                status: VideoSessionStatus.completed,
              );
          return NgoVideoCompletedScreen(session: session);
        },
      ),

      // NGO Portal StatefulShellRoute
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) =>
            NgoScaffold(navigationShell: navigationShell),
        branches: [
          // Branch 0: Home
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/ngo/home',
                builder: (context, state) => const NgoHomeScreen(),
              ),
            ],
          ),
          // Branch 1: Projects
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/ngo/projects',
                builder: (context, state) => const NgoProjectsScreen(),
                routes: [
                  GoRoute(
                    path: 'detail/:id',
                    builder: (context, state) {
                      final id = state.pathParameters['id'] ?? '';
                      return NgoProjectDetailsScreen(projectId: id);
                    },
                  ),
                ],
              ),
            ],
          ),
          // Branch 2: Inspections
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/ngo/inspections',
                builder: (context, state) => const NgoInspectionsScreen(),
                routes: [
                  GoRoute(
                    path: 'detail/:id',
                    builder: (context, state) {
                      final id = state.pathParameters['id'] ?? '';
                      return NgoInspectionDetailScreen(inspectionId: id);
                    },
                  ),
                  GoRoute(
                    path: 'response/:id',
                    builder: (context, state) {
                      final id = state.pathParameters['id'] ?? '';
                      return NgoResponseFormScreen(inspectionId: id);
                    },
                  ),
                  GoRoute(
                    path: 'review/:id',
                    builder: (context, state) {
                      final id = state.pathParameters['id'] ?? '';
                      return NgoResponseReviewScreen(inspectionId: id);
                    },
                  ),
                  GoRoute(
                    path: 'receipt/:id',
                    builder: (context, state) {
                      final id = state.pathParameters['id'] ?? '';
                      return NgoSubmissionReceiptScreen(inspectionId: id);
                    },
                  ),
                  GoRoute(
                    path: 'outcome/:id',
                    builder: (context, state) {
                      final id = state.pathParameters['id'] ?? '';
                      return NgoOutcomeScreen(inspectionId: id);
                    },
                  ),
                  GoRoute(
                    path: 'follow-up/:id',
                    builder: (context, state) {
                      final id = state.pathParameters['id'] ?? '';
                      return NgoFollowUpScreen(inspectionId: id);
                    },
                  ),
                ],
              ),
            ],
          ),
          // Branch 3: Notifications
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/ngo/notifications',
                builder: (context, state) => const NgoNotificationsScreen(),
              ),
            ],
          ),
          // Branch 4: Profile
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/ngo/profile',
                builder: (context, state) => const NgoProfileScreen(),
                routes: [
                  GoRoute(
                    path: 'organization',
                    builder: (context, state) => const NgoOrganizationScreen(),
                  ),
                  GoRoute(
                    path: 'settings',
                    builder: (context, state) => const NgoSettingsScreen(),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),

      // Inspector Experience StatefulShellRoute
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) =>
            InspectorScaffold(navigationShell: navigationShell),
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/inspector/dashboard',
                builder: (context, state) => const InspectorDashboardScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/inspector/assignments',
                builder: (context, state) => const AssignedInspectionsScreen(),
                routes: [
                  GoRoute(
                    path: 'execute/:id',
                    builder: (context, state) {
                      final id = state.pathParameters['id'] ?? '';
                      return InspectionExecutionScreen(inspectionId: id);
                    },
                  ),
                ],
              ),
              GoRoute(
                path: '/inspector/reports/draft/:id',
                builder: (context, state) {
                  final id = state.pathParameters['id'] ?? '';
                  return InspectionReportDraftScreen(inspectionId: id);
                },
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/inspector/video',
                builder: (context, state) => const InspectorVideoScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/inspector/profile',
                builder: (context, state) => const InspectorProfileScreen(),
              ),
            ],
          ),
        ],
      ),

      // Official Experience StatefulShellRoute
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) =>
            OfficialScaffold(navigationShell: navigationShell),
        branches: [
          // Branch 0: Dashboard
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/official/dashboard',
                builder: (context, state) => const OfficialDashboardScreen(),
                routes: [
                  GoRoute(
                    path: 'scheduler',
                    builder: (context, state) =>
                        const ScheduleInspectionScreen(),
                  ),
                  GoRoute(
                    path: 'reports/dossier/:id',
                    builder: (context, state) {
                      final id = state.pathParameters['id'] ?? '';
                      return AuditDossierScreen(inspectionId: id);
                    },
                  ),
                ],
              ),
              GoRoute(
                path: '/official/scheduler',
                builder: (context, state) => const ScheduleInspectionScreen(),
              ),
            ],
          ),
          // Branch 1: ALL NGOs Directory
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/official/ngos',
                builder: (context, state) => const AllNgosScreen(),
                routes: [
                  GoRoute(
                    path: 'detail/:id',
                    builder: (context, state) {
                      final id = state.pathParameters['id'] ?? '';
                      return NgoDetailsScreen(ngoId: id);
                    },
                  ),
                  GoRoute(
                    path: 'review/:id',
                    builder: (context, state) {
                      final id = state.pathParameters['id'] ?? '';
                      return NgoRegistrationReviewScreen(ngoId: id);
                    },
                  ),
                ],
              ),
            ],
          ),
          // Branch 2: CCTV Monitor Wall
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/official/cctv',
                builder: (context, state) => const CctvMonitorScreen(),
              ),
            ],
          ),
          // Branch 3: AI Risk Analytics
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/official/analytics',
                builder: (context, state) => const AiRiskAnalyticsScreen(),
              ),
            ],
          ),
          // Branch 4: Official Profile & RBAC
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/official/profile',
                builder: (context, state) => const OfficialProfileScreen(),
              ),
            ],
          ),
        ],
      ),
    ],
  );
});

class _RiverpodRefreshListenable extends ChangeNotifier {
  _RiverpodRefreshListenable(Ref ref) {
    ref.listen(authNotifierProvider, (_, __) {
      notifyListeners();
    });
  }
}
