/// The primary stakeholder roles in the DoSJE Sentinel system
enum UserRole {
  ngoRepresentative,
  inspector,
  official;

  String get displayName {
    switch (this) {
      case UserRole.ngoRepresentative:
        return 'NGO Representative';
      case UserRole.inspector:
        return 'PMU / Field Inspector';
      case UserRole.official:
        return 'Department Official';
    }
  }

  static UserRole fromString(String role) {
    switch (role.toLowerCase()) {
      case 'ngo':
      case 'ngo_representative':
      case 'ngorepresentative':
        return UserRole.ngoRepresentative;
      case 'inspector':
      case 'pmu_inspector':
      case 'pmu':
        return UserRole.inspector;
      case 'official':
      case 'department_official':
        return UserRole.official;
      default:
        return UserRole.ngoRepresentative;
    }
  }
}
