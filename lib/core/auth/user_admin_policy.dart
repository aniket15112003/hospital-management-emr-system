import 'permissions.dart';

/// Client-side mirror of the authorisation policy enforced by the
/// `adminCreateUser`, `adminSetUserRole` and `adminSetUserStatus` Cloud
/// Functions. Used to disable UI controls and by the demo backend.
/// The backend remains the authority.
///
/// Returns null when allowed, otherwise the reason it is denied.
String? checkUserAdminAction({
  required AppRole callerRole,
  required String callerUid,
  required PermissionMatrix callerPermissions,
  required String action,
  String? targetUid,
  AppRole? targetCurrentRole,
  AppRole? newRole,
}) {
  final isSuper = callerRole == AppRole.superAdmin;
  if (!isSuper &&
      !(callerPermissions[Modules.users]?.contains(action) ?? false)) {
    return 'You do not have permission to $action users.';
  }
  if (targetUid != null && targetUid == callerUid) {
    return 'You cannot change your own account role or status.';
  }
  if (!isSuper && targetCurrentRole != null && targetCurrentRole.isPrivileged) {
    return 'Only a Super Admin can modify ${targetCurrentRole.label} accounts.';
  }
  if (!isSuper && newRole != null && newRole.isPrivileged) {
    return 'Only a Super Admin can assign the ${newRole.label} role.';
  }
  return null;
}
