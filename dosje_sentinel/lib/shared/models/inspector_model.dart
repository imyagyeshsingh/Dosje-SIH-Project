class InspectorModel {
  final int id;
  final String inspectorId;
  final String inspectorName;
  final bool isActive;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  const InspectorModel({
    required this.id,
    required this.inspectorId,
    required this.inspectorName,
    this.isActive = true,
    this.createdAt,
    this.updatedAt,
  });

  factory InspectorModel.fromJson(Map<String, dynamic> json) {
    return InspectorModel(
      id: json['id'] is int
          ? json['id'] as int
          : int.tryParse(json['id']?.toString() ?? '0') ?? 0,
      inspectorId: json['inspector_id'] as String? ?? '',
      inspectorName: json['inspector_name'] as String? ?? '',
      isActive: json['is_active'] as bool? ?? true,
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'].toString())
          : null,
      updatedAt: json['updated_at'] != null
          ? DateTime.tryParse(json['updated_at'].toString())
          : null,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'inspector_id': inspectorId,
    'inspector_name': inspectorName,
    'is_active': isActive,
    'created_at': createdAt?.toIso8601String(),
    'updated_at': updatedAt?.toIso8601String(),
  };
}
