import 'ngo_registration_status.dart';

class NgoProfileModel {
  final String id;
  // Representative Information
  final String fullName;
  final String designation;
  final String mobileNumber;
  final String email;

  // Organization Information
  final String ngoName;
  final String organizationType;
  final String registrationNumber;
  final int establishmentYear;
  final String contactNumber;
  final String officialEmail;

  // Address
  final String address;
  final String state;
  final String district;
  final String city;
  final String pinCode;

  // Workflow Status
  final NgoRegistrationStatus status;
  final DateTime? submittedAt;
  final DateTime? reviewedAt;
  final String? reviewNotes;
  final String? correctionNotes;

  String get organizationName => ngoName;
  String get representativeName => fullName;
  int get yearOfEstablishment => establishmentYear;
  String get officialContactNumber => contactNumber;

  const NgoProfileModel({
    required this.id,
    required this.fullName,
    required this.designation,
    required this.mobileNumber,
    required this.email,
    required this.ngoName,
    required this.organizationType,
    required this.registrationNumber,
    required this.establishmentYear,
    required this.contactNumber,
    required this.officialEmail,
    required this.address,
    required this.state,
    required this.district,
    required this.city,
    required this.pinCode,
    this.status = NgoRegistrationStatus.incomplete,
    this.submittedAt,
    this.reviewedAt,
    this.reviewNotes,
    this.correctionNotes,
  });

  NgoProfileModel copyWith({
    String? id,
    String? fullName,
    String? designation,
    String? mobileNumber,
    String? email,
    String? ngoName,
    String? organizationType,
    String? registrationNumber,
    int? establishmentYear,
    String? contactNumber,
    String? officialEmail,
    String? address,
    String? state,
    String? district,
    String? city,
    String? pinCode,
    NgoRegistrationStatus? status,
    DateTime? submittedAt,
    DateTime? reviewedAt,
    String? reviewNotes,
    String? correctionNotes,
  }) {
    return NgoProfileModel(
      id: id ?? this.id,
      fullName: fullName ?? this.fullName,
      designation: designation ?? this.designation,
      mobileNumber: mobileNumber ?? this.mobileNumber,
      email: email ?? this.email,
      ngoName: ngoName ?? this.ngoName,
      organizationType: organizationType ?? this.organizationType,
      registrationNumber: registrationNumber ?? this.registrationNumber,
      establishmentYear: establishmentYear ?? this.establishmentYear,
      contactNumber: contactNumber ?? this.contactNumber,
      officialEmail: officialEmail ?? this.officialEmail,
      address: address ?? this.address,
      state: state ?? this.state,
      district: district ?? this.district,
      city: city ?? this.city,
      pinCode: pinCode ?? this.pinCode,
      status: status ?? this.status,
      submittedAt: submittedAt ?? this.submittedAt,
      reviewedAt: reviewedAt ?? this.reviewedAt,
      reviewNotes: reviewNotes ?? this.reviewNotes,
      correctionNotes: correctionNotes ?? this.correctionNotes,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'fullName': fullName,
      'designation': designation,
      'mobileNumber': mobileNumber,
      'email': email,
      'ngoName': ngoName,
      'organizationType': organizationType,
      'registrationNumber': registrationNumber,
      'establishmentYear': establishmentYear,
      'contactNumber': contactNumber,
      'officialEmail': officialEmail,
      'address': address,
      'state': state,
      'district': district,
      'city': city,
      'pinCode': pinCode,
      'status': status.name,
      'submittedAt': submittedAt?.toIso8601String(),
      'reviewedAt': reviewedAt?.toIso8601String(),
      'reviewNotes': reviewNotes,
      'correctionNotes': correctionNotes,
    };
  }

  factory NgoProfileModel.fromJson(Map<String, dynamic> json) {
    return NgoProfileModel(
      id: json['id'] as String? ?? '',
      fullName: json['fullName'] as String? ?? '',
      designation: json['designation'] as String? ?? '',
      mobileNumber: json['mobileNumber'] as String? ?? '',
      email: json['email'] as String? ?? '',
      ngoName: json['ngoName'] as String? ?? '',
      organizationType: json['organizationType'] as String? ?? '',
      registrationNumber: json['registrationNumber'] as String? ?? '',
      establishmentYear: json['establishmentYear'] as int? ?? 2020,
      contactNumber: json['contactNumber'] as String? ?? '',
      officialEmail: json['officialEmail'] as String? ?? '',
      address: json['address'] as String? ?? '',
      state: json['state'] as String? ?? '',
      district: json['district'] as String? ?? '',
      city: json['city'] as String? ?? '',
      pinCode: json['pinCode'] as String? ?? '',
      status: NgoRegistrationStatus.fromString(
        json['status'] as String? ?? 'incomplete',
      ),
      submittedAt: json['submittedAt'] != null
          ? DateTime.tryParse(json['submittedAt'] as String)
          : null,
      reviewedAt: json['reviewedAt'] != null
          ? DateTime.tryParse(json['reviewedAt'] as String)
          : null,
      reviewNotes: json['reviewNotes'] as String?,
      correctionNotes: json['correctionNotes'] as String?,
    );
  }
}
