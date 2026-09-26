import 'dart:convert';

class AuditLogModel {
  final int id;
  final int? projectId;
  final String entityType;
  final int? entityId;
  final String action;
  final String? actorId;
  final String? actorName;
  final String? details;
  final DateTime createdAt;

  const AuditLogModel({
    required this.id,
    this.projectId,
    required this.entityType,
    this.entityId,
    required this.action,
    this.actorId,
    this.actorName,
    this.details,
    required this.createdAt,
  });

  factory AuditLogModel.fromJson(Map<String, dynamic> json) {
    String? parsedDetails;
    if (json['details'] != null) {
      if (json['details'] is String) {
        parsedDetails = json['details'] as String;
      } else {
        parsedDetails = jsonEncode(json['details']);
      }
    }

    return AuditLogModel(
      id: json['id'] as int,
      projectId: json['project_id'] as int?,
      entityType: (json['entity_type'] ?? '') as String,
      entityId: json['entity_id'] as int?,
      action: (json['action'] ?? '') as String,
      actorId: json['actor_id'] as String?,
      actorName: json['actor_name'] as String?,
      details: parsedDetails,
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'] as String)
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      if (projectId != null) 'project_id': projectId,
      'entity_type': entityType,
      if (entityId != null) 'entity_id': entityId,
      'action': action,
      if (actorId != null) 'actor_id': actorId,
      if (actorName != null) 'actor_name': actorName,
      if (details != null) 'details': details,
      'created_at': createdAt.toIso8601String(),
    };
  }

  /// Helpful display getters
  String get actorDisplay {
    if (actorName != null && actorName!.trim().isNotEmpty) {
      if (actorId != null && actorId!.trim().isNotEmpty) {
        return '$actorName ($actorId)';
      }
      return actorName!;
    }
    if (actorId != null && actorId!.trim().isNotEmpty) {
      return actorId!;
    }
    return 'System Engine';
  }

  String get displayTitle => '$entityType • $action';

  String get formattedDate {
    final y = createdAt.year.toString().padLeft(4, '0');
    final m = createdAt.month.toString().padLeft(2, '0');
    final d = createdAt.day.toString().padLeft(2, '0');
    final hr = createdAt.hour.toString().padLeft(2, '0');
    final min = createdAt.minute.toString().padLeft(2, '0');
    return '$y-$m-$d $hr:$min';
  }

  AuditLogModel copyWith({
    int? id,
    int? projectId,
    String? entityType,
    int? entityId,
    String? action,
    String? actorId,
    String? actorName,
    String? details,
    DateTime? createdAt,
  }) {
    return AuditLogModel(
      id: id ?? this.id,
      projectId: projectId ?? this.projectId,
      entityType: entityType ?? this.entityType,
      entityId: entityId ?? this.entityId,
      action: action ?? this.action,
      actorId: actorId ?? this.actorId,
      actorName: actorName ?? this.actorName,
      details: details ?? this.details,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  @override
  String toString() =>
      'AuditLogModel(id: $id, project: $projectId, entity: $entityType #$entityId, action: $action, actor: $actorDisplay)';
}
