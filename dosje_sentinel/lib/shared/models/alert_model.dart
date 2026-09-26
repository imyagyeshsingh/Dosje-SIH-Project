enum AlertType {
  risk,
  aiActivity,
  attendance,
  camera;

  String get value {
    switch (this) {
      case AlertType.risk:
        return 'RISK';
      case AlertType.aiActivity:
        return 'AI_ACTIVITY';
      case AlertType.attendance:
        return 'ATTENDANCE';
      case AlertType.camera:
        return 'CAMERA';
    }
  }

  static AlertType fromString(String? val) {
    switch (val?.toUpperCase()) {
      case 'RISK':
        return AlertType.risk;
      case 'AI_ACTIVITY':
        return AlertType.aiActivity;
      case 'ATTENDANCE':
        return AlertType.attendance;
      case 'CAMERA':
      default:
        return AlertType.camera;
    }
  }
}

enum AlertSeverity {
  low,
  medium,
  high,
  critical;

  String get value {
    switch (this) {
      case AlertSeverity.low:
        return 'LOW';
      case AlertSeverity.medium:
        return 'MEDIUM';
      case AlertSeverity.high:
        return 'HIGH';
      case AlertSeverity.critical:
        return 'CRITICAL';
    }
  }

  static AlertSeverity fromString(String? val) {
    switch (val?.toUpperCase()) {
      case 'CRITICAL':
        return AlertSeverity.critical;
      case 'HIGH':
        return AlertSeverity.high;
      case 'MEDIUM':
        return AlertSeverity.medium;
      case 'LOW':
      default:
        return AlertSeverity.low;
    }
  }
}

enum AlertStatus {
  open,
  acknowledged,
  resolved;

  String get value {
    switch (this) {
      case AlertStatus.open:
        return 'OPEN';
      case AlertStatus.acknowledged:
        return 'ACKNOWLEDGED';
      case AlertStatus.resolved:
        return 'RESOLVED';
    }
  }

  static AlertStatus fromString(String? val) {
    switch (val?.toUpperCase()) {
      case 'ACKNOWLEDGED':
        return AlertStatus.acknowledged;
      case 'RESOLVED':
        return AlertStatus.resolved;
      case 'OPEN':
      default:
        return AlertStatus.open;
    }
  }
}

class AlertModel {
  final int id;
  final int projectId;
  final String alertType;
  final String severity;
  final String message;
  final double? confidence;
  final String status;
  final String? source;
  final int? detectionId;
  final DateTime createdAt;
  final DateTime updatedAt;

  const AlertModel({
    required this.id,
    required this.projectId,
    required this.alertType,
    required this.severity,
    required this.message,
    this.confidence,
    required this.status,
    this.source,
    this.detectionId,
    required this.createdAt,
    required this.updatedAt,
  });

  AlertType get typeEnum => AlertType.fromString(alertType);
  AlertSeverity get severityEnum => AlertSeverity.fromString(severity);
  AlertStatus get statusEnum => AlertStatus.fromString(status);

  factory AlertModel.fromJson(Map<String, dynamic> json) {
    return AlertModel(
      id: json['id'] as int? ?? 0,
      projectId: json['project_id'] as int? ?? 0,
      alertType: json['alert_type'] as String? ?? 'RISK',
      severity: json['severity'] as String? ?? 'LOW',
      message: json['message'] as String? ?? '',
      confidence: (json['confidence'] as num?)?.toDouble(),
      status: json['status'] as String? ?? 'OPEN',
      source: json['source'] as String?,
      detectionId: json['detection_id'] as int?,
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
      'alert_type': alertType,
      'severity': severity,
      'message': message,
      'confidence': confidence,
      'status': status,
      'source': source,
      'detection_id': detectionId,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  AlertModel copyWith({
    int? id,
    int? projectId,
    String? alertType,
    String? severity,
    String? message,
    double? confidence,
    String? status,
    String? source,
    int? detectionId,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return AlertModel(
      id: id ?? this.id,
      projectId: projectId ?? this.projectId,
      alertType: alertType ?? this.alertType,
      severity: severity ?? this.severity,
      message: message ?? this.message,
      confidence: confidence ?? this.confidence,
      status: status ?? this.status,
      source: source ?? this.source,
      detectionId: detectionId ?? this.detectionId,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
