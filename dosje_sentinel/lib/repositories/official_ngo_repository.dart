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
  final List<NgoProfileModel> _ngos = [
    NgoProfileModel(
      id: 'ngo_8821',
      fullName: 'Shri Rajesh Sharma',
      designation: 'Project Director',
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
      submittedAt: DateTime(2026, 8, 14),
      reviewedAt: DateTime(2026, 8, 16),
      reviewNotes:
          'Verified compliant under district social welfare guidelines.',
    ),
    NgoProfileModel(
      id: 'ngo_3012',
      fullName: 'Smt. Vandana Mishra',
      designation: 'Managing Trustee',
      mobileNumber: '+91 94150 99881',
      email: 'director@childhope-varanasi.org',
      ngoName: 'Child Hope Foundation',
      organizationType: 'Public Charitable Trust',
      registrationNumber: 'NGO-UP-3012',
      establishmentYear: 2015,
      contactNumber: '+91 542 2218700',
      officialEmail: 'contact@childhope-varanasi.org',
      address: 'B-42, Sigra Road',
      state: 'Uttar Pradesh',
      district: 'Varanasi',
      city: 'Varanasi',
      pinCode: '221002',
      status: NgoRegistrationStatus.submitted,
      submittedAt: DateTime(2026, 9, 22),
    ),
    NgoProfileModel(
      id: 'ngo_4419',
      fullName: 'Dr. Ramesh Chandra',
      designation: 'General Secretary',
      mobileNumber: '+91 98390 12345',
      email: 'sec@sewasadan-lucknow.org',
      ngoName: 'Sewa Sadan Senior Care Mission',
      organizationType: 'Non-Profit Society',
      registrationNumber: 'NGO-UP-4419',
      establishmentYear: 2012,
      contactNumber: '+91 522 2309871',
      officialEmail: 'office@sewasadan-lucknow.org',
      address: '7/2, Hazratganj',
      state: 'Uttar Pradesh',
      district: 'Lucknow',
      city: 'Lucknow',
      pinCode: '226001',
      status: NgoRegistrationStatus.underReview,
      submittedAt: DateTime(2026, 9, 18),
      reviewedAt: DateTime(2026, 9, 21),
      reviewNotes: 'Under review by District Social Welfare Directorate.',
    ),
  ];

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
