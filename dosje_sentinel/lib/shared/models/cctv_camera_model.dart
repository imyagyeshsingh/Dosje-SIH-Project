class CctvCamera {
  final String id;
  final String facilityId;
  final String facilityName;
  final String name;
  final String status; // 'ACTIVE', 'INACTIVE', 'OFFLINE'
  final bool isOnline;
  final String streamUrl;
  final String? videoPath;
  final String resolution;
  final int fps;
  final DateTime? lastActive;
  final DateTime lastPing;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  const CctvCamera({
    required this.id,
    required this.facilityId,
    required this.facilityName,
    required this.name,
    this.status = 'ACTIVE',
    required this.isOnline,
    required this.streamUrl,
    this.videoPath,
    this.resolution = '1080p',
    this.fps = 30,
    this.lastActive,
    required this.lastPing,
    this.createdAt,
    this.updatedAt,
  });

  CctvCamera copyWith({
    String? id,
    String? facilityId,
    String? facilityName,
    String? name,
    String? status,
    bool? isOnline,
    String? streamUrl,
    String? videoPath,
    String? resolution,
    int? fps,
    DateTime? lastActive,
    DateTime? lastPing,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) => CctvCamera(
    id: id ?? this.id,
    facilityId: facilityId ?? this.facilityId,
    facilityName: facilityName ?? this.facilityName,
    name: name ?? this.name,
    status: status ?? this.status,
    isOnline: isOnline ?? this.isOnline,
    streamUrl: streamUrl ?? this.streamUrl,
    videoPath: videoPath ?? this.videoPath,
    resolution: resolution ?? this.resolution,
    fps: fps ?? this.fps,
    lastActive: lastActive ?? this.lastActive,
    lastPing: lastPing ?? this.lastPing,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
  );

  /// Task 20: Camera is stale if ACTIVE and lastActive > 15 minutes ago.
  /// If lastActive is null (never activated since creation), it is not marked stale.
  bool get isStale {
    if (status != 'ACTIVE' || lastActive == null) return false;
    return DateTime.now().toUtc().difference(lastActive!.toUtc()) > const Duration(minutes: 15);
  }

  /// Authoritative tri-state health status: ACTIVE, STALE, or OFFLINE
  String get healthStatus {
    if (status == 'OFFLINE' || status == 'INACTIVE') return 'OFFLINE';
    if (isStale) return 'STALE';
    return 'ACTIVE';
  }

  /// Relative human-readable format for last ping/active timestamp
  String get formattedLastActive {
    if (lastActive == null) return 'Never';
    final diff = DateTime.now().toUtc().difference(lastActive!.toUtc());
    if (diff.isNegative || diff.inSeconds < 60) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return '${diff.inDays}d ago';
  }

  Map<String, dynamic> toJson() => {
    'id': int.tryParse(id) ?? id,
    'project_id': int.tryParse(facilityId) ?? facilityId,
    'facilityId': facilityId,
    'facilityName': facilityName,
    'camera_name': name,
    'name': name,
    'status': status,
    'isOnline': isOnline,
    'stream_url': streamUrl.isNotEmpty ? streamUrl : null,
    'streamUrl': streamUrl,
    'video_path': videoPath,
    'resolution': resolution,
    'fps': fps,
    'last_active': lastActive?.toIso8601String(),
    'lastPing': lastPing.toIso8601String(),
    'created_at': createdAt?.toIso8601String(),
    'updated_at': updatedAt?.toIso8601String(),
  };

  factory CctvCamera.fromJson(Map<String, dynamic> json) {
    final statusStr = (json['status'] ?? (json['isOnline'] == true ? 'ACTIVE' : 'OFFLINE'))
        .toString()
        .toUpperCase();
    final projId = (json['project_id'] ?? json['facilityId'] ?? '').toString();
    final camName = (json['camera_name'] ?? json['name'] ?? 'Unnamed Camera').toString();
    final sUrl = (json['stream_url'] ?? json['streamUrl'] ?? '').toString();
    final vPath = json['video_path'] as String?;
    final lastAct = json['last_active'] != null
        ? DateTime.tryParse(json['last_active'].toString())
        : (json['lastPing'] != null ? DateTime.tryParse(json['lastPing'].toString()) : null);
    final isOnlineVal = statusStr == 'ACTIVE' || json['isOnline'] == true;

    return CctvCamera(
      id: (json['id'] ?? '').toString(),
      facilityId: projId,
      facilityName: (json['facilityName'] ??
              json['facility_name'] ??
              (projId.isNotEmpty ? 'Facility #$projId' : 'General Facility'))
          .toString(),
      name: camName,
      status: statusStr,
      isOnline: isOnlineVal,
      streamUrl: sUrl,
      videoPath: vPath,
      resolution: json['resolution'] as String? ?? '1080p',
      fps: json['fps'] as int? ?? 30,
      lastActive: lastAct,
      lastPing: lastAct ??
          (json['lastPing'] != null
              ? DateTime.tryParse(json['lastPing'].toString()) ?? DateTime.now()
              : DateTime.now()),
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'].toString())
          : null,
      updatedAt: json['updated_at'] != null
          ? DateTime.tryParse(json['updated_at'].toString())
          : null,
    );
  }
}
