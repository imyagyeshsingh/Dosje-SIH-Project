import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/theme/colors.dart';
import '../../../../app/theme/typography.dart';
import '../../../../app/theme/spacing.dart';
import '../../../../shared/models/permission.dart';
import '../../../../shared/models/ngo_registration_status.dart';
import '../../../../shared/providers/core_providers.dart';
import '../../../../shared/widgets/civic_app_bar.dart';
import '../../../../shared/widgets/civic_card.dart';
import '../../../../shared/widgets/civic_button.dart';
import '../../../../shared/widgets/status_chip.dart';
import '../../../../shared/widgets/loading_skeleton.dart';
import '../../../../shared/widgets/error_state_view.dart';
import '../providers/official_ngos_provider.dart';

class NgoDetailsScreen extends ConsumerWidget {
  final String ngoId;

  const NgoDetailsScreen({super.key, required this.ngoId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authStateProvider);
    final canViewDetails = authState.hasPermission(Permission.viewNgoDetails);

    if (!canViewDetails) {
      return const Scaffold(
        appBar: CivicAppBar(title: 'NGO Dossier'),
        body: ErrorStateView(
          title: 'Permission Denied',
          message:
              'Your official credentials lack the viewNgoDetails permission.',
        ),
      );
    }

    final ngoAsync = ref.watch(ngoDetailProvider(ngoId));
    final canReview = authState.hasPermission(Permission.reviewNgoRegistration);

    return Scaffold(
      appBar: const CivicAppBar(
        title: 'NGO Organization Dossier',
        subtitle: 'Verified Record Details',
      ),
      body: SafeArea(
        child: ngoAsync.when(
          loading: () => const Center(child: LoadingSkeletonCard(height: 250)),
          error: (e, _) => ErrorStateView(message: e.toString()),
          data: (ngo) {
            if (ngo == null) {
              return const ErrorStateView(message: 'NGO record not found.');
            }

            return ListView(
              padding: const EdgeInsets.all(AppSpacing.screenMargin),
              children: [
                // Top Org Header
                CivicCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Text(
                              ngo.ngoName,
                              style: AppTypography.headlineSm.copyWith(
                                color: AppColors.primaryContainer,
                              ),
                            ),
                          ),
                          StatusChip(
                            label: ngo.status.label,
                            variant:
                                ngo.status == NgoRegistrationStatus.approved
                                ? ChipVariant.success
                                : ChipVariant.warning,
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Type: ${ngo.organizationType} • Reg #: ${ngo.registrationNumber}',
                        style: AppTypography.bodySm,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Established: ${ngo.establishmentYear}',
                        style: AppTypography.bodySm,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.md),

                // Representative Information
                _buildSectionHeader('Authorized Representative'),
                CivicCard(
                  child: Column(
                    children: [
                      _buildInfoRow(
                        'Name',
                        ngo.fullName,
                        icon: Icons.person_outline,
                      ),
                      const Divider(height: 16),
                      _buildInfoRow(
                        'Designation',
                        ngo.designation,
                        icon: Icons.badge_outlined,
                      ),
                      const Divider(height: 16),
                      _buildInfoRow(
                        'Mobile Number',
                        ngo.mobileNumber,
                        icon: Icons.phone_android,
                      ),
                      const Divider(height: 16),
                      _buildInfoRow(
                        'Official Email',
                        ngo.email,
                        icon: Icons.mail_outline,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.md),

                // Contact & Address
                _buildSectionHeader('Registered Office & Contact'),
                CivicCard(
                  child: Column(
                    children: [
                      _buildInfoRow(
                        'Office Contact',
                        ngo.contactNumber,
                        icon: Icons.phone,
                      ),
                      const Divider(height: 16),
                      _buildInfoRow(
                        'Organization Email',
                        ngo.officialEmail,
                        icon: Icons.alternate_email,
                      ),
                      const Divider(height: 16),
                      _buildInfoRow(
                        'Address',
                        '${ngo.address}, ${ngo.city}, ${ngo.district}, ${ngo.state} - ${ngo.pinCode}',
                        icon: Icons.location_on_outlined,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.md),

                // Review Status Notes
                if (ngo.reviewNotes != null || ngo.correctionNotes != null) ...[
                  _buildSectionHeader('Administrative Review Log'),
                  CivicCard(
                    leadingStripeColor:
                        ngo.status == NgoRegistrationStatus.correctionRequired
                        ? AppColors.error
                        : AppColors.saffron,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (ngo.reviewNotes != null) ...[
                          Text('Review Notes:', style: AppTypography.labelMd),
                          const SizedBox(height: 2),
                          Text(ngo.reviewNotes!, style: AppTypography.bodySm),
                        ],
                        if (ngo.correctionNotes != null) ...[
                          const SizedBox(height: 8),
                          Text(
                            'Requested Corrections:',
                            style: AppTypography.labelMd.copyWith(
                              color: AppColors.error,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            ngo.correctionNotes!,
                            style: AppTypography.bodySm,
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: AppSpacing.lg),
                ],

                // Action to Review & Sanction
                if (canReview &&
                    ngo.status != NgoRegistrationStatus.approved) ...[
                  CivicButton(
                    label: 'Conduct Official Registration Review',
                    icon: Icons.rate_review_outlined,
                    onPressed: () {
                      context.push('/official/ngos/$ngoId/review');
                    },
                  ),
                ],
                const SizedBox(height: AppSpacing.xl),
              ],
            );
          },
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

  Widget _buildInfoRow(String label, String value, {IconData? icon}) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (icon != null) ...[
          Icon(icon, size: 16, color: AppColors.outline),
          const SizedBox(width: 8),
        ],
        SizedBox(width: 110, child: Text(label, style: AppTypography.bodySm)),
        Expanded(
          child: Text(
            value,
            style: AppTypography.bodyMd.copyWith(
              color: AppColors.onSurface,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ],
    );
  }
}
