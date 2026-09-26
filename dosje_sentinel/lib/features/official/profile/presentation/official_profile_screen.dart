import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/theme/colors.dart';
import '../../../../app/theme/spacing.dart';
import '../../../../app/theme/typography.dart';
import '../../../../shared/models/permission.dart';
import '../../../../shared/providers/core_providers.dart';
import '../../../../shared/widgets/civic_app_bar.dart';
import '../../../../shared/widgets/civic_card.dart';
import '../../../../shared/widgets/status_chip.dart';

class OfficialProfileScreen extends ConsumerWidget {
  const OfficialProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authNotifierProvider);
    final user = authState.user;

    return Scaffold(
      backgroundColor: AppColors.surfaceCanvas,
      appBar: const CivicAppBar(
        title: 'Official Profile',
        showProfileAvatar: false,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpacing.screenMargin),
        child: Column(
          children: [
            // Directorate Official Card
            CivicCard(
              child: Column(
                children: [
                  CircleAvatar(
                    radius: 40,
                    backgroundColor: AppColors.primaryNavy,
                    child: const Icon(
                      Icons.account_balance,
                      size: 38,
                      color: AppColors.saffron,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    user?.name ?? 'Dr. Ananya Deshmukh, IAS',
                    style: AppTypography.headlineSm.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Joint Secretary & Director General',
                    style: AppTypography.bodySm.copyWith(
                      color: AppColors.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Ministry of Social Justice & Empowerment',
                    style: AppTypography.caption.copyWith(
                      color: AppColors.primaryContainer,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const StatusChip(
                    label: 'DEPARTMENT AUTHORIZED',
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
                    'GRANULAR OFFICIAL RBAC PERMISSIONS',
                    style: AppTypography.labelSm.copyWith(
                      color: AppColors.outline,
                    ),
                  ),
                  const SizedBox(height: 12),
                  _buildPermItem(
                    'View ALL NGOs Directory',
                    user?.hasPermission(AppPermission.viewAllNgos) ?? true,
                  ),
                  _buildPermItem(
                    'View NGO Confidential Profile',
                    user?.hasPermission(AppPermission.viewNgoDetails) ?? true,
                  ),
                  _buildPermItem(
                    'Review NGO Onboarding Applications',
                    user?.hasPermission(AppPermission.reviewNgoRegistration) ??
                        true,
                  ),
                  _buildPermItem(
                    'Approve NGO Registration',
                    user?.hasPermission(AppPermission.approveNgoRegistration) ??
                        true,
                  ),
                  _buildPermItem(
                    'Nationwide CCTV Wall Monitoring',
                    user?.hasPermission(AppPermission.viewCctvStreams) ?? true,
                  ),
                  _buildPermItem(
                    'Backend AI Risk & Anomaly Scoring',
                    user?.hasPermission(AppPermission.viewAiRiskAnalytics) ??
                        true,
                  ),
                  _buildPermItem(
                    'Dispatch Field Inspectors & Randomization',
                    user?.hasPermission(AppPermission.assignInspector) ?? true,
                  ),
                  _buildPermItem(
                    'Sanction Compliance & Grant Clearance',
                    user?.hasPermission(AppPermission.canApproveAudit) ?? true,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Backend Security Details
            CivicCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'AUTHENTICATION & ROLE ENGINE',
                    style: AppTypography.labelSm.copyWith(
                      color: AppColors.outline,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Authoritative Layer', style: AppTypography.bodySm),
                      Text(
                        'FastAPI GET /auth/me',
                        style: AppTypography.caption.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const Divider(height: 20, color: AppColors.surfaceContainer),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Active Database', style: AppTypography.bodySm),
                      Text(
                        'Neon Serverless PostgreSQL',
                        style: AppTypography.caption.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const Divider(height: 20, color: AppColors.surfaceContainer),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Realtime Event Engine',
                        style: AppTypography.bodySm,
                      ),
                      Text(
                        'WebSocket Application Bus',
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
                'Sign Out from Directorate Terminal',
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
