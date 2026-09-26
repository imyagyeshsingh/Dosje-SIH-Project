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
  NgoProfileModel _profile = const NgoProfileModel(
    id: 'ngo_8821',
    fullName: 'Shri Rajesh Sharma',
    designation: 'Authorized Project Director',
    mobileNumber: '+91 98712 34567',
    email: 'rep.officer@samarpan-ngo.org',
    ngoName: 'Samarpan Welfare Society',
    organizationType: 'Registered Society',
    registrationNumber: 'NGO-UP-8821',
    establishmentYear: 2018,
    contactNumber: '+91 562 2891000',
    officialEmail: 'info@samarpan-ngo.org',
    address: 'Plot 14, Sanjay Place',
    state: 'Uttar Pradesh',
    district: 'Agra',
    city: 'Agra',
    pinCode: '282002',
    status: NgoRegistrationStatus.approved,
  );

  @override
  Future<NgoProfileModel?> getMyProfile() async {
    await Future.delayed(const Duration(milliseconds: 300));
    return _profile;
  }

  @override
  Future<NgoRegistrationStatus> getRegistrationStatus() async {
    await Future.delayed(const Duration(milliseconds: 200));
    return _profile.status;
  }

  @override
  Future<NgoProfileModel> createProfile(NgoProfileModel profile) async {
    await Future.delayed(const Duration(milliseconds: 400));
    _profile = profile.copyWith(
      id: 'ngo_${DateTime.now().millisecondsSinceEpoch}',
      status: NgoRegistrationStatus.incomplete,
    );
    return _profile;
  }

  @override
  Future<NgoProfileModel> updateProfile(NgoProfileModel profile) async {
    await Future.delayed(const Duration(milliseconds: 400));
    _profile = profile;
    return _profile;
  }

  @override
  Future<NgoProfileModel> submitRegistration(String ngoId) async {
    await Future.delayed(const Duration(milliseconds: 500));
    _profile = _profile.copyWith(
      status: NgoRegistrationStatus.submitted,
      submittedAt: DateTime.now(),
    );
    return _profile;
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
    final response = await apiClient.post(ApiEndpoints.ngoSubmitRegistration);
    return NgoProfileModel.fromJson(response.data as Map<String, dynamic>);
  }
}
