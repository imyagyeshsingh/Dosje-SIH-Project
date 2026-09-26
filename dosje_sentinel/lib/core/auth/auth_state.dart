import '../../shared/models/user_model.dart';
import '../../shared/models/user_role.dart';
import '../../shared/models/permission.dart';
import '../../shared/models/ngo_registration_status.dart';

enum AuthStatus {
  initial,
  unauthenticated,
  authenticating,
  authenticated,
  resolvingAuthorization,
  authenticatedWithContext,
  error,

  // Legacy status support
  authenticatedNgo,
  authenticatedStaff,
}

class AuthState {
  final AuthStatus status;
  final UserModel? user;
  final String? token;
  final String? clerkUserId;
  final String accountStatus;
  // NGO-specific onboarding state
  final NgoRegistrationStatus ngoRegistrationStatus;
  final String? errorMessage;

  const AuthState({
    this.status = AuthStatus.initial,
    this.user,
    this.token,
    this.clerkUserId,
    this.accountStatus = 'active',
    this.ngoRegistrationStatus = NgoRegistrationStatus.incomplete,
    this.errorMessage,
  });

  bool get isAuthenticated =>
      status == AuthStatus.authenticatedWithContext ||
      status == AuthStatus.authenticated ||
      status == AuthStatus.authenticatedNgo ||
      status == AuthStatus.authenticatedStaff;

  bool get isResolvingAuthorization =>
      status == AuthStatus.resolvingAuthorization;

  bool get isAuthenticating => status == AuthStatus.authenticating;

  bool get isNgo =>
      user?.role == UserRole.ngoRepresentative ||
      status == AuthStatus.authenticatedNgo;

  bool get isInspector => user?.role == UserRole.inspector;

  bool get isOfficial => user?.role == UserRole.official;

  bool hasPermission(Permission permission) {
    if (user == null) return false;
    return user!.hasPermission(permission);
  }

  AuthState copyWith({
    AuthStatus? status,
    UserModel? user,
    String? token,
    String? clerkUserId,
    String? accountStatus,
    NgoRegistrationStatus? ngoRegistrationStatus,
    String? errorMessage,
  }) {
    return AuthState(
      status: status ?? this.status,
      user: user ?? this.user,
      token: token ?? this.token,
      clerkUserId: clerkUserId ?? this.clerkUserId,
      accountStatus: accountStatus ?? this.accountStatus,
      ngoRegistrationStatus:
          ngoRegistrationStatus ?? this.ngoRegistrationStatus,
      errorMessage: errorMessage,
    );
  }
}
