import 'user_role.dart';
import 'permission.dart';

class UserModel {
  final String id;
  final String? clerkUserId;
  final String email;
  final String fullName;
  final String? designation;
  final UserRole role;
  final List<Permission> permissions;
  final String? organizationId;
  final String? organizationName;
  final List<String> authorizedProjectIds;
  final String? avatarUrl;
  final String accountStatus;

  const UserModel({
    required this.id,
    this.clerkUserId,
    required this.email,
    required this.fullName,
    this.designation,
    required this.role,
    this.permissions = const [],
    this.organizationId,
    this.organizationName,
    this.authorizedProjectIds = const [],
    this.avatarUrl,
    this.accountStatus = 'active',
  });

  bool hasPermission(Permission permission) => permissions.contains(permission);

  String get name => fullName;

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'clerk_user_id': clerkUserId,
      'email': email,
      'fullName': fullName,
      'designation': designation,
      'role': role.name,
      'permissions': permissions.map((p) => p.name).toList(),
      'organizationId': organizationId,
      'organizationName': organizationName,
      'authorizedProjectIds': authorizedProjectIds,
      'avatarUrl': avatarUrl,
      'account_status': accountStatus,
    };
  }

  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      id: json['id'] as String? ?? '',
      clerkUserId:
          json['clerk_user_id'] as String? ?? json['clerkUserId'] as String?,
      email: json['email'] as String? ?? '',
      fullName: json['fullName'] as String? ?? '',
      designation: json['designation'] as String?,
      role: UserRole.fromString(json['role'] as String? ?? 'ngoRepresentative'),
      permissions:
          (json['permissions'] as List<dynamic>?)
              ?.map((p) => Permission.fromString(p.toString()))
              .whereType<Permission>()
              .toList() ??
          [],
      organizationId: json['organizationId'] as String?,
      organizationName: json['organizationName'] as String?,
      authorizedProjectIds:
          (json['authorizedProjectIds'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          [],
      avatarUrl: json['avatarUrl'] as String?,
    );
  }
}
