class AttendanceConfigModel {
  final int id;
  final int projectId;
  final int expectedWorkers;
  final DateTime createdAt;
  final DateTime updatedAt;

  const AttendanceConfigModel({
    required this.id,
    required this.projectId,
    required this.expectedWorkers,
    required this.createdAt,
    required this.updatedAt,
  });

  factory AttendanceConfigModel.fromJson(Map<String, dynamic> json) {
    return AttendanceConfigModel(
      id: json['id'] as int? ?? 0,
      projectId: json['project_id'] as int? ?? 0,
      expectedWorkers: json['expected_workers'] as int? ?? 0,
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'] as String)
          : DateTime.now(),
      updatedAt: json['updated_at'] != null
          ? DateTime.parse(json['updated_at'] as String)
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'project_id': projectId,
      'expected_workers': expectedWorkers,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  AttendanceConfigModel copyWith({
    int? id,
    int? projectId,
    int? expectedWorkers,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return AttendanceConfigModel(
      id: id ?? this.id,
      projectId: projectId ?? this.projectId,
      expectedWorkers: expectedWorkers ?? this.expectedWorkers,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}

class AttendanceSummaryModel {
  final int projectId;
  final int? expectedWorkers;
  final int? detectedWorkers;
  final double? attendancePercentage;
  final DateTime? detectionTimestamp;

  const AttendanceSummaryModel({
    required this.projectId,
    this.expectedWorkers,
    this.detectedWorkers,
    this.attendancePercentage,
    this.detectionTimestamp,
  });

  factory AttendanceSummaryModel.fromJson(Map<String, dynamic> json) {
    return AttendanceSummaryModel(
      projectId: json['project_id'] as int? ?? 0,
      expectedWorkers: json['expected_workers'] as int?,
      detectedWorkers: json['detected_workers'] as int?,
      attendancePercentage: (json['attendance_percentage'] as num?)?.toDouble(),
      detectionTimestamp: json['detection_timestamp'] != null
          ? DateTime.parse(json['detection_timestamp'] as String)
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'project_id': projectId,
      'expected_workers': expectedWorkers,
      'detected_workers': detectedWorkers,
      'attendance_percentage': attendancePercentage,
      'detection_timestamp': detectionTimestamp?.toIso8601String(),
    };
  }

  AttendanceSummaryModel copyWith({
    int? projectId,
    int? expectedWorkers,
    int? detectedWorkers,
    double? attendancePercentage,
    DateTime? detectionTimestamp,
  }) {
    return AttendanceSummaryModel(
      projectId: projectId ?? this.projectId,
      expectedWorkers: expectedWorkers ?? this.expectedWorkers,
      detectedWorkers: detectedWorkers ?? this.detectedWorkers,
      attendancePercentage: attendancePercentage ?? this.attendancePercentage,
      detectionTimestamp: detectionTimestamp ?? this.detectionTimestamp,
    );
  }
}
