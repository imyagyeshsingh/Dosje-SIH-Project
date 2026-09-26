import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/theme/colors.dart';
import '../../../../app/theme/typography.dart';
import '../../../../app/theme/spacing.dart';
import '../../../../shared/models/ngo_registration_status.dart';
import '../../../../shared/providers/core_providers.dart';
import '../../../../shared/widgets/civic_app_bar.dart';
import '../../../../shared/widgets/civic_card.dart';
import '../../../../shared/widgets/civic_button.dart';
import '../../../../shared/widgets/status_chip.dart';

class RegistrationUnderReviewScreen extends ConsumerWidget {
  const RegistrationUnderReviewScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: const CivicAppBar(
        title: 'Application Under Review',
        showEmblem: true,
        automaticallyImplyLeading: false,
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.screenMargin),
          child: Column(
            children: [
              const Spacer(),
              Container(
                width: 72,
                height: 72,
                decoration: const BoxDecoration(
                  color: AppColors.warningBg,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.policy_outlined,
                  size: 40,
                  color: AppColors.saffron,
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              Text(
                'Verification in Progress',
                style: AppTypography.headlineSm.copyWith(
                  color: AppColors.primaryContainer,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                'Department officers are reviewing your organization credentials and registered facilities against state welfare records.',
                style: AppTypography.bodyMd.copyWith(
                  color: AppColors.onSurfaceVariant,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: AppSpacing.lg),

              CivicCard(
                leadingStripeColor: AppColors.saffron,
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: const [
                        Text('Status:'),
                        StatusChip(
                          label: 'Under Review',
                          variant: ChipVariant.warning,
                          icon: Icons.hourglass_bottom,
                        ),
                      ],
                    ),
                    const Divider(height: 24),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Assigned Desk:', style: AppTypography.bodySm),
                        Text(
                          'State Nodal Directorate',
                          style: AppTypography.labelMd.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Estimated Turnaround:',
                          style: AppTypography.bodySm,
                        ),
                        Text(
                          '1 - 2 Business Days',
                          style: AppTypography.labelMd,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const Spacer(),

              // Testing trigger: Approve to go to NGO portal, or Correction Required
              CivicButton(
                label: 'Simulate Approval → Enter Portal',
                icon: Icons.verified_outlined,
                onPressed: () {
                  ref
                      .read(authStateProvider.notifier)
                      .updateNgoRegistrationStatus(
                        NgoRegistrationStatus.approved,
                      );
                  context.go('/ngo/home');
                },
              ),
              const SizedBox(height: AppSpacing.sm),
              CivicButton(
                label: 'Simulate Correction Required',
                type: ButtonType.secondary,
                onPressed: () {
                  ref
                      .read(authStateProvider.notifier)
                      .updateNgoRegistrationStatus(
                        NgoRegistrationStatus.correctionRequired,
                      );
                  context.go('/ngo/onboarding/correction');
                },
              ),
              const SizedBox(height: AppSpacing.sm),
              CivicButton(
                label: 'Sign Out',
                type: ButtonType.outline,
                onPressed: () {
                  ref.read(authStateProvider.notifier).signOut();
                  context.go('/login');
                },
              ),
              const SizedBox(height: AppSpacing.md),
            ],
          ),
        ),
      ),
    );
  }
}
