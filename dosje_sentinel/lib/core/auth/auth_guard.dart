import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../shared/models/ngo_registration_status.dart';
import 'auth_state.dart';
import 'role_guard.dart';

class AuthGuard {
  AuthGuard._();

  /// Top-level redirect function for GoRouter
  static String? redirect(
    BuildContext context,
    GoRouterState state,
    AuthState authState,
  ) {
    return resolveRedirect(state.matchedLocation, authState);
  }

  /// Pure routing decision engine testable without BuildContext/GoRouter state
  static String? resolveRedirect(String matchedLocation, AuthState authState) {
    final loc = matchedLocation;
    final isLoggingIn = loc == '/login' || loc == '/splash';
    final isRoot = loc == '/';

    // 1. Not authenticated -> direct to /login
    if (!authState.isAuthenticated) {
      return isLoggingIn ? null : '/login';
    }

    // 2. If authenticated and trying to access root or login/splash
    if (isLoggingIn || isRoot) {
      if (authState.isNgo) {
        // Direct to appropriate NGO onboarding or portal route
        return resolveNgoInitialRoute(authState.ngoRegistrationStatus);
      } else if (authState.isInspector) {
        return '/inspector/dashboard';
      } else if (authState.isOfficial) {
        return '/official/dashboard';
      }
    }

    // 3. Role boundary enforcement (NGO users cannot access /official or /inspector, etc.)
    if (!RoleGuard.canAccessRoute(authState, loc)) {
      if (authState.isNgo) {
        return resolveNgoInitialRoute(authState.ngoRegistrationStatus);
      } else if (authState.isInspector) {
        return '/inspector/dashboard';
      } else if (authState.isOfficial) {
        return '/official/dashboard';
      }
    }

    // 4. NGO-specific onboarding enforcement:
    // If NGO user has not approved registration, enforce onboarding routes
    if (authState.isNgo) {
      final status = authState.ngoRegistrationStatus;

      // Onboarding screens allowed during incomplete/submitted/underReview/correctionRequired
      if (status != NgoRegistrationStatus.approved) {
        final expectedRoute = resolveNgoInitialRoute(status);
        if (loc != expectedRoute && !loc.startsWith('/ngo/onboarding')) {
          return expectedRoute;
        }
      }
    }

    return null;
  }

  static String resolveNgoInitialRoute(NgoRegistrationStatus status) {
    switch (status) {
      case NgoRegistrationStatus.incomplete:
        return '/ngo/onboarding/register';
      case NgoRegistrationStatus.submitted:
        return '/ngo/onboarding/submitted';
      case NgoRegistrationStatus.underReview:
        return '/ngo/onboarding/under-review';
      case NgoRegistrationStatus.correctionRequired:
        return '/ngo/onboarding/correction';
      case NgoRegistrationStatus.approved:
        return '/ngo/home';
    }
  }
}
