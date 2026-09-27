import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/theme/colors.dart';
import '../../../../app/theme/typography.dart';
import '../../../../app/theme/spacing.dart';
import '../../../../shared/models/ngo_profile_model.dart';
import '../../../../shared/widgets/civic_app_bar.dart';
import '../../../../shared/widgets/civic_card.dart';
import '../../../../shared/widgets/civic_button.dart';
import '../../../../shared/providers/core_providers.dart';
import '../providers/ngo_registration_provider.dart';

class NgoRegistrationScreen extends ConsumerStatefulWidget {
  const NgoRegistrationScreen({super.key});

  @override
  ConsumerState<NgoRegistrationScreen> createState() =>
      _NgoRegistrationScreenState();
}

class _NgoRegistrationScreenState extends ConsumerState<NgoRegistrationScreen> {
  final _formKey = GlobalKey<FormState>();

  // Representative Controllers
  final _nameController = TextEditingController();
  final _designationController = TextEditingController();
  final _mobileController = TextEditingController();
  final _emailController = TextEditingController();

  // Organization Controllers
  final _orgNameController = TextEditingController();
  final _orgTypeController = TextEditingController();
  final _regNumController = TextEditingController();
  final _yearController = TextEditingController();
  final _orgPhoneController = TextEditingController();
  final _orgEmailController = TextEditingController();

  // Address Controllers
  final _addressController = TextEditingController();
  final _stateController = TextEditingController();
  final _districtController = TextEditingController();
  final _cityController = TextEditingController();
  final _pinController = TextEditingController();

  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    final user = ref.read(authStateProvider).user;
    if (user != null && user.email.isNotEmpty) {
      _emailController.text = user.email;
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _designationController.dispose();
    _mobileController.dispose();
    _emailController.dispose();
    _orgNameController.dispose();
    _orgTypeController.dispose();
    _regNumController.dispose();
    _yearController.dispose();
    _orgPhoneController.dispose();
    _orgEmailController.dispose();
    _addressController.dispose();
    _stateController.dispose();
    _districtController.dispose();
    _cityController.dispose();
    _pinController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSubmitting = true);
    try {
      final profile = NgoProfileModel(
        id: 'ngo_${DateTime.now().millisecondsSinceEpoch}',
        fullName: _nameController.text.trim(),
        designation: _designationController.text.trim(),
        mobileNumber: _mobileController.text.trim(),
        email: _emailController.text.trim(),
        ngoName: _orgNameController.text.trim(),
        organizationType: _orgTypeController.text.trim(),
        registrationNumber: _regNumController.text.trim(),
        establishmentYear: int.tryParse(_yearController.text.trim()) ?? 2020,
        contactNumber: _orgPhoneController.text.trim(),
        officialEmail: _orgEmailController.text.trim(),
        address: _addressController.text.trim(),
        state: _stateController.text.trim(),
        district: _districtController.text.trim(),
        city: _cityController.text.trim(),
        pinCode: _pinController.text.trim(),
      );

      await ref
          .read(ngoRegistrationProvider.notifier)
          .submitRegistration(profile);
      if (mounted) {
        context.go('/ngo/onboarding/submitted');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Registration submission failed: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const CivicAppBar(
        title: 'NGO Registration',
        subtitle: 'Official Onboarding Dossier',
        showEmblem: true,
      ),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.all(AppSpacing.screenMargin),
            children: [
              // Header Card
              CivicCard(
                leadingStripeColor: AppColors.saffron,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(
                          Icons.app_registration,
                          color: AppColors.saffron,
                          size: 22,
                        ),
                        const SizedBox(width: AppSpacing.sm),
                        Text(
                          'Organization Enrollment',
                          style: AppTypography.titleMd.copyWith(
                            color: AppColors.primaryContainer,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      'Please complete your NGO registration profile. Upon submission, the Department will verify your credentials.',
                      style: AppTypography.bodySm,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.md),

              // Section 1: Representative Information
              _buildSectionHeader(
                '1. Representative Information (Verified)',
              ),
              CivicCard(
                child: Column(
                  children: [
                    _buildTextField(
                      controller: _nameController,
                      label: 'Full Name *',
                      icon: Icons.person_outline,
                      validator: (v) =>
                          v?.isEmpty == true ? 'Name is required' : null,
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    _buildTextField(
                      controller: _designationController,
                      label: 'Designation / Role *',
                      icon: Icons.badge_outlined,
                      validator: (v) =>
                          v?.isEmpty == true ? 'Designation is required' : null,
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    _buildTextField(
                      controller: _mobileController,
                      label: 'Mobile Number *',
                      icon: Icons.phone_android,
                      keyboardType: TextInputType.phone,
                      validator: (v) =>
                          v?.isEmpty == true ? 'Mobile is required' : null,
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    _buildTextField(
                      controller: _emailController,
                      label: 'Official Email (Verified)',
                      icon: Icons.mail_outline,
                      readOnly: true,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.md),

              // Section 2: Organization Information
              _buildSectionHeader('2. Organization Details'),
              CivicCard(
                child: Column(
                  children: [
                    _buildTextField(
                      controller: _orgNameController,
                      label: 'NGO / Organization Name *',
                      icon: Icons.corporate_fare,
                      validator: (v) => v?.isEmpty == true
                          ? 'Organization Name is required'
                          : null,
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    _buildTextField(
                      controller: _orgTypeController,
                      label: 'Organization Type *',
                      icon: Icons.category_outlined,
                      validator: (v) =>
                          v?.isEmpty == true ? 'Type is required' : null,
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    _buildTextField(
                      controller: _regNumController,
                      label: 'Registration Number *',
                      icon: Icons.confirmation_number_outlined,
                      validator: (v) => v?.isEmpty == true
                          ? 'Registration number is required'
                          : null,
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    _buildTextField(
                      controller: _yearController,
                      label: 'Year of Establishment *',
                      icon: Icons.calendar_today_outlined,
                      keyboardType: TextInputType.number,
                      validator: (v) =>
                          v?.isEmpty == true ? 'Year is required' : null,
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    _buildTextField(
                      controller: _orgPhoneController,
                      label: 'Official Contact Number *',
                      icon: Icons.phone_outlined,
                      keyboardType: TextInputType.phone,
                      validator: (v) => v?.isEmpty == true
                          ? 'Contact number is required'
                          : null,
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    _buildTextField(
                      controller: _orgEmailController,
                      label: 'Official Organization Email *',
                      icon: Icons.alternate_email,
                      keyboardType: TextInputType.emailAddress,
                      validator: (v) =>
                          v?.isEmpty == true ? 'Email is required' : null,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.md),

              // Section 3: Registered Address
              _buildSectionHeader('3. Registered Office Address'),
              CivicCard(
                child: Column(
                  children: [
                    _buildTextField(
                      controller: _addressController,
                      label: 'Street / Plot Address *',
                      icon: Icons.location_on_outlined,
                      validator: (v) =>
                          v?.isEmpty == true ? 'Address is required' : null,
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    Row(
                      children: [
                        Expanded(
                          child: _buildTextField(
                            controller: _stateController,
                            label: 'State *',
                            validator: (v) =>
                                v?.isEmpty == true ? 'State is required' : null,
                          ),
                        ),
                        const SizedBox(width: AppSpacing.sm),
                        Expanded(
                          child: _buildTextField(
                            controller: _districtController,
                            label: 'District *',
                            validator: (v) => v?.isEmpty == true
                                ? 'District is required'
                                : null,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    Row(
                      children: [
                        Expanded(
                          child: _buildTextField(
                            controller: _cityController,
                            label: 'City *',
                            validator: (v) =>
                                v?.isEmpty == true ? 'City is required' : null,
                          ),
                        ),
                        const SizedBox(width: AppSpacing.sm),
                        Expanded(
                          child: _buildTextField(
                            controller: _pinController,
                            label: 'PIN Code *',
                            keyboardType: TextInputType.number,
                            validator: (v) =>
                                v?.isEmpty == true ? 'PIN is required' : null,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.xl),

              // Submit Action
              CivicButton(
                label: 'Submit Registration Dossier',
                icon: Icons.check_circle_outline,
                isLoading: _isSubmitting,
                onPressed: _submit,
              ),
              const SizedBox(height: AppSpacing.lg),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.xs, left: 4),
      child: Text(
        title,
        style: AppTypography.labelLg.copyWith(
          color: AppColors.primaryContainer,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    IconData? icon,
    bool readOnly = false,
    TextInputType? keyboardType,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      readOnly: readOnly,
      keyboardType: keyboardType,
      validator: validator,
      style: AppTypography.bodyMd,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: icon != null
            ? Icon(icon, size: 20, color: AppColors.onSurfaceVariant)
            : null,
        filled: true,
        fillColor: readOnly
            ? AppColors.surfaceContainerHigh.withOpacity(0.5)
            : AppColors.surfaceLow,
      ),
    );
  }
}
