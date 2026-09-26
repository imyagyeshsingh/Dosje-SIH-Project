import 'dart:convert';

enum VideoSessionStatus {
  created,
  active,
  ended,
  cancelled,
  incoming,
  completed;

  static VideoSessionStatus fromString(String? val) {
    if (val == null) return VideoSessionStatus.created;
    switch (val.toUpperCase()) {
      case 'ACTIVE':
        return VideoSessionStatus.active;
      case 'ENDED':
        return VideoSessionStatus.ended;
      case 'COMPLETED':
        return VideoSessionStatus.completed;
      case 'CANCELLED':
        return VideoSessionStatus.cancelled;
      case 'INCOMING':
        return VideoSessionStatus.incoming;
      case 'CREATED':
      default:
        return VideoSessionStatus.created;
    }
  }

  String toBackendString() {
    switch (this) {
      case VideoSessionStatus.created:
      case VideoSessionStatus.incoming:
        return 'CREATED';
      case VideoSessionStatus.active:
        return 'ACTIVE';
      case VideoSessionStatus.ended:
      case VideoSessionStatus.completed:
        return 'ENDED';
      case VideoSessionStatus.cancelled:
        return 'CANCELLED';
    }
  }
}

class VideoSessionModel {
  final dynamic id; // Numeric id in backend (int), or String in mock
  final dynamic projectId;
  final dynamic inspectionId;
  final String sessionId; // UUID string used for WebSocket URL
  final VideoSessionStatus status;
  final String? officerName;
  final String? representativeName;
  final DateTime? startedAt;
  final DateTime? endedAt;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  // Backward compatibility fields
  final String? _projectName;
  final String? _callerName;
  final String? _callerDesignation;
  final int _durationSeconds;

  VideoSessionModel({
    required this.id,
    this.projectId = 0,
    this.inspectionId,
    String? sessionId,
    this.status = VideoSessionStatus.created,
    this.officerName,
    this.representativeName,
    this.startedAt,
    this.endedAt,
    this.createdAt,
    this.updatedAt,
    String? projectName,
    String? callerName,
    String? callerDesignation,
    int durationSeconds = 0,
  })  : sessionId = sessionId ?? (id is String ? id : id.toString()),
        _projectName = projectName,
        _callerName = callerName ?? officerName,
        _callerDesignation = callerDesignation,
        _durationSeconds = durationSeconds;

  int get numericId =>
      id is int ? id as int : (int.tryParse(id.toString()) ?? 0);

  int get numericProjectId => projectId is int
      ? projectId as int
      : (int.tryParse(projectId?.toString() ?? '') ?? 0);

  int? get numericInspectionId => inspectionId is int
      ? inspectionId as int
      : (inspectionId != null
          ? int.tryParse(inspectionId.toString())
          : null);

  String get projectName => _projectName ?? 'Project #$numericProjectId';
  String get callerName => _callerName ?? (officerName ?? 'Officer');
  String get callerDesignation =>
      _callerDesignation ?? 'Field Inspection Directorate';

  int get durationSeconds {
    if (_durationSeconds > 0) return _durationSeconds;
    if (startedAt != null && endedAt != null) {
      return endedAt!.difference(startedAt!).inSeconds;
    }
    return 0;
  }

  bool get isActive =>
      status == VideoSessionStatus.active;
  bool get isEnded =>
      status == VideoSessionStatus.ended || status == VideoSessionStatus.completed;
  bool get isCancelled => status == VideoSessionStatus.cancelled;

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'project_id': numericProjectId,
      'inspection_id': numericInspectionId,
      'session_id': sessionId,
      'status': status.toBackendString(),
      'officer_name': officerName,
      'representative_name': representativeName,
      'started_at': startedAt?.toIso8601String(),
      'ended_at': endedAt?.toIso8601String(),
      'created_at': createdAt?.toIso8601String(),
      'updated_at': updatedAt?.toIso8601String(),
      'projectName': projectName,
      'callerName': callerName,
      'callerDesignation': callerDesignation,
      'durationSeconds': durationSeconds,
    };
  }

  factory VideoSessionModel.fromJson(Map<String, dynamic> json) {
    final rawId = json['id'];
    final sId = json['session_id'] as String? ??
        json['sessionId'] as String? ??
        rawId?.toString() ??
        '';

    final pId = json['project_id'] ?? json['projectId'] ?? 0;
    final inspId = json['inspection_id'] ?? json['inspectionId'];

    final statusStr = json['status'] as String?;
    final parsedStatus = VideoSessionStatus.fromString(statusStr);

    final offName = json['officer_name'] as String? ??
        json['officerName'] as String? ??
        json['callerName'] as String?;

    final repName = json['representative_name'] as String? ??
        json['representativeName'] as String?;

    DateTime? parseDate(dynamic val) {
      if (val == null) return null;
      if (val is DateTime) return val;
      return DateTime.tryParse(val.toString());
    }

    return VideoSessionModel(
      id: rawId ?? sId,
      projectId: pId,
      inspectionId: inspId,
      sessionId: sId,
      status: parsedStatus,
      officerName: offName,
      representativeName: repName,
      startedAt: parseDate(json['started_at'] ?? json['startedAt']),
      endedAt: parseDate(json['ended_at'] ?? json['endedAt']),
      createdAt: parseDate(json['created_at'] ?? json['createdAt']),
      updatedAt: parseDate(json['updated_at'] ?? json['updatedAt']),
      projectName: json['projectName'] as String?,
      callerName: offName,
      callerDesignation: json['callerDesignation'] as String?,
      durationSeconds: (json['durationSeconds'] as num?)?.toInt() ?? 0,
    );
  }
}

class VideoSignalingMessage {
  final String type;
  final String? role;
  final String? sdp;
  final Map<String, dynamic>? candidate;
  final String? message;
  final Map<String, dynamic> raw;

  const VideoSignalingMessage({
    required this.type,
    this.role,
    this.sdp,
    this.candidate,
    this.message,
    this.raw = const {},
  });

  factory VideoSignalingMessage.fromJson(Map<String, dynamic> json) {
    return VideoSignalingMessage(
      type: json['type'] as String? ?? 'unknown',
      role: json['role'] as String?,
      sdp: json['sdp'] as String?,
      candidate: json['candidate'] is Map<String, dynamic>
          ? json['candidate'] as Map<String, dynamic>
          : null,
      message: json['message'] as String?,
      raw: json,
    );
  }

  Map<String, dynamic> toJson() {
    final map = <String, dynamic>{'type': type};
    if (role != null) map['role'] = role;
    if (sdp != null) map['sdp'] = sdp;
    if (candidate != null) map['candidate'] = candidate;
    if (message != null) map['message'] = message;
    return map;
  }

  String encode() => jsonEncode(toJson());
}

class VideoInspectionSession {
  final String sessionId;
  final String inspectionId;
  final String projectId;
  final String projectName;
  final String officerName;
  final String officerDesignation;
  final DateTime startedAt;
  final int durationSeconds;
  final String status;
  final List<String> directives;
  final List<String> mandateItems;
  final String? completionNotes;

  const VideoInspectionSession({
    required this.sessionId,
    required this.inspectionId,
    required this.projectId,
    required this.projectName,
    required this.officerName,
    required this.officerDesignation,
    required this.startedAt,
    this.durationSeconds = 0,
    this.status = 'INCOMING',
    this.directives = const [],
    this.mandateItems = const [],
    this.completionNotes,
  });

  Map<String, dynamic> toJson() => {
    'sessionId': sessionId,
    'inspectionId': inspectionId,
    'projectId': projectId,
    'projectName': projectName,
    'officerName': officerName,
    'officerDesignation': officerDesignation,
    'startedAt': startedAt.toIso8601String(),
    'durationSeconds': durationSeconds,
    'status': status,
    'directives': directives,
    'mandateItems': mandateItems,
    'completionNotes': completionNotes,
  };

  factory VideoInspectionSession.fromJson(Map<String, dynamic> json) =>
      VideoInspectionSession(
        sessionId: json['sessionId'] as String? ?? '',
        inspectionId: json['inspectionId'] as String? ?? '',
        projectId: json['projectId'] as String? ?? '',
        projectName: json['projectName'] as String? ?? '',
        officerName: json['officerName'] as String? ?? '',
        officerDesignation: json['officerDesignation'] as String? ?? '',
        startedAt:
            DateTime.tryParse(json['startedAt'] as String? ?? '') ??
            DateTime.now(),
        durationSeconds: json['durationSeconds'] as int? ?? 0,
        status: json['status'] as String? ?? 'INCOMING',
        directives:
            (json['directives'] as List<dynamic>?)
                ?.map((e) => e.toString())
                .toList() ??
            [],
        mandateItems:
            (json['mandateItems'] as List<dynamic>?)
                ?.map((e) => e.toString())
                .toList() ??
            [],
        completionNotes: json['completionNotes'] as String?,
      );
}
