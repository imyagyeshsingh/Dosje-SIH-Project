import '../core/error/app_exception.dart';
import '../core/network/api_client.dart';
import '../core/network/api_endpoints.dart';
import '../shared/models/inspection_model.dart';
import 'project_repository.dart';

abstract class InspectionRepository {
  Future<List<InspectionModel>> getInspections({dynamic projectId});
  Future<List<InspectionModel>> getInspectionsForProject(dynamic projectId, {int limit = 50, int offset = 0});
  Future<InspectionModel?> getInspectionById(dynamic id);
  Future<InspectionModel> createInspection({
    required dynamic projectId,
    required String inspectionType,
    String status = 'PENDING',
    int? alertId,
    String? officerName,
    String? officerId,
    String? reason,
    DateTime? scheduledAt,
  });
  Future<InspectionModel> createRandomInspection();
  Future<InspectionModel> createInspectionFromAlert(int alertId);
  Future<InspectionModel> updateInspectionStatus(dynamic inspectionId, String status);
  Future<InspectionModel> updateInspection(dynamic inspectionId, Map<String, dynamic> updates);
  Future<InspectionModel> assignInspector(
    dynamic inspectionId, {
    required String inspectorId,
    String? inspectorName,
    String assignmentStatus = 'ASSIGNED',
  });
  Future<InspectionModel> assignRandomInspector(dynamic inspectionId);
  Future<InspectionAssignmentModel> getInspectionAssignment(dynamic inspectionId);
  Future<InspectionLocationModel> submitInspectionLocation(
    dynamic inspectionId, {
    required double latitude,
    required double longitude,
    double? accuracy,
    DateTime? capturedAt,
  });
  Future<InspectionLocationModel> getInspectionLocation(dynamic inspectionId);
  Future<List<InspectorModel>> getInspectors({bool? isActive, int limit = 50, int offset = 0});
  Future<InspectorModel> createInspector({
    required String inspectorId,
    required String inspectorName,
    bool isActive = true,
  });

  // Legacy compatibility
  Future<void> submitInspectionResponse({
    required String inspectionId,
    required String responseText,
    required List<String> evidenceIds,
  });
  Future<void> submitFollowUp({
    required String followUpId,
    required String responseText,
    required List<String> evidenceIds,
  });
}

class MockInspectionRepository implements InspectionRepository {
  final List<InspectionModel> _inspections = [
    InspectionModel(
      id: '1',
      projectId: '76',
      code: 'INS-2026-00482',
      projectName: 'District Rehabilitation & Support Centre',
      schemeCode: 'DSJ-AG-1042',
      inspectionType: 'SCHEDULED',
      type: 'SURPRISE EVALUATION',
      status: 'IN_PROGRESS',
      scheduledAt: DateTime(2026, 9, 23, 10, 42),
      officerName: 'Shri V. K. Saxena',
      officerId: 'INS-001',
      assignmentStatus: 'ASSIGNED',
      assignedAt: DateTime(2026, 9, 23, 8, 0),
      locationVerified: true,
      distanceFromProject: 35.0,
      nodalOfficerName: 'Shri V. K. Saxena',
      nodalOfficerDesignation: 'Deputy Director, DoSJE',
      syncChannel: 'Secure Field Handshake',
      checklistItems: const [
        InspectionChecklistItem(
          id: 'chk_1',
          title: 'Staff Attendance Register Verification',
          description: 'Physical inspection and punch verification of on-duty personnel.',
          isCompleted: false,
        ),
        InspectionChecklistItem(
          id: 'chk_2',
          title: 'Kitchen & Meal Quality Logbook',
          description: 'Pantry sanitation and nutritional ration storage audit.',
          isCompleted: false,
        ),
        InspectionChecklistItem(
          id: 'chk_3',
          title: 'Supervisor Observation Photo',
          description: 'On-site center supervisor photographic evidence.',
          isCompleted: false,
          isOptional: true,
        ),
      ],
      requests: [
        InformationRequest(
          id: 'req_1',
          title: 'Staff Attendance & Meal Log',
          description: 'Please provide the current staff attendance information and meal logs.',
          deadline: DateTime.now().add(const Duration(hours: 2)),
          isMandatory: true,
          status: 'PENDING',
        ),
      ],
      outcome: 'Provisionally Satisfactory',
      outcomeNotes: 'Facility operational during surprise evaluation.',
      requiredFollowUp: 'Submit final certified attendance roster.',
      followUpDeadline: DateTime.now().add(const Duration(days: 3)),
      followUpStatus: 'PENDING',
    ),
    InspectionModel(
      id: '2',
      projectId: '20',
      code: 'AUD-2026-00192',
      projectName: 'Integrated Child Development & Daycare Centre',
      schemeCode: 'DSJ-VR-2089',
      inspectionType: 'MANUAL',
      type: 'ANNUAL COMPLIANCE AUDIT',
      status: 'SCHEDULED',
      scheduledAt: DateTime(2026, 10, 5, 10, 0),
      officerName: 'Inspector Jane',
      officerId: 'INS-002',
      assignmentStatus: 'ASSIGNED',
      nodalOfficerName: 'State Social Welfare Directorate Squad',
      nodalOfficerDesignation: 'Inspection Team',
    ),
    InspectionModel(
      id: '3',
      projectId: '76',
      code: 'INS-2026-00419',
      projectName: 'District Rehabilitation & Support Centre',
      schemeCode: 'DSJ-AG-1042',
      inspectionType: 'RANDOM',
      type: 'ROUTINE EVALUATION',
      status: 'COMPLETED',
      scheduledAt: DateTime(2026, 8, 15, 11, 0),
      officerName: 'Shri V. K. Saxena',
      officerId: 'INS-001',
      assignmentStatus: 'ASSIGNED',
      result: 'Approved',
      findings: 'Quarterly compliance standards successfully met across all departments.',
    ),
  ];

  final List<InspectorModel> _inspectors = [
    InspectorModel(
      id: 1,
      inspectorId: 'INS-001',
      inspectorName: 'Shri V. K. Saxena',
      isActive: true,
    ),
    InspectorModel(
      id: 2,
      inspectorId: 'INS-002',
      inspectorName: 'Inspector Jane',
      isActive: true,
    ),
  ];

  @override
  Future<List<InspectionModel>> getInspections({dynamic projectId}) async {
    await Future.delayed(const Duration(milliseconds: 100));
    if (projectId != null) {
      final pidStr = projectId.toString();
      return _inspections.where((i) => i.projectId == pidStr).toList();
    }
    return List.unmodifiable(_inspections);
  }

  @override
  Future<List<InspectionModel>> getInspectionsForProject(
    dynamic projectId, {
    int limit = 50,
    int offset = 0,
  }) async {
    await Future.delayed(const Duration(milliseconds: 100));
    final pidStr = projectId.toString();
    return _inspections.where((i) => i.projectId == pidStr).skip(offset).take(limit).toList();
  }

  @override
  Future<InspectionModel?> getInspectionById(dynamic id) async {
    await Future.delayed(const Duration(milliseconds: 100));
    final idStr = id.toString();
    try {
      return _inspections.firstWhere((i) => i.id == idStr || i.code == idStr);
    } catch (_) {
      return null;
    }
  }

  @override
  Future<InspectionModel> createInspection({
    required dynamic projectId,
    required String inspectionType,
    String status = 'PENDING',
    int? alertId,
    String? officerName,
    String? officerId,
    String? reason,
    DateTime? scheduledAt,
  }) async {
    await Future.delayed(const Duration(milliseconds: 100));
    final newId = (_inspections.length + 1).toString();
    final inspection = InspectionModel(
      id: newId,
      projectId: projectId.toString(),
      inspectionType: inspectionType,
      status: status,
      alertId: alertId,
      officerName: officerName,
      officerId: officerId,
      reason: reason,
      scheduledAt: scheduledAt,
      assignmentStatus: officerId != null ? 'ASSIGNED' : 'UNASSIGNED',
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );
    _inspections.add(inspection);
    return inspection;
  }

  @override
  Future<InspectionModel> createRandomInspection() async {
    await Future.delayed(const Duration(milliseconds: 100));
    return createInspection(
      projectId: '76',
      inspectionType: 'RANDOM',
      status: 'PENDING',
    );
  }

  @override
  Future<InspectionModel> createInspectionFromAlert(int alertId) async {
    await Future.delayed(const Duration(milliseconds: 100));
    return createInspection(
      projectId: '76',
      inspectionType: 'ALERT_TRIGGERED',
      alertId: alertId,
      reason: 'Inspection triggered by alert #$alertId',
    );
  }

  @override
  Future<InspectionModel> updateInspectionStatus(dynamic inspectionId, String status) async {
    await Future.delayed(const Duration(milliseconds: 100));
    final inspection = await getInspectionById(inspectionId);
    if (inspection == null) throw NotFoundException('Inspection not found');
    final updated = inspection.copyWith(
      status: status,
      startedAt: status == 'IN_PROGRESS' ? (inspection.startedAt ?? DateTime.now()) : inspection.startedAt,
      completedAt: status == 'COMPLETED' ? (inspection.completedAt ?? DateTime.now()) : inspection.completedAt,
      updatedAt: DateTime.now(),
    );
    final idx = _inspections.indexWhere((i) => i.id == inspection.id);
    if (idx != -1) _inspections[idx] = updated;
    return updated;
  }

  @override
  Future<InspectionModel> updateInspection(dynamic inspectionId, Map<String, dynamic> updates) async {
    await Future.delayed(const Duration(milliseconds: 100));
    final inspection = await getInspectionById(inspectionId);
    if (inspection == null) throw NotFoundException('Inspection not found');
    final updated = inspection.copyWith(
      status: updates['status'] as String? ?? inspection.status,
      reason: updates['reason'] as String? ?? inspection.reason,
      findings: updates['findings'] as String? ?? inspection.findings,
      result: updates['result'] as String? ?? inspection.result,
      officerId: updates['officer_id'] as String? ?? inspection.officerId,
      officerName: updates['officer_name'] as String? ?? inspection.officerName,
      updatedAt: DateTime.now(),
    );
    final idx = _inspections.indexWhere((i) => i.id == inspection.id);
    if (idx != -1) _inspections[idx] = updated;
    return updated;
  }

  @override
  Future<InspectionModel> assignInspector(
    dynamic inspectionId, {
    required String inspectorId,
    String? inspectorName,
    String assignmentStatus = 'ASSIGNED',
  }) async {
    await Future.delayed(const Duration(milliseconds: 100));
    final inspection = await getInspectionById(inspectionId);
    if (inspection == null) throw NotFoundException('Inspection not found');
    final updated = inspection.copyWith(
      officerId: inspectorId,
      officerName: inspectorName ?? inspection.officerName,
      assignmentStatus: assignmentStatus,
      assignedAt: assignmentStatus == 'ASSIGNED' ? DateTime.now() : null,
      updatedAt: DateTime.now(),
    );
    final idx = _inspections.indexWhere((i) => i.id == inspection.id);
    if (idx != -1) _inspections[idx] = updated;
    return updated;
  }

  @override
  Future<InspectionModel> assignRandomInspector(dynamic inspectionId) async {
    await Future.delayed(const Duration(milliseconds: 100));
    final activeInspectors = _inspectors.where((i) => i.isActive).toList();
    if (activeInspectors.isEmpty) {
      throw NotFoundException('No active inspectors available');
    }
    final selected = activeInspectors.first;
    return assignInspector(
      inspectionId,
      inspectorId: selected.inspectorId,
      inspectorName: selected.inspectorName,
    );
  }

  @override
  Future<InspectionAssignmentModel> getInspectionAssignment(dynamic inspectionId) async {
    await Future.delayed(const Duration(milliseconds: 100));
    final inspection = await getInspectionById(inspectionId);
    if (inspection == null) throw NotFoundException('Inspection not found');
    return InspectionAssignmentModel(
      inspectionId: inspection.idInt,
      inspectorId: inspection.officerId,
      inspectorName: inspection.officerName,
      assignedAt: inspection.assignedAt,
      assignmentStatus: inspection.assignmentStatus,
    );
  }

  @override
  Future<InspectionLocationModel> submitInspectionLocation(
    dynamic inspectionId, {
    required double latitude,
    required double longitude,
    double? accuracy,
    DateTime? capturedAt,
  }) async {
    await Future.delayed(const Duration(milliseconds: 100));
    final inspection = await getInspectionById(inspectionId);
    if (inspection == null) throw NotFoundException('Inspection not found');
    final updated = inspection.copyWith(
      inspectionLatitude: latitude,
      inspectionLongitude: longitude,
      locationAccuracy: accuracy,
      locationCapturedAt: capturedAt ?? DateTime.now(),
      locationVerified: true,
      distanceFromProject: 25.0,
      updatedAt: DateTime.now(),
    );
    final idx = _inspections.indexWhere((i) => i.id == inspection.id);
    if (idx != -1) _inspections[idx] = updated;
    return InspectionLocationModel(
      inspectionId: inspection.idInt,
      projectId: inspection.projectIdInt,
      inspectionLatitude: latitude,
      inspectionLongitude: longitude,
      locationAccuracy: accuracy,
      locationCapturedAt: capturedAt ?? DateTime.now(),
      locationVerified: true,
      distanceFromProject: 25.0,
    );
  }

  @override
  Future<InspectionLocationModel> getInspectionLocation(dynamic inspectionId) async {
    await Future.delayed(const Duration(milliseconds: 100));
    final inspection = await getInspectionById(inspectionId);
    if (inspection == null) throw NotFoundException('Inspection not found');
    return InspectionLocationModel(
      inspectionId: inspection.idInt,
      projectId: inspection.projectIdInt,
      inspectionLatitude: inspection.inspectionLatitude,
      inspectionLongitude: inspection.inspectionLongitude,
      locationAccuracy: inspection.locationAccuracy,
      locationCapturedAt: inspection.locationCapturedAt,
      locationVerified: inspection.locationVerified,
      distanceFromProject: inspection.distanceFromProject,
    );
  }

  @override
  Future<List<InspectorModel>> getInspectors({bool? isActive, int limit = 50, int offset = 0}) async {
    await Future.delayed(const Duration(milliseconds: 100));
    var list = _inspectors;
    if (isActive != null) {
      list = list.where((i) => i.isActive == isActive).toList();
    }
    return list.skip(offset).take(limit).toList();
  }

  @override
  Future<InspectorModel> createInspector({
    required String inspectorId,
    required String inspectorName,
    bool isActive = true,
  }) async {
    await Future.delayed(const Duration(milliseconds: 100));
    final inspector = InspectorModel(
      id: _inspectors.length + 1,
      inspectorId: inspectorId,
      inspectorName: inspectorName,
      isActive: isActive,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );
    _inspectors.add(inspector);
    return inspector;
  }

  @override
  Future<void> submitInspectionResponse({
    required String inspectionId,
    required String responseText,
    required List<String> evidenceIds,
  }) async {
    await Future.delayed(const Duration(milliseconds: 100));
  }

  @override
  Future<void> submitFollowUp({
    required String followUpId,
    required String responseText,
    required List<String> evidenceIds,
  }) async {
    await Future.delayed(const Duration(milliseconds: 100));
  }
}

class ApiInspectionRepository implements InspectionRepository {
  final ApiClient apiClient;
  final ProjectRepository? projectRepository;

  ApiInspectionRepository({
    required this.apiClient,
    this.projectRepository,
  });

  Future<int> _resolveProjectId(dynamic rawId) async {
    if (rawId is int) return rawId;
    final parsed = int.tryParse(rawId.toString());
    if (parsed != null) return parsed;

    if (projectRepository != null) {
      try {
        final project = await projectRepository!.getProjectById(rawId.toString());
        if (project != null) {
          final idNum = int.tryParse(project.id);
          if (idNum != null) return idNum;
        }
      } catch (_) {}
    }
    return 0;
  }

  int _resolveInspectionId(dynamic rawId) {
    if (rawId is int) return rawId;
    final idStr = rawId.toString();
    final parsed = int.tryParse(idStr);
    if (parsed != null) return parsed;
    final digits = RegExp(r'\d+').allMatches(idStr).map((m) => m.group(0)).join();
    final parsedDigits = int.tryParse(digits);
    if (parsedDigits != null && parsedDigits > 0) return parsedDigits;
    return 0;
  }

  @override
  Future<List<InspectionModel>> getInspections({dynamic projectId}) async {
    if (projectId != null) {
      return getInspectionsForProject(projectId);
    }

    if (projectRepository != null) {
      try {
        final projects = await projectRepository!.getProjects(limit: 20);
        final all = <InspectionModel>[];
        for (final p in projects) {
          try {
            final list = await getInspectionsForProject(p.id);
            all.addAll(list);
          } catch (_) {}
        }
        return all;
      } catch (_) {}
    }
    return [];
  }

  @override
  Future<List<InspectionModel>> getInspectionsForProject(
    dynamic projectId, {
    int limit = 50,
    int offset = 0,
  }) async {
    final pid = await _resolveProjectId(projectId);
    if (pid <= 0) return [];

    final response = await apiClient.get(
      '${ApiEndpoints.inspections}/project/$pid?limit=$limit&offset=$offset',
    );
    final list = response.data as List<dynamic>? ?? [];
    return list
        .map((e) => InspectionModel.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  @override
  Future<InspectionModel?> getInspectionById(dynamic id) async {
    final iid = _resolveInspectionId(id);
    if (iid <= 0) return null;

    try {
      final response = await apiClient.get('${ApiEndpoints.inspections}/$iid');
      if (response.data == null) return null;
      return InspectionModel.fromJson(response.data as Map<String, dynamic>);
    } on NotFoundException {
      return null;
    }
  }

  @override
  Future<InspectionModel> createInspection({
    required dynamic projectId,
    required String inspectionType,
    String status = 'PENDING',
    int? alertId,
    String? officerName,
    String? officerId,
    String? reason,
    DateTime? scheduledAt,
  }) async {
    final pid = await _resolveProjectId(projectId);
    final payload = <String, dynamic>{
      'project_id': pid,
      'inspection_type': inspectionType,
      'status': status,
      // ignore: use_null_aware_elements
      if (alertId != null) 'alert_id': alertId,
      // ignore: use_null_aware_elements
      if (officerName != null) 'officer_name': officerName,
      // ignore: use_null_aware_elements
      if (officerId != null) 'officer_id': officerId,
      // ignore: use_null_aware_elements
      if (reason != null) 'reason': reason,
      // ignore: use_null_aware_elements
      if (scheduledAt != null) 'scheduled_at': scheduledAt.toIso8601String(),
    };

    final response = await apiClient.post(ApiEndpoints.inspections, data: payload);
    return InspectionModel.fromJson(response.data as Map<String, dynamic>);
  }

  @override
  Future<InspectionModel> createRandomInspection() async {
    final response = await apiClient.post(ApiEndpoints.inspectionsRandom);
    return InspectionModel.fromJson(response.data as Map<String, dynamic>);
  }

  @override
  Future<InspectionModel> createInspectionFromAlert(int alertId) async {
    final response = await apiClient.post('${ApiEndpoints.inspections}/from-alert/$alertId');
    return InspectionModel.fromJson(response.data as Map<String, dynamic>);
  }

  @override
  Future<InspectionModel> updateInspectionStatus(dynamic inspectionId, String status) async {
    final iid = _resolveInspectionId(inspectionId);
    final response = await apiClient.put(
      '${ApiEndpoints.inspections}/$iid/status',
      data: {'status': status},
    );
    return InspectionModel.fromJson(response.data as Map<String, dynamic>);
  }

  @override
  Future<InspectionModel> updateInspection(dynamic inspectionId, Map<String, dynamic> updates) async {
    final iid = _resolveInspectionId(inspectionId);
    final response = await apiClient.put(
      '${ApiEndpoints.inspections}/$iid',
      data: updates,
    );
    return InspectionModel.fromJson(response.data as Map<String, dynamic>);
  }

  @override
  Future<InspectionModel> assignInspector(
    dynamic inspectionId, {
    required String inspectorId,
    String? inspectorName,
    String assignmentStatus = 'ASSIGNED',
  }) async {
    final iid = _resolveInspectionId(inspectionId);
    final response = await apiClient.post(
      '${ApiEndpoints.inspections}/$iid/assign',
      data: {
        'inspector_id': inspectorId,
        // ignore: use_null_aware_elements
        if (inspectorName != null) 'inspector_name': inspectorName,
        'assignment_status': assignmentStatus,
      },
    );
    return InspectionModel.fromJson(response.data as Map<String, dynamic>);
  }

  @override
  Future<InspectionModel> assignRandomInspector(dynamic inspectionId) async {
    final iid = _resolveInspectionId(inspectionId);
    final response = await apiClient.post(
      '${ApiEndpoints.inspections}/$iid/assign-random',
    );
    return InspectionModel.fromJson(response.data as Map<String, dynamic>);
  }

  @override
  Future<InspectionAssignmentModel> getInspectionAssignment(dynamic inspectionId) async {
    final iid = _resolveInspectionId(inspectionId);
    final response = await apiClient.get(
      '${ApiEndpoints.inspections}/$iid/assignment',
    );
    return InspectionAssignmentModel.fromJson(response.data as Map<String, dynamic>);
  }

  @override
  Future<InspectionLocationModel> submitInspectionLocation(
    dynamic inspectionId, {
    required double latitude,
    required double longitude,
    double? accuracy,
    DateTime? capturedAt,
  }) async {
    final iid = _resolveInspectionId(inspectionId);
    final response = await apiClient.post(
      '${ApiEndpoints.inspections}/$iid/location',
      data: {
        'latitude': latitude,
        'longitude': longitude,
        // ignore: use_null_aware_elements
        if (accuracy != null) 'location_accuracy': accuracy,
        // ignore: use_null_aware_elements
        if (capturedAt != null) 'location_captured_at': capturedAt.toIso8601String(),
      },
    );
    return InspectionLocationModel.fromJson(response.data as Map<String, dynamic>);
  }

  @override
  Future<InspectionLocationModel> getInspectionLocation(dynamic inspectionId) async {
    final iid = _resolveInspectionId(inspectionId);
    final response = await apiClient.get(
      '${ApiEndpoints.inspections}/$iid/location',
    );
    return InspectionLocationModel.fromJson(response.data as Map<String, dynamic>);
  }

  @override
  Future<List<InspectorModel>> getInspectors({bool? isActive, int limit = 50, int offset = 0}) async {
    var url = '${ApiEndpoints.inspectors}?limit=$limit&offset=$offset';
    if (isActive != null) {
      url += '&is_active=$isActive';
    }
    final response = await apiClient.get(url);
    final list = response.data as List<dynamic>? ?? [];
    return list.map((e) => InspectorModel.fromJson(e as Map<String, dynamic>)).toList();
  }

  @override
  Future<InspectorModel> createInspector({
    required String inspectorId,
    required String inspectorName,
    bool isActive = true,
  }) async {
    final response = await apiClient.post(
      ApiEndpoints.inspectors,
      data: {
        'inspector_id': inspectorId,
        'inspector_name': inspectorName,
        'is_active': isActive,
      },
    );
    return InspectorModel.fromJson(response.data as Map<String, dynamic>);
  }

  @override
  Future<void> submitInspectionResponse({
    required String inspectionId,
    required String responseText,
    required List<String> evidenceIds,
  }) async {
    final iid = _resolveInspectionId(inspectionId);
    if (iid > 0) {
      try {
        await updateInspection(iid, {'findings': responseText});
      } catch (_) {}
    }
  }

  @override
  Future<void> submitFollowUp({
    required String followUpId,
    required String responseText,
    required List<String> evidenceIds,
  }) async {
    // Legacy support
  }
}
