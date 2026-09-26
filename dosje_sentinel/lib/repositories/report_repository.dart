import '../core/error/app_exception.dart';
import '../core/network/api_client.dart';
import '../core/network/api_endpoints.dart';
import '../shared/models/report_model.dart';

abstract class ReportRepository {
  Future<ReportModel> createReport({
    required int projectId,
    required int inspectionId,
    required ReportType reportType,
    ReportStatus status = ReportStatus.draft,
    required String title,
    String? summary,
    String? findings,
    String? recommendations,
    DateTime? generatedAt,
  });

  Future<ReportModel?> getReportById(dynamic reportId);

  Future<List<ReportModel>> getReportsForProject(
    dynamic projectId, {
    int limit = 50,
    int offset = 0,
  });

  Future<ReportModel> updateReport(
    dynamic reportId, {
    int? projectId,
    int? inspectionId,
    ReportType? reportType,
    ReportStatus? status,
    String? title,
    String? summary,
    String? findings,
    String? recommendations,
    DateTime? generatedAt,
  });

  Future<ReportAggregationModel> getReportAggregation(dynamic reportId);

  Future<ReportEvidenceReferenceModel> linkEvidenceToReport(
    dynamic reportId, {
    required String externalEvidenceId,
    required String evidenceType,
    String? source,
  });

  Future<List<ReportEvidenceReferenceModel>> getReportEvidence(
    dynamic reportId, {
    int limit = 50,
    int offset = 0,
  });

  Future<void> removeReportEvidence(dynamic reportId, dynamic referenceId);
}

class MockReportRepository implements ReportRepository {
  final List<ReportModel> _reports = [
    ReportModel(
      id: 1,
      projectId: 1,
      inspectionId: 1,
      reportType: ReportType.inspection,
      status: ReportStatus.finalStatus,
      title: 'Initial Field Audit Report - Project DL-001',
      summary: 'Biometric roster and nutrition distribution logs physically verified on-site.',
      findings: 'Living quarters compliant. Minor delay in ledger upload rectified.',
      recommendations: 'Continue monthly surprise audits.',
      generatedAt: DateTime.now().subtract(const Duration(days: 2)),
      createdAt: DateTime.now().subtract(const Duration(days: 2)),
      updatedAt: DateTime.now().subtract(const Duration(days: 1)),
    ),
  ];

  final Map<int, List<ReportEvidenceReferenceModel>> _evidenceRefs = {
    1: [
      ReportEvidenceReferenceModel(
        id: 1,
        reportId: 1,
        externalEvidenceId: '101',
        evidenceType: 'IMAGE',
        source: 'INSPECTION_EVIDENCE',
        createdAt: DateTime.now().subtract(const Duration(days: 2)),
      ),
    ],
  };

  @override
  Future<ReportModel> createReport({
    required int projectId,
    required int inspectionId,
    required ReportType reportType,
    ReportStatus status = ReportStatus.draft,
    required String title,
    String? summary,
    String? findings,
    String? recommendations,
    DateTime? generatedAt,
  }) async {
    await Future.delayed(const Duration(milliseconds: 50));
    final newReport = ReportModel(
      id: _reports.length + 1,
      projectId: projectId,
      inspectionId: inspectionId,
      reportType: reportType,
      status: status,
      title: title,
      summary: summary,
      findings: findings,
      recommendations: recommendations,
      generatedAt: generatedAt ?? DateTime.now(),
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );
    _reports.add(newReport);
    return newReport;
  }

  @override
  Future<ReportModel?> getReportById(dynamic reportId) async {
    await Future.delayed(const Duration(milliseconds: 50));
    final idInt = int.tryParse(reportId.toString()) ?? -1;
    final matches = _reports.where((r) => r.id == idInt).toList();
    return matches.isNotEmpty ? matches.first : null;
  }

  @override
  Future<List<ReportModel>> getReportsForProject(
    dynamic projectId, {
    int limit = 50,
    int offset = 0,
  }) async {
    await Future.delayed(const Duration(milliseconds: 50));
    final pId = int.tryParse(projectId.toString()) ?? -1;
    final filtered = _reports.where((r) => r.projectId == pId).toList();
    if (offset >= filtered.length) return [];
    final end = (offset + limit < filtered.length) ? offset + limit : filtered.length;
    return filtered.sublist(offset, end);
  }

  @override
  Future<ReportModel> updateReport(
    dynamic reportId, {
    int? projectId,
    int? inspectionId,
    ReportType? reportType,
    ReportStatus? status,
    String? title,
    String? summary,
    String? findings,
    String? recommendations,
    DateTime? generatedAt,
  }) async {
    await Future.delayed(const Duration(milliseconds: 50));
    final idInt = int.tryParse(reportId.toString()) ?? -1;
    final index = _reports.indexWhere((r) => r.id == idInt);
    if (index == -1) {
      throw NotFoundException('Report not found');
    }
    final existing = _reports[index];
    final updated = existing.copyWith(
      projectId: projectId,
      inspectionId: inspectionId,
      reportType: reportType,
      status: status,
      title: title,
      summary: summary,
      findings: findings,
      recommendations: recommendations,
      generatedAt: generatedAt,
      updatedAt: DateTime.now(),
    );
    _reports[index] = updated;
    return updated;
  }

  @override
  Future<ReportAggregationModel> getReportAggregation(dynamic reportId) async {
    await Future.delayed(const Duration(milliseconds: 50));
    final report = await getReportById(reportId);
    if (report == null) {
      throw NotFoundException('Report not found');
    }
    return ReportAggregationModel(
      reportId: report.id,
      projectId: report.projectId,
      projectName: 'District Rehabilitation & Support Centre',
      projectCode: 'DL-001',
      risk: const ReportAggregationRisk(score: 24, level: 'LOW'),
      attendance: const ReportAggregationAttendance(
        expectedWorkers: 45,
        detectedWorkers: 42,
        attendancePercentage: 93.33,
      ),
      cctv: const ReportAggregationCCTV(totalCameras: 3, activeCameras: 3),
      ai: const ReportAggregationAI(
        totalDetections: 12,
        latestActivity: 'Normal Activity',
        latestConfidence: 0.94,
      ),
      alerts: const ReportAggregationAlerts(totalAlerts: 1, activeAlerts: 0, resolvedAlerts: 1),
      inspections: const ReportAggregationInspections(totalInspections: 1, completed: 1),
      videoSessions: const ReportAggregationVideoSessions(totalSessions: 1, endedSessions: 1),
      evidence: ReportAggregationEvidence(
        totalReferences: _evidenceRefs[report.id]?.length ?? 0,
        projectEvidenceIds: _evidenceRefs[report.id]?.map((e) => e.externalEvidenceId).toList() ?? [],
      ),
    );
  }

  @override
  Future<ReportEvidenceReferenceModel> linkEvidenceToReport(
    dynamic reportId, {
    required String externalEvidenceId,
    required String evidenceType,
    String? source,
  }) async {
    await Future.delayed(const Duration(milliseconds: 50));
    final idInt = int.tryParse(reportId.toString()) ?? -1;
    final refs = _evidenceRefs.putIfAbsent(idInt, () => []);
    if (refs.any((r) => r.externalEvidenceId == externalEvidenceId)) {
      throw ConflictException('Evidence reference already exists for this report');
    }
    final newRef = ReportEvidenceReferenceModel(
      id: refs.length + 1,
      reportId: idInt,
      externalEvidenceId: externalEvidenceId,
      evidenceType: evidenceType,
      source: source,
      createdAt: DateTime.now(),
    );
    refs.add(newRef);
    return newRef;
  }

  @override
  Future<List<ReportEvidenceReferenceModel>> getReportEvidence(
    dynamic reportId, {
    int limit = 50,
    int offset = 0,
  }) async {
    await Future.delayed(const Duration(milliseconds: 50));
    final idInt = int.tryParse(reportId.toString()) ?? -1;
    final refs = _evidenceRefs[idInt] ?? [];
    if (offset >= refs.length) return [];
    final end = (offset + limit < refs.length) ? offset + limit : refs.length;
    return refs.sublist(offset, end);
  }

  @override
  Future<void> removeReportEvidence(dynamic reportId, dynamic referenceId) async {
    await Future.delayed(const Duration(milliseconds: 50));
    final rId = int.tryParse(reportId.toString()) ?? -1;
    final refId = int.tryParse(referenceId.toString()) ?? -1;
    final refs = _evidenceRefs[rId];
    if (refs != null) {
      refs.removeWhere((e) => e.id == refId);
    }
  }
}

class ApiReportRepository implements ReportRepository {
  final ApiClient apiClient;

  ApiReportRepository({required this.apiClient});

  @override
  Future<ReportModel> createReport({
    required int projectId,
    required int inspectionId,
    required ReportType reportType,
    ReportStatus status = ReportStatus.draft,
    required String title,
    String? summary,
    String? findings,
    String? recommendations,
    DateTime? generatedAt,
  }) async {
    final payload = <String, dynamic>{
      'project_id': projectId,
      'inspection_id': inspectionId,
      'report_type': reportType.value,
      'status': status.value,
      'title': title,
    };
    if (summary != null) payload['summary'] = summary;
    if (findings != null) payload['findings'] = findings;
    if (recommendations != null) payload['recommendations'] = recommendations;
    if (generatedAt != null) payload['generated_at'] = generatedAt.toIso8601String();

    final response = await apiClient.post(
      ApiEndpoints.reports,
      data: payload,
    );
    return ReportModel.fromJson(response.data as Map<String, dynamic>);
  }

  @override
  Future<ReportModel?> getReportById(dynamic reportId) async {
    try {
      final response = await apiClient.get(ApiEndpoints.reportById(reportId));
      return ReportModel.fromJson(response.data as Map<String, dynamic>);
    } on NotFoundException {
      return null;
    }
  }

  @override
  Future<List<ReportModel>> getReportsForProject(
    dynamic projectId, {
    int limit = 50,
    int offset = 0,
  }) async {
    try {
      final response = await apiClient.get(
        ApiEndpoints.reportsByProject(projectId),
        queryParameters: {'limit': limit, 'offset': offset},
      );
      final list = response.data as List<dynamic>? ?? [];
      return list.map((e) => ReportModel.fromJson(e as Map<String, dynamic>)).toList();
    } on NotFoundException {
      return [];
    }
  }

  @override
  Future<ReportModel> updateReport(
    dynamic reportId, {
    int? projectId,
    int? inspectionId,
    ReportType? reportType,
    ReportStatus? status,
    String? title,
    String? summary,
    String? findings,
    String? recommendations,
    DateTime? generatedAt,
  }) async {
    final payload = <String, dynamic>{};
    if (projectId != null) payload['project_id'] = projectId;
    if (inspectionId != null) payload['inspection_id'] = inspectionId;
    if (reportType != null) payload['report_type'] = reportType.value;
    if (status != null) payload['status'] = status.value;
    if (title != null) payload['title'] = title;
    if (summary != null) payload['summary'] = summary;
    if (findings != null) payload['findings'] = findings;
    if (recommendations != null) payload['recommendations'] = recommendations;
    if (generatedAt != null) payload['generated_at'] = generatedAt.toIso8601String();

    final response = await apiClient.put(
      ApiEndpoints.reportById(reportId),
      data: payload,
    );
    return ReportModel.fromJson(response.data as Map<String, dynamic>);
  }

  @override
  Future<ReportAggregationModel> getReportAggregation(dynamic reportId) async {
    final response = await apiClient.get(ApiEndpoints.reportAggregation(reportId));
    return ReportAggregationModel.fromJson(response.data as Map<String, dynamic>);
  }

  @override
  Future<ReportEvidenceReferenceModel> linkEvidenceToReport(
    dynamic reportId, {
    required String externalEvidenceId,
    required String evidenceType,
    String? source,
  }) async {
    final payload = <String, dynamic>{
      'external_evidence_id': externalEvidenceId,
      'evidence_type': evidenceType,
    };
    if (source != null) payload['source'] = source;

    final response = await apiClient.post(
      ApiEndpoints.reportEvidence(reportId),
      data: payload,
    );
    return ReportEvidenceReferenceModel.fromJson(response.data as Map<String, dynamic>);
  }

  @override
  Future<List<ReportEvidenceReferenceModel>> getReportEvidence(
    dynamic reportId, {
    int limit = 50,
    int offset = 0,
  }) async {
    try {
      final response = await apiClient.get(
        ApiEndpoints.reportEvidence(reportId),
        queryParameters: {'limit': limit, 'offset': offset},
      );
      final list = response.data as List<dynamic>? ?? [];
      return list
          .map((e) => ReportEvidenceReferenceModel.fromJson(e as Map<String, dynamic>))
          .toList();
    } on NotFoundException {
      return [];
    }
  }

  @override
  Future<void> removeReportEvidence(dynamic reportId, dynamic referenceId) async {
    await apiClient.delete(ApiEndpoints.reportEvidenceById(reportId, referenceId));
  }
}
