enum EvidenceStatus {
  selected,
  uploading,
  uploaded,
  underReview,
  accepted,
  requiresAction,
  rejected,
  uploadFailed;

  String get label {
    switch (this) {
      case EvidenceStatus.selected:
        return 'Selected';
      case EvidenceStatus.uploading:
        return 'Uploading';
      case EvidenceStatus.uploaded:
        return 'Uploaded';
      case EvidenceStatus.underReview:
        return 'Under Review';
      case EvidenceStatus.accepted:
        return 'Accepted';
      case EvidenceStatus.requiresAction:
        return 'Requires Action';
      case EvidenceStatus.rejected:
        return 'Rejected';
      case EvidenceStatus.uploadFailed:
        return 'Upload Failed';
    }
  }
}

class EvidenceModel {
  final String id;
  final String inspectionId;
  final String title;
  final String fileName;
  final String fileType; // JPG, PNG, PDF, MP4
  final int fileSizeBytes;
  final EvidenceStatus status;
  final bool isGeoVerified;
  final double? latitude;
  final double? longitude;
  final double? locationAccuracy;
  final DateTime timestamp;
  final String? sha256Hash; // Optional backend integrity metadata
  final String? remoteUrl;
  final String? localFilePath;
  final double uploadProgress; // 0.0 to 1.0

  // Backend Media entity parity fields
  final int? projectId;
  final int? cameraId;
  final String? mediaType; // IMAGE, VIDEO, DOCUMENT
  final String? sourceType; // UPLOAD, MANUAL, MANUAL_UPLOAD, AI_GENERATED
  final String? storageProvider;
  final String? storagePublicId;
  final String? description;
  final DateTime? createdAt;

  const EvidenceModel({
    required this.id,
    required this.inspectionId,
    required this.title,
    required this.fileName,
    required this.fileType,
    required this.fileSizeBytes,
    this.status = EvidenceStatus.selected,
    this.isGeoVerified = false,
    this.latitude,
    this.longitude,
    this.locationAccuracy,
    required this.timestamp,
    this.sha256Hash,
    this.remoteUrl,
    this.localFilePath,
    this.uploadProgress = 0.0,
    this.projectId,
    this.cameraId,
    this.mediaType,
    this.sourceType,
    this.storageProvider,
    this.storagePublicId,
    this.description,
    this.createdAt,
  });

  String get formattedSize {
    if (fileSizeBytes < 1024) return '$fileSizeBytes B';
    if (fileSizeBytes < 1024 * 1024) {
      return '${(fileSizeBytes / 1024).toStringAsFixed(1)} KB';
    }
    return '${(fileSizeBytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  EvidenceModel copyWith({
    String? id,
    String? inspectionId,
    String? title,
    String? fileName,
    String? fileType,
    int? fileSizeBytes,
    EvidenceStatus? status,
    bool? isGeoVerified,
    double? latitude,
    double? longitude,
    double? locationAccuracy,
    DateTime? timestamp,
    String? sha256Hash,
    String? remoteUrl,
    String? localFilePath,
    double? uploadProgress,
    int? projectId,
    int? cameraId,
    String? mediaType,
    String? sourceType,
    String? storageProvider,
    String? storagePublicId,
    String? description,
    DateTime? createdAt,
  }) {
    return EvidenceModel(
      id: id ?? this.id,
      inspectionId: inspectionId ?? this.inspectionId,
      title: title ?? this.title,
      fileName: fileName ?? this.fileName,
      fileType: fileType ?? this.fileType,
      fileSizeBytes: fileSizeBytes ?? this.fileSizeBytes,
      status: status ?? this.status,
      isGeoVerified: isGeoVerified ?? this.isGeoVerified,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      locationAccuracy: locationAccuracy ?? this.locationAccuracy,
      timestamp: timestamp ?? this.timestamp,
      sha256Hash: sha256Hash ?? this.sha256Hash,
      remoteUrl: remoteUrl ?? this.remoteUrl,
      localFilePath: localFilePath ?? this.localFilePath,
      uploadProgress: uploadProgress ?? this.uploadProgress,
      projectId: projectId ?? this.projectId,
      cameraId: cameraId ?? this.cameraId,
      mediaType: mediaType ?? this.mediaType,
      sourceType: sourceType ?? this.sourceType,
      storageProvider: storageProvider ?? this.storageProvider,
      storagePublicId: storagePublicId ?? this.storagePublicId,
      description: description ?? this.description,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'inspectionId': inspectionId,
    'title': title,
    'fileName': fileName,
    'fileType': fileType,
    'fileSizeBytes': fileSizeBytes,
    'status': status.name,
    'isGeoVerified': isGeoVerified,
    'latitude': latitude,
    'longitude': longitude,
    'locationAccuracy': locationAccuracy,
    'timestamp': timestamp.toIso8601String(),
    'sha256Hash': sha256Hash,
    'remoteUrl': remoteUrl,
    if (projectId != null) 'project_id': projectId,
    if (cameraId != null) 'camera_id': cameraId,
    if (mediaType != null) 'media_type': mediaType,
    if (sourceType != null) 'source_type': sourceType,
    if (storageProvider != null) 'storage_provider': storageProvider,
    if (storagePublicId != null) 'storage_public_id': storagePublicId,
    if (description != null) 'description': description,
    if (createdAt != null) 'created_at': createdAt!.toIso8601String(),
  };

  factory EvidenceModel.fromJson(Map<String, dynamic> json) {
    // Detect backend MediaResponse format
    if (json.containsKey('media_url') || json.containsKey('storage_public_id')) {
      return EvidenceModel.fromMediaJson(json);
    }

    return EvidenceModel(
      id: json['id']?.toString() ?? '',
      inspectionId: json['inspectionId']?.toString() ?? (json['inspection_id']?.toString() ?? ''),
      title: json['title'] as String? ?? (json['original_filename'] as String? ?? ''),
      fileName: json['fileName'] as String? ?? (json['original_filename'] as String? ?? ''),
      fileType: json['fileType'] as String? ?? (json['media_type'] as String? ?? 'JPG'),
      fileSizeBytes: json['fileSizeBytes'] as int? ?? (json['file_size'] as int? ?? 0),
      status: EvidenceStatus.values.firstWhere(
        (e) => e.name == json['status'],
        orElse: () => EvidenceStatus.selected,
      ),
      isGeoVerified: json['isGeoVerified'] as bool? ?? (json['latitude'] != null),
      latitude: (json['latitude'] as num?)?.toDouble(),
      longitude: (json['longitude'] as num?)?.toDouble(),
      locationAccuracy: (json['locationAccuracy'] as num?)?.toDouble() ??
          (json['location_accuracy'] as num?)?.toDouble(),
      timestamp:
          DateTime.tryParse(json['timestamp'] as String? ?? '') ?? DateTime.now(),
      sha256Hash: json['sha256Hash'] as String?,
      remoteUrl: json['remoteUrl'] as String? ?? (json['media_url'] as String?),
      projectId: json['project_id'] as int?,
      cameraId: json['camera_id'] as int?,
      mediaType: json['media_type'] as String?,
      sourceType: json['source_type'] as String?,
      storageProvider: json['storage_provider'] as String?,
      storagePublicId: json['storage_public_id'] as String?,
      description: json['description'] as String?,
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'].toString())
          : null,
    );
  }

  factory EvidenceModel.fromMediaJson(Map<String, dynamic> json) {
    final lat = (json['latitude'] as num?)?.toDouble();
    final lng = (json['longitude'] as num?)?.toDouble();
    final filename = json['original_filename'] as String? ?? 'media_${json['id']}';
    final desc = json['description'] as String?;
    final mediaType = json['media_type'] as String? ?? 'IMAGE';

    DateTime parsedTimestamp = DateTime.now();
    if (json['captured_at'] != null) {
      parsedTimestamp = DateTime.tryParse(json['captured_at'].toString()) ?? parsedTimestamp;
    } else if (json['created_at'] != null) {
      parsedTimestamp = DateTime.tryParse(json['created_at'].toString()) ?? parsedTimestamp;
    }

    return EvidenceModel(
      id: json['id']?.toString() ?? '',
      inspectionId: json['inspection_id']?.toString() ?? '',
      title: (desc != null && desc.isNotEmpty) ? desc : filename,
      fileName: filename,
      fileType: mediaType,
      fileSizeBytes: json['file_size'] as int? ?? 0,
      status: EvidenceStatus.uploaded,
      isGeoVerified: lat != null && lng != null,
      latitude: lat,
      longitude: lng,
      locationAccuracy: (json['location_accuracy'] as num?)?.toDouble(),
      timestamp: parsedTimestamp,
      remoteUrl: json['media_url'] as String?,
      projectId: json['project_id'] as int?,
      cameraId: json['camera_id'] as int?,
      mediaType: mediaType,
      sourceType: json['source_type'] as String?,
      storageProvider: json['storage_provider'] as String?,
      storagePublicId: json['storage_public_id'] as String?,
      description: desc,
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'].toString())
          : null,
      uploadProgress: 1.0,
    );
  }
}
