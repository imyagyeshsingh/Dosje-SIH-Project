import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/theme/colors.dart';
import '../../../../app/theme/spacing.dart';
import '../../../../app/theme/typography.dart';
import '../../../../shared/providers/core_providers.dart';
import '../../../../shared/widgets/civic_app_bar.dart';
import '../../../../shared/widgets/civic_card.dart';
import '../../../../shared/widgets/status_chip.dart';

class InspectorProfileScreen extends ConsumerWidget {
  const InspectorProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authNotifierProvider);
    final user = authState.user;

    return Scaffold(
      backgroundColor: AppColors.surfaceCanvas,
      appBar: const CivicAppBar(
        title: 'Inspector Profile',
        showProfileAvatar: false,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpacing.screenMargin),
        child: Column(
          children: [
            // Inspector Badge Card
            CivicCard(
              child: Column(
                children: [
                  CircleAvatar(
                    radius: 40,
                    backgroundColor: AppColors.primaryContainer,
                    child: const Icon(
                      Icons.badge_outlined,
                      size: 40,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    user?.name ?? 'Inspector Rajesh Kumar',
                    style: AppTypography.headlineSm.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Senior PMU Field Officer • Zone North',
                    style: AppTypography.bodySm.copyWith(
                      color: AppColors.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const StatusChip(
                    label: 'GOVT CREDENTIAL VERIFIED',
                    variant: ChipVariant.success,
                    icon: Icons.verified_user,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Official Authorized Permissions
            CivicCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'AUTHORIZED FIELD PERMISSIONS',
                    style: AppTypography.labelSm.copyWith(
                      color: AppColors.outline,
                    ),
                  ),
                  const SizedBox(height: 12),
                  _buildPermItem('Conduct On-Site Physical Audits', true),
                  _buildPermItem('Initiate Surprise Video Calls', true),
                  _buildPermItem('Upload Server-Signed Evidence', true),
                  _buildPermItem('Draft & Submit Discrepancy Dossiers', true),
                  _buildPermItem(
                    'Sanction Departmental Grants (Official Only)',
                    false,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Device Telemetry Status
            CivicCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'DEVICE & SECURITY TELEMETRY',
                    style: AppTypography.labelSm.copyWith(
                      color: AppColors.outline,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('GNSS Hardware Lock', style: AppTypography.bodySm),
                      const StatusChip(
                        label: 'ACTIVE',
                        variant: ChipVariant.success,
                      ),
                    ],
                  ),
                  const Divider(height: 20, color: AppColors.surfaceContainer),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Backend API Auth', style: AppTypography.bodySm),
                      Text(
                        'FastAPI /auth/me',
                        style: AppTypography.caption.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Logout Button
            OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                minimumSize: const Size.fromHeight(AppSpacing.buttonHeight),
                side: const BorderSide(color: AppColors.error),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppSpacing.buttonRadius),
                ),
              ),
              icon: const Icon(Icons.logout, color: AppColors.error),
              label: Text(
                'Sign Out from PMU Terminal',
                style: AppTypography.labelMd.copyWith(color: AppColors.error),
              ),
              onPressed: () async {
                await ref.read(authNotifierProvider.notifier).logout();
                if (context.mounted) {
                  context.go('/login');
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPermItem(String label, bool isGranted) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(
            isGranted ? Icons.check_circle : Icons.cancel_outlined,
            size: 16,
            color: isGranted ? AppColors.success : AppColors.outline,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              label,
              style: AppTypography.bodySm.copyWith(
                color: isGranted ? AppColors.onSurface : AppColors.outline,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
