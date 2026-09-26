export 'inspector_model.dart';
export 'inspection_location_model.dart';

class InspectionChecklistItem {
  final String id;
  final String title;
  final String description;
  final bool isCompleted;
  final bool isOptional;

  const InspectionChecklistItem({
    required this.id,
    required this.title,
    required this.description,
    this.isCompleted = false,
    this.isOptional = false,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'description': description,
    'isCompleted': isCompleted,
    'isOptional': isOptional,
  };

  factory InspectionChecklistItem.fromJson(Map<String, dynamic> json) =>
      InspectionChecklistItem(
        id: json['id']?.toString() ?? '',
        title: json['title'] as String? ?? '',
        description: json['description'] as String? ?? '',
        isCompleted: json['isCompleted'] as bool? ?? false,
        isOptional: json['isOptional'] as bool? ?? false,
      );
}

class InformationRequest {
  final String id;
  final String title;
  final String description;
  final DateTime deadline;
  final bool isMandatory;
  final String status; // PENDING, SUBMITTED, REVIEWED

  const InformationRequest({
    required this.id,
    required this.title,
    required this.description,
    required this.deadline,
    this.isMandatory = true,
    this.status = 'PENDING',
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'description': description,
    'deadline': deadline.toIso8601String(),
    'isMandatory': isMandatory,
    'status': status,
  };

  factory InformationRequest.fromJson(Map<String, dynamic> json) =>
      InformationRequest(
        id: json['id']?.toString() ?? '',
        title: json['title'] as String? ?? '',
        description: json['description'] as String? ?? '',
        deadline:
            DateTime.tryParse(json['deadline'] as String? ?? '') ??
            DateTime.now(),
        isMandatory: json['isMandatory'] as bool? ?? true,
        status: json['status'] as String? ?? 'PENDING',
      );
}

class InspectionAssignmentModel {
  final int inspectionId;
  final String? inspectorId;
  final String? inspectorName;
  final DateTime? assignedAt;
  final String assignmentStatus;

  const InspectionAssignmentModel({
    required this.inspectionId,
    this.inspectorId,
    this.inspectorName,
    this.assignedAt,
    this.assignmentStatus = 'UNASSIGNED',
  });

  factory InspectionAssignmentModel.fromJson(Map<String, dynamic> json) {
    return InspectionAssignmentModel(
      inspectionId: json['inspection_id'] is int
          ? json['inspection_id'] as int
          : int.tryParse(json['inspection_id']?.toString() ?? '0') ?? 0,
      inspectorId: json['inspector_id'] as String?,
      inspectorName: json['inspector_name'] as String?,
      assignedAt: json['assigned_at'] != null
          ? DateTime.tryParse(json['assigned_at'].toString())
          : null,
      assignmentStatus: json['assignment_status'] as String? ?? 'UNASSIGNED',
    );
  }

  Map<String, dynamic> toJson() => {
    'inspection_id': inspectionId,
    'inspector_id': inspectorId,
    'inspector_name': inspectorName,
    'assigned_at': assignedAt?.toIso8601String(),
    'assignment_status': assignmentStatus,
  };
}

class InspectionModel {
  final String id;
  final String projectId;
  final int? alertId;
  final String inspectionType; // RANDOM, ALERT_TRIGGERED, SCHEDULED, MANUAL
  final String status; // PENDING, SCHEDULED, IN_PROGRESS, COMPLETED, CANCELLED
  final DateTime? scheduledAt;
  final DateTime? startedAt;
  final DateTime? completedAt;
  final String? officerName;
  final String? officerId;
  final String assignmentStatus; // UNASSIGNED, ASSIGNED
  final DateTime? assignedAt;
  final double? inspectionLatitude;
  final double? inspectionLongitude;
  final double? locationAccuracy;
  final DateTime? locationCapturedAt;
  final bool locationVerified;
  final double? distanceFromProject;
  final String? reason;
  final String? findings;
  final String? result;
  final String? videoSessionId;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  // Legacy/UI Compatibility overrides
  final String? _code;
  final String? _projectName;
  final String? _schemeCode;
  final String? _type;
  final String? _nodalOfficerName;
  final String? _nodalOfficerDesignation;
  final String? syncChannel;
  final List<InspectionChecklistItem> checklistItems;
  final List<InformationRequest> requests;
  final String? _outcome;
  final String? _outcomeNotes;
  final String? _requiredFollowUp;
  final DateTime? followUpDeadline;
  final String? followUpStatus;

  const InspectionModel({
    required this.id,
    required this.projectId,
    this.alertId,
    this.inspectionType = 'SCHEDULED',
    this.status = 'PENDING',
    this.scheduledAt,
    this.startedAt,
    this.completedAt,
    this.officerName,
    this.officerId,
    this.assignmentStatus = 'UNASSIGNED',
    this.assignedAt,
    this.inspectionLatitude,
    this.inspectionLongitude,
    this.locationAccuracy,
    this.locationCapturedAt,
    this.locationVerified = false,
    this.distanceFromProject,
    this.reason,
    this.findings,
    this.result,
    this.videoSessionId,
    this.createdAt,
    this.updatedAt,
    // Legacy support
    String? code,
    String? projectName,
    String? schemeCode,
    String? type,
    DateTime? scheduledDate,
    String? nodalOfficerName,
    String? nodalOfficerDesignation,
    this.syncChannel,
    this.checklistItems = const [],
    this.requests = const [],
    String? outcome,
    String? outcomeNotes,
    String? requiredFollowUp,
    this.followUpDeadline,
    this.followUpStatus,
  })  : _code = code,
        _projectName = projectName,
        _schemeCode = schemeCode,
        _type = type,
        _nodalOfficerName = nodalOfficerName,
        _nodalOfficerDesignation = nodalOfficerDesignation,
        _outcome = outcome,
        _outcomeNotes = outcomeNotes,
        _requiredFollowUp = requiredFollowUp;

  int get idInt => int.tryParse(id) ?? 0;
  int get projectIdInt => int.tryParse(projectId) ?? 0;

  String get code =>
      _code ??
      (id.startsWith('ins_') || id.startsWith('INS-') || id.startsWith('AUD-')
          ? id
          : 'INS-$id');

  String get projectName => _projectName ?? 'Project #$projectId';
  String get schemeCode => _schemeCode ?? 'DSJ-PRJ-$projectId';
  String get type => _type ?? inspectionType;
  DateTime get scheduledDate => scheduledAt ?? createdAt ?? DateTime.now();
  String get nodalOfficerName =>
      officerName ?? _nodalOfficerName ?? 'Unassigned Officer';
  String get nodalOfficerDesignation =>
      _nodalOfficerDesignation ??
      (officerName != null ? 'Inspection Officer' : 'Unassigned');
  String? get outcome => result ?? _outcome;
  String? get outcomeNotes => findings ?? _outcomeNotes;
  String? get requiredFollowUp => reason ?? _requiredFollowUp;

  Map<String, dynamic> toJson() => {
    'id': int.tryParse(id) ?? id,
    'project_id': int.tryParse(projectId) ?? projectId,
    'alert_id': alertId,
    'inspection_type': inspectionType,
    'status': status,
    'scheduled_at': scheduledAt?.toIso8601String(),
    'started_at': startedAt?.toIso8601String(),
    'completed_at': completedAt?.toIso8601String(),
    'officer_name': officerName,
    'officer_id': officerId,
    'assignment_status': assignmentStatus,
    'assigned_at': assignedAt?.toIso8601String(),
    'inspection_latitude': inspectionLatitude,
    'inspection_longitude': inspectionLongitude,
    'location_accuracy': locationAccuracy,
    'location_captured_at': locationCapturedAt?.toIso8601String(),
    'location_verified': locationVerified,
    'distance_from_project': distanceFromProject,
    'reason': reason,
    'findings': findings,
    'result': result,
    'video_session_id': videoSessionId,
    'created_at': createdAt?.toIso8601String(),
    'updated_at': updatedAt?.toIso8601String(),
    // Legacy fields
    'code': code,
    'projectId': projectId,
    'projectName': projectName,
    'schemeCode': schemeCode,
    'type': type,
    'scheduledDate': scheduledDate.toIso8601String(),
    'nodalOfficerName': nodalOfficerName,
    'nodalOfficerDesignation': nodalOfficerDesignation,
    'syncChannel': syncChannel,
    'checklistItems': checklistItems.map((e) => e.toJson()).toList(),
    'requests': requests.map((e) => e.toJson()).toList(),
    'outcome': outcome,
    'outcomeNotes': outcomeNotes,
    'requiredFollowUp': requiredFollowUp,
    'followUpDeadline': followUpDeadline?.toIso8601String(),
    'followUpStatus': followUpStatus,
  };

  factory InspectionModel.fromJson(Map<String, dynamic> json) {
    final rawId = json['id']?.toString() ?? '';
    final rawProjId = (json['project_id'] ?? json['projectId'])?.toString() ?? '';
    final rawType = json['inspection_type'] as String? ?? json['type'] as String? ?? 'SCHEDULED';
    final rawStatus = json['status'] as String? ?? 'PENDING';
    final rawOfficerName = json['officer_name'] as String? ?? json['nodalOfficerName'] as String?;
    final rawOfficerId = json['officer_id'] as String?;
    final rawAssignStatus = json['assignment_status'] as String? ?? 'UNASSIGNED';

    final schedAt = json['scheduled_at'] != null
        ? DateTime.tryParse(json['scheduled_at'].toString())
        : (json['scheduledDate'] != null ? DateTime.tryParse(json['scheduledDate'].toString()) : null);

    return InspectionModel(
      id: rawId,
      projectId: rawProjId,
      alertId: json['alert_id'] is int
          ? json['alert_id'] as int
          : (json['alert_id'] != null ? int.tryParse(json['alert_id'].toString()) : null),
      inspectionType: rawType,
      status: rawStatus,
      scheduledAt: schedAt,
      startedAt: json['started_at'] != null ? DateTime.tryParse(json['started_at'].toString()) : null,
      completedAt: json['completed_at'] != null ? DateTime.tryParse(json['completed_at'].toString()) : null,
      officerName: rawOfficerName,
      officerId: rawOfficerId,
      assignmentStatus: rawAssignStatus,
      assignedAt: json['assigned_at'] != null ? DateTime.tryParse(json['assigned_at'].toString()) : null,
      inspectionLatitude: json['inspection_latitude'] != null ? double.tryParse(json['inspection_latitude'].toString()) : null,
      inspectionLongitude: json['inspection_longitude'] != null ? double.tryParse(json['inspection_longitude'].toString()) : null,
      locationAccuracy: json['location_accuracy'] != null ? double.tryParse(json['location_accuracy'].toString()) : null,
      locationCapturedAt: json['location_captured_at'] != null ? DateTime.tryParse(json['location_captured_at'].toString()) : null,
      locationVerified: json['location_verified'] as bool? ?? false,
      distanceFromProject: json['distance_from_project'] != null ? double.tryParse(json['distance_from_project'].toString()) : null,
      reason: json['reason'] as String?,
      findings: json['findings'] as String?,
      result: json['result'] as String?,
      videoSessionId: json['video_session_id'] as String?,
      createdAt: json['created_at'] != null ? DateTime.tryParse(json['created_at'].toString()) : null,
      updatedAt: json['updated_at'] != null ? DateTime.tryParse(json['updated_at'].toString()) : null,
      // Legacy
      code: json['code'] as String?,
      projectName: json['projectName'] as String?,
      schemeCode: json['schemeCode'] as String?,
      type: json['type'] as String?,
      nodalOfficerName: rawOfficerName,
      nodalOfficerDesignation: json['nodalOfficerDesignation'] as String?,
      syncChannel: json['syncChannel'] as String?,
      checklistItems: (json['checklistItems'] as List<dynamic>?)
              ?.map((e) => InspectionChecklistItem.fromJson(e as Map<String, dynamic>))
              .toList() ??
          const [],
      requests: (json['requests'] as List<dynamic>?)
              ?.map((e) => InformationRequest.fromJson(e as Map<String, dynamic>))
              .toList() ??
          const [],
      outcome: json['outcome'] as String? ?? json['result'] as String?,
      outcomeNotes: json['outcomeNotes'] as String? ?? json['findings'] as String?,
      requiredFollowUp: json['requiredFollowUp'] as String? ?? json['reason'] as String?,
      followUpDeadline: json['followUpDeadline'] != null
          ? DateTime.tryParse(json['followUpDeadline'].toString())
          : null,
      followUpStatus: json['followUpStatus'] as String?,
    );
  }

  InspectionModel copyWith({
    String? id,
    String? projectId,
    int? alertId,
    String? inspectionType,
    String? status,
    DateTime? scheduledAt,
    DateTime? startedAt,
    DateTime? completedAt,
    String? officerName,
    String? officerId,
    String? assignmentStatus,
    DateTime? assignedAt,
    double? inspectionLatitude,
    double? inspectionLongitude,
    double? locationAccuracy,
    DateTime? locationCapturedAt,
    bool? locationVerified,
    double? distanceFromProject,
    String? reason,
    String? findings,
    String? result,
    String? videoSessionId,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? code,
    String? projectName,
    String? schemeCode,
    String? type,
    String? nodalOfficerName,
    String? nodalOfficerDesignation,
    String? syncChannel,
    List<InspectionChecklistItem>? checklistItems,
    List<InformationRequest>? requests,
    String? outcome,
    String? outcomeNotes,
    String? requiredFollowUp,
    DateTime? followUpDeadline,
    String? followUpStatus,
  }) {
    return InspectionModel(
      id: id ?? this.id,
      projectId: projectId ?? this.projectId,
      alertId: alertId ?? this.alertId,
      inspectionType: inspectionType ?? this.inspectionType,
      status: status ?? this.status,
      scheduledAt: scheduledAt ?? this.scheduledAt,
      startedAt: startedAt ?? this.startedAt,
      completedAt: completedAt ?? this.completedAt,
      officerName: officerName ?? this.officerName,
      officerId: officerId ?? this.officerId,
      assignmentStatus: assignmentStatus ?? this.assignmentStatus,
      assignedAt: assignedAt ?? this.assignedAt,
      inspectionLatitude: inspectionLatitude ?? this.inspectionLatitude,
      inspectionLongitude: inspectionLongitude ?? this.inspectionLongitude,
      locationAccuracy: locationAccuracy ?? this.locationAccuracy,
      locationCapturedAt: locationCapturedAt ?? this.locationCapturedAt,
      locationVerified: locationVerified ?? this.locationVerified,
      distanceFromProject: distanceFromProject ?? this.distanceFromProject,
      reason: reason ?? this.reason,
      findings: findings ?? this.findings,
      result: result ?? this.result,
      videoSessionId: videoSessionId ?? this.videoSessionId,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      code: code ?? _code,
      projectName: projectName ?? _projectName,
      schemeCode: schemeCode ?? _schemeCode,
      type: type ?? _type,
      nodalOfficerName: nodalOfficerName ?? _nodalOfficerName,
      nodalOfficerDesignation: nodalOfficerDesignation ?? _nodalOfficerDesignation,
      syncChannel: syncChannel ?? this.syncChannel,
      checklistItems: checklistItems ?? this.checklistItems,
      requests: requests ?? this.requests,
      outcome: outcome ?? _outcome,
      outcomeNotes: outcomeNotes ?? _outcomeNotes,
      requiredFollowUp: requiredFollowUp ?? _requiredFollowUp,
      followUpDeadline: followUpDeadline ?? this.followUpDeadline,
      followUpStatus: followUpStatus ?? this.followUpStatus,
    );
  }
}
