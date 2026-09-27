import '../core/network/api_client.dart';
import '../core/network/api_endpoints.dart';
import '../shared/models/ngo_profile_model.dart';
import '../shared/models/ngo_registration_status.dart';

abstract class OfficialNgoRepository {
  Future<List<NgoProfileModel>> getAllNgos();
  Future<NgoProfileModel?> getNgoDetails(String ngoId);
  Future<NgoProfileModel> approveRegistration(String ngoId);
  Future<NgoProfileModel> requestCorrection(String ngoId, String notes);
  void addRegisteredNgo(NgoProfileModel ngo); // For realtime event integration
}

class MockOfficialNgoRepository implements OfficialNgoRepository {
  final List<NgoProfileModel> _ngos;

  MockOfficialNgoRepository({List<NgoProfileModel>? initialNgos})
      : _ngos = initialNgos != null ? List.from(initialNgos) : [];

  @override
  Future<List<NgoProfileModel>> getAllNgos() async {
    await Future.delayed(const Duration(milliseconds: 300));
    return List.unmodifiable(_ngos);
  }

  @override
  Future<NgoProfileModel?> getNgoDetails(String ngoId) async {
    await Future.delayed(const Duration(milliseconds: 200));
    try {
      return _ngos.firstWhere((n) => n.id == ngoId);
    } catch (_) {
      return null;
    }
  }

  @override
  Future<NgoProfileModel> approveRegistration(String ngoId) async {
    await Future.delayed(const Duration(milliseconds: 400));
    final index = _ngos.indexWhere((n) => n.id == ngoId);
    if (index != -1) {
      _ngos[index] = _ngos[index].copyWith(
        status: NgoRegistrationStatus.approved,
        reviewedAt: DateTime.now(),
        reviewNotes: 'Approved by State Reviewing Authority.',
      );
      return _ngos[index];
    }
    throw Exception('NGO not found');
  }

  @override
  Future<NgoProfileModel> requestCorrection(String ngoId, String notes) async {
    await Future.delayed(const Duration(milliseconds: 400));
    final index = _ngos.indexWhere((n) => n.id == ngoId);
    if (index != -1) {
      _ngos[index] = _ngos[index].copyWith(
        status: NgoRegistrationStatus.correctionRequired,
        correctionNotes: notes,
        reviewedAt: DateTime.now(),
      );
      return _ngos[index];
    }
    throw Exception('NGO not found');
  }

  @override
  void addRegisteredNgo(NgoProfileModel ngo) {
    _ngos.insert(0, ngo);
  }
}

class ApiOfficialNgoRepository implements OfficialNgoRepository {
  final ApiClient apiClient;

  ApiOfficialNgoRepository({required this.apiClient});

  @override
  Future<List<NgoProfileModel>> getAllNgos() async {
    final response = await apiClient.get(ApiEndpoints.officialNgos);
    final list = response.data as List<dynamic>? ?? [];
    return list
        .map((e) => NgoProfileModel.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  @override
  Future<NgoProfileModel?> getNgoDetails(String ngoId) async {
    final response = await apiClient.get('${ApiEndpoints.officialNgos}/$ngoId');
    if (response.data == null) return null;
    return NgoProfileModel.fromJson(response.data as Map<String, dynamic>);
  }

  @override
  Future<NgoProfileModel> approveRegistration(String ngoId) async {
    final response = await apiClient.post(
      '${ApiEndpoints.officialNgos}/$ngoId/approve',
    );
    return NgoProfileModel.fromJson(response.data as Map<String, dynamic>);
  }

  @override
  Future<NgoProfileModel> requestCorrection(String ngoId, String notes) async {
    final response = await apiClient.post(
      '${ApiEndpoints.officialNgos}/$ngoId/correction',
      data: {'notes': notes},
    );
    return NgoProfileModel.fromJson(response.data as Map<String, dynamic>);
  }

  @override
  void addRegisteredNgo(NgoProfileModel ngo) {}
}
