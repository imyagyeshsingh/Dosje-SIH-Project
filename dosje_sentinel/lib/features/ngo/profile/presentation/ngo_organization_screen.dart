import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/theme/colors.dart';
import '../../../../app/theme/spacing.dart';
import '../../../../app/theme/typography.dart';
import '../../../../shared/models/ngo_profile_model.dart';
import '../../../../shared/providers/core_providers.dart';
import '../../../../shared/widgets/civic_app_bar.dart';
import '../../../../shared/widgets/civic_card.dart';
import '../../../../shared/widgets/loading_skeleton.dart';
import '../../../../shared/widgets/status_chip.dart';

class NgoOrganizationScreen extends ConsumerWidget {
  const NgoOrganizationScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ngoRepo = ref.watch(ngoRepositoryProvider);

    return Scaffold(
      backgroundColor: AppColors.surfaceCanvas,
      appBar: const CivicAppBar(
        title: 'Organization Registry',
        showProfileAvatar: false,
      ),
      body: FutureBuilder<NgoProfileModel?>(
        future: ngoRepo.getMyProfile(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Padding(
              padding: EdgeInsets.all(AppSpacing.screenMargin),
              child: LoadingSkeleton(count: 4, height: 90),
            );
          }

          final profile = snapshot.data;
          if (profile == null) {
            return const Center(child: Text('No organization profile found'));
          }

          return SingleChildScrollView(
            padding: const EdgeInsets.all(AppSpacing.screenMargin),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CivicCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Text(
                              profile.organizationName,
                              style: AppTypography.headlineSm.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          StatusChip(
                            label: profile.status.displayName,
                            variant: profile.status.isApproved
                                ? ChipVariant.success
                                : ChipVariant.warning,
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Org Type: ${profile.organizationType}',
                        style: AppTypography.bodySm.copyWith(
                          color: AppColors.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: 16),
                      const Divider(color: AppColors.surfaceContainer),
                      const SizedBox(height: 8),
                      _buildRow(
                        'Registration Number',
                        profile.registrationNumber,
                      ),
                      _buildRow(
                        'Year Established',
                        profile.yearOfEstablishment.toString(),
                      ),
                      _buildRow(
                        'Official Contact',
                        profile.officialContactNumber,
                      ),
                      _buildRow('Official Email', profile.officialEmail),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                CivicCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'REGISTERED OFFICE ADDRESS',
                        style: AppTypography.labelSm.copyWith(
                          color: AppColors.outline,
                        ),
                      ),
                      const SizedBox(height: 12),
                      _buildRow('Street Address', profile.address),
                      _buildRow('District', profile.district),
                      _buildRow('City / Town', profile.city),
                      _buildRow('State / UT', profile.state),
                      _buildRow('Postal PIN Code', profile.pinCode),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                CivicCard(
                  backgroundColor: AppColors.surfaceContainerLow,
                  child: Row(
                    children: [
                      const Icon(
                        Icons.shield_outlined,
                        color: AppColors.primaryContainer,
                        size: 24,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'Verified through authenticated NGO registration workflow. Authorized under Department of Social Justice & Empowerment.',
                          style: AppTypography.caption.copyWith(
                            color: AppColors.primaryNavy,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            flex: 2,
            child: Text(
              label,
              style: AppTypography.caption.copyWith(
                color: AppColors.onSurfaceVariant,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            flex: 3,
            child: Text(
              value,
              style: AppTypography.bodySm.copyWith(
                fontWeight: FontWeight.w600,
                color: AppColors.primaryNavy,
              ),
              textAlign: TextAlign.end,
            ),
          ),
        ],
      ),
    );
  }
}
