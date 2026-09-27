import '../core/network/api_client.dart';
import '../core/network/api_endpoints.dart';
import '../shared/models/ngo_profile_model.dart';
import '../shared/models/ngo_registration_status.dart';

abstract class NgoRepository {
  Future<NgoProfileModel?> getMyProfile();
  Future<NgoRegistrationStatus> getRegistrationStatus();
  Future<NgoProfileModel> createProfile(NgoProfileModel profile);
  Future<NgoProfileModel> updateProfile(NgoProfileModel profile);
  Future<NgoProfileModel> submitRegistration(String ngoId);
}

class MockNgoRepository implements NgoRepository {
  NgoProfileModel? _profile;

  MockNgoRepository({NgoProfileModel? initialProfile}) : _profile = initialProfile;

  @override
  Future<NgoProfileModel?> getMyProfile() async {
    await Future.delayed(const Duration(milliseconds: 300));
    return _profile;
  }

  @override
  Future<NgoRegistrationStatus> getRegistrationStatus() async {
    await Future.delayed(const Duration(milliseconds: 200));
    return _profile?.status ?? NgoRegistrationStatus.incomplete;
  }

  @override
  Future<NgoProfileModel> createProfile(NgoProfileModel profile) async {
    await Future.delayed(const Duration(milliseconds: 400));
    _profile = profile.copyWith(
      id: 'ngo_${DateTime.now().millisecondsSinceEpoch}',
      status: NgoRegistrationStatus.incomplete,
    );
    return _profile!;
  }

  @override
  Future<NgoProfileModel> updateProfile(NgoProfileModel profile) async {
    await Future.delayed(const Duration(milliseconds: 400));
    _profile = profile;
    return _profile!;
  }

  @override
  Future<NgoProfileModel> submitRegistration(String ngoId) async {
    await Future.delayed(const Duration(milliseconds: 500));
    _profile = (_profile ??
        NgoProfileModel(
          id: ngoId,
          fullName: '',
          designation: '',
          mobileNumber: '',
          email: '',
          ngoName: '',
          organizationType: '',
          registrationNumber: '',
          establishmentYear: 2026,
          contactNumber: '',
          officialEmail: '',
          address: '',
          state: '',
          district: '',
          city: '',
          pinCode: '',
          status: NgoRegistrationStatus.submitted,
        )).copyWith(
      status: NgoRegistrationStatus.submitted,
      submittedAt: DateTime.now(),
    );
    return _profile!;
  }
}

class ApiNgoRepository implements NgoRepository {
  final ApiClient apiClient;

  ApiNgoRepository({required this.apiClient});

  @override
  Future<NgoProfileModel?> getMyProfile() async {
    final response = await apiClient.get(ApiEndpoints.ngoMe);
    if (response.data == null) return null;
    return NgoProfileModel.fromJson(response.data as Map<String, dynamic>);
  }

  @override
  Future<NgoRegistrationStatus> getRegistrationStatus() async {
    final response = await apiClient.get(ApiEndpoints.ngoRegistrationStatus);
    final statusStr = response.data['status'] as String? ?? 'incomplete';
    return NgoRegistrationStatus.fromString(statusStr);
  }

  @override
  Future<NgoProfileModel> createProfile(NgoProfileModel profile) async {
    final response = await apiClient.post(
      ApiEndpoints.ngoProfile,
      data: profile.toJson(),
    );
    return NgoProfileModel.fromJson(response.data as Map<String, dynamic>);
  }

  @override
  Future<NgoProfileModel> updateProfile(NgoProfileModel profile) async {
    final response = await apiClient.patch(
      ApiEndpoints.ngoProfile,
      data: profile.toJson(),
    );
    return NgoProfileModel.fromJson(response.data as Map<String, dynamic>);
  }

  @override
  Future<NgoProfileModel> submitRegistration(String ngoId) async {
    final response = await apiClient.post(
      ApiEndpoints.ngoSubmitRegistration,
      data: {'id': ngoId},
    );
    return NgoProfileModel.fromJson(response.data as Map<String, dynamic>);
  }
}
