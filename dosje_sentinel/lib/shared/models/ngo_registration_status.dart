/// Registration workflow status for an NGO
enum NgoRegistrationStatus {
  incomplete,
  submitted,
  underReview,
  approved,
  correctionRequired;

  String get label {
    switch (this) {
      case NgoRegistrationStatus.incomplete:
        return 'Incomplete';
      case NgoRegistrationStatus.submitted:
        return 'Submitted';
      case NgoRegistrationStatus.underReview:
        return 'Under Review';
      case NgoRegistrationStatus.approved:
        return 'Approved';
      case NgoRegistrationStatus.correctionRequired:
        return 'Correction Required';
    }
  }

  String get displayName => label;
  bool get isApproved => this == NgoRegistrationStatus.approved;

  static NgoRegistrationStatus fromString(String status) {
    switch (status.toLowerCase()) {
      case 'incomplete':
        return NgoRegistrationStatus.incomplete;
      case 'submitted':
        return NgoRegistrationStatus.submitted;
      case 'underreview':
      case 'under_review':
        return NgoRegistrationStatus.underReview;
      case 'approved':
        return NgoRegistrationStatus.approved;
      case 'correctionrequired':
      case 'correction_required':
        return NgoRegistrationStatus.correctionRequired;
      default:
        return NgoRegistrationStatus.incomplete;
    }
  }
}
