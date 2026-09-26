import '../core/error/app_exception.dart';
import '../core/network/api_client.dart';
import '../core/network/api_endpoints.dart';
import '../shared/models/cctv_camera_model.dart';
import 'project_repository.dart';

abstract class CctvRepository {
  Future<List<CctvCamera>> getCameras({String? facilityId});
  Future<CctvCamera?> getCameraById(dynamic cameraId);
  Future<CctvCamera> createCamera(Map<String, dynamic> cameraData);
  Future<CctvCamera> updateCameraStatus(dynamic cameraId, String status);
}

class MockCctvRepository implements CctvRepository {
  final List<CctvCamera> _cameras = [
    CctvCamera(
      id: 'cam_1',
      facilityId: 'DSJ-AG-1042',
      facilityName: 'District Rehabilitation & Support Centre (Agra)',
      name: 'CAM-01: Main Entrance & Reception',
      isOnline: true,
      streamUrl: 'https://stream.sentinel.gov.in/live/cam_1.m3u8',
      resolution: '1080p',
      fps: 30,
      lastPing: DateTime.now(),
    ),
    CctvCamera(
      id: 'cam_2',
      facilityId: 'DSJ-AG-1042',
      facilityName: 'District Rehabilitation & Support Centre (Agra)',
      name: 'CAM-02: Vocational Training Hall',
      isOnline: true,
      streamUrl: 'https://stream.sentinel.gov.in/live/cam_2.m3u8',
      resolution: '1080p',
      fps: 30,
      lastPing: DateTime.now(),
    ),
    CctvCamera(
      id: 'cam_3',
      facilityId: 'DSJ-AG-1042',
      facilityName: 'District Rehabilitation & Support Centre (Agra)',
      name: 'CAM-03: Nutrition & Dining Area',
      isOnline: true,
      streamUrl: 'https://stream.sentinel.gov.in/live/cam_3.m3u8',
      resolution: '720p',
      fps: 25,
      lastPing: DateTime.now(),
    ),
    CctvCamera(
      id: 'cam_4',
      facilityId: 'DSJ-AG-1042',
      facilityName: 'District Rehabilitation & Support Centre (Agra)',
      name: 'CAM-04: Living Quarters Corridor',
      isOnline: true,
      streamUrl: 'https://stream.sentinel.gov.in/live/cam_4.m3u8',
      resolution: '1080p',
      fps: 30,
      lastPing: DateTime.now(),
    ),
    CctvCamera(
      id: 'cam_5',
      facilityId: 'DSJ-VR-2089',
      facilityName: 'Integrated Child Development (Varanasi)',
      name: 'CAM-01: Activity Room',
      isOnline: true,
      streamUrl: 'https://stream.sentinel.gov.in/live/cam_5.m3u8',
      resolution: '1080p',
      fps: 30,
      lastPing: DateTime.now(),
    ),
  ];

  @override
  Future<List<CctvCamera>> getCameras({String? facilityId}) async {
    await Future.delayed(const Duration(milliseconds: 100));
    if (facilityId != null && facilityId.isNotEmpty) {
      return _cameras.where((c) => c.facilityId == facilityId).toList();
    }
    return List.unmodifiable(_cameras);
  }

  @override
  Future<CctvCamera?> getCameraById(dynamic cameraId) async {
    await Future.delayed(const Duration(milliseconds: 100));
    final idStr = cameraId.toString();
    try {
      return _cameras.firstWhere((c) => c.id == idStr);
    } catch (_) {
      return null;
    }
  }

  @override
  Future<CctvCamera> createCamera(Map<String, dynamic> cameraData) async {
    await Future.delayed(const Duration(milliseconds: 100));
    final newCam = CctvCamera(
      id: 'cam_${_cameras.length + 1}',
      facilityId: (cameraData['project_id'] ?? cameraData['facilityId'] ?? '').toString(),
      facilityName: 'Registered Facility',
      name: (cameraData['camera_name'] ?? cameraData['name'] ?? 'New Camera').toString(),
      status: (cameraData['status'] ?? 'ACTIVE').toString(),
      isOnline: (cameraData['status'] ?? 'ACTIVE').toString().toUpperCase() == 'ACTIVE',
      streamUrl: (cameraData['stream_url'] ?? cameraData['streamUrl'] ?? '').toString(),
      videoPath: cameraData['video_path'] as String?,
      resolution: '1080p',
      fps: 30,
      lastPing: DateTime.now(),
      lastActive: DateTime.now(),
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );
    _cameras.add(newCam);
    return newCam;
  }

  @override
  Future<CctvCamera> updateCameraStatus(dynamic cameraId, String status) async {
    await Future.delayed(const Duration(milliseconds: 100));
    final idStr = cameraId.toString();
    final index = _cameras.indexWhere((c) => c.id == idStr);
    if (index == -1) throw Exception('Camera not found');
    final updated = _cameras[index].copyWith(
      status: status,
      isOnline: status.toUpperCase() == 'ACTIVE',
      lastActive: status.toUpperCase() == 'ACTIVE' ? DateTime.now() : _cameras[index].lastActive,
      updatedAt: DateTime.now(),
    );
    _cameras[index] = updated;
    return updated;
  }
}

class ApiCctvRepository implements CctvRepository {
  final ApiClient apiClient;
  final ProjectRepository? projectRepository;

  ApiCctvRepository({
    required this.apiClient,
    this.projectRepository,
  });

  @override
  Future<List<CctvCamera>> getCameras({String? facilityId}) async {
    if (facilityId != null && facilityId.isNotEmpty) {
      dynamic targetId = facilityId;
      // If facilityId is not numeric (e.g. project code DSJ-AG-1042), resolve to numeric ID
      if (int.tryParse(facilityId.toString()) == null && projectRepository != null) {
        final project = await projectRepository!.getProjectById(facilityId);
        if (project == null || int.tryParse(project.id) == null) {
          return [];
        }
        targetId = project.id;
      }

      try {
        final response = await apiClient.get(ApiEndpoints.cctvByProject(targetId));
        final list = response.data as List<dynamic>? ?? [];
        return list
            .map((e) => CctvCamera.fromJson(e as Map<String, dynamic>))
            .toList();
      } on NotFoundException {
        return [];
      }
    }

    // When facilityId is null ("All Facilities Nationwide"), aggregate across registered projects
    if (projectRepository != null) {
      final projects = await projectRepository!.getProjects(limit: 50);
      final allCameras = <CctvCamera>[];
      for (final p in projects) {
        if (int.tryParse(p.id) != null) {
          try {
            final response = await apiClient.get(ApiEndpoints.cctvByProject(p.id));
            final list = response.data as List<dynamic>? ?? [];
            for (final item in list) {
              final cam = CctvCamera.fromJson(item as Map<String, dynamic>);
              allCameras.add(cam.copyWith(facilityName: p.name));
            }
          } catch (_) {
            // Gracefully ignore individual facility failure
          }
        }
      }
      return allCameras;
    }

    return [];
  }

  @override
  Future<CctvCamera?> getCameraById(dynamic cameraId) async {
    try {
      final response = await apiClient.get(ApiEndpoints.cctvById(cameraId));
      if (response.data == null) return null;
      return CctvCamera.fromJson(response.data as Map<String, dynamic>);
    } on NotFoundException {
      return null;
    }
  }

  @override
  Future<CctvCamera> createCamera(Map<String, dynamic> cameraData) async {
    final response = await apiClient.post(
      ApiEndpoints.cctv,
      data: cameraData,
    );
    return CctvCamera.fromJson(response.data as Map<String, dynamic>);
  }

  @override
  Future<CctvCamera> updateCameraStatus(dynamic cameraId, String status) async {
    final response = await apiClient.put(
      ApiEndpoints.cctvStatus(cameraId),
      data: {'status': status},
    );
    return CctvCamera.fromJson(response.data as Map<String, dynamic>);
  }
}
