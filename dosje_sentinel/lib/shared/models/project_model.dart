class ProjectModel {
  final String id;
  final String code;
  final String name;
  final String category;
  final String organizationId;
  final String organizationName;
  final String organizationCode;
  final String district;
  final String state;
  final String address;
  final String status; // ACTIVE, UNDER_REVIEW, COMPLETED, PLANNED, DELAYED, AT_RISK
  final bool hasActiveInspection;
  final String? activeInspectionId;
  final String? activeInspectionType;
  final bool cctvOnline;
  final int cctvActiveCameras;
  final int cctvTotalCameras;
  final DateTime? lastInspectionDate;
  final String? assignedNodalOfficer;
  final String? nodalOfficerDesignation;
  final String? description;
  final double progress;
  final double? latitude;
  final double? longitude;
  final DateTime? startDate;
  final DateTime? expectedEndDate;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  const ProjectModel({
    required this.id,
    required this.code,
    required this.name,
    required this.category,
    this.organizationId = 'org_8821',
    this.organizationName = 'Samarpan Welfare Society',
    this.organizationCode = 'NGO-UP-8821',
    this.district = 'Central',
    this.state = 'State',
    this.address = '',
    this.status = 'ACTIVE',
    this.hasActiveInspection = false,
    this.activeInspectionId,
    this.activeInspectionType,
    this.cctvOnline = true,
    this.cctvActiveCameras = 4,
    this.cctvTotalCameras = 4,
    this.lastInspectionDate,
    this.assignedNodalOfficer,
    this.nodalOfficerDesignation,
    this.description,
    this.progress = 0.0,
    this.latitude,
    this.longitude,
    this.startDate,
    this.expectedEndDate,
    this.createdAt,
    this.updatedAt,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'project_name': name,
      'project_code': code,
      'description': description,
      'location': address,
      'department': category,
      'status': status,
      'progress': progress,
      'latitude': latitude,
      'longitude': longitude,
      'start_date': startDate?.toIso8601String().split('T').first,
      'expected_end_date': expectedEndDate?.toIso8601String().split('T').first,
      'organizationId': organizationId,
      'organizationName': organizationName,
      'organizationCode': organizationCode,
      'district': district,
      'state': state,
      'address': address,
      'hasActiveInspection': hasActiveInspection,
      'activeInspectionId': activeInspectionId,
      'activeInspectionType': activeInspectionType,
      'cctvOnline': cctvOnline,
      'cctvActiveCameras': cctvActiveCameras,
      'cctvTotalCameras': cctvTotalCameras,
      'lastInspectionDate': lastInspectionDate?.toIso8601String(),
      'assignedNodalOfficer': assignedNodalOfficer,
      'nodalOfficerDesignation': nodalOfficerDesignation,
    };
  }

  factory ProjectModel.fromJson(Map<String, dynamic> json) {
    // If backend returns wrapped project (from /summary)
    final Map<String, dynamic> data =
        (json.containsKey('project') && json['project'] is Map<String, dynamic>)
            ? json['project'] as Map<String, dynamic>
            : json;

    final idStr = (data['id'] ?? '').toString();
    final nameStr =
        (data['project_name'] ?? data['name'] ?? 'Unnamed Project').toString();
    final codeStr =
        (data['project_code'] ?? data['code'] ?? 'DSJ-PRJ-$idStr').toString();
    final categoryStr =
        (data['department'] ?? data['category'] ?? 'Social Welfare').toString();
    final addressStr =
        (data['location'] ?? data['address'] ?? '').toString();

    // Parse district & state heuristics if not directly present
    String districtStr = (data['district'] ?? '').toString();
    String stateStr = (data['state'] ?? '').toString();
    if (districtStr.isEmpty && addressStr.isNotEmpty) {
      final parts = addressStr.split(',').map((s) => s.trim()).toList();
      if (parts.length >= 2) {
        districtStr = parts[parts.length - 2];
        stateStr = parts.last.replaceAll(RegExp(r'[\d\-]'), '').trim();
      } else {
        districtStr = addressStr;
        stateStr = 'India';
      }
    }
    if (districtStr.isEmpty) districtStr = 'District Headquarters';
    if (stateStr.isEmpty) stateStr = 'State Jurisdiction';

    // Parse numeric fields safely
    final progressVal = data['progress'] != null
        ? (double.tryParse(data['progress'].toString()) ?? 0.0)
        : 0.0;
    final latVal = data['latitude'] != null
        ? double.tryParse(data['latitude'].toString())
        : null;
    final lngVal = data['longitude'] != null
        ? double.tryParse(data['longitude'].toString())
        : null;

    // Handle nested summary if passed directly
    int totalCams = data['cctvTotalCameras'] as int? ?? 4;
    int activeCams = data['cctvActiveCameras'] as int? ?? 4;
    if (json.containsKey('cctv') && json['cctv'] is Map) {
      final cctv = json['cctv'] as Map;
      totalCams = cctv['total_cameras'] as int? ?? totalCams;
      activeCams = cctv['active_cameras'] as int? ?? activeCams;
    }

    return ProjectModel(
      id: idStr,
      code: codeStr,
      name: nameStr,
      category: categoryStr,
      organizationId: data['organizationId'] as String? ?? 'org_8821',
      organizationName:
          data['organizationName'] as String? ?? 'Samarpan Welfare Society',
      organizationCode:
          data['organizationCode'] as String? ?? 'NGO-UP-8821',
      district: districtStr,
      state: stateStr,
      address: addressStr,
      status: (data['status'] ?? 'ACTIVE').toString(),
      hasActiveInspection: data['hasActiveInspection'] as bool? ?? false,
      activeInspectionId: data['activeInspectionId'] as String?,
      activeInspectionType: data['activeInspectionType'] as String?,
      cctvOnline: data['cctvOnline'] as bool? ?? true,
      cctvActiveCameras: activeCams,
      cctvTotalCameras: totalCams,
      lastInspectionDate: data['lastInspectionDate'] != null
          ? DateTime.tryParse(data['lastInspectionDate'].toString())
          : null,
      assignedNodalOfficer: data['assignedNodalOfficer'] as String?,
      nodalOfficerDesignation: data['nodalOfficerDesignation'] as String?,
      description: data['description'] as String?,
      progress: progressVal,
      latitude: latVal,
      longitude: lngVal,
      startDate: data['start_date'] != null
          ? DateTime.tryParse(data['start_date'].toString())
          : null,
      expectedEndDate: data['expected_end_date'] != null
          ? DateTime.tryParse(data['expected_end_date'].toString())
          : null,
      createdAt: data['created_at'] != null
          ? DateTime.tryParse(data['created_at'].toString())
          : null,
      updatedAt: data['updated_at'] != null
          ? DateTime.tryParse(data['updated_at'].toString())
          : null,
    );
  }
}

class ProjectSummaryModel {
  final ProjectModel project;
  final int? riskScore;
  final String? riskLevel;
  final int? expectedWorkers;
  final int? detectedWorkers;
  final double? attendancePercentage;
  final int totalAlerts;
  final int activeAlerts;
  final int totalInspections;
  final int pendingInspections;
  final int completedInspections;
  final int totalCameras;
  final int activeCameras;

  const ProjectSummaryModel({
    required this.project,
    this.riskScore,
    this.riskLevel,
    this.expectedWorkers,
    this.detectedWorkers,
    this.attendancePercentage,
    this.totalAlerts = 0,
    this.activeAlerts = 0,
    this.totalInspections = 0,
    this.pendingInspections = 0,
    this.completedInspections = 0,
    this.totalCameras = 0,
    this.activeCameras = 0,
  });

  factory ProjectSummaryModel.fromJson(Map<String, dynamic> json) {
    final proj = ProjectModel.fromJson(json);

    final risk = json['risk'] as Map<String, dynamic>? ?? {};
    final attendance = json['attendance'] as Map<String, dynamic>? ?? {};
    final alerts = json['alerts'] as Map<String, dynamic>? ?? {};
    final inspections = json['inspections'] as Map<String, dynamic>? ?? {};
    final cctv = json['cctv'] as Map<String, dynamic>? ?? {};

    return ProjectSummaryModel(
      project: proj,
      riskScore: risk['score'] as int?,
      riskLevel: risk['level'] as String?,
      expectedWorkers: attendance['expected_workers'] as int?,
      detectedWorkers: attendance['detected_workers'] as int?,
      attendancePercentage: attendance['percentage'] != null
          ? double.tryParse(attendance['percentage'].toString())
          : null,
      totalAlerts: alerts['total'] as int? ?? 0,
      activeAlerts: alerts['active'] as int? ?? 0,
      totalInspections: inspections['total'] as int? ?? 0,
      pendingInspections: inspections['pending'] as int? ?? 0,
      completedInspections: inspections['completed'] as int? ?? 0,
      totalCameras: cctv['total_cameras'] as int? ?? 0,
      activeCameras: cctv['active_cameras'] as int? ?? 0,
    );
  }
}

