/// Fine-grained permission set enforced authoritatively by FastAPI
enum Permission {
  viewAssignedProjects,
  viewAllProjects,
  viewCctvStreams,
  viewAiRiskAnalytics,
  scheduleInspection,
  assignInspector,
  executeInspection,
  submitAuditFindings,
  joinVideoInspection,
  uploadEvidence,
  reviewEvidence,
  viewAllNgos,
  viewNgoDetails,
  reviewNgoRegistration,
  approveNgoRegistration,
  canApproveAudit;

  static Permission? fromString(String name) {
    for (final perm in Permission.values) {
      if (perm.name == name) return perm;
    }
    return null;
  }
}

typedef AppPermission = Permission;
