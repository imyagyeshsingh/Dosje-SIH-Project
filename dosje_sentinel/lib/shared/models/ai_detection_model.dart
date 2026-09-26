class AiDetectionModel {
  final int id;
  final int projectId;
  final int cameraId;
  final int peopleDetected;
  final String activity;
  final double confidence;
  final DateTime timestamp;
  final DateTime createdAt;

  const AiDetectionModel({
    required this.id,
    required this.projectId,
    required this.cameraId,
    required this.peopleDetected,
    required this.activity,
    required this.confidence,
    required this.timestamp,
    required this.createdAt,
  });

  factory AiDetectionModel.fromJson(Map<String, dynamic> json) {
    return AiDetectionModel(
      id: json['id'] as int? ?? 0,
      projectId: json['project_id'] as int? ?? 0,
      cameraId: json['camera_id'] as int? ?? 0,
      peopleDetected: json['people_detected'] as int? ?? 0,
      activity: json['activity'] as String? ?? 'NORMAL',
      confidence: (json['confidence'] as num?)?.toDouble() ?? 0.0,
      timestamp: json['timestamp'] != null
          ? DateTime.parse(json['timestamp'] as String)
          : DateTime.now(),
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'] as String)
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'project_id': projectId,
      'camera_id': cameraId,
      'people_detected': peopleDetected,
      'activity': activity,
      'confidence': confidence,
      'timestamp': timestamp.toIso8601String(),
      'created_at': createdAt.toIso8601String(),
    };
  }

  AiDetectionModel copyWith({
    int? id,
    int? projectId,
    int? cameraId,
    int? peopleDetected,
    String? activity,
    double? confidence,
    DateTime? timestamp,
    DateTime? createdAt,
  }) {
    return AiDetectionModel(
      id: id ?? this.id,
      projectId: projectId ?? this.projectId,
      cameraId: cameraId ?? this.cameraId,
      peopleDetected: peopleDetected ?? this.peopleDetected,
      activity: activity ?? this.activity,
      confidence: confidence ?? this.confidence,
      timestamp: timestamp ?? this.timestamp,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  @override
  String toString() =>
      'AiDetectionModel(id: $id, project_id: $projectId, camera_id: $cameraId, people: $peopleDetected, activity: $activity, confidence: $confidence)';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AiDetectionModel &&
          runtimeType == other.runtimeType &&
          id == other.id;

  @override
  int get hashCode => id.hashCode;
}

class AiDetectionSummaryModel {
  final int projectId;
  final int? latestPeopleDetected;
  final String? latestActivity;
  final double? latestConfidence;
  final DateTime? latestTimestamp;
  final int detectionCount;

  const AiDetectionSummaryModel({
    required this.projectId,
    this.latestPeopleDetected,
    this.latestActivity,
    this.latestConfidence,
    this.latestTimestamp,
    this.detectionCount = 0,
  });

  factory AiDetectionSummaryModel.fromJson(Map<String, dynamic> json) {
    return AiDetectionSummaryModel(
      projectId: json['project_id'] as int? ?? 0,
      latestPeopleDetected: json['latest_people_detected'] as int?,
      latestActivity: json['latest_activity'] as String?,
      latestConfidence: (json['latest_confidence'] as num?)?.toDouble(),
      latestTimestamp: json['latest_timestamp'] != null
          ? DateTime.tryParse(json['latest_timestamp'] as String)
          : null,
      detectionCount: json['detection_count'] as int? ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'project_id': projectId,
      'latest_people_detected': latestPeopleDetected,
      'latest_activity': latestActivity,
      'latest_confidence': latestConfidence,
      'latest_timestamp': latestTimestamp?.toIso8601String(),
      'detection_count': detectionCount,
    };
  }

  AiDetectionSummaryModel copyWith({
    int? projectId,
    int? latestPeopleDetected,
    String? latestActivity,
    double? latestConfidence,
    DateTime? latestTimestamp,
    int? detectionCount,
  }) {
    return AiDetectionSummaryModel(
      projectId: projectId ?? this.projectId,
      latestPeopleDetected:
          latestPeopleDetected ?? this.latestPeopleDetected,
      latestActivity: latestActivity ?? this.latestActivity,
      latestConfidence: latestConfidence ?? this.latestConfidence,
      latestTimestamp: latestTimestamp ?? this.latestTimestamp,
      detectionCount: detectionCount ?? this.detectionCount,
    );
  }

  @override
  String toString() =>
      'AiDetectionSummaryModel(project_id: $projectId, count: $detectionCount, latest_people: $latestPeopleDetected, activity: $latestActivity)';
}
