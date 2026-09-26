class InspectionLocationModel {
  final int inspectionId;
  final int projectId;
  final double? inspectionLatitude;
  final double? inspectionLongitude;
  final double? locationAccuracy;
  final DateTime? locationCapturedAt;
  final bool locationVerified;
  final double? distanceFromProject;
  final double verificationRadiusMeters;

  const InspectionLocationModel({
    required this.inspectionId,
    required this.projectId,
    this.inspectionLatitude,
    this.inspectionLongitude,
    this.locationAccuracy,
    this.locationCapturedAt,
    this.locationVerified = false,
    this.distanceFromProject,
    this.verificationRadiusMeters = 50.0,
  });

  bool get hasLocation =>
      inspectionLatitude != null && inspectionLongitude != null;

  String get formattedCoordinates {
    if (!hasLocation) return 'No GPS fix';
    return '${inspectionLatitude!.toStringAsFixed(4)}° N, ${inspectionLongitude!.toStringAsFixed(4)}° E';
  }

  String get formattedDistance {
    if (distanceFromProject == null) return 'Distance unknown';
    if (distanceFromProject! < 1000) {
      return '${distanceFromProject!.toStringAsFixed(1)}m from perimeter';
    }
    return '${(distanceFromProject! / 1000).toStringAsFixed(2)}km from perimeter';
  }

  String get formattedAccuracy {
    if (locationAccuracy == null) return 'N/A';
    return '±${locationAccuracy!.toStringAsFixed(1)}m';
  }

  InspectionLocationModel copyWith({
    int? inspectionId,
    int? projectId,
    double? inspectionLatitude,
    double? inspectionLongitude,
    double? locationAccuracy,
    DateTime? locationCapturedAt,
    bool? locationVerified,
    double? distanceFromProject,
    double verificationRadiusMeters = 50.0,
  }) {
    return InspectionLocationModel(
      inspectionId: inspectionId ?? this.inspectionId,
      projectId: projectId ?? this.projectId,
      inspectionLatitude: inspectionLatitude ?? this.inspectionLatitude,
      inspectionLongitude: inspectionLongitude ?? this.inspectionLongitude,
      locationAccuracy: locationAccuracy ?? this.locationAccuracy,
      locationCapturedAt: locationCapturedAt ?? this.locationCapturedAt,
      locationVerified: locationVerified ?? this.locationVerified,
      distanceFromProject: distanceFromProject ?? this.distanceFromProject,
      verificationRadiusMeters: verificationRadiusMeters,
    );
  }

  factory InspectionLocationModel.fromJson(Map<String, dynamic> json) {
    return InspectionLocationModel(
      inspectionId: json['inspection_id'] is int
          ? json['inspection_id'] as int
          : int.tryParse(json['inspection_id']?.toString() ?? '0') ?? 0,
      projectId: json['project_id'] is int
          ? json['project_id'] as int
          : int.tryParse(json['project_id']?.toString() ?? '0') ?? 0,
      inspectionLatitude: json['inspection_latitude'] != null
          ? double.tryParse(json['inspection_latitude'].toString())
          : null,
      inspectionLongitude: json['inspection_longitude'] != null
          ? double.tryParse(json['inspection_longitude'].toString())
          : null,
      locationAccuracy: json['location_accuracy'] != null
          ? double.tryParse(json['location_accuracy'].toString())
          : null,
      locationCapturedAt: json['location_captured_at'] != null
          ? DateTime.tryParse(json['location_captured_at'].toString())
          : null,
      locationVerified: json['location_verified'] as bool? ?? false,
      distanceFromProject: json['distance_from_project'] != null
          ? double.tryParse(json['distance_from_project'].toString())
          : null,
      verificationRadiusMeters: json['verification_radius_meters'] != null
          ? double.tryParse(json['verification_radius_meters'].toString()) ?? 50.0
          : 50.0,
    );
  }

  Map<String, dynamic> toJson() => {
    'inspection_id': inspectionId,
    'project_id': projectId,
    'inspection_latitude': inspectionLatitude,
    'inspection_longitude': inspectionLongitude,
    'location_accuracy': locationAccuracy,
    'location_captured_at': locationCapturedAt?.toIso8601String(),
    'location_verified': locationVerified,
    'distance_from_project': distanceFromProject,
    'verification_radius_meters': verificationRadiusMeters,
  };
}
