import 'auth_state.dart';

class RoleGuard {
  RoleGuard._();

  static bool canAccessRoute(AuthState authState, String routeLocation) {
    if (routeLocation.startsWith('/ngo')) {
      return authState.isNgo;
    }
    if (routeLocation.startsWith('/inspector')) {
      return authState.isInspector;
    }
    if (routeLocation.startsWith('/official')) {
      return authState.isOfficial;
    }
    return true;
  }
}
