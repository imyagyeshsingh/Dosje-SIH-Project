import 'package:dio/dio.dart';

import '../core/network/api_client.dart';
import '../core/network/api_endpoints.dart';
import '../shared/models/evidence_model.dart';

abstract class EvidenceRepository {
  Future<List<EvidenceModel>> getEvidenceForInspection(
    dynamic inspectionId, {
    int limit = 50,
    int offset = 0,
  });

  Future<EvidenceModel> uploadInspectionEvidence({
    required dynamic inspectionId,
    required List<int> fileBytes,
    required String fileName,
    String? description,
    DateTime? capturedAt,
    double? latitude,
    double? longitude,
    double? locationAccuracy,
    void Function(double progress)? onProgress,
  });

  Future<EvidenceModel> submitEvidence(EvidenceModel evidence);
  Future<void> removeEvidence(String evidenceId);
}

class MockEvidenceRepository implements EvidenceRepository {
  final List<EvidenceModel> _evidenceList = [
    EvidenceModel(
      id: '101',
      inspectionId: '1',
      title: 'Attendance Register Morning Session',
      fileName: 'Attendance_Register_Morning.jpg',
      fileType: 'IMAGE',
      fileSizeBytes: 2400000,
      status: EvidenceStatus.uploaded,
      isGeoVerified: true,
      latitude: 27.1982,
      longitude: 78.0059,
      timestamp: DateTime.now().subtract(const Duration(minutes: 15)),
      sha256Hash: '8f4a21e12d90a78b54c0e6f3329184ba',
      remoteUrl: 'https://res.cloudinary.com/dosje-sentinel/image/upload/v1/mock/attendance.jpg',
      projectId: 1,
      mediaType: 'IMAGE',
      sourceType: 'UPLOAD',
      storageProvider: 'cloudinary',
      storagePublicId: 'mock/attendance',
    ),
    EvidenceModel(
      id: '102',
      inspectionId: '1',
      title: 'Nutrition & Kitchen Distribution Log',
      fileName: 'Kitchen_Distribution_Log.pdf',
      fileType: 'DOCUMENT',
      fileSizeBytes: 840000,
      status: EvidenceStatus.uploaded,
      isGeoVerified: true,
      latitude: 27.1982,
      longitude: 78.0059,
      timestamp: DateTime.now().subtract(const Duration(minutes: 12)),
      sha256Hash: '3c9b44a7810fc11894d87210e53a02bb',
      remoteUrl: 'https://res.cloudinary.com/dosje-sentinel/raw/upload/v1/mock/kitchen.pdf',
      projectId: 1,
      mediaType: 'DOCUMENT',
      sourceType: 'UPLOAD',
      storageProvider: 'cloudinary',
      storagePublicId: 'mock/kitchen',
    ),
  ];

  @override
  Future<List<EvidenceModel>> getEvidenceForInspection(
    dynamic inspectionId, {
    int limit = 50,
    int offset = 0,
  }) async {
    await Future.delayed(const Duration(milliseconds: 50));
    final idStr = inspectionId.toString();
    final filtered = _evidenceList.where((e) => e.inspectionId == idStr).toList();
    if (offset >= filtered.length) return [];
    final end = (offset + limit < filtered.length) ? offset + limit : filtered.length;
    return filtered.sublist(offset, end);
  }

  @override
  Future<EvidenceModel> uploadInspectionEvidence({
    required dynamic inspectionId,
    required List<int> fileBytes,
    required String fileName,
    String? description,
    DateTime? capturedAt,
    double? latitude,
    double? longitude,
    double? locationAccuracy,
    void Function(double progress)? onProgress,
  }) async {
    onProgress?.call(0.5);
    await Future.delayed(const Duration(milliseconds: 50));
    onProgress?.call(1.0);

    final newEvidence = EvidenceModel(
      id: '${_evidenceList.length + 101}',
      inspectionId: inspectionId.toString(),
      title: description ?? fileName,
      fileName: fileName,
      fileType: fileName.toUpperCase().endsWith('.PDF') ? 'DOCUMENT' : 'IMAGE',
      fileSizeBytes: fileBytes.length,
      status: EvidenceStatus.uploaded,
      isGeoVerified: latitude != null && longitude != null,
      latitude: latitude,
      longitude: longitude,
      locationAccuracy: locationAccuracy,
      timestamp: capturedAt ?? DateTime.now(),
      remoteUrl: 'https://res.cloudinary.com/dosje-sentinel/image/upload/v1/mock/$fileName',
      projectId: 1,
      mediaType: 'IMAGE',
      sourceType: 'UPLOAD',
      storageProvider: 'cloudinary',
      storagePublicId: 'mock/$fileName',
      description: description,
      uploadProgress: 1.0,
    );
    _evidenceList.add(newEvidence);
    return newEvidence;
  }

  @override
  Future<EvidenceModel> submitEvidence(EvidenceModel evidence) async {
    await Future.delayed(const Duration(milliseconds: 50));
    final updated = evidence.copyWith(
      status: EvidenceStatus.uploaded,
      sha256Hash: 'e921d8fbc4a${DateTime.now().millisecondsSinceEpoch}',
    );
    _evidenceList.add(updated);
    return updated;
  }

  @override
  Future<void> removeEvidence(String evidenceId) async {
    await Future.delayed(const Duration(milliseconds: 50));
    _evidenceList.removeWhere((e) => e.id == evidenceId);
  }
}

class ApiEvidenceRepository implements EvidenceRepository {
  final ApiClient apiClient;

  ApiEvidenceRepository({required this.apiClient});

  @override
  Future<List<EvidenceModel>> getEvidenceForInspection(
    dynamic inspectionId, {
    int limit = 50,
    int offset = 0,
  }) async {
    final response = await apiClient.get(
      ApiEndpoints.inspectionEvidence(inspectionId),
      queryParameters: {'limit': limit, 'offset': offset},
    );
    final list = response.data as List<dynamic>? ?? [];
    return list
        .map((e) => EvidenceModel.fromMediaJson(e as Map<String, dynamic>))
        .toList();
  }

  @override
  Future<EvidenceModel> uploadInspectionEvidence({
    required dynamic inspectionId,
    required List<int> fileBytes,
    required String fileName,
    String? description,
    DateTime? capturedAt,
    double? latitude,
    double? longitude,
    double? locationAccuracy,
    void Function(double progress)? onProgress,
  }) async {
    final formMap = <String, dynamic>{
      'file': MultipartFile.fromBytes(fileBytes, filename: fileName),
    };
    if (description != null && description.isNotEmpty) {
      formMap['description'] = description;
    }
    if (capturedAt != null) {
      formMap['captured_at'] = capturedAt.toIso8601String();
    }
    if (latitude != null) {
      formMap['latitude'] = latitude.toString();
    }
    if (longitude != null) {
      formMap['longitude'] = longitude.toString();
    }
    if (locationAccuracy != null) {
      formMap['location_accuracy'] = locationAccuracy.toString();
    }

    final formData = FormData.fromMap(formMap);

    final response = await apiClient.postMultipart(
      ApiEndpoints.inspectionEvidence(inspectionId),
      formData: formData,
      onSendProgress: (sent, total) {
        if (total > 0 && onProgress != null) {
          onProgress(sent / total);
        }
      },
    );

    return EvidenceModel.fromMediaJson(response.data as Map<String, dynamic>);
  }

  @override
  Future<EvidenceModel> submitEvidence(EvidenceModel evidence) async {
    // Legacy support
    return evidence;
  }

  @override
  Future<void> removeEvidence(String evidenceId) async {
    // Not directly exposed on backend media/evidence router
  }
}
