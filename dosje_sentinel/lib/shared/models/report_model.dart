import 'package:flutter/foundation.dart';

enum ReportType {
  inspection('INSPECTION'),
  monitoring('MONITORING'),
  incident('INCIDENT');

  final String value;
  const ReportType(this.value);

  static ReportType fromString(String? val) {
    if (val == null) return ReportType.inspection;
    final upper = val.toUpperCase().trim();
    return ReportType.values.firstWhere(
      (e) => e.value == upper || e.name.toUpperCase() == upper,
      orElse: () => ReportType.inspection,
    );
  }
}

enum ReportStatus {
  draft('DRAFT'),
  finalStatus('FINAL');

  final String value;
  const ReportStatus(this.value);

  static ReportStatus fromString(String? val) {
    if (val == null) return ReportStatus.draft;
    final upper = val.toUpperCase().trim();
    if (upper == 'FINAL') return ReportStatus.finalStatus;
    return ReportStatus.draft;
  }
}

@immutable
class ReportModel {
  final int id;
  final int projectId;
  final int inspectionId;
  final ReportType reportType;
  final ReportStatus status;
  final String title;
  final String? summary;
  final String? findings;
  final String? recommendations;
  final DateTime? generatedAt;
  final DateTime createdAt;
  final DateTime updatedAt;

  const ReportModel({
    required this.id,
    required this.projectId,
    required this.inspectionId,
    required this.reportType,
    required this.status,
    required this.title,
    this.summary,
    this.findings,
    this.recommendations,
    this.generatedAt,
    required this.createdAt,
    required this.updatedAt,
  });

  factory ReportModel.fromJson(Map<String, dynamic> json) {
    return ReportModel(
      id: json['id'] is int ? json['id'] as int : int.parse(json['id'].toString()),
      projectId: json['project_id'] is int
          ? json['project_id'] as int
          : int.parse(json['project_id'].toString()),
      inspectionId: json['inspection_id'] is int
          ? json['inspection_id'] as int
          : int.parse(json['inspection_id'].toString()),
      reportType: ReportType.fromString(json['report_type'] as String?),
      status: ReportStatus.fromString(json['status'] as String?),
      title: json['title'] as String? ?? '',
      summary: json['summary'] as String?,
      findings: json['findings'] as String?,
      recommendations: json['recommendations'] as String?,
      generatedAt: json['generated_at'] != null
          ? DateTime.tryParse(json['generated_at'].toString())
          : null,
      createdAt: json['created_at'] != null
          ? (DateTime.tryParse(json['created_at'].toString()) ?? DateTime.now())
          : DateTime.now(),
      updatedAt: json['updated_at'] != null
          ? (DateTime.tryParse(json['updated_at'].toString()) ?? DateTime.now())
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'project_id': projectId,
      'inspection_id': inspectionId,
      'report_type': reportType.value,
      'status': status.value,
      'title': title,
      if (summary != null) 'summary': summary,
      if (findings != null) 'findings': findings,
      if (recommendations != null) 'recommendations': recommendations,
      if (generatedAt != null) 'generated_at': generatedAt!.toIso8601String(),
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  ReportModel copyWith({
    int? id,
    int? projectId,
    int? inspectionId,
    ReportType? reportType,
    ReportStatus? status,
    String? title,
    String? summary,
    String? findings,
    String? recommendations,
    DateTime? generatedAt,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return ReportModel(
      id: id ?? this.id,
      projectId: projectId ?? this.projectId,
      inspectionId: inspectionId ?? this.inspectionId,
      reportType: reportType ?? this.reportType,
      status: status ?? this.status,
      title: title ?? this.title,
      summary: summary ?? this.summary,
      findings: findings ?? this.findings,
      recommendations: recommendations ?? this.recommendations,
      generatedAt: generatedAt ?? this.generatedAt,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}

@immutable
class ReportEvidenceReferenceModel {
  final int id;
  final int reportId;
  final String externalEvidenceId;
  final String evidenceType;
  final String? source;
  final DateTime createdAt;

  const ReportEvidenceReferenceModel({
    required this.id,
    required this.reportId,
    required this.externalEvidenceId,
    required this.evidenceType,
    this.source,
    required this.createdAt,
  });

  factory ReportEvidenceReferenceModel.fromJson(Map<String, dynamic> json) {
    return ReportEvidenceReferenceModel(
      id: json['id'] is int ? json['id'] as int : int.parse(json['id'].toString()),
      reportId: json['report_id'] is int
          ? json['report_id'] as int
          : int.parse(json['report_id'].toString()),
      externalEvidenceId: json['external_evidence_id'] as String? ?? '',
      evidenceType: json['evidence_type'] as String? ?? 'IMAGE',
      source: json['source'] as String?,
      createdAt: json['created_at'] != null
          ? (DateTime.tryParse(json['created_at'].toString()) ?? DateTime.now())
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'report_id': reportId,
      'external_evidence_id': externalEvidenceId,
      'evidence_type': evidenceType,
      if (source != null) 'source': source,
      'created_at': createdAt.toIso8601String(),
    };
  }
}

@immutable
class ReportAggregationRisk {
  final int? score;
  final String? level;

  const ReportAggregationRisk({this.score, this.level});

  factory ReportAggregationRisk.fromJson(Map<String, dynamic> json) {
    return ReportAggregationRisk(
      score: json['score'] as int?,
      level: json['level'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {'score': score, 'level': level};
}

@immutable
class ReportAggregationAttendance {
  final int? expectedWorkers;
  final int? detectedWorkers;
  final double? attendancePercentage;
  final DateTime? detectionTimestamp;

  const ReportAggregationAttendance({
    this.expectedWorkers,
    this.detectedWorkers,
    this.attendancePercentage,
    this.detectionTimestamp,
  });

  factory ReportAggregationAttendance.fromJson(Map<String, dynamic> json) {
    return ReportAggregationAttendance(
      expectedWorkers: json['expected_workers'] as int?,
      detectedWorkers: json['detected_workers'] as int?,
      attendancePercentage: (json['attendance_percentage'] as num?)?.toDouble(),
      detectionTimestamp: json['detection_timestamp'] != null
          ? DateTime.tryParse(json['detection_timestamp'].toString())
          : null,
    );
  }

  Map<String, dynamic> toJson() => {
    'expected_workers': expectedWorkers,
    'detected_workers': detectedWorkers,
    'attendance_percentage': attendancePercentage,
    'detection_timestamp': detectionTimestamp?.toIso8601String(),
  };
}

@immutable
class ReportAggregationCCTV {
  final int totalCameras;
  final int activeCameras;

  const ReportAggregationCCTV({
    this.totalCameras = 0,
    this.activeCameras = 0,
  });

  factory ReportAggregationCCTV.fromJson(Map<String, dynamic> json) {
    return ReportAggregationCCTV(
      totalCameras: json['total_cameras'] as int? ?? 0,
      activeCameras: json['active_cameras'] as int? ?? 0,
    );
  }

  Map<String, dynamic> toJson() => {
    'total_cameras': totalCameras,
    'active_cameras': activeCameras,
  };
}

@immutable
class ReportAggregationAI {
  final int totalDetections;
  final int? latestDetectionId;
  final String? latestActivity;
  final int? latestPeopleDetected;
  final double? latestConfidence;
  final DateTime? latestTimestamp;

  const ReportAggregationAI({
    this.totalDetections = 0,
    this.latestDetectionId,
    this.latestActivity,
    this.latestPeopleDetected,
    this.latestConfidence,
    this.latestTimestamp,
  });

  factory ReportAggregationAI.fromJson(Map<String, dynamic> json) {
    return ReportAggregationAI(
      totalDetections: json['total_detections'] as int? ?? 0,
      latestDetectionId: json['latest_detection_id'] as int?,
      latestActivity: json['latest_activity'] as String?,
      latestPeopleDetected: json['latest_people_detected'] as int?,
      latestConfidence: (json['latest_confidence'] as num?)?.toDouble(),
      latestTimestamp: json['latest_timestamp'] != null
          ? DateTime.tryParse(json['latest_timestamp'].toString())
          : null,
    );
  }

  Map<String, dynamic> toJson() => {
    'total_detections': totalDetections,
    'latest_detection_id': latestDetectionId,
    'latest_activity': latestActivity,
    'latest_people_detected': latestPeopleDetected,
    'latest_confidence': latestConfidence,
    'latest_timestamp': latestTimestamp?.toIso8601String(),
  };
}

@immutable
class ReportAggregationAlerts {
  final int totalAlerts;
  final int activeAlerts;
  final int resolvedAlerts;

  const ReportAggregationAlerts({
    this.totalAlerts = 0,
    this.activeAlerts = 0,
    this.resolvedAlerts = 0,
  });

  factory ReportAggregationAlerts.fromJson(Map<String, dynamic> json) {
    return ReportAggregationAlerts(
      totalAlerts: json['total_alerts'] as int? ?? 0,
      activeAlerts: json['active_alerts'] as int? ?? 0,
      resolvedAlerts: json['resolved_alerts'] as int? ?? 0,
    );
  }

  Map<String, dynamic> toJson() => {
    'total_alerts': totalAlerts,
    'active_alerts': activeAlerts,
    'resolved_alerts': resolvedAlerts,
  };
}

@immutable
class ReportAggregationInspections {
  final int totalInspections;
  final int pending;
  final int scheduled;
  final int inProgress;
  final int completed;
  final int cancelled;
  final int? latestInspectionId;
  final String? latestInspectionStatus;

  const ReportAggregationInspections({
    this.totalInspections = 0,
    this.pending = 0,
    this.scheduled = 0,
    this.inProgress = 0,
    this.completed = 0,
    this.cancelled = 0,
    this.latestInspectionId,
    this.latestInspectionStatus,
  });

  factory ReportAggregationInspections.fromJson(Map<String, dynamic> json) {
    return ReportAggregationInspections(
      totalInspections: json['total_inspections'] as int? ?? 0,
      pending: json['pending'] as int? ?? 0,
      scheduled: json['scheduled'] as int? ?? 0,
      inProgress: json['in_progress'] as int? ?? 0,
      completed: json['completed'] as int? ?? 0,
      cancelled: json['cancelled'] as int? ?? 0,
      latestInspectionId: json['latest_inspection_id'] as int?,
      latestInspectionStatus: json['latest_inspection_status'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
    'total_inspections': totalInspections,
    'pending': pending,
    'scheduled': scheduled,
    'in_progress': inProgress,
    'completed': completed,
    'cancelled': cancelled,
    'latest_inspection_id': latestInspectionId,
    'latest_inspection_status': latestInspectionStatus,
  };
}

@immutable
class ReportAggregationVideoSessions {
  final int totalSessions;
  final int activeSessions;
  final int endedSessions;
  final int? latestSessionId;
  final String? latestSessionStatus;

  const ReportAggregationVideoSessions({
    this.totalSessions = 0,
    this.activeSessions = 0,
    this.endedSessions = 0,
    this.latestSessionId,
    this.latestSessionStatus,
  });

  factory ReportAggregationVideoSessions.fromJson(Map<String, dynamic> json) {
    return ReportAggregationVideoSessions(
      totalSessions: json['total_sessions'] as int? ?? 0,
      activeSessions: json['active_sessions'] as int? ?? 0,
      endedSessions: json['ended_sessions'] as int? ?? 0,
      latestSessionId: json['latest_session_id'] as int?,
      latestSessionStatus: json['latest_session_status'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
    'total_sessions': totalSessions,
    'active_sessions': activeSessions,
    'ended_sessions': endedSessions,
    'latest_session_id': latestSessionId,
    'latest_session_status': latestSessionStatus,
  };
}

@immutable
class ReportAggregationEvidence {
  final int totalReferences;
  final List<String> projectEvidenceIds;

  const ReportAggregationEvidence({
    this.totalReferences = 0,
    this.projectEvidenceIds = const [],
  });

  factory ReportAggregationEvidence.fromJson(Map<String, dynamic> json) {
    final list = json['project_evidence_ids'] as List<dynamic>? ?? [];
    return ReportAggregationEvidence(
      totalReferences: json['total_references'] as int? ?? 0,
      projectEvidenceIds: list.map((e) => e.toString()).toList(),
    );
  }

  Map<String, dynamic> toJson() => {
    'total_references': totalReferences,
    'project_evidence_ids': projectEvidenceIds,
  };
}

@immutable
class ReportInspectionContext {
  final int? id;
  final String? inspectionType;
  final String? status;
  final String? officerName;
  final String? reason;

  const ReportInspectionContext({
    this.id,
    this.inspectionType,
    this.status,
    this.officerName,
    this.reason,
  });

  factory ReportInspectionContext.fromJson(Map<String, dynamic> json) {
    return ReportInspectionContext(
      id: json['id'] is int ? json['id'] as int : (json['id'] != null ? int.tryParse(json['id'].toString()) : null),
      inspectionType: json['inspection_type'] as String?,
      status: json['status'] as String?,
      officerName: json['officer_name'] as String?,
      reason: json['reason'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'inspection_type': inspectionType,
    'status': status,
    'officer_name': officerName,
    'reason': reason,
  };
}

@immutable
class ReportAggregationModel {
  final int reportId;
  final int projectId;
  final String projectName;
  final String projectCode;
  final ReportAggregationRisk risk;
  final ReportAggregationAttendance attendance;
  final ReportAggregationCCTV cctv;
  final ReportAggregationAI ai;
  final ReportAggregationAlerts alerts;
  final ReportAggregationInspections inspections;
  final ReportAggregationVideoSessions videoSessions;
  final ReportAggregationEvidence evidence;
  final ReportInspectionContext? inspection;

  const ReportAggregationModel({
    required this.reportId,
    required this.projectId,
    required this.projectName,
    required this.projectCode,
    required this.risk,
    required this.attendance,
    required this.cctv,
    required this.ai,
    required this.alerts,
    required this.inspections,
    required this.videoSessions,
    required this.evidence,
    this.inspection,
  });

  factory ReportAggregationModel.fromJson(Map<String, dynamic> json) {
    return ReportAggregationModel(
      reportId: json['report_id'] is int
          ? json['report_id'] as int
          : int.parse(json['report_id'].toString()),
      projectId: json['project_id'] is int
          ? json['project_id'] as int
          : int.parse(json['project_id'].toString()),
      projectName: json['project_name'] as String? ?? '',
      projectCode: json['project_code'] as String? ?? '',
      risk: ReportAggregationRisk.fromJson(
        json['risk'] as Map<String, dynamic>? ?? {},
      ),
      attendance: ReportAggregationAttendance.fromJson(
        json['attendance'] as Map<String, dynamic>? ?? {},
      ),
      cctv: ReportAggregationCCTV.fromJson(
        json['cctv'] as Map<String, dynamic>? ?? {},
      ),
      ai: ReportAggregationAI.fromJson(
        json['ai'] as Map<String, dynamic>? ?? {},
      ),
      alerts: ReportAggregationAlerts.fromJson(
        json['alerts'] as Map<String, dynamic>? ?? {},
      ),
      inspections: ReportAggregationInspections.fromJson(
        json['inspections'] as Map<String, dynamic>? ?? {},
      ),
      videoSessions: ReportAggregationVideoSessions.fromJson(
        json['video_sessions'] as Map<String, dynamic>? ?? {},
      ),
      evidence: ReportAggregationEvidence.fromJson(
        json['evidence'] as Map<String, dynamic>? ?? {},
      ),
      inspection: json['inspection'] != null
          ? ReportInspectionContext.fromJson(
              json['inspection'] as Map<String, dynamic>,
            )
          : null,
    );
  }

  Map<String, dynamic> toJson() => {
    'report_id': reportId,
    'project_id': projectId,
    'project_name': projectName,
    'project_code': projectCode,
    'risk': risk.toJson(),
    'attendance': attendance.toJson(),
    'cctv': cctv.toJson(),
    'ai': ai.toJson(),
    'alerts': alerts.toJson(),
    'inspections': inspections.toJson(),
    'video_sessions': videoSessions.toJson(),
    'evidence': evidence.toJson(),
    if (inspection != null) 'inspection': inspection!.toJson(),
  };
}
