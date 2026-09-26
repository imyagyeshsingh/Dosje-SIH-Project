import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/theme/colors.dart';
import '../../../../app/theme/spacing.dart';
import '../../../../app/theme/typography.dart';
import '../../../../shared/models/ngo_registration_status.dart';
import '../../../../shared/providers/core_providers.dart';
import '../../../../shared/widgets/civic_app_bar.dart';
import '../../../../shared/widgets/civic_card.dart';
import '../../../../shared/widgets/status_chip.dart';

class NgoProfileScreen extends ConsumerWidget {
  const NgoProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authNotifierProvider);
    final user = authState.user;
    final ngoRepo = ref.watch(ngoRepositoryProvider);

    return Scaffold(
      backgroundColor: AppColors.surfaceCanvas,
      appBar: const CivicAppBar(
        title: 'Representative Identity',
        showProfileAvatar: false,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpacing.screenMargin),
        child: Column(
          children: [
            // Profile Card Header
            CivicCard(
              child: Column(
                children: [
                  CircleAvatar(
                    radius: 44,
                    backgroundColor: AppColors.primaryContainer,
                    child: Text(
                      user?.name.substring(0, 1).toUpperCase() ?? 'N',
                      style: const TextStyle(
                        fontSize: 32,
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    user?.name ?? 'Dr. Vikramaditya Rathore',
                    style: AppTypography.headlineSm.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Project Director & Nodal Officer',
                    style: AppTypography.bodySm.copyWith(
                      color: AppColors.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    user?.organizationName ??
                        'Samvedna Foundation for Social Care',
                    style: AppTypography.caption.copyWith(
                      color: AppColors.primaryContainer,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 12),
                  const StatusChip(
                    label: 'CLERK SSO VERIFIED',
                    variant: ChipVariant.success,
                    icon: Icons.verified_user_outlined,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Performance & Onboarding Metric
            FutureBuilder(
              future: ngoRepo.getRegistrationStatus(),
              builder: (context, snapshot) {
                final status = snapshot.data ?? NgoRegistrationStatus.approved;
                return CivicCard(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _buildMetric('Active Projects', '3'),
                      Container(
                        width: 1,
                        height: 40,
                        color: AppColors.outlineVariant,
                      ),
                      _buildMetric('Audits Passed', '14'),
                      Container(
                        width: 1,
                        height: 40,
                        color: AppColors.outlineVariant,
                      ),
                      _buildMetric('Onboarding', status.displayName),
                    ],
                  ),
                );
              },
            ),
            const SizedBox(height: 16),

            // Profile Attributes
            CivicCard(
              child: Column(
                children: [
                  _buildListTile(
                    icon: Icons.email_outlined,
                    title: 'Official Email',
                    subtitle: user?.email ?? 'vikramaditya@samvedna.org',
                  ),
                  const Divider(height: 1, color: AppColors.surfaceContainer),
                  _buildListTile(
                    icon: Icons.phone_outlined,
                    title: 'Verified Mobile',
                    subtitle: '+91 98765 43210',
                  ),
                  const Divider(height: 1, color: AppColors.surfaceContainer),
                  _buildListTile(
                    icon: Icons.business_outlined,
                    title: 'Organization Compliance Registry',
                    subtitle: 'View registered legal entities & state licenses',
                    showArrow: true,
                    onTap: () => context.push('/ngo/profile/organization'),
                  ),
                  const Divider(height: 1, color: AppColors.surfaceContainer),
                  _buildListTile(
                    icon: Icons.settings_outlined,
                    title: 'Security & App Preferences',
                    subtitle: 'Biometric locks, sessions, and notifications',
                    showArrow: true,
                    onTap: () => context.push('/ngo/profile/settings'),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Sign Out
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
                'Sign Out',
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

  Widget _buildMetric(String label, String value) {
    return Column(
      children: [
        Text(
          value,
          style: AppTypography.titleMd.copyWith(
            fontWeight: FontWeight.bold,
            color: AppColors.primaryContainer,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: AppTypography.caption.copyWith(color: AppColors.outline),
        ),
      ],
    );
  }

  Widget _buildListTile({
    required IconData icon,
    required String title,
    required String subtitle,
    bool showArrow = false,
    VoidCallback? onTap,
  }) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: AppColors.surfaceContainer,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(icon, color: AppColors.primaryContainer, size: 20),
      ),
      title: Text(
        title,
        style: AppTypography.bodySm.copyWith(fontWeight: FontWeight.w600),
      ),
      subtitle: Text(
        subtitle,
        style: AppTypography.caption.copyWith(
          color: AppColors.onSurfaceVariant,
        ),
      ),
      trailing: showArrow
          ? const Icon(Icons.chevron_right, color: AppColors.outline)
          : null,
      onTap: onTap,
    );
  }
}
