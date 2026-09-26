import '../../shared/models/permission.dart';
import 'auth_state.dart';

class PermissionGuard {
  PermissionGuard._();

  static bool check(AuthState authState, Permission requiredPermission) {
    if (!authState.isAuthenticated) return false;
    return authState.hasPermission(requiredPermission);
  }
}
