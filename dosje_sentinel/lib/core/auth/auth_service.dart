import '../../shared/models/user_model.dart';
import '../../shared/models/user_role.dart';
import '../../shared/models/permission.dart';
import '../../shared/models/ngo_registration_status.dart';
import '../network/api_client.dart';
import 'auth_state.dart';

abstract class AuthService {
  Future<AuthState> signInWithClerk({
    required String email,
    required String password,
    NgoRegistrationStatus? status,
    UserRole? roleHint,
  });
  Future<AuthState> signInStaff({
    required String email,
    required String password,
  });
  Future<AuthState> resolveAuthorization(
    String token, {
    String? clerkUserId,
    String? email,
    NgoRegistrationStatus? status,
    UserRole? roleHint,
  });
  Future<AuthState> checkNgoRegistrationStatus(AuthState currentState);
  Future<AuthState> resolveStaffMe(String token);
  Future<AuthState> signOut();
}

class DefaultAuthService implements AuthService {
  final ApiClient apiClient;

  DefaultAuthService({required this.apiClient});

  @override
  Future<AuthState> signInWithClerk({
    required String email,
    required String password,
    NgoRegistrationStatus? status,
    UserRole? roleHint,
  }) async {
    // 1. Clerk Authentication & Session Generation
    // In production, this interfaces with Clerk SDK/Web SSO
    await Future.delayed(const Duration(milliseconds: 500));

    final sanitized = email.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '_');
    final clerkUserId = 'user_clerk_$sanitized';
    final clerkToken = 'clerk_session_${DateTime.now().millisecondsSinceEpoch}';
    apiClient.setAuthToken(clerkToken);

    // 2. FastAPI Authorization / Identity Handshake (GET /api/v1/auth/me)
    return await resolveAuthorization(
      clerkToken,
      clerkUserId: clerkUserId,
      email: email,
      status: status,
      roleHint: roleHint,
    );
  }

  @override
  Future<AuthState> resolveAuthorization(
    String token, {
    String? clerkUserId,
    String? email,
    NgoRegistrationStatus? status,
    UserRole? roleHint,
  }) async {
    final userEmail = email ?? 'user@dosje-sentinel.gov.in';
    final effectiveClerkId =
        clerkUserId ??
        'user_clerk_${userEmail.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '_')}';

    // In production:
    // final response = await apiClient.get(ApiEndpoints.me);
    // and parse response: role, permissions, account_status, registration_status.
    //
    // For reliable local and test execution, simulate the FastAPI RBAC resolution:
    final isInspector =
        roleHint == UserRole.inspector ||
        userEmail.contains('inspector') ||
        userEmail.contains('pmu');

    final isOfficial =
        roleHint == UserRole.official ||
        userEmail.contains('official') ||
        userEmail.contains('dosje.gov.in') ||
        userEmail.contains('admin');

    if (isInspector) {
      final inspectorUser = UserModel(
        id: 'inspector_01',
        clerkUserId: effectiveClerkId,
        email: userEmail,
        fullName: 'Shri V. K. Saxena',
        designation: 'Lead Inspection Officer, PMU',
        role: UserRole.inspector,
        permissions: const [
          Permission.viewAssignedProjects,
          Permission.executeInspection,
          Permission.submitAuditFindings,
          Permission.joinVideoInspection,
          Permission.uploadEvidence,
          Permission.reviewEvidence,
        ],
        authorizedProjectIds: const ['DSJ-AG-1042', 'DSJ-VR-2089'],
        avatarUrl: null,
      );

      return AuthState(
        status: AuthStatus.authenticatedWithContext,
        user: inspectorUser,
        token: token,
        clerkUserId: effectiveClerkId,
        accountStatus: 'active',
        ngoRegistrationStatus: NgoRegistrationStatus.approved,
      );
    }

    if (isOfficial) {
      final officialUser = UserModel(
        id: 'official_01',
        clerkUserId: effectiveClerkId,
        email: userEmail,
        fullName: 'Dr. Anand Verma, IAS',
        designation: 'Joint Secretary, DoSJE',
        role: UserRole.official,
        permissions: const [
          Permission.viewAllProjects,
          Permission.viewAssignedProjects,
          Permission.viewCctvStreams,
          Permission.viewAiRiskAnalytics,
          Permission.scheduleInspection,
          Permission.assignInspector,
          Permission.joinVideoInspection,
          Permission.reviewEvidence,
          Permission.viewAllNgos,
          Permission.viewNgoDetails,
          Permission.reviewNgoRegistration,
          Permission.approveNgoRegistration,
          Permission.canApproveAudit,
        ],
        authorizedProjectIds: const [],
        avatarUrl: null,
      );

      return AuthState(
        status: AuthStatus.authenticatedWithContext,
        user: officialUser,
        token: token,
        clerkUserId: effectiveClerkId,
        accountStatus: 'active',
        ngoRegistrationStatus: NgoRegistrationStatus.approved,
      );
    }

    // Role: NGO Representative
    final NgoRegistrationStatus resolvedStatus;
    if (status != null) {
      resolvedStatus = status;
    } else if (userEmail.contains('new') ||
        userEmail.contains('register') ||
        userEmail.contains('incomplete')) {
      resolvedStatus = NgoRegistrationStatus.incomplete;
    } else if (userEmail.contains('submitted')) {
      resolvedStatus = NgoRegistrationStatus.submitted;
    } else if (userEmail.contains('review')) {
      resolvedStatus = NgoRegistrationStatus.underReview;
    } else if (userEmail.contains('correction')) {
      resolvedStatus = NgoRegistrationStatus.correctionRequired;
    } else {
      resolvedStatus = NgoRegistrationStatus.approved;
    }

    final isNewOrIncomplete =
        resolvedStatus == NgoRegistrationStatus.incomplete;

    final ngoUser = UserModel(
      id: isNewOrIncomplete ? 'ngo_user_new' : 'ngo_user_101',
      clerkUserId: effectiveClerkId,
      email: userEmail,
      fullName: isNewOrIncomplete ? 'Shri Arvind Verma' : 'Shri Rajesh Sharma',
      designation: 'Project Director',
      role: UserRole.ngoRepresentative,
      permissions: const [
        Permission.viewAssignedProjects,
        Permission.uploadEvidence,
        Permission.joinVideoInspection,
      ],
      organizationId: isNewOrIncomplete ? 'org_new_99' : 'org_8821',
      organizationName: isNewOrIncomplete
          ? 'Gramin Vikas Sansthan'
          : 'Samarpan Welfare Society',
      authorizedProjectIds: isNewOrIncomplete
          ? const []
          : const ['DSJ-AG-1042', 'DSJ-VR-2089', 'DSJ-LK-3014'],
      avatarUrl: 'assets/images/representative_avatar.png',
    );

    return AuthState(
      status: AuthStatus.authenticatedWithContext,
      user: ngoUser,
      token: token,
      clerkUserId: effectiveClerkId,
      accountStatus: 'active',
      ngoRegistrationStatus: resolvedStatus,
    );
  }

  @override
  Future<AuthState> signInStaff({
    required String email,
    required String password,
  }) async {
    // Delegated to unified Clerk authentication pipeline
    return signInWithClerk(email: email, password: password);
  }

  @override
  Future<AuthState> resolveStaffMe(String token) async {
    return resolveAuthorization(token);
  }

  @override
  Future<AuthState> checkNgoRegistrationStatus(AuthState currentState) async {
    return currentState;
  }

  @override
  Future<AuthState> signOut() async {
    apiClient.setAuthToken(null);
    return const AuthState(status: AuthStatus.unauthenticated);
  }
}
